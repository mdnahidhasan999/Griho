// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/rent_adjustment.dart';
import '../../domain/entities/rent_rate.dart';
import '../models/rent_rate_model.dart';

typedef JsonMap = Map<String, dynamic>;

class RentRateDataSource {
  final FirebaseFirestore _firestore;

  RentRateDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'rentRates';
  static const String _unitCollectionName = 'units';
  static const int _unitsPerBatch = 10;

  CollectionReference<JsonMap> get _rentRates =>
      _firestore.collection(_collectionName);

  CollectionReference<JsonMap> get _units =>
      _firestore.collection(_unitCollectionName);

  // ============================================================
  // CREATE INITIAL RENT RATE (NO EXTRA POST-WRITE READ)
  // ============================================================

  Future<RentRateModel> createInitialRentRate({
    required RentRateModel rentRate,
  }) async {
    final ownerId = rentRate.ownerId.trim();
    final propertyId = rentRate.propertyId.trim();
    final unitId = rentRate.unitId.trim();

    if (ownerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }
    if (propertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }
    if (unitId.isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }
    if (rentRate.amount <= 0) {
      throw ArgumentError('Rent amount must be greater than zero.');
    }
    if (rentRate.source != RentRateSource.initial) {
      throw ArgumentError('Initial rent rate must use initial source.');
    }
    if (rentRate.previousRentRateId != null) {
      throw ArgumentError('Initial rent rate cannot have a previous rate.');
    }
    if (rentRate.nextRentRateId != null) {
      throw ArgumentError('Initial rent rate cannot have a next rate.');
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

    await document.set(initialRentRate.toFirestore());
    return initialRentRate;
  }

  // ============================================================
  // GET CURRENT RENT RATE
  // ============================================================

  Future<RentRateModel?> getCurrentRentRate({
    required String unitId,
    required String ownerId,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedUnitId.isEmpty || normalizedOwnerId.isEmpty) {
      return null;
    }

    return getRentRateApplicableAt(
      unitId: normalizedUnitId,
      ownerId: normalizedOwnerId,
      effectiveAt: DateTime.now(),
    );
  }

  // ============================================================
  // GET APPLICABLE RENT RATE (BOUNDED READ)
  // ============================================================

  Future<RentRateModel?> getRentRateApplicableAt({
    required String unitId,
    required String ownerId,
    required DateTime effectiveAt,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedUnitId.isEmpty || normalizedOwnerId.isEmpty) {
      return null;
    }

    final snapshot = await _rentRates
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('unitId', isEqualTo: normalizedUnitId)
        .where(
          'effectiveFrom',
          isLessThanOrEqualTo: Timestamp.fromDate(effectiveAt),
        )
        .orderBy('effectiveFrom', descending: true)
        .limit(10)
        .get();

    for (final document in snapshot.docs) {
      final rate = RentRateModel.fromFirestore(document);
      if (rate.isApplicableAt(effectiveAt)) {
        return rate;
      }
    }

    return null;
  }

  // ============================================================
  // UNIT HISTORY
  // ============================================================

  Future<List<RentRateModel>> getRentRateHistoryByUnitId({
    required String unitId,
    required String ownerId,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedUnitId.isEmpty || normalizedOwnerId.isEmpty) {
      return [];
    }

    final snapshot = await _rentRates
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('unitId', isEqualTo: normalizedUnitId)
        .orderBy('effectiveFrom', descending: true)
        .limit(50)
        .get();

    return snapshot.docs.map(RentRateModel.fromFirestore).toList();
  }

  // ============================================================
  // CURRENT RATES BY PROPERTY
  // ============================================================

  Future<List<RentRateModel>> getCurrentRentRatesByProperty({
    required String propertyId,
    required String ownerId,
  }) async {
    final normalizedPropertyId = propertyId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedPropertyId.isEmpty || normalizedOwnerId.isEmpty) {
      return [];
    }

    final now = DateTime.now();

    final snapshot = await _rentRates
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('propertyId', isEqualTo: normalizedPropertyId)
        .where('effectiveFrom', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('effectiveFrom', descending: true)
        .limit(300)
        .get();

    return _getLatestApplicableRates(
      documents: snapshot.docs,
      effectiveAt: now,
    );
  }

  // ============================================================
  // CURRENT RATES BY FLOOR (PARALLEL FETCH)
  // ============================================================

  Future<List<RentRateModel>> getCurrentRentRatesByFloor({
    required String propertyId,
    required int floorNumber,
    required String ownerId,
  }) async {
    final normalizedPropertyId = propertyId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedPropertyId.isEmpty || normalizedOwnerId.isEmpty) {
      return [];
    }

    final results = await Future.wait<dynamic>([
      _units
          .where('propertyId', isEqualTo: normalizedPropertyId)
          .where('floorNumber', isEqualTo: floorNumber)
          .get(),
      getCurrentRentRatesByProperty(
        propertyId: normalizedPropertyId,
        ownerId: normalizedOwnerId,
      ),
    ]);

    final floorUnitsSnap = results[0] as QuerySnapshot<JsonMap>;
    final propertyRates = results[1] as List<RentRateModel>;

    final floorUnitIds = floorUnitsSnap.docs.map((doc) => doc.id).toSet();
    if (floorUnitIds.isEmpty) {
      return [];
    }

    return propertyRates
        .where((rate) => floorUnitIds.contains(rate.unitId))
        .toList();
  }

