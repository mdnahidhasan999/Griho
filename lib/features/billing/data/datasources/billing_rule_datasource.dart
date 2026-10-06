import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/create_billing_rule_request.dart';
import '../../domain/entities/update_billing_rule_request.dart';
import '../models/billing_rule_model.dart';

class BillingRuleDataSource {
  final FirebaseFirestore _firestore;

  BillingRuleDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'billingRules';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionName);

  // ==========================================================================
  // CREATE
  // ==========================================================================

  Future<BillingRuleModel> createBillingRule({
    required CreateBillingRuleRequest request,
  }) async {
    final ownerId = request.ownerId.trim();
    final propertyId = request.propertyId.trim();
    final scopeId = request.scopeId.trim();

    _validateRequiredId(ownerId, 'Owner ID');
    _validateRequiredId(propertyId, 'Property ID');
    _validateRequiredId(scopeId, 'Billing scope ID');

    _validateAmount(
      valueType: request.valueType,
      amount: request.amount,
    );

    _validateTitle(
      chargeType: request.chargeType,
      title: request.title,
    );

    _validateEffectiveDates(
      effectiveFrom: request.effectiveFrom,
      effectiveTo: request.effectiveTo,
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

    final previousRule = _findPreviousRule(
      rules: relatedRules,
      effectiveFrom: request.effectiveFrom,
    );

    final nextRule = _findNextRule(
      rules: relatedRules,
      effectiveFrom: request.effectiveFrom,
    );

    _validateNewRuleVersion(
      rules: relatedRules,
      effectiveFrom: request.effectiveFrom,
      effectiveTo: request.effectiveTo,
    );

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
      effectiveFrom: request.effectiveFrom,
      effectiveTo: request.effectiveTo,
      isActive: request.isActive,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.runTransaction(
          (transaction) async {
        BillingRuleModel? currentPreviousRule;

        if (previousRule != null &&
            _shouldClosePreviousRule(
              previousRule,
              request.effectiveFrom,
            )) {
          final previousDocument = _collection.doc(previousRule.id);

          final previousSnapshot = await transaction.get(
            previousDocument,
          );

          if (!previousSnapshot.exists) {
            throw StateError(
              'The previous billing rule no longer exists.',
            );
          }

          currentPreviousRule =
              BillingRuleModel.fromFirestore(previousSnapshot);

          _validatePreviousRuleStillMatches(
            currentPreviousRule,
            previousRule,
            request.effectiveFrom,
          );
        }

        if (nextRule != null) {
          final nextDocument = _collection.doc(nextRule.id);

          final nextSnapshot = await transaction.get(
            nextDocument,
          );

          if (!nextSnapshot.exists) {
            throw StateError(
              'The future billing rule no longer exists.',
            );
          }

          final currentNextRule =
          BillingRuleModel.fromFirestore(nextSnapshot);

          if (!currentNextRule.effectiveFrom.isAtSameMomentAs(
            nextRule.effectiveFrom,
          )) {
            throw StateError(
              'The future billing rule changed while '
                  'the operation was being processed.',
            );
          }
        }

        if (currentPreviousRule != null) {
          transaction.update(
            _collection.doc(currentPreviousRule.id),
            {
              'effectiveTo': Timestamp.fromDate(
                request.effectiveFrom,
              ),
              'isActive': false,
              'updatedAt': Timestamp.fromDate(now),
            },
          );
        }

        transaction.set(
          newDocument,
          newRule.toFirestore(),
        );
      },
    );

    return newRule;
  }

  // ==========================================================================
  // GET BY ID
  // ==========================================================================

  Future<BillingRuleModel?> getBillingRuleById(String ruleId,) async {
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

  // ==========================================================================
  // PROPERTY RULES
  // ==========================================================================

  Future<List<BillingRuleModel>> getPropertyBillingRules({
    required String ownerId,
    required String propertyId,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    final normalizedPropertyId = propertyId.trim();

    _validateRequiredId(normalizedOwnerId, 'Owner ID');
    _validateRequiredId(normalizedPropertyId, 'Property ID');

    final snapshot = await _collection
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'propertyId',
      isEqualTo: normalizedPropertyId,
    )
        .get();

    final rules = snapshot.docs
        .map(BillingRuleModel.fromFirestore)
        .toList();

    rules.sort(
          (a, b) =>
          b.effectiveFrom.compareTo(
            a.effectiveFrom,
          ),
    );

    return rules;
  }

  // ==========================================================================
  // RULES APPLICABLE TO A DATE
  // ==========================================================================

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

      // effectiveFrom = inclusive
      if (date.isBefore(rule.effectiveFrom)) {
        return false;
      }

      // effectiveTo = exclusive
      if (rule.effectiveTo != null &&
          !date.isBefore(rule.effectiveTo!)) {
        return false;
      }

      return true;
    }).toList();
  }

  // ==========================================================================
  // UPDATE
  // ==========================================================================

  Future<BillingRuleModel> updateBillingRule({
    required UpdateBillingRuleRequest request,
  }) async {
    final ruleId = request.ruleId.trim();
    final ownerId = request.ownerId.trim();

    _validateRequiredId(ruleId, 'Billing rule ID');
    _validateRequiredId(ownerId, 'Owner ID');

    _validateAmount(
      valueType: request.valueType,
      amount: request.amount,
    );

    _validateTitle(
      chargeType: request.chargeType,
      title: request.title,
    );

    _validateEffectiveDates(
      effectiveFrom: request.effectiveFrom,
      effectiveTo: request.effectiveTo,
    );

    final document = _collection.doc(ruleId);
    final existingSnapshot = await document.get();

    if (!existingSnapshot.exists) {
      throw StateError('Billing rule not found.');
    }

    final existingRule =
    BillingRuleModel.fromFirestore(existingSnapshot);

    if (existingRule.ownerId != ownerId) {
      throw StateError(
        'You are not allowed to update this billing rule.',
      );
    }

    // ------------------------------------------------------------------------
    // Same effectiveFrom = edit existing version.
    // ------------------------------------------------------------------------

    if (existingRule.effectiveFrom.isAtSameMomentAs(
      request.effectiveFrom,
    )) {
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
        effectiveFrom: existingRule.effectiveFrom,
        effectiveTo: request.effectiveTo,
        isActive: request.isActive,
        createdAt: existingRule.createdAt,
        updatedAt: now,
      );

      await document.set(
        updatedRule.toFirestore(),
      );

      return updatedRule;
    }

    // ------------------------------------------------------------------------
    // Moving effectiveFrom forward creates a new version.
    // ------------------------------------------------------------------------

    if (request.effectiveFrom.isBefore(
      existingRule.effectiveFrom,
    )) {
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

    final previousRule = _findPreviousRule(
      rules: relatedRules,
      effectiveFrom: request.effectiveFrom,
      ignoredRuleId: existingRule.id,
    );

    final nextRule = _findNextRule(
      rules: relatedRules,
      effectiveFrom: request.effectiveFrom,
      ignoredRuleId: existingRule.id,
    );

    _validateNewRuleVersion(
      rules: relatedRules,
      effectiveFrom: request.effectiveFrom,
      effectiveTo: request.effectiveTo,
      ignoredRuleId: existingRule.id,
    );

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
      effectiveFrom: request.effectiveFrom,
      effectiveTo: request.effectiveTo,
      isActive: request.isActive,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.runTransaction(
          (transaction) async {
        final currentExistingSnapshot =
        await transaction.get(document);

        if (!currentExistingSnapshot.exists) {
          throw StateError(
            'Billing rule no longer exists.',
          );
        }

        final currentExistingRule =
        BillingRuleModel.fromFirestore(
          currentExistingSnapshot,
        );

        if (currentExistingRule.ownerId != ownerId) {
          throw StateError(
            'You are not allowed to update this billing rule.',
          );
        }

        if (previousRule != null &&
            _shouldClosePreviousRule(
              previousRule,
              request.effectiveFrom,
            )) {
          final previousDocument = _collection.doc(previousRule.id);

          final previousSnapshot = await transaction.get(
            previousDocument,
          );

          if (!previousSnapshot.exists) {
            throw StateError(
              'The previous billing rule no longer exists.',
            );
          }

          final currentPreviousRule =
          BillingRuleModel.fromFirestore(previousSnapshot);

          _validatePreviousRuleStillMatches(
            currentPreviousRule,
            previousRule,
            request.effectiveFrom,
          );

          transaction.update(
            previousDocument,
            {
              'effectiveTo': Timestamp.fromDate(
                request.effectiveFrom,
              ),
              'isActive': false,
              'updatedAt': Timestamp.fromDate(now),
            },
          );
        }

        if (nextRule != null) {
          final nextDocument = _collection.doc(nextRule.id);

          final nextSnapshot = await transaction.get(
            nextDocument,
          );

          if (!nextSnapshot.exists) {
            throw StateError(
              'The future billing rule no longer exists.',
            );
          }
        }

        if (currentExistingRule.effectiveFrom.isBefore(
          request.effectiveFrom,
        ) &&
            (currentExistingRule.effectiveTo == null ||
                request.effectiveFrom.isBefore(
                  currentExistingRule.effectiveTo!,
                ))) {
          transaction.update(
            document,
            {
              'effectiveTo': Timestamp.fromDate(
                request.effectiveFrom,
              ),
              'isActive': false,
              'updatedAt': Timestamp.fromDate(now),
            },
          );
        }

        transaction.set(
          newDocument,
          newRule.toFirestore(),
        );
      },
    );

    return newRule;
  }

  // ==========================================================================
  // DEACTIVATE
  // ==========================================================================

  Future<void> deactivateBillingRule({
    required String ruleId,
    required String ownerId,
  }) async {
    final normalizedRuleId = ruleId.trim();
    final normalizedOwnerId = ownerId.trim();

    _validateRequiredId(
      normalizedRuleId,
      'Billing rule ID',
    );

    _validateRequiredId(
      normalizedOwnerId,
      'Owner ID',
    );

    final document = _collection.doc(normalizedRuleId);
    final snapshot = await document.get();

    if (!snapshot.exists) {
      throw StateError('Billing rule not found.');
    }

    final existingRule =
    BillingRuleModel.fromFirestore(snapshot);

    if (existingRule.ownerId != normalizedOwnerId) {
      throw StateError(
        'You are not allowed to deactivate this billing rule.',
      );
    }

    await document.update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(
        DateTime.now(),
      ),
    });
  }

  // ==========================================================================
  // FIRESTORE QUERY
  // ==========================================================================

  Query<Map<String, dynamic>> _relatedRulesQuery({
    required String ownerId,
    required String propertyId,
    required BillingScopeType scopeType,
    required String scopeId,
    required BillingChargeType chargeType,
  }) {
    return _collection
        .where(
      'ownerId',
      isEqualTo: ownerId,
    )
        .where(
      'propertyId',
      isEqualTo: propertyId,
    )
        .where(
      'scopeType',
      isEqualTo: scopeType.name,
    )
        .where(
      'scopeId',
      isEqualTo: scopeId,
    )
        .where(
      'chargeType',
      isEqualTo: chargeType.name,
    );
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

  // ==========================================================================
  // VERSION RESOLUTION
  // ==========================================================================

  BillingRuleModel? _findPreviousRule({
    required List<BillingRuleModel> rules,
    required DateTime effectiveFrom,
    String? ignoredRuleId,
  }) {
    BillingRuleModel? previous;

    for (final rule in rules) {
      if (ignoredRuleId != null &&
          rule.id == ignoredRuleId) {
        continue;
      }

      if (!rule.effectiveFrom.isBefore(effectiveFrom)) {
        continue;
      }

      if (previous == null ||
          rule.effectiveFrom.isAfter(
            previous.effectiveFrom,
          )) {
        previous = rule;
      }
    }

    return previous;
  }

  BillingRuleModel? _findNextRule({
    required List<BillingRuleModel> rules,
    required DateTime effectiveFrom,
    String? ignoredRuleId,
  }) {
    BillingRuleModel? next;

    for (final rule in rules) {
      if (ignoredRuleId != null &&
          rule.id == ignoredRuleId) {
        continue;
      }

      if (!rule.effectiveFrom.isAfter(effectiveFrom)) {
        continue;
      }

      if (next == null ||
          rule.effectiveFrom.isBefore(
            next.effectiveFrom,
          )) {
        next = rule;
      }
    }

    return next;
  }

  bool _shouldClosePreviousRule(BillingRuleModel previousRule,
      DateTime newEffectiveFrom,) {
    if (previousRule.effectiveTo == null) {
      return true;
    }

    return newEffectiveFrom.isBefore(
      previousRule.effectiveTo!,
    );
  }

  // ==========================================================================
  // VALIDATION
  // ==========================================================================

  void _validateNewRuleVersion({
    required List<BillingRuleModel> rules,
    required DateTime effectiveFrom,
    required DateTime? effectiveTo,
    String? ignoredRuleId,
  }) {
    for (final rule in rules) {
      if (ignoredRuleId != null &&
          rule.id == ignoredRuleId) {
        continue;
      }

      // Same starting point is never allowed.
      if (rule.effectiveFrom.isAtSameMomentAs(
        effectiveFrom,
      )) {
        throw StateError(
          'A billing rule version with the same '
              'effective date already exists.',
        );
      }
    }

    final nextRule = _findNextRule(
      rules: rules,
      effectiveFrom: effectiveFrom,
      ignoredRuleId: ignoredRuleId,
    );

    // A new version cannot extend beyond the next scheduled version.
    if (nextRule != null) {
      if (effectiveTo == null) {
        throw StateError(
          'The new billing rule must end before '
              'the next scheduled billing rule.',
        );
      }

      if (effectiveTo.isAfter(
        nextRule.effectiveFrom,
      )) {
        throw StateError(
          'The new billing rule overlaps a future '
              'billing rule version.',
        );
      }
    }

    final previousRule = _findPreviousRule(
      rules: rules,
      effectiveFrom: effectiveFrom,
      ignoredRuleId: ignoredRuleId,
    );

    // The previous rule is allowed to overlap because
    // this operation will close it at the new effectiveFrom.
    //
    // Any other existing rule that overlaps the new
    // interval is invalid.
    for (final rule in rules) {
      if (ignoredRuleId != null &&
          rule.id == ignoredRuleId) {
        continue;
      }

      if (previousRule != null &&
          rule.id == previousRule.id) {
        continue;
      }

      final existingStart = rule.effectiveFrom;
      final existingEnd = rule.effectiveTo;

      final startsBeforeExistingEnds =
          existingEnd == null ||
              effectiveFrom.isBefore(existingEnd);

      final endsAfterExistingStarts =
          effectiveTo == null ||
              effectiveTo.isAfter(existingStart);

      if (startsBeforeExistingEnds &&
          endsAfterExistingStarts) {
        throw StateError(
          'The new billing rule overlaps an existing '
              'billing rule version.',
        );
      }
    }
  }

  void _validatePreviousRuleStillMatches(BillingRuleModel current,
      BillingRuleModel expected,
      DateTime newEffectiveFrom,) {
    if (current.id != expected.id) {
      throw StateError(
        'Billing rule changed while the operation '
            'was being processed.',
      );
    }

    if (!current.effectiveFrom.isAtSameMomentAs(
      expected.effectiveFrom,
    )) {
      throw StateError(
        'Billing rule effective date changed while '
            'the operation was being processed.',
      );
    }

    if (current.effectiveTo != null &&
        !newEffectiveFrom.isBefore(
          current.effectiveTo!,
        )) {
      throw StateError(
        'Billing rule versions would overlap.',
      );
    }
  }

  void _validateSameVersionUpdate({
    required BillingRuleModel existingRule,
    required UpdateBillingRuleRequest request,
    required List<BillingRuleModel> relatedRules,
  }) {
    for (final rule in relatedRules) {
      if (rule.id == existingRule.id) {
        continue;
      }

      final existingStart = rule.effectiveFrom;
      final existingEnd = rule.effectiveTo;

      final updatedStart = existingRule.effectiveFrom;
      final updatedEnd = request.effectiveTo;

      final startsBeforeExistingEnds =
          existingEnd == null ||
              updatedStart.isBefore(existingEnd);

      final endsAfterExistingStarts =
          updatedEnd == null ||
              updatedEnd.isAfter(existingStart);

      if (startsBeforeExistingEnds &&
          endsAfterExistingStarts) {
        throw StateError(
          'The updated billing rule would overlap '
              'another billing rule version.',
        );
      }
    }
  }

  void _validateRequiredId(String value,
      String label,) {
    if (value
        .trim()
        .isEmpty) {
      throw ArgumentError(
        '$label cannot be empty.',
      );
    }
  }

  void _validateAmount({
    required BillingValueType valueType,
    required double? amount,
  }) {
    switch (valueType) {
      case BillingValueType.fixed:
        if (amount == null || amount < 0) {
          throw ArgumentError(
            'Fixed billing amount must be zero or greater.',
          );
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

    if (title == null || title
        .trim()
        .isEmpty) {
      throw ArgumentError(
        'A title is required for the Other billing type.',
      );
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

  String? _normalizeNullableString(String? value,) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }
}