import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/rent_rate.dart';
import '../models/rent_rate_model.dart';

class RentRateDataSource {
  final FirebaseFirestore _firestore;

  RentRateDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'rentRates';

  CollectionReference<Map<String, dynamic>> get _collection =>
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
    final tenantId = rentRate.tenantId.trim();

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

    if (rentRate.amount <= 0) {
      throw ArgumentError('Rent amount must be greater than zero.');
    }

    if (rentRate.source != RentRateSource.initial) {
      throw ArgumentError('Initial rent rate must use RentRateSource.initial.');
    }

    final docRef = _collection.doc();

    await docRef.set(rentRate.toFirestore());

    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      throw StateError('Rent rate was created but could not be retrieved.');
    }

    return RentRateModel.fromFirestore(snapshot);
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

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }

    final snapshot = await _collection
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('unitId', isEqualTo: normalizedUnitId)
        .where('effectiveTo', isNull: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return RentRateModel.fromFirestore(snapshot.docs.first);
  }

  // ============================================================
  // GET RENT RATE HISTORY BY UNIT
  // ============================================================

  Future<List<RentRateModel>> getRentRateHistoryByUnitId({
    required String unitId,
    required String ownerId,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }

    final snapshot = await _collection
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('unitId', isEqualTo: normalizedUnitId)
        .orderBy('effectiveFrom', descending: true)
        .get();

    return snapshot.docs.map(RentRateModel.fromFirestore).toList();
  }

  // ============================================================
  // GET RENT RATE HISTORY BY TENANT
  // ============================================================

  Future<List<RentRateModel>> getRentRateHistoryByTenantId({
    required String tenantId,
    required String ownerId,
  }) async {
    final normalizedTenantId = tenantId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError('Tenant ID cannot be empty.');
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }

    final snapshot = await _collection
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('tenantId', isEqualTo: normalizedTenantId)
        .orderBy('effectiveFrom', descending: true)
        .get();

    return snapshot.docs.map(RentRateModel.fromFirestore).toList();
  }

  // ============================================================
  // GET CURRENT RENT RATES BY FLOOR
  // ============================================================
  //
  // IMPORTANT:
  //
  // This method intentionally does NOT use floorNumber from
  // rentRates because RentRate does not store floorNumber.
  //
  // The caller must provide the already-filtered current rates
  // belonging to occupied units on the requested floor.
  //
  // This method is kept for repository compatibility.
  // ============================================================

  Future<List<RentRateModel>> getCurrentRentRatesByFloor({
    required String propertyId,
    required int floorNumber,
    required String ownerId,
  }) async {
    final normalizedPropertyId = propertyId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }

    if (floorNumber < 1) {
      throw ArgumentError('Floor number must be at least 1.');
    }

    final snapshot = await _collection
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('propertyId', isEqualTo: normalizedPropertyId)
        .where('effectiveTo', isNull: true)
        .get();

    return snapshot.docs.map(RentRateModel.fromFirestore).toList();
  }

  // ============================================================
  // CHANGE UNIT RENT
  // ============================================================
  //
  // Flow:
  //
  // 1. Find current rate.
  // 2. Validate tenant.
  // 3. Validate effective date.
  // 4. Transaction re-reads current rate.
  // 5. Close old rate.
  // 6. Create new rate.
  //
  // Both writes happen atomically.
  //
  // Future effective dates are allowed.
  //
  // Example:
  //
  // Current rate:
  // 01 Sep -> 10,000
  //
  // New rate:
  // 01 Oct -> 12,000
  //
  // Old effectiveTo:
  // 30 Sep 23:59:59
  // ============================================================

  Future<RentRateModel> changeUnitRent({
    required String unitId,
    required String tenantId,
    required String ownerId,
    required double amount,
    required DateTime effectiveFrom,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedTenantId = tenantId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError('Tenant ID cannot be empty.');
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }

    if (amount <= 0) {
      throw ArgumentError('Rent amount must be greater than zero.');
    }

    final currentSnapshot = await _collection
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('unitId', isEqualTo: normalizedUnitId)
        .where('effectiveTo', isNull: true)
        .limit(1)
        .get();

    if (currentSnapshot.docs.isEmpty) {
      throw StateError('No current rent rate exists for this unit.');
    }

    final currentDoc = currentSnapshot.docs.first;

    final currentRate = RentRateModel.fromFirestore(currentDoc);

    if (currentRate.tenantId != normalizedTenantId) {
      throw StateError(
        'The current rent rate does not belong to the specified tenant.',
      );
    }

    if (!effectiveFrom.isAfter(currentRate.effectiveFrom)) {
      throw ArgumentError(
        'New rent must become effective after the current rent rate started.',
      );
    }

    final now = DateTime.now();

    final newDocRef = _collection.doc();

    final newRate = RentRateModel(
      id: newDocRef.id,
      ownerId: currentRate.ownerId,
      propertyId: currentRate.propertyId,
      unitId: currentRate.unitId,
      tenantId: currentRate.tenantId,
      tenantUserId: currentRate.tenantUserId,
      amount: amount,
      effectiveFrom: effectiveFrom,
      effectiveTo: null,
      source: RentRateSource.unit,
      createdAt: now,
      updatedAt: now,
    );

    final oldRateEffectiveTo = effectiveFrom.subtract(
      const Duration(seconds: 1),
    );

    await _firestore.runTransaction((transaction) async {
      // --------------------------------------------------------
      // READ FIRST
      // --------------------------------------------------------

      final latestSnapshot = await transaction.get(currentDoc.reference);

      if (!latestSnapshot.exists) {
        throw StateError('The current rent rate no longer exists.');
      }

      final latestRate = RentRateModel.fromFirestore(latestSnapshot);

      // --------------------------------------------------------
      // CONCURRENCY VALIDATION
      // --------------------------------------------------------

      if (latestRate.ownerId != normalizedOwnerId) {
        throw StateError('The rent rate owner has changed.');
      }

      if (latestRate.unitId != normalizedUnitId) {
        throw StateError('The rent rate unit has changed.');
      }

      if (latestRate.tenantId != normalizedTenantId) {
        throw StateError(
          'The current rent rate no longer belongs to the specified tenant.',
        );
      }

      if (latestRate.effectiveTo != null) {
        throw StateError('The current rent rate has already been closed.');
      }

      if (!effectiveFrom.isAfter(latestRate.effectiveFrom)) {
        throw ArgumentError(
          'New rent must become effective after the current rent rate started.',
        );
      }

      // --------------------------------------------------------
      // WRITE 1 — CLOSE OLD RATE
      // --------------------------------------------------------

      transaction.update(currentDoc.reference, {
        'effectiveTo': Timestamp.fromDate(oldRateEffectiveTo),
        'updatedAt': Timestamp.fromDate(now),
      });

      // --------------------------------------------------------
      // WRITE 2 — CREATE NEW RATE
      // --------------------------------------------------------

      transaction.set(newDocRef, newRate.toFirestore());
    });

    // ----------------------------------------------------------
    // VERIFY CREATED RATE
    // ----------------------------------------------------------

    final snapshot = await newDocRef.get();

    if (!snapshot.exists) {
      throw StateError('New rent rate was created but could not be retrieved.');
    }

    return RentRateModel.fromFirestore(snapshot);
  }

  // ============================================================
  // CHANGE FLOOR RENT
  // ============================================================
  //
  // The caller supplies ONLY current rates of occupied units
  // on the selected floor.
  //
  // Vacant units therefore receive NO new RentRate.
  //
  // Every occupied unit gets its OWN new RentRate.
  //
  // Example:
  //
  // Unit A:
  // old 10,000 -> new 12,000
  //
  // Unit B:
  // old 11,000 -> new 12,000
  //
  // Unit C:
  // old 10,500 -> new 12,000
  //
  // Each unit keeps its own independent history.
  // ============================================================

  Future<List<RentRateModel>> changeFloorRent({
    required List<RentRateModel> currentRates,
    required double amount,
    required DateTime effectiveFrom,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Rent amount must be greater than zero.');
    }

    if (currentRates.isEmpty) {
      return [];
    }

    // ----------------------------------------------------------
    // BASIC VALIDATION BEFORE TRANSACTION
    // ----------------------------------------------------------

    final ownerId = currentRates.first.ownerId;
    final propertyId = currentRates.first.propertyId;

    if (ownerId.trim().isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }

    if (propertyId.trim().isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    final unitIds = <String>{};
    final tenantIds = <String>{};

    for (final currentRate in currentRates) {
      if (currentRate.ownerId != ownerId) {
        throw StateError('All floor rent rates must belong to the same owner.');
      }

      if (currentRate.propertyId != propertyId) {
        throw StateError(
          'All floor rent rates must belong to the same property.',
        );
      }

      if (currentRate.unitId.trim().isEmpty) {
        throw StateError('A rent rate contains an empty unit ID.');
      }

      if (currentRate.tenantId.trim().isEmpty) {
        throw StateError('A rent rate contains an empty tenant ID.');
      }

      if (!unitIds.add(currentRate.unitId)) {
        throw StateError(
          'Duplicate current rent rate found for unit ${currentRate.unitId}.',
        );
      }

      if (!tenantIds.add(currentRate.tenantId)) {
        throw StateError(
          'Multiple current rent rates found for tenant ${currentRate.tenantId}.',
        );
      }

      if (currentRate.effectiveTo != null) {
        throw StateError('A supplied rent rate is no longer current.');
      }

      if (!effectiveFrom.isAfter(currentRate.effectiveFrom)) {
        throw ArgumentError(
          'New rent must become effective after every current rent rate being changed.',
        );
      }
    }

    final now = DateTime.now();

    final oldRateEffectiveTo = effectiveFrom.subtract(
      const Duration(seconds: 1),
    );

    // ----------------------------------------------------------
    // PREPARE NEW RATE DOCUMENTS
    // ----------------------------------------------------------

    final newRates = <RentRateModel>[];

    final transactionItems =
        <
          ({
            DocumentReference<Map<String, dynamic>> currentRef,
            DocumentReference<Map<String, dynamic>> newRef,
            RentRateModel newRate,
          })
        >[];

    for (final currentRate in currentRates) {
      final currentRef = _collection.doc(currentRate.id);

      final newRef = _collection.doc();

      final newRate = RentRateModel(
        id: newRef.id,
        ownerId: currentRate.ownerId,
        propertyId: currentRate.propertyId,
        unitId: currentRate.unitId,
        tenantId: currentRate.tenantId,
        tenantUserId: currentRate.tenantUserId,
        amount: amount,
        effectiveFrom: effectiveFrom,
        effectiveTo: null,
        source: RentRateSource.floor,
        createdAt: now,
        updatedAt: now,
      );

      newRates.add(newRate);

      transactionItems.add((
        currentRef: currentRef,
        newRef: newRef,
        newRate: newRate,
      ));
    }

    // ----------------------------------------------------------
    // ATOMIC FLOOR TRANSACTION
    // ----------------------------------------------------------

    await _firestore.runTransaction((transaction) async {
      // ========================================================
      // READ PHASE
      // ========================================================
      //
      // IMPORTANT:
      // Firestore transaction reads must happen before writes.
      // ========================================================

      final latestSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final item in transactionItems) {
        final snapshot = await transaction.get(item.currentRef);

        latestSnapshots.add(snapshot);
      }

      // ========================================================
      // VALIDATE ALL CURRENT RATES
      // ========================================================

      for (var index = 0; index < transactionItems.length; index++) {
        final item = transactionItems[index];

        final latestSnapshot = latestSnapshots[index];

        if (!latestSnapshot.exists) {
          throw StateError('One of the current rent rates no longer exists.');
        }

        final latestRate = RentRateModel.fromFirestore(latestSnapshot);

        // ------------------------------------------------------
        // OWNER
        // ------------------------------------------------------

        if (latestRate.ownerId != ownerId) {
          throw StateError(
            'One of the rent rates belongs to a different owner.',
          );
        }

        // ------------------------------------------------------
        // PROPERTY
        // ------------------------------------------------------

        if (latestRate.propertyId != propertyId) {
          throw StateError(
            'One of the rent rates belongs to a different property.',
          );
        }

        // ------------------------------------------------------
        // UNIT
        // ------------------------------------------------------

        if (latestRate.unitId != item.newRate.unitId) {
          throw StateError('One of the rent rate unit references changed.');
        }

        // ------------------------------------------------------
        // TENANT
        // ------------------------------------------------------

        if (latestRate.tenantId != item.newRate.tenantId) {
          throw StateError('One of the rent rate tenant references changed.');
        }

        // ------------------------------------------------------
        // CURRENT RATE
        // ------------------------------------------------------

        if (latestRate.effectiveTo != null) {
          throw StateError('One of the rent rates has already been changed.');
        }

        // ------------------------------------------------------
        // EFFECTIVE DATE
        // ------------------------------------------------------

        if (!effectiveFrom.isAfter(latestRate.effectiveFrom)) {
          throw ArgumentError(
            'New rent must become effective after every current rent rate being changed.',
          );
        }
      }

      // ========================================================
      // WRITE PHASE
      // ========================================================

      for (final item in transactionItems) {
        // ------------------------------------------------------
        // CLOSE OLD RATE
        // ------------------------------------------------------

        transaction.update(item.currentRef, {
          'effectiveTo': Timestamp.fromDate(oldRateEffectiveTo),
          'updatedAt': Timestamp.fromDate(now),
        });

        // ------------------------------------------------------
        // CREATE NEW RATE
        // ------------------------------------------------------

        transaction.set(item.newRef, item.newRate.toFirestore());
      }
    });

    // ----------------------------------------------------------
    // VERIFY CREATED RATES
    // ----------------------------------------------------------

    final createdRates = <RentRateModel>[];

    for (final newRate in newRates) {
      final snapshot = await _collection.doc(newRate.id).get();

      if (!snapshot.exists) {
        throw StateError(
          'One of the new floor rent rates could not be retrieved.',
        );
      }

      createdRates.add(RentRateModel.fromFirestore(snapshot));
    }

    return createdRates;
  }

  Future<RentRateModel?> getRentRateApplicableAt({
    required String unitId,
    required String ownerId,
    required DateTime effectiveAt,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
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
      'effectiveFrom',
      isLessThanOrEqualTo: Timestamp.fromDate(
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

    final rate = RentRateModel.fromFirestore(
      snapshot.docs.first,
    );

    if (rate.effectiveTo != null &&
        effectiveAt.isAfter(rate.effectiveTo!)) {
      return null;
    }

    return rate;
  }
}
