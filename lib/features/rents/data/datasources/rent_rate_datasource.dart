import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/rent_adjustment.dart';
import '../../domain/entities/rent_rate.dart';
import '../models/rent_rate_model.dart';

class RentRateDataSource {
  final FirebaseFirestore _firestore;

  RentRateDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore =
      firestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'rentRates';

  static const int _unitsPerBatch = 2;

  CollectionReference<Map<String, dynamic>> get _rentRates =>
      _firestore.collection(_collectionName);

  // ============================================================
  // CREATE INITIAL RENT RATE
  // ============================================================

  Future<RentRateModel> createInitialRentRate({
    required RentRateModel rentRate,
  }) async {
    final ownerId = rentRate.ownerId.trim();
    final propertyId = rentRate.propertyId.trim();
    final unitId = rentRate.unitId.trim();

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

    if (unitId.isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
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

    final existingRate = await getRentRateApplicableAt(
      unitId: unitId,
      ownerId: ownerId,
      effectiveAt: rentRate.effectiveFrom,
    );

    if (existingRate != null) {
      throw StateError(
        'A rent rate already exists for this unit at the specified effective date.',
      );
    }

    final document = _rentRates.doc();

    final initialRentRate = RentRateModel(
      id: document.id,
      ownerId: ownerId,
      propertyId: propertyId,
      unitId: unitId,
      amount: rentRate.amount,
      effectiveFrom: rentRate.effectiveFrom,
      effectiveTo: null,
      source: RentRateSource.initial,
      previousRentRateId: null,
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

  Future<RentRateModel?> getCurrentRentRate({
    required String unitId,
    required String ownerId,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedUnitId.isEmpty ||
        normalizedOwnerId.isEmpty) {
      return null;
    }

    return getRentRateApplicableAt(
      unitId: normalizedUnitId,
      ownerId: normalizedOwnerId,
      effectiveAt: DateTime.now(),
    );
  }

  // ============================================================
  // GET APPLICABLE RENT RATE — OWNER
  // ============================================================
  //
  // Rent interval:
  //
  // [effectiveFrom, effectiveTo)
  //
  // We intentionally read all rates whose effectiveFrom is
  // before/equal to the requested date and find the first rate
  // whose interval actually contains that date.
  //
  // This correctly handles future scheduled rent changes.
  // ============================================================

  Future<RentRateModel?> getRentRateApplicableAt({
    required String unitId,
    required String ownerId,
    required DateTime effectiveAt,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedUnitId.isEmpty ||
        normalizedOwnerId.isEmpty) {
      return null;
    }

    final timestamp = Timestamp.fromDate(
      effectiveAt,
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
      isLessThanOrEqualTo: timestamp,
    )
        .orderBy(
      'effectiveFrom',
      descending: true,
    )
        .get();

    for (final document in snapshot.docs) {
      final rate = RentRateModel.fromFirestore(
        document,
      );

      if (rate.isApplicableAt(effectiveAt)) {
        return rate;
      }
    }

    return null;
  }

  // ============================================================
  // UNIT HISTORY — OWNER
  // ============================================================

  Future<List<RentRateModel>> getRentRateHistoryByUnitId({
    required String unitId,
    required String ownerId,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

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
  // CURRENT RATES BY PROPERTY
  // ============================================================
  //
  // This returns all currently applicable Unit rent rates in a
  // property, including VACANT units.
  //
  // Property/Floor rent adjustment must operate on Units, not
  // tenants.
  // ============================================================

  Future<List<RentRateModel>> getCurrentRentRatesByProperty({
    required String propertyId,
    required String ownerId,
  }) async {
    final normalizedPropertyId = propertyId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedPropertyId.isEmpty ||
        normalizedOwnerId.isEmpty) {
      return [];
    }

    final now = DateTime.now();

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
      isLessThanOrEqualTo: Timestamp.fromDate(now),
    )
        .orderBy(
      'effectiveFrom',
      descending: true,
    )
        .get();

    return _getLatestApplicableRates(
      documents: snapshot.docs,
      effectiveAt: now,
    );
  }

  // ============================================================
  // CURRENT RATES BY FLOOR
  // ============================================================
  //
  // RentRate itself does not store floorNumber.
  //
  // Therefore this datasource method cannot reliably filter by
  // floor unless the Unit layer supplies the relevant Unit IDs.
  //
  // It is kept for compatibility with the existing architecture.
  // The Repository should resolve Units by floor and then obtain
  // their current rent rates individually.
  // ============================================================

  Future<List<RentRateModel>> getCurrentRentRatesByFloor({
    required String propertyId,
    required int floorNumber,
    required String ownerId,
  }) async {
    final normalizedPropertyId = propertyId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedPropertyId.isEmpty ||
        normalizedOwnerId.isEmpty) {
      return [];
    }

    final now = DateTime.now();

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
      isLessThanOrEqualTo: Timestamp.fromDate(now),
    )
        .orderBy(
      'effectiveFrom',
      descending: true,
    )
        .get();

    return _getLatestApplicableRates(
      documents: snapshot.docs,
      effectiveAt: now,
    );
  }

  // ============================================================
  // CHANGE UNIT RENT
  // ============================================================
  //
  // IMPORTANT:
  //
  // There is NO tenantId here.
  //
  // Rent belongs to the Unit.
  //
  // This works for:
  //
  // 1. Occupied unit
  // 2. Vacant unit
  // 3. Unit receiving a new tenant
  //
  // A new tenant may have a different agreed rent.
  // That new rent will simply become a new RentRate for the Unit.
  // ============================================================

  Future<RentRateModel> changeUnitRent({
    required String unitId,
    required String ownerId,
    required double amount,
    required DateTime effectiveFrom,
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

    if (amount <= 0) {
      throw ArgumentError(
        'Rent amount must be greater than zero.',
      );
    }

    final currentRate = await getCurrentRentRate(
      unitId: normalizedUnitId,
      ownerId: normalizedOwnerId,
    );

    if (currentRate == null) {
      throw StateError(
        'No current rent rate exists for this unit.',
      );
    }

    if (!effectiveFrom.isAfter(
      currentRate.effectiveFrom,
    )) {
      throw ArgumentError(
        'New effective date must be after the current rent rate start date.',
      );
    }

    await _ensureNoFutureRateConflict(
      unitId: normalizedUnitId,
      ownerId: normalizedOwnerId,
      effectiveFrom: effectiveFrom,
    );

    final newDocument = _rentRates.doc();

    final now = DateTime.now();

    final newRate = RentRateModel(
      id: newDocument.id,
      ownerId: currentRate.ownerId,
      propertyId: currentRate.propertyId,
      unitId: currentRate.unitId,
      amount: amount,
      effectiveFrom: effectiveFrom,
      effectiveTo: null,
      source: RentRateSource.unit,
      previousRentRateId: currentRate.id,
      nextRentRateId: null,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.runTransaction(
          (transaction) async {
        final oldRateReference = _rentRates.doc(
          currentRate.id,
        );

        final freshOldSnapshot = await transaction.get(
          oldRateReference,
        );

        if (!freshOldSnapshot.exists) {
          throw StateError(
            'Current rent rate no longer exists.',
          );
        }

        final freshOld = RentRateModel.fromFirestore(
          freshOldSnapshot,
        );

        if (!freshOld.isApplicableAt(
          DateTime.now(),
        )) {
          throw StateError(
            'The current rent rate is no longer applicable.',
          );
        }

        if (!effectiveFrom.isAfter(
          freshOld.effectiveFrom,
        )) {
          throw StateError(
            'Effective date is no longer valid.',
          );
        }

        transaction.update(
          oldRateReference,
          {
            'effectiveTo': Timestamp.fromDate(
              effectiveFrom,
            ),
            'nextRentRateId': newDocument.id,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

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
    required RentAdjustmentType adjustmentType,
    required DateTime effectiveFrom,
  }) async {
    return _changeBulkRent(
      currentRates: currentRates,
      amount: amount,
      adjustmentType: adjustmentType,
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
    required RentAdjustmentType adjustmentType,
    required DateTime effectiveFrom,
  }) async {
    return _changeBulkRent(
      currentRates: currentRates,
      amount: amount,
      adjustmentType: adjustmentType,
      effectiveFrom: effectiveFrom,
      source: RentRateSource.property,
    );
  }

  // ============================================================
  // BULK RENT ADJUSTMENT
  // ============================================================
  //
  // Every supplied RentRate represents a UNIT.
  //
  // The Repository is responsible for supplying ALL units,
  // including vacant units.
  //
  // Example:
  //
  // Property has 10 units:
  //   occupied = 6
  //   vacant   = 4
  //
  // Property rent increase must update:
  //   10 / 10 units
  //
  // NOT:
  //   6 / 6 occupied units.
  // ============================================================

  Future<List<RentRateModel>> _changeBulkRent({
    required List<RentRateModel> currentRates,
    required double amount,
    required RentAdjustmentType adjustmentType,
    required DateTime effectiveFrom,
    required RentRateSource source,
  }) async {
    if (currentRates.isEmpty) {
      return [];
    }

    if (amount <= 0) {
      throw ArgumentError(
        'Rent adjustment amount must be greater than zero.',
      );
    }

    final adjustment = RentAdjustment(
      type: adjustmentType,
      amount: amount,
    );

    final unitIds = <String>{};

    for (final rate in currentRates) {
      if (!unitIds.add(rate.unitId)) {
        throw StateError(
          'Duplicate current rent rate found for unit ${rate.unitId}.',
        );
      }

      if (!rate.isApplicableAt(
        DateTime.now(),
      )) {
        throw StateError(
          'Supplied rent rate for unit ${rate
              .unitId} is not currently applicable.',
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

    for (final rate in currentRates) {
      await _ensureNoFutureRateConflict(
        unitId: rate.unitId,
        ownerId: rate.ownerId,
        effectiveFrom: effectiveFrom,
      );
    }

    final newRates = <RentRateModel>[];

    for (final currentRate in currentRates) {
      final newAmount = adjustment.applyTo(
        currentRate.amount,
      );

      final document = _rentRates.doc();

      final now = DateTime.now();

      newRates.add(
        RentRateModel(
          id: document.id,
          ownerId: currentRate.ownerId,
          propertyId: currentRate.propertyId,
          unitId: currentRate.unitId,
          amount: newAmount,
          effectiveFrom: effectiveFrom,
          effectiveTo: null,
          source: source,
          previousRentRateId: currentRate.id,
          nextRentRateId: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // ==========================================================
    // FIRESTORE BATCHES
    // ==========================================================
    //
    // Each unit requires:
    //
    // 1 update old RentRate
    // 1 create new RentRate
    //
    // Keep the existing conservative two-unit batch size.
    // ==========================================================

    for (
    var start = 0;
    start < currentRates.length;
    start += _unitsPerBatch
    ) {
      final end = (start + _unitsPerBatch)
          .clamp(
        0,
        currentRates.length,
      );

      final batch = _firestore.batch();

      for (
      var index = start;
      index < end;
      index++
      ) {
        final currentRate = currentRates[index];
        final newRate = newRates[index];

        final oldReference = _rentRates.doc(
          currentRate.id,
        );

        final newReference = _rentRates.doc(
          newRate.id,
        );

        batch.update(
          oldReference,
          {
            'effectiveTo': Timestamp.fromDate(
              effectiveFrom,
            ),
            'nextRentRateId': newRate.id,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        batch.set(
          newReference,
          newRate.toFirestore(),
        );
      }

      await batch.commit();
    }

    return newRates;
  }

  // ============================================================
  // ENSURE NO FUTURE RATE CONFLICT
  // ============================================================

  Future<void> _ensureNoFutureRateConflict({
    required String unitId,
    required String ownerId,
    required DateTime effectiveFrom,
  }) async {
    final snapshot = await _rentRates
        .where(
      'ownerId',
      isEqualTo: ownerId,
    )
        .where(
      'unitId',
      isEqualTo: unitId,
    )
        .where(
      'effectiveFrom',
      isGreaterThanOrEqualTo: Timestamp.fromDate(
        effectiveFrom,
      ),
    )
        .orderBy(
      'effectiveFrom',
      descending: false,
    )
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      throw StateError(
        'A future rent rate is already scheduled for unit $unitId.',
      );
    }
  }

  // ============================================================
  // GET LATEST APPLICABLE RATES
  // ============================================================

  List<RentRateModel> _getLatestApplicableRates({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    documents,
    required DateTime effectiveAt,
  }) {
    final latestByUnit = <String, RentRateModel>{};

    for (final document in documents) {
      final rate = RentRateModel.fromFirestore(
        document,
      );

      if (!rate.isApplicableAt(
        effectiveAt,
      )) {
        continue;
      }

      latestByUnit.putIfAbsent(
        rate.unitId,
            () => rate,
      );
    }

    return latestByUnit.values.toList();
  }
}