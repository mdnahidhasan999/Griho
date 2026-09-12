import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/rent_rate.dart';
import '../models/rent_rate_model.dart';

class RentRateDataSource {
  final FirebaseFirestore _firestore;

  RentRateDataSource({FirebaseFirestore? firestore})
      : _firestore =
      firestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'rentRates';

  CollectionReference<Map<String, dynamic>> get _rentRates =>
      _firestore.collection(_collectionName);

  // ============================================================
  // CREATE INITIAL RENT RATE
  // ============================================================

  Future<RentRateModel> createInitialRentRate({
    required RentRateModel rentRate,
  }) async {
    if (rentRate.ownerId
        .trim()
        .isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    if (rentRate.propertyId
        .trim()
        .isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    if (rentRate.unitId
        .trim()
        .isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    if (rentRate.tenantId
        .trim()
        .isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    if (rentRate.amount <= 0) {
      throw ArgumentError(
        'Rent amount must be greater than zero.',
      );
    }

    if (rentRate.source != RentRateSource.initial) {
      throw ArgumentError(
        'Initial rent rate must use initial source.',
      );
    }

    if (rentRate.previousRentRateId != null) {
      throw ArgumentError(
        'Initial rent rate cannot have a previous rate.',
      );
    }

    if (rentRate.nextRentRateId != null) {
      throw ArgumentError(
        'Initial rent rate cannot have a next rate.',
      );
    }

    if (rentRate.effectiveTo != null) {
      throw ArgumentError(
        'Initial rent rate must not have an effective end date.',
      );
    }

    final document = _rentRates.doc();

    final initialRentRate = RentRateModel(
      id: document.id,
      ownerId: rentRate.ownerId,
      propertyId: rentRate.propertyId,
      unitId: rentRate.unitId,
      tenantId: rentRate.tenantId,
      tenantUserId: rentRate.tenantUserId,
      amount: rentRate.amount,
      effectiveFrom: rentRate.effectiveFrom,
      effectiveTo: null,
      source: rentRate.source,
      previousRentRateId:
      rentRate.previousRentRateId,
      nextRentRateId: null,
      createdAt: rentRate.createdAt,
      updatedAt: rentRate.updatedAt,
    );

    await document.set(
      initialRentRate.toFirestore(),
    );

    final snapshot = await document.get();

    if (!snapshot.exists) {
      throw StateError(
        'Initial rent rate was created but could not be retrieved.',
      );
    }

    return RentRateModel.fromFirestore(
      snapshot,
    );
  }

  // ============================================================
  // GET CURRENT RENT RATE — OWNER
  // ============================================================
  //
  // IMPORTANT:
  //
  // A future scheduled rate must NOT be returned as the current
  // rate.
  //
  // Example:
  //
  // Today:              10 September
  //
  // Old rate:
  // effectiveFrom:      01 January
  // effectiveTo:        30 September
  //
  // Future rate:
  // effectiveFrom:      01 October
  // effectiveTo:        null
  //
  // On 10 September, the old rate is applicable.
  // The future rate must not be returned here.
  //
  // Therefore we require:
  //
  // effectiveFrom <= now
  // AND
  // effectiveTo == null
  //
  // ============================================================

  Future<RentRateModel?> getCurrentRentRate({
    required String unitId,
    required String ownerId,
  }) async {
    final normalizedUnitId =
    unitId.trim();

    final normalizedOwnerId =
    ownerId.trim();

    if (normalizedUnitId.isEmpty ||
        normalizedOwnerId.isEmpty) {
      return null;
    }

    final now = Timestamp.fromDate(
      DateTime.now(),
    );

    final snapshot = await _rentRates
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'unitId',
      isEqualTo: normalizedUnitId,
    )
        .where(
      'effectiveFrom',
      isLessThanOrEqualTo: now,
    )
        .where(
      'effectiveTo',
      isNull: true,
    )
        .orderBy(
      'effectiveFrom',
      descending: true,
    )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return RentRateModel.fromFirestore(
      snapshot.docs.first,
    );
  }

  // ============================================================
  // GET CURRENT RENT RATE — TENANT
  // ============================================================

  Future<RentRateModel?> getCurrentRentRateForTenant({
    required String unitId,
    required String tenantUserId,
  }) async {
    final normalizedUnitId =
    unitId.trim();

    final normalizedTenantUserId =
    tenantUserId.trim();

    if (normalizedUnitId.isEmpty ||
        normalizedTenantUserId.isEmpty) {
      return null;
    }

    final now = Timestamp.fromDate(
      DateTime.now(),
    );

    final snapshot = await _rentRates
        .where(
      'tenantUserId',
      isEqualTo: normalizedTenantUserId,
    )
        .where(
      'unitId',
      isEqualTo: normalizedUnitId,
    )
        .where(
      'effectiveFrom',
      isLessThanOrEqualTo: now,
    )
        .where(
      'effectiveTo',
      isNull: true,
    )
        .orderBy(
      'effectiveFrom',
      descending: true,
    )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return RentRateModel.fromFirestore(
      snapshot.docs.first,
    );
  }

  // ============================================================
  // GET APPLICABLE RENT RATE — OWNER
  // ============================================================

  Future<RentRateModel?> getRentRateApplicableAt({
    required String unitId,
    required String ownerId,
    required DateTime effectiveAt,
  }) async {
    final normalizedUnitId =
    unitId.trim();

    final normalizedOwnerId =
    ownerId.trim();

    if (normalizedUnitId.isEmpty ||
        normalizedOwnerId.isEmpty) {
      return null;
    }

    final snapshot = await _rentRates
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'unitId',
      isEqualTo: normalizedUnitId,
    )
        .where(
      'effectiveFrom',
      isLessThanOrEqualTo:
      Timestamp.fromDate(
        effectiveAt,
      ),
    )
        .orderBy(
      'effectiveFrom',
      descending: true,
    )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final rate =
    RentRateModel.fromFirestore(
      snapshot.docs.first,
    );

    if (rate.effectiveTo != null &&
        effectiveAt.isAfter(
          rate.effectiveTo!,
        )) {
      return null;
    }

    return rate;
  }

  // ============================================================
  // UNIT HISTORY — OWNER
  // ============================================================

  Future<List<RentRateModel>>
  getRentRateHistoryByUnitId({
    required String unitId,
    required String ownerId,
  }) async {
    final normalizedUnitId =
    unitId.trim();

    final normalizedOwnerId =
    ownerId.trim();

    if (normalizedUnitId.isEmpty ||
        normalizedOwnerId.isEmpty) {
      return [];
    }

    final snapshot = await _rentRates
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'unitId',
      isEqualTo: normalizedUnitId,
    )
        .orderBy(
      'effectiveFrom',
      descending: true,
    )
        .get();

    return snapshot.docs
        .map(
      RentRateModel.fromFirestore,
    )
        .toList();
  }

  // ============================================================
  // TENANT HISTORY — OWNER
  // ============================================================

  Future<List<RentRateModel>>
  getRentRateHistoryByTenantId({
    required String tenantId,
    required String ownerId,
  }) async {
    final normalizedTenantId =
    tenantId.trim();

    final normalizedOwnerId =
    ownerId.trim();

    if (normalizedTenantId.isEmpty ||
        normalizedOwnerId.isEmpty) {
      return [];
    }

    final snapshot = await _rentRates
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'tenantId',
      isEqualTo: normalizedTenantId,
    )
        .orderBy(
      'effectiveFrom',
      descending: true,
    )
        .get();

    return snapshot.docs
        .map(
      RentRateModel.fromFirestore,
    )
        .toList();
  }

