import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/create_billing_rule_request.dart';
import '../../domain/entities/update_billing_rule_request.dart';
import '../models/billing_rule_model.dart';

class BillingRuleDataSource {
  final FirebaseFirestore _firestore;

  BillingRuleDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore =
      firestore ?? FirebaseFirestore.instance;

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

    _validateRequiredId(
      ownerId,
      'Owner ID',
    );

    _validateRequiredId(
      propertyId,
      'Property ID',
    );

    _validateRequiredId(
      scopeId,
      'Billing scope ID',
    );

    _validateAmount(
      valueType: request.valueType,
      amount: request.amount,
    );

    _validateEffectiveDates(
      effectiveFrom: request.effectiveFrom,
      effectiveTo: request.effectiveTo,
    );

    final document = _collection.doc();

    final now = DateTime.now();

    final rule = BillingRuleModel(
      id: document.id,
      ownerId: ownerId,
      propertyId: propertyId,
      scopeType: request.scopeType,
      scopeId: scopeId,
      chargeType: request.chargeType,
      valueType: request.valueType,
      amount: request.amount,
      title: _normalizeNullableString(
        request.title,
      ),
      effectiveFrom: request.effectiveFrom,
      effectiveTo: request.effectiveTo,
      isActive: request.isActive,
      createdAt: now,
      updatedAt: now,
    );

    await document.set(
      rule.toFirestore(),
    );

