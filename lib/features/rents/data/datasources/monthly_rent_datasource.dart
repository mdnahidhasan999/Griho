import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/create_monthly_rent_request.dart';
import '../models/monthly_rent_model.dart';

class MonthlyRentDataSource {
  final FirebaseFirestore _firestore;

  MonthlyRentDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'monthlyRents';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionName);

  // ==========================================================================
  // CREATE MONTHLY RENT
  // ==========================================================================

  Future<MonthlyRentModel> createMonthlyRent({
    required CreateMonthlyRentRequest request,
  }) async {
    final ownerId = request.ownerId.trim();
    final propertyId = request.propertyId.trim();
    final unitId = request.unitId.trim();
    final tenantId = request.tenantId.trim();
    final rentRateId = request.rentRateId.trim();

    if (ownerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }

    if (propertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    if (unitId.isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }

    if (tenantId.isEmpty) {
      throw ArgumentError('Tenant ID cannot be empty.');
    }

    if (rentRateId.isEmpty) {
      throw ArgumentError('Rent rate ID cannot be empty.');
    }

    if (request.monthlyRate <= 0) {
      throw ArgumentError(
        'Monthly rent rate must be greater than zero.',
      );
    }

    if (request.amount <= 0) {
      throw ArgumentError(
        'Rent amount must be greater than zero.',
      );
    }

    if (request.chargeableDays <= 0) {
      throw ArgumentError(
        'Chargeable days must be greater than zero.',
      );
    }

    if (request.daysInBillingPeriod <= 0) {
      throw ArgumentError(
        'Billing period days must be greater than zero.',
      );
    }

    if (request.chargeableDays > request.daysInBillingPeriod) {
      throw ArgumentError(
        'Chargeable days cannot exceed billing period days.',
      );
    }

    if (!request.billingPeriodEnd.isAfter(
      request.billingPeriodStart,
    )) {
      throw ArgumentError(
        'Billing period end must be after billing period start.',
      );
    }

    if (request.chargePeriodStart.isBefore(
      request.billingPeriodStart,
    )) {
      throw ArgumentError(
        'Charge period cannot start before billing period.',
      );
    }

    if (request.chargePeriodEnd.isAfter(
      request.billingPeriodEnd,
    )) {
      throw ArgumentError(
        'Charge period cannot end after billing period.',
      );
    }

    if (request.chargePeriodEnd.isBefore(
      request.chargePeriodStart,
    )) {
      throw ArgumentError(
        'Charge period end cannot be before charge period start.',
      );
    }

    if (request.dueDate.isBefore(
      request.billingPeriodStart,
    )) {
      throw ArgumentError(
        'Due date cannot be before the billing period starts.',
      );
    }

    final expectedProrationFactor =
        request.chargeableDays / request.daysInBillingPeriod;

    final calculatedAmount =
        request.monthlyRate * expectedProrationFactor;

    const double tolerance = 0.01;

    if ((request.amount - calculatedAmount).abs() > tolerance) {
      throw ArgumentError(
        'Rent amount does not match the expected '
            'prorated rent calculation.',
      );
    }

    final periodKey = _formatPeriodKey(
      request.billingPeriodStart,
    );

    // Tenant-aware identity.
    //
    // This allows different tenants to have rent records
    // in the same unit and calendar month when tenancy changes.
    final documentId = _buildDocumentId(
      ownerId: ownerId,
      unitId: unitId,
      tenantId: tenantId,
      periodKey: periodKey,
      chargePeriodStart: request.chargePeriodStart,
      chargePeriodEnd: request.chargePeriodEnd,
    );

    final document = _collection.doc(documentId);

    final now = DateTime.now();

    final monthlyRent = MonthlyRentModel(
      id: document.id,
      ownerId: ownerId,
      propertyId: propertyId,
      unitId: unitId,
      tenantId: tenantId,
      tenantUserId: request.tenantUserId,
      rentRateId: rentRateId,
      monthlyRate: request.monthlyRate,
      amount: request.amount,
      chargeableDays: request.chargeableDays,
      daysInBillingPeriod: request.daysInBillingPeriod,
      prorationFactor: expectedProrationFactor,
      billingPeriodStart: request.billingPeriodStart,
      billingPeriodEnd: request.billingPeriodEnd,
      chargePeriodStart: request.chargePeriodStart,
      chargePeriodEnd: request.chargePeriodEnd,
      dueDate: request.dueDate,
      status: request.status,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.runTransaction(
          (transaction) async {
        final existingSnapshot = await transaction.get(
          document,
        );

        if (existingSnapshot.exists) {
          throw StateError(
            'Monthly rent already exists for this '
                'tenant and charge period.',
          );
        }

        transaction.set(
          document,
          monthlyRent.toFirestore(),
        );
      },
    );

    return monthlyRent;
  }

  // ==========================================================================
  // GET BY ID
  // ==========================================================================

  Future<MonthlyRentModel?> getMonthlyRentById(
      String rentId,
      ) async {
    final normalizedRentId = rentId.trim();

    if (normalizedRentId.isEmpty) {
      return null;
    }

    final document = await _collection
        .doc(normalizedRentId)
        .get();

    if (!document.exists) {
      return null;
    }

    return MonthlyRentModel.fromFirestore(
      document,
    );
  }



  // ==========================================================================
  // GET ALL RENTS FOR UNIT + BILLING PERIOD
  // ==========================================================================

  Future<List<MonthlyRentModel>>
  getMonthlyRentsByUnitAndPeriod({
    required String unitId,
    required String ownerId,
    required DateTime billingPeriodStart,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

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
        billingPeriodStart,
      ),
    )
        .orderBy(
      'chargePeriodStart',
      descending: false,
    )
        .get();

    return snapshot.docs
        .map(MonthlyRentModel.fromFirestore)
        .toList();
  }

  // ==========================================================================
  // UNIT HISTORY
  // ==========================================================================

  Future<List<MonthlyRentModel>>
  getMonthlyRentHistoryByUnitId({
    required String unitId,
    required String ownerId,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    final snapshot = await _collection
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'unitId',
      isEqualTo: normalizedUnitId,
    )
        .orderBy(
      'billingPeriodStart',
      descending: true,
    )
        .orderBy(
      'chargePeriodStart',
      descending: true,
    )
        .get();

    return snapshot.docs
        .map(MonthlyRentModel.fromFirestore)
        .toList();
  }

  // ==========================================================================
  // TENANT HISTORY
  // ==========================================================================

  Future<List<MonthlyRentModel>>
  getMonthlyRentHistoryByTenantId({
    required String tenantId,
    required String ownerId,
  }) async {
    final normalizedTenantId = tenantId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    final snapshot = await _collection
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'tenantId',
      isEqualTo: normalizedTenantId,
    )
        .orderBy(
      'billingPeriodStart',
      descending: true,
    )
        .orderBy(
      'chargePeriodStart',
      descending: true,
    )
        .get();

    return snapshot.docs
        .map(MonthlyRentModel.fromFirestore)
        .toList();
  }

  // ==========================================================================
  // PERIOD
  // ==========================================================================

  Future<List<MonthlyRentModel>>
  getMonthlyRentsByPeriod({
    required String ownerId,
    required DateTime billingPeriodStart,
    required DateTime billingPeriodEnd,
  }) async {
    final normalizedOwnerId = ownerId.trim();

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    if (!billingPeriodEnd.isAfter(
      billingPeriodStart,
    )) {
      throw ArgumentError(
        'Billing period end must be after billing period start.',
      );
    }

    final snapshot = await _collection
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'billingPeriodStart',
      isEqualTo: Timestamp.fromDate(
        billingPeriodStart,
      ),
    )
        .where(
      'billingPeriodEnd',
      isEqualTo: Timestamp.fromDate(
        billingPeriodEnd,
      ),
    )
        .orderBy(
      'unitId',
    )
        .orderBy(
      'chargePeriodStart',
    )
        .get();

    return snapshot.docs
        .map(MonthlyRentModel.fromFirestore)
        .toList();
  }

  // ==========================================================================
  // DOCUMENT ID
  // ==========================================================================

  String _buildDocumentId({
    required String ownerId,
    required String unitId,
    required String tenantId,
    required String periodKey,
    required DateTime chargePeriodStart,
    required DateTime chargePeriodEnd,
  }) {
    final startKey = _formatDateKey(
      chargePeriodStart,
    );

    final endKey = _formatDateKey(
      chargePeriodEnd,
    );

    return '${ownerId}_${unitId}_${tenantId}_${periodKey}_${startKey}_$endKey';
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
  // DATE KEY
  // ==========================================================================

  String _formatDateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}