  // ============================================================
  // CHANGE UNIT RENT
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
      throw ArgumentError('Unit ID cannot be empty.');
    }
    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }
    if (amount <= 0) {
      throw ArgumentError('Rent amount must be greater than zero.');
    }

    final currentRate = await getCurrentRentRate(
      unitId: normalizedUnitId,
      ownerId: normalizedOwnerId,
    );

    if (currentRate == null) {
      throw StateError('No current rent rate exists for this unit.');
    }

    if (!effectiveFrom.isAfter(currentRate.effectiveFrom)) {
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

    await _firestore.runTransaction((transaction) async {
      final oldRateReference = _rentRates.doc(currentRate.id);
      final freshOldSnapshot = await transaction.get(oldRateReference);

      if (!freshOldSnapshot.exists) {
        throw StateError('Current rent rate no longer exists.');
      }

      final freshOld = RentRateModel.fromFirestore(freshOldSnapshot);

      if (!freshOld.isApplicableAt(DateTime.now())) {
        throw StateError('The current rent rate is no longer applicable.');
      }

      if (!effectiveFrom.isAfter(freshOld.effectiveFrom)) {
        throw StateError('Effective date is no longer valid.');
      }

      transaction.update(oldRateReference, {
        'effectiveTo': Timestamp.fromDate(effectiveFrom),
        'nextRentRateId': newDocument.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(newDocument, newRate.toFirestore());
    });

    return newRate;
  }

  // ============================================================
  // CHANGE FLOOR & PROPERTY RENT
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
      throw ArgumentError('Rent adjustment amount must be greater than zero.');
    }

    final adjustment = RentAdjustment(type: adjustmentType, amount: amount);
    final unitIds = <String>{};
    final now = DateTime.now();

    for (final rate in currentRates) {
      if (!unitIds.add(rate.unitId)) {
        throw StateError(
          'Duplicate current rent rate found for unit ${rate.unitId}.',
        );
      }
      if (!rate.isApplicableAt(now)) {
        throw StateError(
          'Supplied rent rate for unit ${rate.unitId} is not currently applicable.',
        );
      }
      if (!effectiveFrom.isAfter(rate.effectiveFrom)) {
        throw ArgumentError(
          'New effective date must be after every current rent rate start date.',
        );
      }
    }

    final sample = currentRates.first;
    final futureSnapshot = await _rentRates
        .where('ownerId', isEqualTo: sample.ownerId)
        .where('propertyId', isEqualTo: sample.propertyId)
        .where(
          'effectiveFrom',
          isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveFrom),
        )
        .get();

    for (final doc in futureSnapshot.docs) {
      final futureUnitId = (doc.data()['unitId'] ?? '').toString();
      if (unitIds.contains(futureUnitId)) {
        throw StateError(
          'A future rent rate is already scheduled for unit $futureUnitId.',
        );
      }
    }

    final newRates = <RentRateModel>[];
    for (final currentRate in currentRates) {
      final newAmount = adjustment.applyTo(currentRate.amount);
      final document = _rentRates.doc();

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

    for (var start = 0; start < currentRates.length; start += _unitsPerBatch) {
      final end = (start + _unitsPerBatch).clamp(0, currentRates.length);
      final batch = _firestore.batch();

      for (var index = start; index < end; index++) {
        final currentRate = currentRates[index];
        final newRate = newRates[index];

        batch.update(_rentRates.doc(currentRate.id), {
          'effectiveTo': Timestamp.fromDate(effectiveFrom),
          'nextRentRateId': newRate.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        batch.set(_rentRates.doc(newRate.id), newRate.toFirestore());
      }

      await batch.commit();
    }

    return newRates;
  }

  Future<void> _ensureNoFutureRateConflict({
    required String unitId,
    required String ownerId,
    required DateTime effectiveFrom,
  }) async {
    final snapshot = await _rentRates
        .where('ownerId', isEqualTo: ownerId)
        .where('unitId', isEqualTo: unitId)
        .where(
          'effectiveFrom',
          isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveFrom),
        )
        .orderBy('effectiveFrom', descending: false)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      throw StateError(
        'A future rent rate is already scheduled for unit $unitId.',
      );
    }
  }

  List<RentRateModel> _getLatestApplicableRates({
    required List<QueryDocumentSnapshot<JsonMap>> documents,
    required DateTime effectiveAt,
  }) {
    final latestByUnit = <String, RentRateModel>{};

    for (final document in documents) {
      final rate = RentRateModel.fromFirestore(document);
      if (!rate.isApplicableAt(effectiveAt)) {
        continue;
      }
      latestByUnit.putIfAbsent(rate.unitId, () => rate);
    }

    return latestByUnit.values.toList();
  }
}