    return rule;
  }

  // ==========================================================================
  // GET BY ID
  // ==========================================================================

  Future<BillingRuleModel?> getBillingRuleById(String ruleId,) async {
    final normalizedId = ruleId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    final document = await _collection
        .doc(normalizedId)
        .get();

    if (!document.exists) {
      return null;
    }

    return BillingRuleModel.fromFirestore(
      document,
    );
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

    _validateRequiredId(
      normalizedOwnerId,
      'Owner ID',
    );

    _validateRequiredId(
      normalizedPropertyId,
      'Property ID',
    );

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
        .map(
      BillingRuleModel.fromFirestore,
    )
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

      if (date.isBefore(rule.effectiveFrom)) {
        return false;
      }

      if (rule.effectiveTo != null &&
          date.isAfter(rule.effectiveTo!)) {
        return false;
      }

      return true;
    }).toList();
  }

  // ==========================================================================
  // UPDATE
  // ==========================================================================
  //
  // IMPORTANT:
  //
  // Billing rules are treated as versioned configuration.
  //
  // Example:
  //
  // Old:
  //   effectiveFrom = 2026-01-01
  //   effectiveTo   = null
  //   amount        = 500
  //
  // Owner changes the bill from 500 -> 700
  // effective from 2026-07-01.
  //
  // Result:
  //
  // Old version:
  //   effectiveFrom = 2026-01-01
  //   effectiveTo   = 2026-06-30
  //   amount        = 500
  //
  // New version:
  //   effectiveFrom = 2026-07-01
  //   effectiveTo   = null
  //   amount        = 700
  //
  // Therefore:
  //
  //   - Owner can see old and new billing rules.
  //   - Tenant can see the applicable historical rule.
  //   - Monthly bills already generated are NOT changed.
  //   - New monthly bills use the new rule after effectiveFrom.
  //
  // ==========================================================================

  Future<BillingRuleModel> updateBillingRule({
    required UpdateBillingRuleRequest request,
  }) async {
    final ruleId = request.ruleId.trim();
    final ownerId = request.ownerId.trim();

    _validateRequiredId(
      ruleId,
      'Billing rule ID',
    );

    _validateRequiredId(
      ownerId,
      'Owner ID',
    );

    _validateAmount(
      valueType: request.valueType,
      amount: request.amount,
    );

    _validateEffectiveDates(
      effectiveFrom: request.effectiveFrom,
      effectiveTo: request.effectiveTo,
    );

    final document = _collection.doc(ruleId);

    final snapshot = await document.get();

    if (!snapshot.exists) {
      throw StateError(
        'Billing rule not found.',
      );
    }

    final existingRule =
    BillingRuleModel.fromFirestore(snapshot);

    if (existingRule.ownerId != ownerId) {
      throw StateError(
        'You are not allowed to update this billing rule.',
      );
    }

    final now = DateTime.now();

    // =========================================================================
    // CASE 1
    // =========================================================================
    //
    // Same effectiveFrom.
    //
    // This means the owner is editing the same version rather than creating
    // a new historical version.
    //
    // Example:
    //
    // 2026-07-01 -> 500
    //
    // changed to:
    //
    // 2026-07-01 -> 700
    //
    // We can safely update the existing document.
    //
    final isSameEffectiveStart =
    existingRule.effectiveFrom.isAtSameMomentAs(
      request.effectiveFrom,
    );

    if (isSameEffectiveStart) {
      final updatedRule = BillingRuleModel(
        id: existingRule.id,
        ownerId: existingRule.ownerId,
        propertyId: existingRule.propertyId,
        scopeType: existingRule.scopeType,
        scopeId: existingRule.scopeId,
        chargeType: request.chargeType,
        valueType: request.valueType,
        amount: request.amount,
        title: _normalizeNullableString(
          request.title,
        ),
        effectiveFrom: request.effectiveFrom,
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

    // =========================================================================
    // CASE 2
    // =========================================================================
    //
    // Effective date changed.
    //
    // We must preserve the existing rule as historical data.
    //
    // The new rule cannot start before the existing rule.
    //
    if (request.effectiveFrom.isBefore(
      existingRule.effectiveFrom,
    )) {
      throw ArgumentError(
        'New effective date cannot be before the existing '
            'billing rule effective date.',
      );
    }

    // =========================================================================
    // Determine the end date of the old version.
    // =========================================================================

    final oldEffectiveTo = request.effectiveFrom.subtract(
      const Duration(microseconds: 1),
    );

    if (oldEffectiveTo.isBefore(
      existingRule.effectiveFrom,
    )) {
      throw ArgumentError(
        'New effective date creates an invalid historical period.',
      );
    }

    // =========================================================================
    // Find all rules that belong to the same billing configuration.
    //
    // Same:
    //   owner
    //   property
    //   scope
    //   charge type
    //
    // These rules represent different versions of the same billing charge.
    // =========================================================================

    final snapshotRules = await _collection
        .where(
      'ownerId',
      isEqualTo: ownerId,
    )
        .where(
      'propertyId',
      isEqualTo: existingRule.propertyId,
    )
        .where(
      'scopeType',
      isEqualTo: existingRule.scopeType.name,
    )
        .where(
      'scopeId',
      isEqualTo: existingRule.scopeId,
    )
        .where(
      'chargeType',
      isEqualTo: existingRule.chargeType.name,
    )
        .get();

    final relatedRules = snapshotRules.docs
        .map(
      BillingRuleModel.fromFirestore,
    )
        .toList();

    // =========================================================================
    // Find the version that was active immediately before the new effective
    // date.
    //
    // This prevents overlapping historical versions.
    // =========================================================================

    BillingRuleModel? previousRule;

    for (final rule in relatedRules) {
      if (rule.id == existingRule.id) {
        continue;
      }

      if (rule.effectiveFrom.isAfter(
        request.effectiveFrom,
      )) {
        continue;
      }

      if (previousRule == null ||
          rule.effectiveFrom.isAfter(
            previousRule.effectiveFrom,
          )) {
        previousRule = rule;
      }
    }

    // =========================================================================
    // Determine whether the current document is the latest version.
    // =========================================================================

    final latestRule = _findLatestRule(
      relatedRules,
    );

    // =========================================================================
    // CASE 2A
    // =========================================================================
    //
    // The edited rule is the latest version.
    //
    // Close it at the moment immediately before the new version begins.
    //
    // =========================================================================

    final isLatestRule =
        latestRule?.id == existingRule.id;

    if (isLatestRule) {
      await _firestore.runTransaction(
            (transaction) async {
          final currentSnapshot =
          await transaction.get(document);

          if (!currentSnapshot.exists) {
            throw StateError(
              'Billing rule no longer exists.',
            );
          }

          transaction.update(
            document,
            {
              'effectiveTo': Timestamp.fromDate(
                oldEffectiveTo,
              ),
              'isActive': false,
              'updatedAt': Timestamp.fromDate(
                now,
              ),
            },
          );

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
            title: _normalizeNullableString(
              request.title,
            ),
            effectiveFrom: request.effectiveFrom,
            effectiveTo: request.effectiveTo,
            isActive: request.isActive,
            createdAt: now,
            updatedAt: now,
          );

          transaction.set(
            newDocument,
            newRule.toFirestore(),
          );
        },
      );

      final latestSnapshot = await _collection
          .where(
        'ownerId',
        isEqualTo: ownerId,
      )
          .where(
        'propertyId',
        isEqualTo: existingRule.propertyId,
      )
          .where(
        'scopeType',
        isEqualTo: existingRule.scopeType.name,
      )
          .where(
        'scopeId',
        isEqualTo: existingRule.scopeId,
      )
          .where(
        'chargeType',
        isEqualTo: request.chargeType.name,
      )
          .where(
        'effectiveFrom',
        isEqualTo: Timestamp.fromDate(
          request.effectiveFrom,
        ),
      )
          .get();

      if (latestSnapshot.docs.isEmpty) {
        throw StateError(
          'New billing rule version could not be created.',
        );
      }

      return BillingRuleModel.fromFirestore(
        latestSnapshot.docs.first,
      );
    }

    // =========================================================================
    // CASE 2B
    // =========================================================================
    //
    // The edited rule is historical.
    //
    // In this case we do NOT overwrite history.
    //
    // We create a new version for the requested effective date.
    //
    // =========================================================================

    if (previousRule != null) {
      final previousEnd =
      request.effectiveFrom.subtract(
        const Duration(microseconds: 1),
      );

      if (previousEnd.isBefore(
        previousRule.effectiveFrom,
      )) {
        throw StateError(
          'Billing rule versions would overlap.',
        );
      }
    }

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
      title: _normalizeNullableString(
        request.title,
      ),
      effectiveFrom: request.effectiveFrom,
      effectiveTo: request.effectiveTo,
      isActive: request.isActive,
      createdAt: now,
      updatedAt: now,
    );

    await newDocument.set(
      newRule.toFirestore(),
    );

    return newRule;
  }

  // ==========================================================================
  // DEACTIVATE
  // ==========================================================================
  //
  // Deactivation does NOT delete the rule.
  //
  // Historical data remains available.
  //
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

    final document =
    _collection.doc(normalizedRuleId);

    final snapshot = await document.get();

    if (!snapshot.exists) {
      throw StateError(
        'Billing rule not found.',
      );
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
  // HELPERS
  // ==========================================================================

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
    if (valueType == BillingValueType.fixed) {
      if (amount == null || amount < 0) {
        throw ArgumentError(
          'Fixed billing amount must be zero or greater.',
        );
      }
    }

    if (valueType == BillingValueType.variable) {
      if (amount != null && amount < 0) {
        throw ArgumentError(
          'Billing amount cannot be negative.',
        );
      }
    }
  }

  void _validateEffectiveDates({
    required DateTime effectiveFrom,
    required DateTime? effectiveTo,
  }) {
    if (effectiveTo != null &&
        effectiveTo.isBefore(effectiveFrom)) {
      throw ArgumentError(
        'Effective end date cannot be before start date.',
      );
    }
  }

  String? _normalizeNullableString(String? value,) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim();

    return normalized.isEmpty
        ? null
        : normalized;
  }

  BillingRuleModel? _findLatestRule(List<BillingRuleModel> rules,) {
    if (rules.isEmpty) {
      return null;
    }

    BillingRuleModel? latest;

    for (final rule in rules) {
      if (latest == null ||
          rule.effectiveFrom.isAfter(
            latest.effectiveFrom,
          )) {
        latest = rule;
      }
    }

    return latest;
  }
}