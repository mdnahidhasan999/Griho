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

    if (ownerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    if (propertyId.isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    if (scopeId.isEmpty) {
      throw ArgumentError(
        'Billing scope ID cannot be empty.',
      );
    }

    if (request.valueType == BillingValueType.fixed) {
      if (request.amount == null || request.amount! < 0) {
        throw ArgumentError(
          'Fixed billing amount must be zero or greater.',
        );
      }
    }

    if (request.valueType == BillingValueType.variable &&
        request.amount != null &&
        request.amount! < 0) {
      throw ArgumentError(
        'Billing amount cannot be negative.',
      );
    }

    if (request.effectiveTo != null &&
        request.effectiveTo!.isBefore(
          request.effectiveFrom,
        )) {
      throw ArgumentError(
        'Effective end date cannot be before start date.',
      );
    }

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
      title: request.title?.trim(),
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

  Future<BillingRuleModel?> getBillingRuleById(
      String ruleId,
      ) async {
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

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

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

    return snapshot.docs
        .map(
      BillingRuleModel.fromFirestore,
    )
        .toList();
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

  Future<BillingRuleModel> updateBillingRule({
    required UpdateBillingRuleRequest request,
  }) async {
    final ruleId = request.ruleId.trim();
    final ownerId = request.ownerId.trim();

    if (ruleId.isEmpty) {
      throw ArgumentError(
        'Billing rule ID cannot be empty.',
      );
    }

    if (ownerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    if (request.valueType == BillingValueType.fixed) {
      if (request.amount == null || request.amount! < 0) {
        throw ArgumentError(
          'Fixed billing amount must be zero or greater.',
        );
      }
    }

    if (request.valueType == BillingValueType.variable &&
        request.amount != null &&
        request.amount! < 0) {
      throw ArgumentError(
        'Billing amount cannot be negative.',
      );
    }

    if (request.effectiveTo != null &&
        request.effectiveTo!.isBefore(
          request.effectiveFrom,
        )) {
      throw ArgumentError(
        'Effective end date cannot be before start date.',
      );
    }

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

    final updatedRule = BillingRuleModel(
      id: existingRule.id,
      ownerId: existingRule.ownerId,
      propertyId: existingRule.propertyId,
      scopeType: existingRule.scopeType,
      scopeId: existingRule.scopeId,
      chargeType: request.chargeType,
      valueType: request.valueType,
      amount: request.amount,
      title: request.title?.trim(),
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

  // ==========================================================================
  // DEACTIVATE
  // ==========================================================================

  Future<void> deactivateBillingRule({
    required String ruleId,
    required String ownerId,
  }) async {
    final normalizedRuleId = ruleId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedRuleId.isEmpty) {
      throw ArgumentError(
        'Billing rule ID cannot be empty.',
      );
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

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

}