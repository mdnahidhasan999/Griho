// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../rents/data/models/monthly_rent_model.dart';
import '../../../rents/domain/entities/monthly_rent.dart';
import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/create_monthly_bill_request.dart';
import '../../domain/entities/monthly_bill.dart';
import '../models/monthly_bill_model.dart';

typedef JsonMap = Map<String, dynamic>;

class MonthlyBillDataSource {
  final FirebaseFirestore _firestore;

  MonthlyBillDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'monthlyBills';
  static const String _rentCollectionName = 'monthlyRents';

  CollectionReference<JsonMap> get _collection =>
      _firestore.collection(_collectionName);

  CollectionReference<JsonMap> get _rentCollection =>
      _firestore.collection(_rentCollectionName);

  // ==========================================================================
  // CREATE OR ATOMICALLY OVERRIDE FIXED BILL WITH VARIABLE BILL
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
    final title = request.title?.trim();
    final ruleScopeId = request.ruleScopeId?.trim();

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
    final normalizedPeriodEnd = _normalizeMonthStart(request.billingPeriodEnd);

    if (!normalizedPeriodEnd.isAfter(normalizedPeriodStart)) {
      throw ArgumentError(
        'Billing period end must be after billing period start.',
      );
    }

    final normalizedDueDate = DateTime(
      request.dueDate.year,
      request.dueDate.month,
      request.dueDate.day,
    );

    if (normalizedDueDate.isBefore(normalizedPeriodStart)) {
      throw ArgumentError(
        'Due date cannot be before the billing period starts.',
      );
    }

    final periodKey = _formatPeriodKey(normalizedPeriodStart);
    final documentId =
        '${ownerId}_${propertyId}_${unitId}_${tenantId}_${request.type.name}_$periodKey';

    final document = _collection.doc(documentId);
    final now = DateTime.now();

    final initialBill = MonthlyBillModel(
      id: document.id,
      ownerId: ownerId,
      propertyId: propertyId,
      floorId: floorId,
      unitId: unitId,
      tenantId: tenantId,
      tenantUserId: tenantUserId == null || tenantUserId.isEmpty
          ? null
          : tenantUserId,
      tenancyHistoryId: tenancyHistoryId == null || tenancyHistoryId.isEmpty
          ? null
          : tenancyHistoryId,
      title: title == null || title.isEmpty ? null : title,
      ruleScopeType: request.ruleScopeType,
      ruleScopeId: ruleScopeId == null || ruleScopeId.isEmpty
          ? null
          : ruleScopeId,
      ruleSnapshot: request.ruleSnapshot,
      sourceRuleId: sourceRuleId,
      type: request.type,
      valueType: request.valueType,
      amount: request.amount,
      paidAmount: 0,
      billingPeriodStart: normalizedPeriodStart,
      billingPeriodEnd: normalizedPeriodEnd,
      dueDate: normalizedDueDate,
      status: request.status,
      createdAt: now,
      updatedAt: now,
    );

