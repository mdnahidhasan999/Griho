import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/create_monthly_bill_request.dart';
import '../../domain/entities/monthly_bill.dart';
import '../models/monthly_bill_model.dart';

class MonthlyBillDataSource {
  final FirebaseFirestore _firestore;

  MonthlyBillDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'monthlyBills';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionName);

  // ==========================================================================
  // CREATE
  // ==========================================================================

  Future<MonthlyBillModel> createMonthlyBill({
    required CreateMonthlyBillRequest request,
  }) async {
    final ownerId = request.ownerId.trim();
    final propertyId = request.propertyId.trim();
    final floorId = request.floorId.trim();
    final unitId = request.unitId.trim();
    final tenantId = request.tenantId.trim();
    final tenantUserId = request.tenantUserId?.trim();
    final sourceRuleId = request.sourceRuleId.trim();
    final tenancyHistoryId = request.tenancyHistoryId?.trim();

    _validateRequiredId(ownerId, 'Owner ID');
    _validateRequiredId(propertyId, 'Property ID');
    _validateRequiredId(floorId, 'Floor ID');
    _validateRequiredId(unitId, 'Unit ID');
    _validateRequiredId(tenantId, 'Tenant ID');
    _validateRequiredId(sourceRuleId, 'Source rule ID');

    if (request.amount.isNaN || request.amount.isInfinite) {
      throw ArgumentError('Bill amount must be a valid number.');
    }

    if (request.amount < 0) {
      throw ArgumentError('Bill amount cannot be negative.');
    }

    final normalizedPeriodStart = _normalizeMonthStart(
      request.billingPeriodStart,
    );

    final normalizedPeriodEnd = _normalizeMonthStart(
      request.billingPeriodEnd,
    );

    if (!normalizedPeriodEnd.isAfter(normalizedPeriodStart)) {
      throw ArgumentError(
        'Billing period end must be after billing period start.',
      );
    }

    if (request.dueDate.isBefore(normalizedPeriodStart)) {
      throw ArgumentError(
        'Due date cannot be before billing period start.',
      );
    }

    final periodKey = _formatPeriodKey(normalizedPeriodStart);

    // Different tenants occupying the same unit during
    // the same month must have separate bills.
    final documentId =
        '${ownerId}_${unitId}_${tenantId}_'
        '${request.type.name}_$periodKey';

    final document = _collection.doc(documentId);

    final now = DateTime.now();

    final monthlyBill = MonthlyBillModel(
      id: document.id,
      ownerId: ownerId,
      propertyId: propertyId,
      floorId: floorId,
      unitId: unitId,
      tenantId: tenantId,
      tenantUserId: tenantUserId,
      tenancyHistoryId: tenancyHistoryId,
      sourceRuleId: sourceRuleId,
      type: request.type,
      valueType: request.valueType,
      amount: request.amount,
      paidAmount: 0,
      billingPeriodStart: normalizedPeriodStart,
      billingPeriodEnd: normalizedPeriodEnd,
      dueDate: request.dueDate,
      status: request.status,
      createdAt: now,
      updatedAt: now,
    );

    // Transaction is the authoritative duplicate-prevention layer.
    await _firestore.runTransaction((transaction) async {
      final existingSnapshot = await transaction.get(document);

      if (existingSnapshot.exists) {
        throw StateError(
          'Monthly bill already exists for this '
              'tenant, bill type and billing period.',
        );
      }

      transaction.set(
        document,
        monthlyBill.toFirestore(),
      );
    });

    return monthlyBill;
  }

  // ==========================================================================
  // GET BY ID
  // ==========================================================================

  Future<MonthlyBillModel?> getMonthlyBillById(String billId) async {
    final normalizedBillId = billId.trim();

    if (normalizedBillId.isEmpty) {
      return null;
    }

    final document = await _collection.doc(normalizedBillId).get();

    if (!document.exists) {
      return null;
    }

    return MonthlyBillModel.fromFirestore(document);
  }

  // ==========================================================================
  // UNIT + PERIOD
  // ==========================================================================

  Future<List<MonthlyBillModel>> getMonthlyBillsByUnitAndPeriod({
    required String ownerId,
    required String unitId,
    required DateTime billingPeriodStart,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    final normalizedUnitId = unitId.trim();

    _validateRequiredId(normalizedOwnerId, 'Owner ID');
    _validateRequiredId(normalizedUnitId, 'Unit ID');

    final normalizedPeriodStart = _normalizeMonthStart(
      billingPeriodStart,
    );

    final snapshot = await _collection
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'unitId',
      isEqualTo: normalizedUnitId,
    )
        .where(
      'billingPeriodStart',
      isEqualTo: Timestamp.fromDate(
        normalizedPeriodStart,
      ),
    )
        .get();

    return snapshot.docs
        .map(MonthlyBillModel.fromFirestore)
        .toList();
  }

  // ==========================================================================
  // UNIT + TENANT + PERIOD + TYPE
  // ==========================================================================

  Future<MonthlyBillModel?>
  getMonthlyBillByUnitAndTenantAndPeriodAndType({
    required String ownerId,
    required String unitId,
    required String tenantId,
    required DateTime billingPeriodStart,
    required MonthlyBillType type,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    final normalizedUnitId = unitId.trim();
    final normalizedTenantId = tenantId.trim();

    _validateRequiredId(normalizedOwnerId, 'Owner ID');
    _validateRequiredId(normalizedUnitId, 'Unit ID');
    _validateRequiredId(normalizedTenantId, 'Tenant ID');

    final normalizedPeriodStart = _normalizeMonthStart(
      billingPeriodStart,
    );

    final snapshot = await _collection
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'unitId',
      isEqualTo: normalizedUnitId,
    )
        .where(
      'tenantId',
      isEqualTo: normalizedTenantId,
    )
        .where(
      'billingPeriodStart',
      isEqualTo: Timestamp.fromDate(
        normalizedPeriodStart,
      ),
    )
        .where(
      'type',
      isEqualTo: type.name,
    )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return MonthlyBillModel.fromFirestore(
      snapshot.docs.first,
    );
  }

  // ==========================================================================
  // TENANT + PERIOD
  // ==========================================================================

  Future<List<MonthlyBillModel>> getMonthlyBillsByTenantAndPeriod({
    required String tenantUserId,
    required DateTime billingPeriodStart,
  }) async {
    final normalizedTenantUserId = tenantUserId.trim();

    _validateRequiredId(
      normalizedTenantUserId,
      'Tenant User ID',
    );

    final normalizedPeriodStart = _normalizeMonthStart(
      billingPeriodStart,
    );

    final snapshot = await _collection
        .where(
      'tenantUserId',
      isEqualTo: normalizedTenantUserId,
    )
        .where(
      'billingPeriodStart',
      isEqualTo: Timestamp.fromDate(
        normalizedPeriodStart,
      ),
    )
        .get();

    return snapshot.docs
        .map(MonthlyBillModel.fromFirestore)
        .toList();
  }

  // ==========================================================================
  // TENANT HISTORY
  // ==========================================================================

  Future<List<MonthlyBillModel>>
  getMonthlyBillHistoryByTenantUserId({
    required String tenantUserId,
  }) async {
    final normalizedTenantUserId = tenantUserId.trim();

    _validateRequiredId(
      normalizedTenantUserId,
      'Tenant User ID',
    );

    final snapshot = await _collection
        .where(
      'tenantUserId',
      isEqualTo: normalizedTenantUserId,
    )
        .orderBy(
      'billingPeriodStart',
      descending: true,
    )
        .get();

    return snapshot.docs
        .map(MonthlyBillModel.fromFirestore)
        .toList();
  }

  // ==========================================================================
  // PROPERTY + PERIOD
  // ==========================================================================

  Future<List<MonthlyBillModel>> getMonthlyBillsByPropertyAndPeriod({
    required String ownerId,
    required String propertyId,
    required DateTime billingPeriodStart,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    final normalizedPropertyId = propertyId.trim();

    _validateRequiredId(normalizedOwnerId, 'Owner ID');
    _validateRequiredId(normalizedPropertyId, 'Property ID');

    final normalizedPeriodStart = _normalizeMonthStart(
      billingPeriodStart,
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
        .where(
      'billingPeriodStart',
      isEqualTo: Timestamp.fromDate(
        normalizedPeriodStart,
      ),
    )
        .orderBy('unitId')
        .get();

    return snapshot.docs
        .map(MonthlyBillModel.fromFirestore)
        .toList();
  }

  // ==========================================================================
  // PROPERTY HISTORY
  // ==========================================================================

  Future<List<MonthlyBillModel>>
  getMonthlyBillHistoryByPropertyId({
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
        .orderBy(
      'billingPeriodStart',
      descending: true,
    )
        .get();

    return snapshot.docs
        .map(MonthlyBillModel.fromFirestore)
        .toList();
  }

  // ==========================================================================
  // CANCEL
  // ==========================================================================

  Future<MonthlyBillModel?> cancelMonthlyBill(String billId,) async {
    final normalizedBillId = billId.trim();

    if (normalizedBillId.isEmpty) {
      return null;
    }

    final document = _collection.doc(normalizedBillId);

    final snapshot = await document.get();

    if (!snapshot.exists) {
      return null;
    }

    final existing = MonthlyBillModel.fromFirestore(snapshot);

    if (existing.status == MonthlyBillStatus.paid) {
      throw StateError(
        'A paid billing record cannot be cancelled.',
      );
    }

    if (existing.status == MonthlyBillStatus.cancelled) {
      return existing;
    }

    final updated = existing.copyWithModel(
      status: MonthlyBillStatus.cancelled,
      updatedAt: DateTime.now(),
    );

    await document.update(
      updated.toFirestore(),
    );

    return updated;
  }

  // ==========================================================================
  // DATE HELPERS
  // ==========================================================================

  DateTime _normalizeMonthStart(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      1,
    );
  }

  // ==========================================================================
  // PERIOD KEY
  // ==========================================================================

  String _formatPeriodKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$year-$month';
  }

  // ==========================================================================
  // VALIDATION
  // ==========================================================================

  void _validateRequiredId(String value,
      String label,) {
    if (value.isEmpty) {
      throw ArgumentError(
        '$label cannot be empty.',
      );
    }
  }
}