  // ============================================================
  // CURRENT RATES BY FLOOR — OWNER
  // ============================================================
  //
  // NOTE:
  //
  // floorNumber is currently retained in the method signature
  // for compatibility with the existing architecture.
  //
  // The rentRates collection does not contain floorNumber.
  // Therefore this query currently returns current rates for
  // the whole property.
  //
  // Proper floor filtering should be done by resolving units
  // belonging to the requested floor first.
  //
  // ============================================================

  Future<List<RentRateModel>>
  getCurrentRentRatesByFloor({
    required String propertyId,
    required int floorNumber,
    required String ownerId,
  }) async {
    final normalizedPropertyId =
    propertyId.trim();

    final normalizedOwnerId =
    ownerId.trim();

    if (normalizedPropertyId.isEmpty ||
        normalizedOwnerId.isEmpty) {
      return [];
    }

    final now = Timestamp.fromDate(
      DateTime.now(),
    );

    final snapshot = await _rentRates
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'propertyId',
      isEqualTo: normalizedPropertyId,
    )
        .where(
      'effectiveFrom',
      isLessThanOrEqualTo: now,
    )
        .where(
      'effectiveTo',
      isNull: true,
    )
        .get();

    return snapshot.docs
        .map(
      RentRateModel.fromFirestore,
    )
        .toList();
  }

  // ============================================================
  // CHANGE UNIT RENT
  // ============================================================

  Future<RentRateModel> changeUnitRent({
    required String unitId,
    required String tenantId,
    required String ownerId,
    required double amount,
    required DateTime effectiveFrom,
  }) async {
    final normalizedUnitId =
    unitId.trim();

    final normalizedTenantId =
    tenantId.trim();

    final normalizedOwnerId =
    ownerId.trim();

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

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

    if (amount <= 0) {
      throw ArgumentError(
        'Rent amount must be greater than zero.',
      );
    }

    final currentRate =
    await getCurrentRentRate(
      unitId: normalizedUnitId,
      ownerId: normalizedOwnerId,
    );

    if (currentRate == null) {
      throw StateError(
        'No current rent rate exists.',
      );
    }

    if (currentRate.tenantId !=
        normalizedTenantId) {
      throw StateError(
        'The current rent rate does not belong to this tenant.',
      );
    }

    if (!effectiveFrom.isAfter(
      currentRate.effectiveFrom,
    )) {
      throw ArgumentError(
        'New effective date must be after the current rent rate start date.',
      );
    }

    final newDocument =
    _rentRates.doc();

    final now = DateTime.now();

    final newRate = RentRateModel(
      id: newDocument.id,
      ownerId: currentRate.ownerId,
      propertyId: currentRate.propertyId,
      unitId: currentRate.unitId,
      tenantId: currentRate.tenantId,
      tenantUserId:
      currentRate.tenantUserId,
      amount: amount,
      effectiveFrom: effectiveFrom,
      effectiveTo: null,
      source: RentRateSource.unit,
      previousRentRateId:
      currentRate.id,
      nextRentRateId: null,
      createdAt: now,
      updatedAt: now,
    );

    final oldEffectiveTo =
    effectiveFrom.subtract(
      const Duration(seconds: 1),
    );

    await _firestore.runTransaction(
          (transaction) async {
        final oldRateReference =
        _rentRates.doc(
          currentRate.id,
        );

        final freshOldSnapshot =
        await transaction.get(
          oldRateReference,
        );

        if (!freshOldSnapshot.exists) {
          throw StateError(
            'Current rent rate no longer exists.',
          );
        }

        final freshOld =
        RentRateModel.fromFirestore(
          freshOldSnapshot,
        );

        if (freshOld.effectiveTo !=
            null) {
          throw StateError(
            'The current rent rate has already been closed.',
          );
        }

        if (freshOld.tenantId !=
            normalizedTenantId) {
          throw StateError(
            'Tenant changed while updating rent.',
          );
        }

        if (!effectiveFrom.isAfter(
          freshOld.effectiveFrom,
        )) {
          throw StateError(
            'Effective date is no longer valid.',
          );
        }

        // --------------------------------------------------------
        // CLOSE OLD RENT RATE
        //
        // The forward link allows Firestore Rules to verify that
        // this old rate is being closed specifically because of
        // the newly-created rate in the same transaction.
        // --------------------------------------------------------

        transaction.update(
          oldRateReference,
          {
            'effectiveTo':
            Timestamp.fromDate(
              oldEffectiveTo,
            ),
            'nextRentRateId':
            newDocument.id,
            'updatedAt':
            FieldValue.serverTimestamp(),
          },
        );

        // --------------------------------------------------------
        // CREATE NEW RENT RATE
        // --------------------------------------------------------

        transaction.set(
          newDocument,
          newRate.toFirestore(),
        );
      },
    );

    return newRate;
  }

  // ============================================================
  // CHANGE FLOOR RENT
  // ============================================================

  Future<List<RentRateModel>> changeFloorRent({
    required List<RentRateModel> currentRates,
    required double amount,
    required DateTime effectiveFrom,
  }) async {
    return _changeBulkRent(
      currentRates: currentRates,
      amount: amount,
      effectiveFrom: effectiveFrom,
      source: RentRateSource.floor,
    );
  }

  // ============================================================
  // CHANGE PROPERTY RENT
  // ============================================================

  Future<List<RentRateModel>> changePropertyRent({
    required List<RentRateModel> currentRates,
    required double amount,
    required DateTime effectiveFrom,
  }) async {
    return _changeBulkRent(
      currentRates: currentRates,
      amount: amount,
      effectiveFrom: effectiveFrom,
      source: RentRateSource.property,
    );
  }

  // ============================================================
  // BULK RENT CHANGE
  // ============================================================

  Future<List<RentRateModel>> _changeBulkRent({
    required List<RentRateModel> currentRates,
    required double amount,
    required DateTime effectiveFrom,
    required RentRateSource source,
  }) async {
    if (currentRates.isEmpty) {
      return [];
    }

    if (amount <= 0) {
      throw ArgumentError(
        'Rent amount must be greater than zero.',
      );
    }

    final unitIds = <String>{};

    for (final rate in currentRates) {
      if (!unitIds.add(rate.unitId)) {
        throw StateError(
          'Duplicate current rent rate found for a unit.',
        );
      }

      if (rate.effectiveTo != null) {
        throw StateError(
          'All supplied rent rates must be current rates.',
        );
      }

      if (!effectiveFrom.isAfter(
        rate.effectiveFrom,
      )) {
        throw ArgumentError(
          'New effective date must be after every current rent rate start date.',
        );
      }
    }

    final newRates =
    <RentRateModel>[];

    for (final currentRate in currentRates) {
      final document =
      _rentRates.doc();

      final now = DateTime.now();

      newRates.add(
        RentRateModel(
          id: document.id,
          ownerId: currentRate.ownerId,
          propertyId:
          currentRate.propertyId,
          unitId: currentRate.unitId,
          tenantId: currentRate.tenantId,
          tenantUserId:
          currentRate.tenantUserId,
          amount: amount,
          effectiveFrom:
          effectiveFrom,
          effectiveTo: null,
          source: source,
          previousRentRateId:
          currentRate.id,
          nextRentRateId: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // ==========================================================
    // FIRESTORE SECURITY-RULE ACCESS LIMIT
    //
    // We intentionally process only 2 units per batch.
    //
    // Each unit performs:
    //
    //   1. old rent-rate update
    //   2. new rent-rate create
    //
    // The rent-rate security rules use multiple get/getAfter
    // operations.
    //
    // Two units keeps the expected access-call count safely
    // below Firestore's 20-call limit for the atomic batch.
    //
    // ==========================================================

    const unitsPerBatch = 2;

    for (
    var start = 0;
    start < currentRates.length;
    start += unitsPerBatch
    ) {
      final end =
      (start + unitsPerBatch)
          .clamp(
        0,
        currentRates.length,
      );

      final batch =
      _firestore.batch();

      for (
      var index = start;
      index < end;
      index++
      ) {
        final currentRate =
        currentRates[index];

        final newRate =
        newRates[index];

        final oldEffectiveTo =
        effectiveFrom.subtract(
          const Duration(seconds: 1),
        );

        // ------------------------------------------------------
        // CLOSE OLD RATE
        // ------------------------------------------------------

        batch.update(
          _rentRates.doc(
            currentRate.id,
          ),
          {
            'effectiveTo':
            Timestamp.fromDate(
              oldEffectiveTo,
            ),
            'nextRentRateId':
            newRate.id,
            'updatedAt':
            FieldValue.serverTimestamp(),
          },
        );

        // ------------------------------------------------------
        // CREATE NEW RATE
        // ------------------------------------------------------

        batch.set(
          _rentRates.doc(
            newRate.id,
          ),
          newRate.toFirestore(),
        );
      }

      await batch.commit();
    }

    return newRates;
  }
}