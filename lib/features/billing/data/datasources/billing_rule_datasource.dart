import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/create_billing_rule_request.dart';
import '../../domain/entities/update_billing_rule_request.dart';
import '../models/billing_rule_model.dart';

class BillingRuleDataSource {
  final FirebaseFirestore _firestore;

  BillingRuleDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'billingRules';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionName);

  // ===========================================================================
  // CREATE
  // ===========================================================================

  Future<BillingRuleModel> createBillingRule({
    required CreateBillingRuleRequest request,
  }) async {
    final ownerId = request.ownerId.trim();
    final propertyId = request.propertyId.trim();
    final scopeId = request.scopeId.trim();

    _validateRequiredId(ownerId, 'Owner ID');
    _validateRequiredId(propertyId, 'Property ID');
    _validateRequiredId(scopeId, 'Billing scope ID');

    _validateAmount(valueType: request.valueType, amount: request.amount);

    _validateTitle(chargeType: request.chargeType, title: request.title);

    // All billing rules are month-based.
    final normalizedEffectiveFrom = _normalizeMonthStart(request.effectiveFrom);

    // Variable rules are automatically valid for exactly one month.
    //
    // Example:
    // October variable rule:
    // effectiveFrom = 2026-10-01
    // effectiveTo   = 2026-11-01
    //
    // The fixed rule remains active underneath it.
    final normalizedEffectiveTo = request.valueType == BillingValueType.variable
        ? _nextMonthStart(normalizedEffectiveFrom)
        : request.effectiveTo;

    _validateEffectiveDates(
      effectiveFrom: normalizedEffectiveFrom,
      effectiveTo: normalizedEffectiveTo,
    );

    final relatedRulesSnapshot = await _getRelatedRules(
      ownerId: ownerId,
      propertyId: propertyId,
      scopeType: request.scopeType,
      scopeId: scopeId,
      chargeType: request.chargeType,
    );

    final relatedRules = relatedRulesSnapshot.docs
        .map(BillingRuleModel.fromFirestore)
        .toList();

    _validateNewRuleVersion(
      rules: relatedRules,
      effectiveFrom: normalizedEffectiveFrom,
      effectiveTo: normalizedEffectiveTo,
      valueType: request.valueType,
    );

    // Only fixed rules participate in fixed-rule version closing.
    //
    // A variable rule is a monthly override and must NEVER become the
    // previous fixed version that gets closed.
    final previousRule = request.valueType == BillingValueType.fixed
        ? _findPreviousRule(
            rules: relatedRules,
            effectiveFrom: normalizedEffectiveFrom,
            valueType: BillingValueType.fixed,
          )
        : null;

    final nextRule = request.valueType == BillingValueType.fixed
        ? _findNextRule(
            rules: relatedRules,
            effectiveFrom: normalizedEffectiveFrom,
            valueType: BillingValueType.fixed,
          )
        : null;

    final now = DateTime.now();
    final newDocument = _collection.doc();

    final newRule = BillingRuleModel(
      id: newDocument.id,
      ownerId: ownerId,
      propertyId: propertyId,
      scopeType: request.scopeType,
      scopeId: scopeId,
      chargeType: request.chargeType,
      valueType: request.valueType,
      amount: request.amount,
      title: _normalizeNullableString(request.title),
      effectiveFrom: normalizedEffectiveFrom,
      effectiveTo: normalizedEffectiveTo,
      isActive: request.isActive,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.runTransaction((transaction) async {
      if (previousRule != null &&
          _shouldClosePreviousRule(previousRule, normalizedEffectiveFrom)) {
        final previousDocument = _collection.doc(previousRule.id);

        final previousSnapshot = await transaction.get(previousDocument);

        if (!previousSnapshot.exists) {
          throw StateError('The previous billing rule no longer exists.');
        }

        final currentPreviousRule = BillingRuleModel.fromFirestore(
          previousSnapshot,
        );

        _validatePreviousRuleStillMatches(
          currentPreviousRule,
          previousRule,
          normalizedEffectiveFrom,
        );

        transaction.update(previousDocument, {
          'effectiveTo': Timestamp.fromDate(normalizedEffectiveFrom),
          'isActive': false,
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      if (nextRule != null) {
        final nextDocument = _collection.doc(nextRule.id);

        final nextSnapshot = await transaction.get(nextDocument);

        if (!nextSnapshot.exists) {
          throw StateError('The future billing rule no longer exists.');
        }

        final currentNextRule = BillingRuleModel.fromFirestore(nextSnapshot);

        if (!currentNextRule.effectiveFrom.isAtSameMomentAs(
          nextRule.effectiveFrom,
        )) {
          throw StateError(
            'The future billing rule changed while '
            'the operation was being processed.',
          );
        }
      }

      transaction.set(newDocument, newRule.toFirestore());
    });

    return newRule;
  }

  // ===========================================================================
  // GET
  // ===========================================================================

  Future<BillingRuleModel?> getBillingRuleById(String ruleId) async {
    final normalizedId = ruleId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    final document = await _collection.doc(normalizedId).get();

    if (!document.exists) {
      return null;
    }

    return BillingRuleModel.fromFirestore(document);
  }

  Future<List<BillingRuleModel>> getPropertyBillingRules({
    required String ownerId,
    required String propertyId,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    final normalizedPropertyId = propertyId.trim();

    _validateRequiredId(normalizedOwnerId, 'Owner ID');

    _validateRequiredId(normalizedPropertyId, 'Property ID');

    final snapshot = await _collection
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('propertyId', isEqualTo: normalizedPropertyId)
        .get();

    final rules = snapshot.docs.map(BillingRuleModel.fromFirestore).toList();

    rules.sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));

    return rules;
  }

  Future<List<BillingRuleModel>> getBillingRulesForPeriod({
    required String ownerId,
    required String propertyId,
    required DateTime date,
  }) async {
    final rules = await getPropertyBillingRules(
      ownerId: ownerId,
      propertyId: propertyId,
    );

    return rules.where((rule) {
      if (!rule.isActive) {
        return false;
      }

      if (date.isBefore(rule.effectiveFrom)) {
        return false;
      }

      // effectiveTo is EXCLUSIVE.
      if (rule.effectiveTo != null && !date.isBefore(rule.effectiveTo!)) {
        return false;
      }

      return true;
    }).toList();
  }

  // ===========================================================================
  // UPDATE
  // ===========================================================================

  Future<BillingRuleModel> updateBillingRule({
    required UpdateBillingRuleRequest request,
  }) async {
    final ruleId = request.ruleId.trim();
    final ownerId = request.ownerId.trim();

    _validateRequiredId(ruleId, 'Billing rule ID');

    _validateRequiredId(ownerId, 'Owner ID');

    _validateAmount(valueType: request.valueType, amount: request.amount);

    _validateTitle(chargeType: request.chargeType, title: request.title);

    final existingDocument = _collection.doc(ruleId);

    final existingSnapshot = await existingDocument.get();

    if (!existingSnapshot.exists) {
      throw StateError('Billing rule not found.');
    }

    final existingRule = BillingRuleModel.fromFirestore(existingSnapshot);

    if (existingRule.ownerId != ownerId) {
      throw StateError('You are not allowed to update this billing rule.');
    }

    // Month-based effective start.
    final normalizedEffectiveFrom = _normalizeMonthStart(request.effectiveFrom);

    // Variable rules always represent exactly one month.
    final normalizedEffectiveTo = request.valueType == BillingValueType.variable
        ? _nextMonthStart(normalizedEffectiveFrom)
        : request.effectiveTo;

    _validateEffectiveDates(
      effectiveFrom: normalizedEffectiveFrom,
      effectiveTo: normalizedEffectiveTo,
    );

    // -------------------------------------------------------------------------
    // SAME VERSION UPDATE
    // -------------------------------------------------------------------------

    if (existingRule.effectiveFrom.isAtSameMomentAs(normalizedEffectiveFrom)) {
      final relatedRulesSnapshot = await _getRelatedRules(
        ownerId: ownerId,
        propertyId: existingRule.propertyId,
        scopeType: existingRule.scopeType,
        scopeId: existingRule.scopeId,
        chargeType: existingRule.chargeType,
      );

      final relatedRules = relatedRulesSnapshot.docs
          .map(BillingRuleModel.fromFirestore)
          .toList();

      _validateSameVersionUpdate(
        existingRule: existingRule,
        request: request,
        effectiveFrom: normalizedEffectiveFrom,
        effectiveTo: normalizedEffectiveTo,
        relatedRules: relatedRules,
      );

      final now = DateTime.now();

      final updatedRule = BillingRuleModel(
        id: existingRule.id,
        ownerId: existingRule.ownerId,
        propertyId: existingRule.propertyId,
        scopeType: existingRule.scopeType,
        scopeId: existingRule.scopeId,
        chargeType: request.chargeType,
        valueType: request.valueType,
        amount: request.amount,
        title: _normalizeNullableString(request.title),
        effectiveFrom: normalizedEffectiveFrom,
        effectiveTo: normalizedEffectiveTo,
        isActive: request.isActive,
        createdAt: existingRule.createdAt,
        updatedAt: now,
      );

      await existingDocument.set(updatedRule.toFirestore());

      return updatedRule;
    }

    // -------------------------------------------------------------------------
    // NEW VERSION UPDATE
    // -------------------------------------------------------------------------

    if (normalizedEffectiveFrom.isBefore(existingRule.effectiveFrom)) {
      throw ArgumentError(
        'New effective date cannot be before '
        'the existing billing rule effective date.',
      );
    }

    final relatedRulesSnapshot = await _getRelatedRules(
      ownerId: ownerId,
      propertyId: existingRule.propertyId,
      scopeType: existingRule.scopeType,
      scopeId: existingRule.scopeId,
      chargeType: existingRule.chargeType,
    );

    final relatedRules = relatedRulesSnapshot.docs
        .map(BillingRuleModel.fromFirestore)
        .toList();

    _validateNewRuleVersion(
      rules: relatedRules,
      effectiveFrom: normalizedEffectiveFrom,
      effectiveTo: normalizedEffectiveTo,
      valueType: request.valueType,
      ignoredRuleId: existingRule.id,
    );

    // Only fixed rules can close a previous fixed version.
    final previousRule = request.valueType == BillingValueType.fixed
        ? _findPreviousRule(
            rules: relatedRules,
            effectiveFrom: normalizedEffectiveFrom,
            ignoredRuleId: existingRule.id,
            valueType: BillingValueType.fixed,
          )
        : null;

    final nextRule = request.valueType == BillingValueType.fixed
        ? _findNextRule(
            rules: relatedRules,
            effectiveFrom: normalizedEffectiveFrom,
            ignoredRuleId: existingRule.id,
            valueType: BillingValueType.fixed,
          )
        : null;

    final now = DateTime.now();
    final newDocument = _collection.doc();

    final newRule = BillingRuleModel(
      id: newDocument.id,
      ownerId: existingRule.ownerId,
      propertyId: existingRule.propertyId,
      scopeType: existingRule.scopeType,
      scopeId: existingRule.scopeId,
      chargeType: request.chargeType,
      valueType: request.valueType,
      amount: request.amount,
      title: _normalizeNullableString(request.title),
      effectiveFrom: normalizedEffectiveFrom,
      effectiveTo: normalizedEffectiveTo,
      isActive: request.isActive,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.runTransaction((transaction) async {
      final currentExistingSnapshot = await transaction.get(existingDocument);

      if (!currentExistingSnapshot.exists) {
        throw StateError('Billing rule no longer exists.');
      }

      final currentExistingRule = BillingRuleModel.fromFirestore(
        currentExistingSnapshot,
      );

      if (currentExistingRule.ownerId != ownerId) {
        throw StateError('You are not allowed to update this billing rule.');
      }

      if (previousRule != null &&
          _shouldClosePreviousRule(previousRule, normalizedEffectiveFrom)) {
        final previousDocument = _collection.doc(previousRule.id);

        final previousSnapshot = await transaction.get(previousDocument);

        if (!previousSnapshot.exists) {
          throw StateError('The previous billing rule no longer exists.');
        }

        final currentPreviousRule = BillingRuleModel.fromFirestore(
          previousSnapshot,
        );

        _validatePreviousRuleStillMatches(
          currentPreviousRule,
          previousRule,
          normalizedEffectiveFrom,
        );

        transaction.update(previousDocument, {
          'effectiveTo': Timestamp.fromDate(normalizedEffectiveFrom),
          'isActive': false,
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      if (nextRule != null) {
        final nextDocument = _collection.doc(nextRule.id);

        final nextSnapshot = await transaction.get(nextDocument);

        if (!nextSnapshot.exists) {
          throw StateError('The future billing rule no longer exists.');
        }

        final currentNextRule = BillingRuleModel.fromFirestore(nextSnapshot);

        if (!currentNextRule.effectiveFrom.isAtSameMomentAs(
          nextRule.effectiveFrom,
        )) {
          throw StateError(
            'The future billing rule changed while '
            'the operation was being processed.',
          );
        }
      }

      // The existing rule is replaced only when the new version
      // starts after the existing version.
      //
      // Variable rules should not normally close the existing fixed
      // rule because variable rules are monthly overrides.
      if (request.valueType == BillingValueType.fixed &&
          currentExistingRule.valueType == BillingValueType.fixed &&
          currentExistingRule.effectiveFrom.isBefore(normalizedEffectiveFrom) &&
          (currentExistingRule.effectiveTo == null ||
              normalizedEffectiveFrom.isBefore(
                currentExistingRule.effectiveTo!,
              ))) {
        transaction.update(existingDocument, {
          'effectiveTo': Timestamp.fromDate(normalizedEffectiveFrom),
          'isActive': false,
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      transaction.set(newDocument, newRule.toFirestore());
    });

    return newRule;
  }

  // ===========================================================================
  // DEACTIVATE
  // ===========================================================================

  Future<void> deactivateBillingRule({
    required String ruleId,
    required String ownerId,
  }) async {
    final normalizedRuleId = ruleId.trim();
    final normalizedOwnerId = ownerId.trim();

    _validateRequiredId(normalizedRuleId, 'Billing rule ID');

    _validateRequiredId(normalizedOwnerId, 'Owner ID');

    final document = _collection.doc(normalizedRuleId);

    final snapshot = await document.get();

    if (!snapshot.exists) {
      throw StateError('Billing rule not found.');
    }

    final existingRule = BillingRuleModel.fromFirestore(snapshot);

    if (existingRule.ownerId != normalizedOwnerId) {
      throw StateError('You are not allowed to deactivate this billing rule.');
    }

    await document.update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ===========================================================================
  // RELATED RULES
  // ===========================================================================

  Query<Map<String, dynamic>> _relatedRulesQuery({
    required String ownerId,
    required String propertyId,
    required BillingScopeType scopeType,
    required String scopeId,
    required BillingChargeType chargeType,
  }) {
    return _collection
        .where('ownerId', isEqualTo: ownerId)
        .where('propertyId', isEqualTo: propertyId)
        .where('scopeType', isEqualTo: scopeType.name)
        .where('scopeId', isEqualTo: scopeId)
        .where('chargeType', isEqualTo: chargeType.name);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _getRelatedRules({
    required String ownerId,
    required String propertyId,
    required BillingScopeType scopeType,
    required String scopeId,
    required BillingChargeType chargeType,
  }) {
    return _relatedRulesQuery(
      ownerId: ownerId,
      propertyId: propertyId,
      scopeType: scopeType,
      scopeId: scopeId,
      chargeType: chargeType,
    ).get();
  }

  // ===========================================================================
  // RULE VERSION HELPERS
  // ===========================================================================

  BillingRuleModel? _findPreviousRule({
    required List<BillingRuleModel> rules,
    required DateTime effectiveFrom,
    BillingValueType? valueType,
    String? ignoredRuleId,
  }) {
    BillingRuleModel? previous;

    for (final rule in rules) {
      if (ignoredRuleId != null && rule.id == ignoredRuleId) {
        continue;
      }

      if (valueType != null && rule.valueType != valueType) {
        continue;
      }

      if (!rule.effectiveFrom.isBefore(effectiveFrom)) {
        continue;
      }

      if (previous == null ||
          rule.effectiveFrom.isAfter(previous.effectiveFrom)) {
        previous = rule;
      }
    }

    return previous;
  }

  BillingRuleModel? _findNextRule({
    required List<BillingRuleModel> rules,
    required DateTime effectiveFrom,
    BillingValueType? valueType,
    String? ignoredRuleId,
  }) {
    BillingRuleModel? next;

    for (final rule in rules) {
      if (ignoredRuleId != null && rule.id == ignoredRuleId) {
        continue;
      }

      if (valueType != null && rule.valueType != valueType) {
        continue;
      }

      if (!rule.effectiveFrom.isAfter(effectiveFrom)) {
        continue;
      }

      if (next == null || rule.effectiveFrom.isBefore(next.effectiveFrom)) {
        next = rule;
      }
    }

    return next;
  }

  bool _shouldClosePreviousRule(
    BillingRuleModel previousRule,
    DateTime newEffectiveFrom,
  ) {
    // Variable rules are monthly overrides.
    // They must never close the recurring fixed rule.
    if (previousRule.valueType != BillingValueType.fixed) {
      return false;
    }

    if (previousRule.effectiveTo == null) {
      return true;
    }

    return newEffectiveFrom.isBefore(previousRule.effectiveTo!);
  }

  // ===========================================================================
  // NEW RULE VERSION VALIDATION
  // ===========================================================================

  void _validateNewRuleVersion({
    required List<BillingRuleModel> rules,
    required DateTime effectiveFrom,
    required DateTime? effectiveTo,
    required BillingValueType valueType,
    String? ignoredRuleId,
  }) {
    for (final rule in rules) {
      if (ignoredRuleId != null && rule.id == ignoredRuleId) {
        continue;
      }

      final sameStart = rule.effectiveFrom.isAtSameMomentAs(effectiveFrom);

      // Two variable rules cannot start in the same month.
      if (sameStart &&
          valueType == BillingValueType.variable &&
          rule.valueType == BillingValueType.variable) {
        throw StateError(
          'A variable billing rule already exists '
          'for this month.',
        );
      }

      // Two fixed versions cannot start in the same month.
      if (sameStart &&
          valueType == BillingValueType.fixed &&
          rule.valueType == BillingValueType.fixed) {
        throw StateError(
          'A fixed billing rule version with the same '
          'effective date already exists.',
        );
      }
    }

    // =========================================================================
    // VARIABLE RULE
    // =========================================================================
    //
    // Variable rules are monthly overrides.
    //
    // Example:
    //
    // Fixed Water    = 500
    // October Variable Water = actual 600
    //
    // October:
    //   Variable 600 wins.
    //
    // November:
    //   Variable has expired.
    //   Fixed 500 becomes effective again.
    //
    // Therefore variable rules are allowed to overlap fixed rules.
    // They must only be prevented from overlapping another variable rule.
    // =========================================================================

    if (valueType == BillingValueType.variable) {
      for (final rule in rules) {
        if (ignoredRuleId != null && rule.id == ignoredRuleId) {
          continue;
        }

        if (rule.valueType != BillingValueType.variable) {
          continue;
        }

        final existingStart = rule.effectiveFrom;
        final existingEnd = rule.effectiveTo;

        final newEnd = effectiveTo;

        final overlaps =
            (existingEnd == null || effectiveFrom.isBefore(existingEnd)) &&
            (newEnd == null || newEnd.isAfter(existingStart));

        if (overlaps) {
          throw StateError(
            'The variable billing rule overlaps another '
            'variable billing rule.',
          );
        }
      }

      return;
    }

    // =========================================================================
    // FIXED RULE
    // =========================================================================
    //
    // Fixed rules are recurring versions.
    //
    // Variable rules are ignored here because they are temporary monthly
    // overrides and are allowed to coexist with fixed rules.
    // =========================================================================

    final fixedRules = rules.where(
      (rule) =>
          rule.valueType == BillingValueType.fixed &&
          (ignoredRuleId == null || rule.id != ignoredRuleId),
    );

    final nextFixedRule = _findNextRule(
      rules: fixedRules.toList(),
      effectiveFrom: effectiveFrom,
      valueType: BillingValueType.fixed,
      ignoredRuleId: ignoredRuleId,
    );

    if (nextFixedRule != null) {
      if (effectiveTo == null) {
        throw StateError(
          'The new fixed billing rule must end before '
          'the next scheduled fixed billing rule.',
        );
      }

      if (effectiveTo.isAfter(nextFixedRule.effectiveFrom)) {
        throw StateError(
          'The new fixed billing rule overlaps a future '
          'fixed billing rule version.',
        );
      }
    }

    for (final rule in fixedRules) {
      final existingStart = rule.effectiveFrom;
      final existingEnd = rule.effectiveTo;

      final startsBeforeExistingEnds =
          existingEnd == null || effectiveFrom.isBefore(existingEnd);

      final endsAfterExistingStarts =
          effectiveTo == null || effectiveTo.isAfter(existingStart);

      if (startsBeforeExistingEnds && endsAfterExistingStarts) {
        throw StateError(
          'The new fixed billing rule overlaps an existing '
          'fixed billing rule version.',
        );
      }
    }
  }

  // ===========================================================================
  // CONCURRENT UPDATE VALIDATION
  // ===========================================================================

  void _validatePreviousRuleStillMatches(
    BillingRuleModel current,
    BillingRuleModel expected,
    DateTime newEffectiveFrom,
  ) {
    if (current.id != expected.id) {
      throw StateError(
        'Billing rule changed while the operation '
        'was being processed.',
      );
    }

    if (!current.effectiveFrom.isAtSameMomentAs(expected.effectiveFrom)) {
      throw StateError(
        'Billing rule effective date changed while '
        'the operation was being processed.',
      );
    }

    if (current.effectiveTo != null &&
        !newEffectiveFrom.isBefore(current.effectiveTo!)) {
      throw StateError('Billing rule versions would overlap.');
    }
  }

  // ===========================================================================
  // SAME VERSION UPDATE VALIDATION
  // ===========================================================================

  void _validateSameVersionUpdate({
    required BillingRuleModel existingRule,
    required UpdateBillingRuleRequest request,
    required DateTime effectiveFrom,
    required DateTime? effectiveTo,
    required List<BillingRuleModel> relatedRules,
  }) {
    // -------------------------------------------------------------------------
    // VARIABLE UPDATE
    // -------------------------------------------------------------------------
    //
    // A variable rule may coexist with fixed rules.
    // It must not overlap another variable rule.
    // -------------------------------------------------------------------------

    if (request.valueType == BillingValueType.variable) {
      for (final rule in relatedRules) {
        if (rule.id == existingRule.id) {
          continue;
        }

        if (rule.valueType != BillingValueType.variable) {
          continue;
        }

        final existingStart = rule.effectiveFrom;
        final existingEnd = rule.effectiveTo;

        final overlaps =
            (existingEnd == null || effectiveFrom.isBefore(existingEnd)) &&
            (effectiveTo == null || effectiveTo.isAfter(existingStart));

        if (overlaps) {
          throw StateError(
            'The updated variable billing rule overlaps '
            'another variable billing rule.',
          );
        }
      }

      return;
    }

    // -------------------------------------------------------------------------
    // FIXED UPDATE
    // -------------------------------------------------------------------------
    //
    // A fixed rule may coexist with variable rules.
    // Only fixed rules participate in fixed-version overlap validation.
    // -------------------------------------------------------------------------

    for (final rule in relatedRules) {
      if (rule.id == existingRule.id) {
        continue;
      }

      if (rule.valueType != BillingValueType.fixed) {
        continue;
      }

      final existingStart = rule.effectiveFrom;
      final existingEnd = rule.effectiveTo;

      final startsBeforeExistingEnds =
          existingEnd == null || effectiveFrom.isBefore(existingEnd);

      final endsAfterExistingStarts =
          effectiveTo == null || effectiveTo.isAfter(existingStart);

      if (startsBeforeExistingEnds && endsAfterExistingStarts) {
        throw StateError(
          'The updated fixed billing rule would overlap '
          'another fixed billing rule version.',
        );
      }
    }
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  void _validateRequiredId(String value, String label) {
    if (value.trim().isEmpty) {
      throw ArgumentError('$label cannot be empty.');
    }
  }

  void _validateAmount({
    required BillingValueType valueType,
    required double? amount,
  }) {
    switch (valueType) {
      case BillingValueType.fixed:
        if (amount == null || amount < 0) {
          throw ArgumentError('Fixed billing amount must be zero or greater.');
        }

      case BillingValueType.variable:
        if (amount != null) {
          throw ArgumentError(
            'Variable billing rules cannot contain '
            'a fixed amount.',
          );
        }
    }
  }

  void _validateTitle({
    required BillingChargeType chargeType,
    required String? title,
  }) {
    if (chargeType != BillingChargeType.other) {
      return;
    }

    if (title == null || title.trim().isEmpty) {
      throw ArgumentError('A title is required for the Other billing type.');
    }
  }

  void _validateEffectiveDates({
    required DateTime effectiveFrom,
    required DateTime? effectiveTo,
  }) {
    if (effectiveTo == null) {
      return;
    }

    if (!effectiveTo.isAfter(effectiveFrom)) {
      throw ArgumentError(
        'Effective end date must be after '
        'the effective start date.',
      );
    }
  }

  // ===========================================================================
  // DATE HELPERS
  // ===========================================================================

  DateTime _normalizeMonthStart(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _nextMonthStart(DateTime date) {
    return DateTime(date.year, date.month + 1, 1);
  }

  // ===========================================================================
  // STRING HELPERS
  // ===========================================================================

  String? _normalizeNullableString(String? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }
}
