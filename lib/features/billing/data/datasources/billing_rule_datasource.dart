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

    final effectiveFrom = _normalizeMonthStart(request.effectiveFrom);

    // A variable rule is a one-month override.
    // Its effectiveTo is exclusive and always points to the next month.
    final effectiveTo = request.valueType == BillingValueType.variable
        ? _nextMonthStart(effectiveFrom)
        : request.effectiveTo == null
        ? null
        : _normalizeMonthStart(request.effectiveTo!);

    _validateEffectiveDates(
      effectiveFrom: effectiveFrom,
      effectiveTo: effectiveTo,
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
      effectiveFrom: effectiveFrom,
      effectiveTo: effectiveTo,
      valueType: request.valueType,
    );

    // Only a new Fixed rule can close an earlier Fixed version.
    // A Variable rule must never close the recurring Fixed rule.
    final previousFixedRule = request.valueType == BillingValueType.fixed
        ? _findPreviousRule(
            rules: relatedRules,
            effectiveFrom: effectiveFrom,
            valueType: BillingValueType.fixed,
          )
        : null;

    final nextFixedRule = request.valueType == BillingValueType.fixed
        ? _findNextRule(
            rules: relatedRules,
            effectiveFrom: effectiveFrom,
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
      effectiveFrom: effectiveFrom,
      effectiveTo: effectiveTo,
      isActive: request.isActive,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.runTransaction((transaction) async {
      // Firestore transactions must complete all reads before writes.
      DocumentSnapshot<Map<String, dynamic>>? previousSnapshot;
      DocumentSnapshot<Map<String, dynamic>>? nextSnapshot;

      if (previousFixedRule != null &&
          _shouldClosePreviousRule(previousFixedRule, effectiveFrom)) {
        previousSnapshot = await transaction.get(
          _collection.doc(previousFixedRule.id),
        );

        if (!previousSnapshot.exists) {
          throw StateError('The previous billing rule no longer exists.');
        }

        final currentPreviousRule = BillingRuleModel.fromFirestore(
          previousSnapshot,
        );

        _validatePreviousRuleStillMatches(
          currentPreviousRule,
          previousFixedRule,
          effectiveFrom,
        );
      }

      if (nextFixedRule != null) {
        nextSnapshot = await transaction.get(_collection.doc(nextFixedRule.id));

        if (!nextSnapshot.exists) {
          throw StateError('The future billing rule no longer exists.');
        }

        final currentNextRule = BillingRuleModel.fromFirestore(nextSnapshot);

        if (!currentNextRule.effectiveFrom.isAtSameMomentAs(
          nextFixedRule.effectiveFrom,
        )) {
          throw StateError(
            'The future billing rule changed while '
            'the operation was being processed.',
          );
        }
      }

      // All reads are complete. Writes start here.
      if (previousSnapshot != null && previousFixedRule != null) {
        transaction.update(_collection.doc(previousFixedRule.id), {
          'effectiveTo': Timestamp.fromDate(effectiveFrom),
          'isActive': false,
          'updatedAt': Timestamp.fromDate(now),
        });
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
    final periodStart = _normalizeMonthStart(date);

    final rules = await getPropertyBillingRules(
      ownerId: ownerId,
      propertyId: propertyId,
    );

    return rules.where((rule) {
      // The rule cannot apply before its effective start.
      if (periodStart.isBefore(rule.effectiveFrom)) {
        return false;
      }

      // effectiveTo is exclusive.
      if (rule.effectiveTo != null &&
          !periodStart.isBefore(rule.effectiveTo!)) {
        return false;
      }

      // Inactive Variable rules must never generate new monthly bills.
      // Variable rules are month-specific overrides.
      if (!rule.isActive && rule.valueType == BillingValueType.variable) {
        return false;
      }

      // An inactive Fixed rule with an effectiveTo can represent
      // a historical version that was superseded by a newer Fixed rule.
      //
      // An inactive Fixed rule without an effectiveTo is not applicable.
      if (!rule.isActive &&
          rule.valueType == BillingValueType.fixed &&
          rule.effectiveTo == null) {
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

    final existingDocument = _collection.doc(ruleId);
    final existingSnapshot = await existingDocument.get();

    if (!existingSnapshot.exists) {
      throw StateError('Billing rule not found.');
    }

    final existingRule = BillingRuleModel.fromFirestore(existingSnapshot);

    if (existingRule.ownerId != ownerId) {
      throw StateError('You are not allowed to update this billing rule.');
    }

    // The current Firestore Rules treat these fields as immutable.
    // Changing either field here would create a client/server mismatch.
    if (request.chargeType != existingRule.chargeType) {
      throw StateError(
        'Charge Type cannot be changed on an existing billing rule. '
        'Create a new billing rule instead.',
      );
    }

    if (request.valueType != existingRule.valueType) {
      throw StateError(
        'Value Type cannot be changed on an existing billing rule. '
        'Create a new billing rule instead.',
      );
    }

    _validateAmount(valueType: request.valueType, amount: request.amount);

    _validateTitle(chargeType: request.chargeType, title: request.title);

    final effectiveFrom = _normalizeMonthStart(request.effectiveFrom);

    final effectiveTo = request.valueType == BillingValueType.variable
        ? _nextMonthStart(effectiveFrom)
        : request.effectiveTo == null
        ? null
        : _normalizeMonthStart(request.effectiveTo!);

    _validateEffectiveDates(
      effectiveFrom: effectiveFrom,
      effectiveTo: effectiveTo,
    );

    // -------------------------------------------------------------------------
    // SAME VERSION UPDATE
    // -------------------------------------------------------------------------

    if (existingRule.effectiveFrom.isAtSameMomentAs(effectiveFrom)) {
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
        effectiveFrom: effectiveFrom,
        effectiveTo: effectiveTo,
        relatedRules: relatedRules,
      );

      final now = DateTime.now();

      final updatedRule = BillingRuleModel(
        id: existingRule.id,
        ownerId: existingRule.ownerId,
        propertyId: existingRule.propertyId,
        scopeType: existingRule.scopeType,
        scopeId: existingRule.scopeId,
        chargeType: existingRule.chargeType,
        valueType: existingRule.valueType,
        amount: request.amount,
        title: _normalizeNullableString(request.title),
        effectiveFrom: effectiveFrom,
        effectiveTo: effectiveTo,
        isActive: request.isActive,
        createdAt: existingRule.createdAt,
        updatedAt: now,
      );

      // Update only this rule document. Previously generated monthly bills
      // retain their own amount snapshots.
      await existingDocument.update(updatedRule.toFirestore());

      return updatedRule;
    }

    // -------------------------------------------------------------------------
    // NEW VERSION UPDATE
    // -------------------------------------------------------------------------

    if (effectiveFrom.isBefore(existingRule.effectiveFrom)) {
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
      effectiveFrom: effectiveFrom,
      effectiveTo: effectiveTo,
      valueType: existingRule.valueType,
      ignoredRuleId: existingRule.id,
    );

    final previousFixedRule = existingRule.valueType == BillingValueType.fixed
        ? _findPreviousRule(
            rules: relatedRules,
            effectiveFrom: effectiveFrom,
            valueType: BillingValueType.fixed,
            ignoredRuleId: existingRule.id,
          )
        : null;

    final nextFixedRule = existingRule.valueType == BillingValueType.fixed
        ? _findNextRule(
            rules: relatedRules,
            effectiveFrom: effectiveFrom,
            valueType: BillingValueType.fixed,
            ignoredRuleId: existingRule.id,
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
      chargeType: existingRule.chargeType,
      valueType: existingRule.valueType,
      amount: request.amount,
      title: _normalizeNullableString(request.title),
      effectiveFrom: effectiveFrom,
      effectiveTo: effectiveTo,
      isActive: request.isActive,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.runTransaction((transaction) async {
      // Read every required document before performing any write.
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

      if (currentExistingRule.chargeType != existingRule.chargeType ||
          currentExistingRule.valueType != existingRule.valueType ||
          !currentExistingRule.effectiveFrom.isAtSameMomentAs(
            existingRule.effectiveFrom,
          )) {
        throw StateError(
          'The billing rule changed while the operation '
          'was being processed. Reload it and try again.',
        );
      }

      DocumentSnapshot<Map<String, dynamic>>? previousSnapshot;
      DocumentSnapshot<Map<String, dynamic>>? nextSnapshot;

      if (previousFixedRule != null &&
          _shouldClosePreviousRule(previousFixedRule, effectiveFrom)) {
        previousSnapshot = await transaction.get(
          _collection.doc(previousFixedRule.id),
        );

        if (!previousSnapshot.exists) {
          throw StateError('The previous billing rule no longer exists.');
        }

        final currentPreviousRule = BillingRuleModel.fromFirestore(
          previousSnapshot,
        );

        _validatePreviousRuleStillMatches(
          currentPreviousRule,
          previousFixedRule,
          effectiveFrom,
        );
      }

      if (nextFixedRule != null) {
        nextSnapshot = await transaction.get(_collection.doc(nextFixedRule.id));

        if (!nextSnapshot.exists) {
          throw StateError('The future billing rule no longer exists.');
        }

        final currentNextRule = BillingRuleModel.fromFirestore(nextSnapshot);

        if (!currentNextRule.effectiveFrom.isAtSameMomentAs(
          nextFixedRule.effectiveFrom,
        )) {
          throw StateError(
            'The future billing rule changed while '
            'the operation was being processed.',
          );
        }
      }

      // All transaction reads are complete. Writes start here.
      if (previousSnapshot != null && previousFixedRule != null) {
        transaction.update(_collection.doc(previousFixedRule.id), {
          'effectiveTo': Timestamp.fromDate(effectiveFrom),
          'isActive': false,
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      // When this is a new Fixed version, close the edited Fixed rule if
      // the new version starts during its current effective period.
      //
      // A Variable rule is a one-month override and must not close a Fixed
      // rule. The old Variable version remains available for its own period.
      if (currentExistingRule.valueType == BillingValueType.fixed &&
          currentExistingRule.effectiveFrom.isBefore(effectiveFrom) &&
          (currentExistingRule.effectiveTo == null ||
              effectiveFrom.isBefore(currentExistingRule.effectiveTo!))) {
        transaction.update(existingDocument, {
          'effectiveTo': Timestamp.fromDate(effectiveFrom),
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

    if (!existingRule.isActive) {
      return;
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

      if (sameStart && rule.valueType == valueType) {
        if (valueType == BillingValueType.variable) {
          throw StateError(
            'A variable billing rule already exists for this month.',
          );
        }

        throw StateError(
          'A fixed billing rule version with the same '
          'effective date already exists.',
        );
      }
    }

    // -------------------------------------------------------------------------
    // VARIABLE RULE
    // -------------------------------------------------------------------------
    //
    // Variable rules are one-month overrides.
    // They may overlap Fixed rules but not another Variable rule.
    // -------------------------------------------------------------------------

    if (valueType == BillingValueType.variable) {
      for (final rule in rules) {
        if (ignoredRuleId != null && rule.id == ignoredRuleId) {
          continue;
        }

        if (rule.valueType != BillingValueType.variable) {
          continue;
        }

        if (_periodsOverlap(
          firstStart: effectiveFrom,
          firstEnd: effectiveTo,
          secondStart: rule.effectiveFrom,
          secondEnd: rule.effectiveTo,
        )) {
          throw StateError(
            'The variable billing rule overlaps another '
            'variable billing rule.',
          );
        }
      }

      return;
    }

    // -------------------------------------------------------------------------
    // FIXED RULE
    // -------------------------------------------------------------------------
    //
    // Fixed versions cannot overlap one another.
    // Variable overrides are deliberately excluded from this validation.
    // -------------------------------------------------------------------------

    final fixedRules = rules
        .where(
          (rule) =>
              rule.valueType == BillingValueType.fixed &&
              (ignoredRuleId == null || rule.id != ignoredRuleId),
        )
        .toList();

    final previousFixedRule = _findPreviousRule(
      rules: fixedRules,
      effectiveFrom: effectiveFrom,
      valueType: BillingValueType.fixed,
      ignoredRuleId: ignoredRuleId,
    );

    final nextFixedRule = _findNextRule(
      rules: fixedRules,
      effectiveFrom: effectiveFrom,
      valueType: BillingValueType.fixed,
      ignoredRuleId: ignoredRuleId,
    );

    // A new fixed version must end no later than the next scheduled version.
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
      // The previous version is closed atomically when the new Fixed
      // version is created.
      if (previousFixedRule != null && rule.id == previousFixedRule.id) {
        continue;
      }

      if (_periodsOverlap(
        firstStart: effectiveFrom,
        firstEnd: effectiveTo,
        secondStart: rule.effectiveFrom,
        secondEnd: rule.effectiveTo,
      )) {
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
    if (current.id != expected.id ||
        !current.effectiveFrom.isAtSameMomentAs(expected.effectiveFrom)) {
      throw StateError(
        'Billing rule changed while the operation '
        'was being processed. Reload and try again.',
      );
    }

    if (current.valueType != BillingValueType.fixed ||
        (current.effectiveTo != null &&
            !newEffectiveFrom.isBefore(current.effectiveTo!))) {
      throw StateError('Billing rule versions would overlap.');
    }
  }

  // ===========================================================================
  // SAME VERSION UPDATE VALIDATION
  // ===========================================================================

  void _validateSameVersionUpdate({
    required BillingRuleModel existingRule,
    required DateTime effectiveFrom,
    required DateTime? effectiveTo,
    required List<BillingRuleModel> relatedRules,
  }) {
    for (final rule in relatedRules) {
      if (rule.id == existingRule.id ||
          rule.valueType != existingRule.valueType) {
        continue;
      }

      if (_periodsOverlap(
        firstStart: effectiveFrom,
        firstEnd: effectiveTo,
        secondStart: rule.effectiveFrom,
        secondEnd: rule.effectiveTo,
      )) {
        if (existingRule.valueType == BillingValueType.variable) {
          throw StateError(
            'The updated variable billing rule overlaps '
            'another variable billing rule.',
          );
        }

        throw StateError(
          'The updated fixed billing rule would overlap '
          'another fixed billing rule version.',
        );
      }
    }
  }

  // ===========================================================================
  // PERIOD HELPERS
  // ===========================================================================

  bool _periodsOverlap({
    required DateTime firstStart,
    required DateTime? firstEnd,
    required DateTime secondStart,
    required DateTime? secondEnd,
  }) {
    final firstStartsBeforeSecondEnds =
        secondEnd == null || firstStart.isBefore(secondEnd);

    final firstEndsAfterSecondStarts =
        firstEnd == null || firstEnd.isAfter(secondStart);

    return firstStartsBeforeSecondEnds && firstEndsAfterSecondStarts;
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
        if (amount == null || amount.isNaN || amount.isInfinite || amount < 0) {
          throw ArgumentError(
            'Fixed billing amount must be a valid number '
            'that is zero or greater.',
          );
        }

      case BillingValueType.variable:
        if (amount == null || amount.isNaN || amount.isInfinite || amount < 0) {
          throw ArgumentError(
            'Variable billing amount must be a valid number '
            'that is zero or greater.',
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
        'Effective end date must be after the effective start date.',
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