    return _firestore.runTransaction<MonthlyBillModel>((transaction) async {
      final existingSnapshot = await transaction.get(document);

      if (!existingSnapshot.exists) {
        transaction.set(document, initialBill.toFirestore());
        return initialBill;
      }

      final existing = MonthlyBillModel.fromFirestore(existingSnapshot);

      if (existing.status == MonthlyBillStatus.cancelled) {
        final replacement = initialBill.copyWithModel(
          createdAt: existing.createdAt,
          updatedAt: now,
        );
        transaction.set(document, replacement.toFirestore());
        return replacement;
      }

      final canOverrideFixedWithVariable =
          existing.valueType == BillingValueType.fixed &&
          request.valueType == BillingValueType.variable;

      if (!canOverrideFixedWithVariable) {
        throw StateError(
          'Monthly bill already exists for this tenant, bill type and billing period.',
        );
      }

      if (request.amount < existing.paidAmount) {
        throw StateError(
          'Variable override amount cannot be less than the amount already paid.',
        );
      }

      final updatedStatus = _resolveStatusAfterOverride(
        newAmount: request.amount,
        paidAmount: existing.paidAmount,
      );

      final overriddenBill = existing.copyWithModel(
        sourceRuleId: sourceRuleId,
        title: title == null || title.isEmpty ? null : title,
        clearTitle: title == null || title.isEmpty,
        ruleScopeType: request.ruleScopeType,
        ruleScopeId: ruleScopeId == null || ruleScopeId.isEmpty
            ? null
            : ruleScopeId,
        ruleSnapshot: request.ruleSnapshot,
        overriddenFromRuleId: existing.sourceRuleId,
        overriddenFromAmount: existing.amount,
        valueType: BillingValueType.variable,
        amount: request.amount,
        dueDate: normalizedDueDate,
        status: updatedStatus,
        updatedAt: now,
      );

      transaction.set(document, overriddenBill.toFirestore());
      return overriddenBill;
    });
  }

  MonthlyBillStatus _resolveStatusAfterOverride({
    required double newAmount,
    required double paidAmount,
  }) {
    if (paidAmount <= 0) {
      return MonthlyBillStatus.unpaid;
    }
    if (paidAmount >= newAmount) {
      return MonthlyBillStatus.paid;
    }
    return MonthlyBillStatus.partiallyPaid;
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
    if (document.exists) {
      return MonthlyBillModel.fromFirestore(document);
    }

    final rentDoc = await _rentCollection.doc(normalizedBillId).get();
    if (rentDoc.exists) {
      final rent = MonthlyRentModel.fromFirestore(rentDoc);
      return MonthlyBillModel.fromMonthlyRent(rent);
    }

    return null;
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
    final periodTimestamp = Timestamp.fromDate(normalizedPeriodStart);

    final results = await Future.wait([
      _collection
          .where('ownerId', isEqualTo: normalizedOwnerId)
          .where('unitId', isEqualTo: normalizedUnitId)
          .where('billingPeriodStart', isEqualTo: periodTimestamp)
          .limit(50)
          .get(),
      _rentCollection
          .where('ownerId', isEqualTo: normalizedOwnerId)
          .where('unitId', isEqualTo: normalizedUnitId)
          .where('billingPeriodStart', isEqualTo: periodTimestamp)
          .limit(20)
          .get(),
    ]);

    final utilityBills = results[0].docs.map(MonthlyBillModel.fromFirestore);
    final rentBills = results[1].docs
        .map(MonthlyRentModel.fromFirestore)
        .map(MonthlyBillModel.fromMonthlyRent);

    return _sortCombinedBills([...rentBills, ...utilityBills]);
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

    if (type == MonthlyBillType.rent) {
      final rentSnap = await _rentCollection
          .where('ownerId', isEqualTo: normalizedOwnerId)
          .where('unitId', isEqualTo: normalizedUnitId)
          .where('tenantId', isEqualTo: normalizedTenantId)
          .where(
            'billingPeriodStart',
            isEqualTo: Timestamp.fromDate(normalizedPeriodStart),
          )
          .limit(1)
          .get();

      if (rentSnap.docs.isEmpty) {
        return null;
      }

      return MonthlyBillModel.fromMonthlyRent(
        MonthlyRentModel.fromFirestore(rentSnap.docs.first),
      );
    }

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
    final periodTimestamp = Timestamp.fromDate(normalizedPeriodStart);

    final results = await Future.wait([
      _collection
          .where('tenantUserId', isEqualTo: normalizedTenantUserId)
          .where('billingPeriodStart', isEqualTo: periodTimestamp)
          .limit(50)
          .get(),
      _rentCollection
          .where('tenantUserId', isEqualTo: normalizedTenantUserId)
          .where('billingPeriodStart', isEqualTo: periodTimestamp)
          .limit(20)
          .get(),
    ]);

    final utilityBills = results[0].docs.map(MonthlyBillModel.fromFirestore);
    final rentBills = results[1].docs
        .map(MonthlyRentModel.fromFirestore)
        .map(MonthlyBillModel.fromMonthlyRent);

    return _sortCombinedBills([...rentBills, ...utilityBills]);
  }

  // ==========================================================================
  // RENT + TENANT + BILLING PERIOD
  // ==========================================================================

  Future<List<MonthlyRentModel>> getMonthlyRentsByTenantAndPeriod({
    required String tenantUserId,
    required DateTime billingPeriodStart,
  }) async {
    final normalizedTenantUserId = tenantUserId.trim();
    _validateRequiredId(normalizedTenantUserId, 'Tenant User ID');

    final normalizedPeriodStart = _normalizeMonthStart(billingPeriodStart);

    final snapshot = await _rentCollection
        .where('tenantUserId', isEqualTo: normalizedTenantUserId)
        .where(
          'billingPeriodStart',
          isEqualTo: Timestamp.fromDate(normalizedPeriodStart),
        )
        .limit(20)
        .get();

    return snapshot.docs.map(MonthlyRentModel.fromFirestore).toList();
  }

  // ==========================================================================
  // TENANT HISTORY
  // ==========================================================================

  Future<List<MonthlyBillModel>> getMonthlyBillHistoryByTenantUserId({
    required String tenantUserId,
    int limit = 150,
  }) async {
    final normalizedTenantUserId = tenantUserId.trim();
    _validateRequiredId(normalizedTenantUserId, 'Tenant User ID');

    final results = await Future.wait([
      _collection
          .where('tenantUserId', isEqualTo: normalizedTenantUserId)
          .limit(limit)
          .get(),
      _rentCollection
          .where('tenantUserId', isEqualTo: normalizedTenantUserId)
          .limit(limit)
          .get(),
    ]);

    final utilityBills = results[0].docs.map(MonthlyBillModel.fromFirestore);
    final rentBills = results[1].docs
        .map(MonthlyRentModel.fromFirestore)
        .map(MonthlyBillModel.fromMonthlyRent);

    return _sortCombinedBills([...rentBills, ...utilityBills]);
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
    final periodTimestamp = Timestamp.fromDate(normalizedPeriodStart);

    final results = await Future.wait([
      _collection
          .where('ownerId', isEqualTo: normalizedOwnerId)
          .where('propertyId', isEqualTo: normalizedPropertyId)
          .where('billingPeriodStart', isEqualTo: periodTimestamp)
          .limit(250)
          .get(),
      _rentCollection
          .where('ownerId', isEqualTo: normalizedOwnerId)
          .where('propertyId', isEqualTo: normalizedPropertyId)
          .where('billingPeriodStart', isEqualTo: periodTimestamp)
          .limit(150)
          .get(),
    ]);

    final utilityBills = results[0].docs.map(MonthlyBillModel.fromFirestore);
    final rentBills = results[1].docs
        .map(MonthlyRentModel.fromFirestore)
        .map(MonthlyBillModel.fromMonthlyRent);

    final bills = [...rentBills, ...utilityBills]
      ..sort((a, b) {
        final unitCompare = a.unitId.compareTo(b.unitId);
        if (unitCompare != 0) {
          return unitCompare;
        }

        final typeOrderA = a.type == MonthlyBillType.rent ? 0 : 1;
        final typeOrderB = b.type == MonthlyBillType.rent ? 0 : 1;
        if (typeOrderA != typeOrderB) {
          return typeOrderA.compareTo(typeOrderB);
        }

        return a.type.name.compareTo(b.type.name);
      });

    return bills;
  }

  // ==========================================================================
  // PROPERTY HISTORY
  // ==========================================================================

  Future<List<MonthlyBillModel>> getMonthlyBillHistoryByPropertyId({
    required String ownerId,
    required String propertyId,
    int limit = 250,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    final normalizedPropertyId = propertyId.trim();

    _validateRequiredId(normalizedOwnerId, 'Owner ID');
    _validateRequiredId(normalizedPropertyId, 'Property ID');

    final results = await Future.wait([
      _collection
          .where('ownerId', isEqualTo: normalizedOwnerId)
          .where('propertyId', isEqualTo: normalizedPropertyId)
          .limit(limit)
          .get(),
      _rentCollection
          .where('ownerId', isEqualTo: normalizedOwnerId)
          .where('propertyId', isEqualTo: normalizedPropertyId)
          .limit(limit)
          .get(),
    ]);

    final utilityBills = results[0].docs.map(MonthlyBillModel.fromFirestore);
    final rentBills = results[1].docs
        .map(MonthlyRentModel.fromFirestore)
        .map(MonthlyBillModel.fromMonthlyRent);

    return _sortCombinedBills([...rentBills, ...utilityBills]);
  }

  // ==========================================================================
  // CANCEL BILL OR RENT (NO EXTRA POST-UPDATE READ)
  // ==========================================================================

  Future<MonthlyBillModel?> cancelMonthlyBill(String billId) async {
    final normalizedBillId = billId.trim();
    if (normalizedBillId.isEmpty) {
      return null;
    }

    final document = _collection.doc(normalizedBillId);
    final snapshot = await document.get();

    if (snapshot.exists) {
      final existing = MonthlyBillModel.fromFirestore(snapshot);
      final rawData = snapshot.data()!;
      final pendingAmount = (rawData['pendingPaymentAmount'] is num)
          ? (rawData['pendingPaymentAmount'] as num).toDouble()
          : 0.0;

      if (existing.status == MonthlyBillStatus.paid ||
          existing.paidAmount > 0) {
        throw StateError('A paid or partially paid bill cannot be cancelled.');
      }

      if (pendingAmount > 0) {
        throw StateError(
          'Reject the pending payment verification first before cancelling this bill.',
        );
      }

      if (existing.status == MonthlyBillStatus.cancelled) {
        return existing;
      }

      final now = DateTime.now();
      await document.update({
        'status': MonthlyBillStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return existing.copyWithModel(
        status: MonthlyBillStatus.cancelled,
        updatedAt: now,
      );
    }

    final rentDoc = _rentCollection.doc(normalizedBillId);
    final rentSnapshot = await rentDoc.get();

    if (!rentSnapshot.exists) {
      return null;
    }

    final existingRent = MonthlyRentModel.fromFirestore(rentSnapshot);
    final rentRaw = rentSnapshot.data()!;
    final paidAmount = (rentRaw['paidAmount'] is num)
        ? (rentRaw['paidAmount'] as num).toDouble()
        : 0.0;
    final pendingAmount = (rentRaw['pendingPaymentAmount'] is num)
        ? (rentRaw['pendingPaymentAmount'] as num).toDouble()
        : 0.0;

    if (existingRent.status == MonthlyRentStatus.paid || paidAmount > 0) {
      throw StateError(
        'A paid or partially paid rent record cannot be cancelled.',
      );
    }

    if (pendingAmount > 0) {
      throw StateError(
        'Reject the pending payment verification first before cancelling this rent.',
      );
    }

    final now = DateTime.now();
    await rentDoc.update({
      'status': MonthlyRentStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return MonthlyBillModel.fromMonthlyRent(
      existingRent.copyWith(
        status: MonthlyRentStatus.cancelled,
        updatedAt: now,
      ),
    );
  }

  // ==========================================================================
  // SORT & DATE HELPERS
  // ==========================================================================

  List<MonthlyBillModel> _sortCombinedBills(List<MonthlyBillModel> items) {
    final list = [...items];
    list.sort((a, b) {
      final periodCompare = b.billingPeriodStart.compareTo(
        a.billingPeriodStart,
      );
      if (periodCompare != 0) {
        return periodCompare;
      }

      final unitCompare = a.unitId.compareTo(b.unitId);
      if (unitCompare != 0) {
        return unitCompare;
      }

      final isRentA = a.type == MonthlyBillType.rent ? 0 : 1;
      final isRentB = b.type == MonthlyBillType.rent ? 0 : 1;
      if (isRentA != isRentB) {
        return isRentA.compareTo(isRentB);
      }

      return a.type.name.compareTo(b.type.name);
    });
    return list;
  }

  DateTime _normalizeMonthStart(DateTime date) =>
      DateTime(date.year, date.month, 1);

  String _formatPeriodKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$year-$month';
  }

  void _validateRequiredId(String value, String label) {
    if (value.isEmpty) {
      throw ArgumentError('$label cannot be empty.');
    }
  }
}
