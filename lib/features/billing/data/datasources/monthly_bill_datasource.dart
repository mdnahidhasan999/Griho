import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/billing_rule.dart';
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

    // Monthly bills are always month-based.
    final normalizedPeriodStart = _normalizeMonthStart(
      request.billingPeriodStart,
    );

    final normalizedPeriodEnd = _normalizeMonthStart(request.billingPeriodEnd);

    if (!normalizedPeriodEnd.isAfter(normalizedPeriodStart)) {
      throw ArgumentError(
        'Billing period end must be after billing period start.',
      );
    }

    if (request.dueDate.isBefore(normalizedPeriodStart)) {
      throw ArgumentError('Due date cannot be before billing period start.');
    }

    // Pending means the actual amount is not known yet.
    // Therefore only variable bills may be pending.
    if (request.status == MonthlyBillStatus.pending &&
        request.valueType != BillingValueType.variable) {
      throw ArgumentError('Only variable bills can have pending status.');
    }

    // Variable bills are generated with amount 0.
    //
    // Fixed bills must have an amount greater than zero.
    if (request.valueType == BillingValueType.fixed && request.amount <= 0) {
      throw ArgumentError('Fixed bills must have an amount greater than zero.');
    }

    // A variable bill may only start as pending with amount 0.
    if (request.valueType == BillingValueType.variable &&
        request.status == MonthlyBillStatus.pending &&
        request.amount != 0) {
      throw ArgumentError(
        'Pending variable bills must start with amount zero.',
      );
    }

    final periodKey = _formatPeriodKey(normalizedPeriodStart);

    // Tenant-aware document identity.
    //
    // Different tenants occupying the same unit during the same month
    // must be able to have separate bills.
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

      transaction.set(document, monthlyBill.toFirestore());
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

    final normalizedPeriodStart = _normalizeMonthStart(billingPeriodStart);

    final snapshot = await _collection
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('unitId', isEqualTo: normalizedUnitId)
        .where(
          'billingPeriodStart',
          isEqualTo: Timestamp.fromDate(normalizedPeriodStart),
        )
        .get();

    return snapshot.docs.map(MonthlyBillModel.fromFirestore).toList();
  }

  // ==========================================================================
  // UNIT + TENANT + PERIOD + TYPE
  // ==========================================================================

  Future<MonthlyBillModel?> getMonthlyBillByUnitAndTenantAndPeriodAndType({
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

    final normalizedPeriodStart = _normalizeMonthStart(billingPeriodStart);

    final snapshot = await _collection
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('unitId', isEqualTo: normalizedUnitId)
        .where('tenantId', isEqualTo: normalizedTenantId)
        .where(
          'billingPeriodStart',
          isEqualTo: Timestamp.fromDate(normalizedPeriodStart),
        )
        .where('type', isEqualTo: type.name)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return MonthlyBillModel.fromFirestore(snapshot.docs.first);
  }

  // ==========================================================================
  // TENANT + PERIOD
  // ==========================================================================

  Future<List<MonthlyBillModel>> getMonthlyBillsByTenantAndPeriod({
    required String tenantUserId,
    required DateTime billingPeriodStart,
  }) async {
    final normalizedTenantUserId = tenantUserId.trim();

    _validateRequiredId(normalizedTenantUserId, 'Tenant User ID');

    final normalizedPeriodStart = _normalizeMonthStart(billingPeriodStart);

    final snapshot = await _collection
        .where('tenantUserId', isEqualTo: normalizedTenantUserId)
        .where(
          'billingPeriodStart',
          isEqualTo: Timestamp.fromDate(normalizedPeriodStart),
        )
        .get();

    return snapshot.docs.map(MonthlyBillModel.fromFirestore).toList();
  }

  // ==========================================================================
  // TENANT HISTORY
  // ==========================================================================

  Future<List<MonthlyBillModel>> getMonthlyBillHistoryByTenantUserId({
    required String tenantUserId,
  }) async {
    final normalizedTenantUserId = tenantUserId.trim();

    _validateRequiredId(normalizedTenantUserId, 'Tenant User ID');

    final snapshot = await _collection
        .where('tenantUserId', isEqualTo: normalizedTenantUserId)
        .orderBy('billingPeriodStart', descending: true)
        .get();

    return snapshot.docs.map(MonthlyBillModel.fromFirestore).toList();
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

    final normalizedPeriodStart = _normalizeMonthStart(billingPeriodStart);

    final snapshot = await _collection
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('propertyId', isEqualTo: normalizedPropertyId)
        .where(
          'billingPeriodStart',
          isEqualTo: Timestamp.fromDate(normalizedPeriodStart),
        )
        .orderBy('unitId')
        .get();

    return snapshot.docs.map(MonthlyBillModel.fromFirestore).toList();
  }

  // ==========================================================================
  // PROPERTY HISTORY
  // ==========================================================================

  Future<List<MonthlyBillModel>> getMonthlyBillHistoryByPropertyId({
    required String ownerId,
    required String propertyId,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    final normalizedPropertyId = propertyId.trim();

    _validateRequiredId(normalizedOwnerId, 'Owner ID');

    _validateRequiredId(normalizedPropertyId, 'Property ID');

    final snapshot = await _collection
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .orderBy('billingPeriodStart', descending: true)
        .get();

    return snapshot.docs.map(MonthlyBillModel.fromFirestore).toList();
  }

  // ==========================================================================
  // UPDATE VARIABLE BILL AMOUNT
  // ==========================================================================

  Future<MonthlyBillModel?> updateMonthlyBillAmount({
    required String billId,
    required double amount,
  }) async {
    final normalizedBillId = billId.trim();

    if (normalizedBillId.isEmpty) {
      throw ArgumentError('Bill ID cannot be empty.');
    }

    if (amount.isNaN || amount.isInfinite) {
      throw ArgumentError('Bill amount must be a valid number.');
    }

    if (amount < 0) {
      throw ArgumentError('Bill amount cannot be negative.');
    }

    final document = _collection.doc(normalizedBillId);

    final snapshot = await document.get();

    if (!snapshot.exists) {
      return null;
    }

    final existing = MonthlyBillModel.fromFirestore(snapshot);

    // ------------------------------------------------------------------------
    // RENT IMMUTABILITY
    // ------------------------------------------------------------------------

    if (existing.type == MonthlyBillType.rent) {
      throw StateError(
        'Generated rent bills cannot be edited. '
        'Use a replacement or adjustment workflow.',
      );
    }

    // ------------------------------------------------------------------------
    // ONLY VARIABLE BILLS
    // ------------------------------------------------------------------------

    if (existing.valueType != BillingValueType.variable) {
      throw StateError('Only variable bills can have their amount updated.');
    }

    // ------------------------------------------------------------------------
    // STATUS VALIDATION
    // ------------------------------------------------------------------------

    if (existing.status != MonthlyBillStatus.pending &&
        existing.status != MonthlyBillStatus.unpaid) {
      throw StateError(
        'Only pending or unpaid variable bills '
        'can have their amount entered or updated.',
      );
    }

    // ------------------------------------------------------------------------
    // PAID AMOUNT VALIDATION
    // ------------------------------------------------------------------------
    //
    // The bill cannot be reduced below the amount already paid.
    //
    // Example:
    //
    // bill amount = 1000
    // paid amount = 800
    //
    // New amount cannot be 500.
    // ------------------------------------------------------------------------

    if (existing.paidAmount > amount) {
      throw StateError(
        'Bill amount cannot be less than the amount already paid.',
      );
    }

    // ------------------------------------------------------------------------
    // TRANSACTION-SAFE UPDATE
    // ------------------------------------------------------------------------

    final updated = await _firestore.runTransaction<MonthlyBillModel?>((
      transaction,
    ) async {
      final currentSnapshot = await transaction.get(document);

      if (!currentSnapshot.exists) {
        return null;
      }

      final current = MonthlyBillModel.fromFirestore(currentSnapshot);

      // Prevent stale data from silently overwriting another update.
      if (current.updatedAt.isAtSameMomentAs(existing.updatedAt) == false) {
        throw StateError(
          'This billing record was updated by another operation. '
          'Please reload and try again.',
        );
      }

      if (current.valueType != BillingValueType.variable) {
        throw StateError('Only variable bills can have their amount updated.');
      }

      if (current.type == MonthlyBillType.rent) {
        throw StateError(
          'Generated rent bills cannot be edited. '
          'Use a replacement or adjustment workflow.',
        );
      }

      if (current.status != MonthlyBillStatus.pending &&
          current.status != MonthlyBillStatus.unpaid) {
        throw StateError(
          'Only pending or unpaid variable bills '
          'can have their amount entered or updated.',
        );
      }

      if (current.paidAmount > amount) {
        throw StateError(
          'Bill amount cannot be less than the amount already paid.',
        );
      }

      final updatedBill = current.copyWithModel(
        amount: amount,
        status: _resolveStatusAfterAmountUpdate(
          paidAmount: current.paidAmount,
          amount: amount,
        ),
        updatedAt: DateTime.now(),
      );

      transaction.update(document, updatedBill.toFirestore());

      return updatedBill;
    });

    return updated;
  }

  // ==========================================================================
  // CANCEL
  // ==========================================================================

  Future<MonthlyBillModel?> cancelMonthlyBill(String billId) async {
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
      throw StateError('A paid billing record cannot be cancelled.');
    }

    if (existing.status == MonthlyBillStatus.cancelled) {
      return existing;
    }

    final updated = existing.copyWithModel(
      status: MonthlyBillStatus.cancelled,
      updatedAt: DateTime.now(),
    );

    await document.update(updated.toFirestore());

    return updated;
  }

  // ==========================================================================
  // STATUS
  // ==========================================================================

  MonthlyBillStatus _resolveStatusAfterAmountUpdate({
    required double paidAmount,
    required double amount,
  }) {
    if (amount <= 0) {
      return MonthlyBillStatus.unpaid;
    }

    if (paidAmount >= amount) {
      return MonthlyBillStatus.paid;
    }

    if (paidAmount > 0) {
      return MonthlyBillStatus.partiallyPaid;
    }

    return MonthlyBillStatus.unpaid;
  }

  // ==========================================================================
  // DATE HELPERS
  // ==========================================================================

  DateTime _normalizeMonthStart(DateTime date) {
    return DateTime(date.year, date.month, 1);
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

  void _validateRequiredId(String value, String label) {
    if (value.isEmpty) {
      throw ArgumentError('$label cannot be empty.');
    }
  }
}
