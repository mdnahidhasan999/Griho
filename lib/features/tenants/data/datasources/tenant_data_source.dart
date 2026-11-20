import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/utils/phone_number_utils.dart';
import '../../../rents/data/models/rent_rate_model.dart';
import '../../../rents/domain/entities/rent_rate.dart';
import '../../../units/domain/entities/unit.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/tenant_search_result.dart';
import '../models/tenant_model.dart';

typedef JsonMap = Map<String, dynamic>;

class TenantDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TenantDataSource({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // ==========================================================================
  // COLLECTIONS
  // ==========================================================================

  static const String _tenantCollectionName = 'tenants';
  static const String _unitCollectionName = 'units';
  static const String _propertyCollectionName = 'properties';
  static const String _publicIdCollectionName = 'public_ids';
  static const String _phoneLookupCollectionName = 'phone_lookups';
  static const String _tenantAccessCollectionName = 'tenantAccess';
  static const String _tenancyHistoryCollectionName = 'tenancyHistories';
  static const String _rentRateCollectionName = 'rentRates';
  static const String _managerAccessCollectionName = 'managerAccess';

  CollectionReference<JsonMap> get _tenants =>
      _firestore.collection(_tenantCollectionName);

  CollectionReference<JsonMap> get _units =>
      _firestore.collection(_unitCollectionName);

  CollectionReference<JsonMap> get _properties =>
      _firestore.collection(_propertyCollectionName);

  CollectionReference<JsonMap> get _publicIds =>
      _firestore.collection(_publicIdCollectionName);

  CollectionReference<JsonMap> get _phoneLookups =>
      _firestore.collection(_phoneLookupCollectionName);

  CollectionReference<JsonMap> get _tenantAccess =>
      _firestore.collection(_tenantAccessCollectionName);

  CollectionReference<JsonMap> get _tenancyHistories =>
      _firestore.collection(_tenancyHistoryCollectionName);

  CollectionReference<JsonMap> get _rentRates =>
      _firestore.collection(_rentRateCollectionName);

  CollectionReference<JsonMap> get _managerAccess =>
      _firestore.collection(_managerAccessCollectionName);

  Future<bool> _isOwnerOrActiveManager({
    required String ownerId,
    required String propertyId,
  }) async {
    final currentUid = _auth.currentUser?.uid.trim() ?? '';
    if (currentUid.isEmpty) return false;
    if (currentUid == ownerId) return true;

    final accessDoc = await _managerAccess
        .doc('${currentUid}_$propertyId')
        .get();
    return accessDoc.exists && accessDoc.data()?['status'] == 'active';
  }

  // ==========================================================================
  // GET TENANT BY ID
  // ==========================================================================

  Future<TenantModel?> getTenantById(String tenantId) async {
    final normalizedId = tenantId.trim();
    if (normalizedId.isEmpty) return null;

    final snapshot = await _tenants.doc(normalizedId).get();
    if (!snapshot.exists) return null;

    return TenantModel.fromFirestore(snapshot);
  }

  // ==========================================================================
  // GET ACTIVE TENANT BY USER ID
  // ==========================================================================

  Future<TenantModel?> getTenantByUserId(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return null;

    final activeSnapshot = await _tenants
        .where('userId', isEqualTo: normalizedUserId)
        .where('status', isEqualTo: TenantStatus.active.name)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (activeSnapshot.docs.isNotEmpty) {
      return TenantModel.fromFirestore(activeSnapshot.docs.first);
    }

    return null;
  }

  // ==========================================================================
  // GET TENANTS BY PROPERTY
  // ==========================================================================

  Future<List<TenantModel>> getTenantsByPropertyId({
    required String propertyId,
    required String ownerId,
  }) async {
    final normalizedPropertyId = propertyId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedPropertyId.isEmpty || normalizedOwnerId.isEmpty) {
      return [];
    }

    final snapshot = await _tenants
        .where('propertyId', isEqualTo: normalizedPropertyId)
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map(TenantModel.fromFirestore).toList();
  }

  // ==========================================================================
  // GET ACTIVE TENANT BY UNIT
  // ==========================================================================

  Future<TenantModel?> getTenantByUnitId({
    required String unitId,
    required String ownerId,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedUnitId.isEmpty || normalizedOwnerId.isEmpty) {
      return null;
    }

    final snapshot = await _tenants
        .where('unitId', isEqualTo: normalizedUnitId)
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('status', isEqualTo: TenantStatus.active.name)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return TenantModel.fromFirestore(snapshot.docs.first);
  }

  // ==========================================================================
  // GET ALL ACTIVE TENANTS BY UNIT
  // ==========================================================================

  Future<List<TenantModel>> getActiveTenantsByUnitId({
    required String unitId,
    required String ownerId,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedUnitId.isEmpty || normalizedOwnerId.isEmpty) {
      return [];
    }

    final snapshot = await _tenants
        .where('unitId', isEqualTo: normalizedUnitId)
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('status', isEqualTo: TenantStatus.active.name)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map(TenantModel.fromFirestore).toList();
  }

  // ==========================================================================
  // CREATE TENANT
  // ==========================================================================

  Future<TenantModel> createTenant({required TenantModel tenant}) async {
    final normalizedPhone = tenant.phone.trim();
    final normalizedOwnerId = tenant.ownerId.trim();
    final normalizedPropertyId = tenant.propertyId.trim();
    final normalizedUnitId = tenant.unitId.trim();

    if (normalizedPhone.isEmpty) {
      throw StateError('Tenant phone number cannot be empty.');
    }
    if (normalizedOwnerId.isEmpty) {
      throw StateError('Tenant owner ID cannot be empty.');
    }
    if (normalizedPropertyId.isEmpty) {
      throw StateError('Tenant property ID cannot be empty.');
    }
    if (normalizedUnitId.isEmpty) {
      throw StateError('Tenant unit ID cannot be empty.');
    }

    final existingUnitTenantSnap = await _tenants
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('unitId', isEqualTo: normalizedUnitId)
        .where('phone', isEqualTo: normalizedPhone)
        .limit(1)
        .get();

    if (existingUnitTenantSnap.docs.isNotEmpty) {
      final existingTenant = TenantModel.fromFirestore(
        existingUnitTenantSnap.docs.first,
      );
      if (existingTenant.status == TenantStatus.active ||
          existingTenant.confirmationStatus ==
              TenantConfirmationStatus.pending) {
        throw StateError(
          'A tenant record with this phone already exists for this unit: '
          '${existingTenant.name} (${existingTenant.phone}).',
        );
      }
    }

    final tenantDocument = _tenants.doc(tenant.id);
    final propertyDocument = _properties.doc(normalizedPropertyId);
    final unitDocument = _units.doc(normalizedUnitId);

    final normalizedUserId = tenant.userId?.trim();
    final persistedUserId =
        normalizedUserId != null && normalizedUserId.isNotEmpty
        ? normalizedUserId
        : null;

    final persistedAccountStatus = persistedUserId != null
        ? TenantAccountStatus.registered
        : TenantAccountStatus.notRegistered;

    final tenantToCreate = tenant.copyWith(
      status: TenantStatus.inactive,
      userId: persistedUserId,
      accountStatus: persistedAccountStatus,
      confirmationStatus: TenantConfirmationStatus.pending,
      tenancyStartedAt: null,
      updatedAt: DateTime.now(),
    );

    await _firestore.runTransaction((transaction) async {
      final propertySnapshot = await transaction.get(propertyDocument);
      final unitSnapshot = await transaction.get(unitDocument);

      if (!propertySnapshot.exists) {
        throw StateError('Property $normalizedPropertyId does not exist.');
      }

      final propertyData = propertySnapshot.data();
      if (propertyData == null) {
        throw StateError('Property $normalizedPropertyId contains no data.');
      }

      final propertyOwnerId = (propertyData['ownerId'] as String?)?.trim();
      if (propertyOwnerId != normalizedOwnerId) {
        throw StateError(
          'The selected property does not belong to the specified owner.',
        );
      }

      if (!unitSnapshot.exists) {
        throw StateError('Unit $normalizedUnitId does not exist.');
      }

      final unitData = unitSnapshot.data();
      if (unitData == null) {
        throw StateError('Unit $normalizedUnitId contains no data.');
      }

      final unitPropertyId = (unitData['propertyId'] as String?)?.trim();
      if (unitPropertyId != normalizedPropertyId) {
        throw StateError(
          'The selected unit does not belong to the selected property.',
        );
      }

      transaction.set(
        tenantDocument,
        TenantModel.fromEntity(tenantToCreate).toFirestore(),
      );
    });

    final createdSnapshot = await tenantDocument.get();
    if (!createdSnapshot.exists) {
      throw StateError('Tenant was created but could not be retrieved.');
    }

    return TenantModel.fromFirestore(createdSnapshot);
  }

  // ==========================================================================
  // LINK TENANT ACCOUNT
  // ==========================================================================

  Future<TenantModel> linkTenantAccount({
    required String tenantId,
    required String userId,
  }) async {
    final normalizedTenantId = tenantId.trim();
    final normalizedUserId = userId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError('Tenant ID cannot be empty.');
    }
    if (normalizedUserId.isEmpty) {
      throw ArgumentError('Tenant user ID cannot be empty.');
    }

    final tenantDocument = _tenants.doc(normalizedTenantId);
    final tenantSnapshot = await tenantDocument.get();

    if (!tenantSnapshot.exists) {
      throw StateError('Tenant $normalizedTenantId does not exist.');
    }

    final tenant = TenantModel.fromFirestore(tenantSnapshot);

    if (tenant.userId != null && tenant.userId!.trim().isNotEmpty) {
      if (tenant.userId == normalizedUserId) {
        return tenant;
      }
      throw StateError('This tenant is already linked to another account.');
    }

    final activeUserSnapshot = await _tenants
        .where('userId', isEqualTo: normalizedUserId)
        .where('status', isEqualTo: TenantStatus.active.name)
        .limit(1)
        .get();

    if (activeUserSnapshot.docs.isNotEmpty) {
      final activeTenant = TenantModel.fromFirestore(
        activeUserSnapshot.docs.first,
      );
      if (activeTenant.id != normalizedTenantId) {
        throw StateError('This account already has an active residency.');
      }
    }

    final tenantPropertyDocument = _properties.doc(tenant.propertyId);
    final tenantUnitDocument = _units.doc(tenant.unitId);

    await _firestore.runTransaction((transaction) async {
      final currentTenantSnapshot = await transaction.get(tenantDocument);
      final propertySnapshot = await transaction.get(tenantPropertyDocument);
      final unitSnapshot = await transaction.get(tenantUnitDocument);

      if (!currentTenantSnapshot.exists) {
        throw StateError('Tenant $normalizedTenantId no longer exists.');
      }
      if (!propertySnapshot.exists) {
        throw StateError('Tenant property no longer exists.');
      }
      if (!unitSnapshot.exists) {
        throw StateError('Tenant unit no longer exists.');
      }

      final currentTenant = TenantModel.fromFirestore(currentTenantSnapshot);
      final currentUserId = currentTenant.userId?.trim();

      if (currentUserId != null &&
          currentUserId.isNotEmpty &&
          currentUserId != normalizedUserId) {
        throw StateError('This tenant is already linked to another account.');
      }

      final updatedTenant = currentTenant.copyWith(
        userId: normalizedUserId,
        accountStatus: TenantAccountStatus.registered,
        updatedAt: DateTime.now(),
      );

      transaction.update(
        tenantDocument,
        TenantModel.fromEntity(updatedTenant).toFirestore(),
      );

      if (currentTenant.status == TenantStatus.active) {
        transaction.update(tenantUnitDocument, {
          'tenantUserId': normalizedUserId,
          'status': UnitStatus.occupied.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(tenantPropertyDocument, {
          'tenantUserIds': FieldValue.arrayUnion([normalizedUserId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    final updatedSnapshot = await tenantDocument.get();
    if (!updatedSnapshot.exists) {
      throw StateError('Tenant was linked but could not be retrieved.');
    }

    return TenantModel.fromFirestore(updatedSnapshot);
  }

  // ==========================================================================
  // UPDATE TENANT
  // ==========================================================================

  Future<TenantModel> updateTenant(TenantModel tenant) async {
    final tenantId = tenant.id.trim();
    if (tenantId.isEmpty) {
      throw ArgumentError('Tenant ID cannot be empty.');
    }

    final tenantDocument = _tenants.doc(tenantId);
    final existingSnapshot = await tenantDocument.get();

    if (!existingSnapshot.exists) {
      throw StateError('Tenant $tenantId does not exist.');
    }

    final existingTenant = TenantModel.fromFirestore(existingSnapshot);

    final existingOwnerId = existingTenant.ownerId.trim();
    final newOwnerId = tenant.ownerId.trim();
    final oldPropertyId = existingTenant.propertyId.trim();
    final newPropertyId = tenant.propertyId.trim();
    final oldUnitId = existingTenant.unitId.trim();
    final newUnitId = tenant.unitId.trim();

    if (newOwnerId != existingOwnerId) {
      throw StateError(
        'Tenant owner cannot be changed through updateTenant().',
      );
    }

    if (tenant.status != existingTenant.status) {
      throw StateError(
        'Tenant status cannot be changed through updateTenant(). '
        'Use endTenancy() or startNewTenancy().',
      );
    }

    final existingUserId = existingTenant.userId?.trim();
    final newUserId = tenant.userId?.trim();
    final normalizedExistingUserId =
        existingUserId != null && existingUserId.isNotEmpty
        ? existingUserId
        : null;
    final normalizedNewUserId = newUserId != null && newUserId.isNotEmpty
        ? newUserId
        : null;

    if (normalizedNewUserId != normalizedExistingUserId) {
      throw StateError(
        'Tenant account cannot be changed through updateTenant(). '
        'Use linkTenantAccount().',
      );
    }

    if (tenant.accountStatus != existingTenant.accountStatus) {
      throw StateError(
        'Tenant account status cannot be changed through updateTenant().',
      );
    }

    if (tenant.tenancyStartedAt != existingTenant.tenancyStartedAt) {
      throw StateError(
        'Tenancy start date cannot be changed through updateTenant().',
      );
    }

    final normalizedPhone = tenant.phone.trim();
    if (normalizedPhone.isEmpty) {
      throw ArgumentError('Tenant phone number cannot be empty.');
    }

    final isActive = existingTenant.status == TenantStatus.active;
    final propertyChanged = oldPropertyId != newPropertyId;
    final unitChanged = oldUnitId != newUnitId;

    if (isActive && (propertyChanged || unitChanged)) {
      throw StateError(
        'An active tenant cannot be moved to another property or unit '
        'through updateTenant(). End the current tenancy first, then '
        'start a new tenancy.',
      );
    }

    final newPropertyDocument = _properties.doc(newPropertyId);
    final newUnitDocument = _units.doc(newUnitId);

    await _firestore.runTransaction((transaction) async {
      final currentTenantSnapshot = await transaction.get(tenantDocument);
      final newPropertySnapshot = await transaction.get(newPropertyDocument);
      final newUnitSnapshot = await transaction.get(newUnitDocument);

      if (!currentTenantSnapshot.exists) {
        throw StateError('Tenant $tenantId no longer exists.');
      }

      final currentTenant = TenantModel.fromFirestore(currentTenantSnapshot);

      if (!newPropertySnapshot.exists) {
        throw StateError('Property $newPropertyId does not exist.');
      }

      final propertyData = newPropertySnapshot.data();
      if (propertyData == null ||
          (propertyData['ownerId'] as String?)?.trim() != existingOwnerId) {
        throw StateError(
          'The selected property does not belong to the current owner.',
        );
      }

      if (!newUnitSnapshot.exists) {
        throw StateError('Unit $newUnitId does not exist.');
      }

      final unitData = newUnitSnapshot.data();
      if (unitData == null ||
          (unitData['propertyId'] as String?)?.trim() != newPropertyId) {
        throw StateError(
          'The selected unit does not belong to the selected property.',
        );
      }

      if (!isActive && newUnitId != oldUnitId) {
        final unitStatus = unitData['status'];
        final unitTenantUserId = unitData['tenantUserId'];
        final hasTenantUser =
            unitTenantUserId is String && unitTenantUserId.trim().isNotEmpty;

        if (unitStatus != UnitStatus.available.name || hasTenantUser) {
          throw StateError('The selected unit is not available.');
        }
      }

      final updatedTenant = currentTenant.copyWith(
        name: tenant.name.trim(),
        phone: normalizedPhone,
        email: tenant.email,
        nidNumber: tenant.nidNumber,
        propertyId: newPropertyId,
        unitId: newUnitId,
        updatedAt: DateTime.now(),
      );

      transaction.update(
        tenantDocument,
        TenantModel.fromEntity(updatedTenant).toFirestore(),
      );
    });

    final updatedSnapshot = await tenantDocument.get();
    if (!updatedSnapshot.exists) {
      throw StateError('Tenant was updated but could not be retrieved.');
    }

    return TenantModel.fromFirestore(updatedSnapshot);
  }

  // ==========================================================================
  // CLEANUP DUPLICATE ACTIVE TENANTS
  // ==========================================================================

  Future<void> cleanupDuplicateActiveTenants({
    required String unitId,
    required String ownerId,
    required String keepTenantId,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();
    final normalizedKeepTenantId = keepTenantId.trim();

    if (normalizedUnitId.isEmpty ||
        normalizedOwnerId.isEmpty ||
        normalizedKeepTenantId.isEmpty) {
      return;
    }

    final snapshot = await _tenants
        .where('unitId', isEqualTo: normalizedUnitId)
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('status', isEqualTo: TenantStatus.active.name)
        .get();

    final duplicateDocuments = snapshot.docs
        .where((document) => document.id != normalizedKeepTenantId)
        .toList();

    if (duplicateDocuments.isEmpty) return;

    final batch = _firestore.batch();
    for (final document in duplicateDocuments) {
      batch.update(document.reference, {
        'status': TenantStatus.inactive.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // ==========================================================================
  // END TENANCY (OWNER OR ACTIVE MANAGER)
  // ==========================================================================

  Future<TenantModel> endTenancy({
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

    final tenantDocument = _tenants.doc(normalizedTenantId);
    final tenantSnapshot = await tenantDocument.get();

    if (!tenantSnapshot.exists) {
      throw StateError('Tenant $normalizedTenantId does not exist.');
    }

    final tenant = TenantModel.fromFirestore(tenantSnapshot);
    final normalizedPropertyId = tenant.propertyId.trim();
    final normalizedUnitId = tenant.unitId.trim();

    if (tenant.ownerId != normalizedOwnerId) {
      throw StateError('This tenant does not belong to the property owner.');
    }

    final authorized = await _isOwnerOrActiveManager(
      ownerId: normalizedOwnerId,
      propertyId: normalizedPropertyId,
    );
    if (!authorized) {
      throw StateError(
        'Only the property owner or an active manager can end a tenancy.',
      );
    }

    if (tenant.status == TenantStatus.inactive) {
      throw StateError('This tenant is already inactive.');
    }

    final tenancyStartedAt = tenant.tenancyStartedAt;
    if (tenancyStartedAt == null) {
      throw StateError('Tenancy start date is missing.');
    }

    final endedAt = DateTime.now();
    if (endedAt.isBefore(tenancyStartedAt)) {
      throw StateError('Tenancy end date cannot be before tenancy start date.');
    }

    final rentRateSnapshot = await _rentRates
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('unitId', isEqualTo: normalizedUnitId)
        .where(
          'effectiveFrom',
          isLessThanOrEqualTo: Timestamp.fromDate(endedAt),
        )
        .orderBy('effectiveFrom', descending: true)
        .limit(1)
        .get();

    if (rentRateSnapshot.docs.isEmpty) {
      throw StateError('No current rent rate was found for this unit.');
    }

    final rentRateQueryDocument = rentRateSnapshot.docs.first;
    final queriedRentRate = RentRateModel.fromFirestore(rentRateQueryDocument);

    if (!queriedRentRate.isApplicableAt(endedAt)) {
      throw StateError('No rent rate is currently applicable to this unit.');
    }

    final rentRateDocument = rentRateQueryDocument.reference;
    final propertyDocument = _properties.doc(normalizedPropertyId);
    final unitDocument = _units.doc(normalizedUnitId);

    await _firestore.runTransaction((transaction) async {
      final currentTenantSnapshot = await transaction.get(tenantDocument);
      final propertySnapshot = await transaction.get(propertyDocument);
      final unitSnapshot = await transaction.get(unitDocument);
      final currentRentRateSnapshot = await transaction.get(rentRateDocument);

      if (!currentTenantSnapshot.exists) {
        throw StateError('Tenant $normalizedTenantId no longer exists.');
      }

      final currentTenant = TenantModel.fromFirestore(currentTenantSnapshot);
      if (currentTenant.status == TenantStatus.inactive) {
        throw StateError('This tenancy has already ended.');
      }

      if (!propertySnapshot.exists || propertySnapshot.data() == null) {
        throw StateError('Tenant property no longer exists.');
      }
      final propertyData = propertySnapshot.data()!;

      if (!unitSnapshot.exists || unitSnapshot.data() == null) {
        throw StateError('Tenant unit no longer exists.');
      }
      final unitData = unitSnapshot.data()!;

      if (!currentRentRateSnapshot.exists) {
        throw StateError('The current rent rate no longer exists.');
      }
      final currentRentRate = RentRateModel.fromFirestore(
        currentRentRateSnapshot,
      );

      final propertyName = (propertyData['name'] as String?)?.trim() ?? '';
      final propertyCode =
          (propertyData['propertyCode'] as String?)?.trim() ?? '';
      final propertyAddress = (propertyData['address'] as String?)?.trim();
      final unitNumber = (unitData['unitNumber'] as String?)?.trim() ?? '';
      final unitName = (unitData['name'] as String?)?.trim();
      final floorNumber = (unitData['floorNumber'] as num?)?.toInt() ?? 1;

      final historyDocument = _tenancyHistories.doc();

      transaction.set(historyDocument, {
        'tenantId': normalizedTenantId,
        'tenantUserId': currentTenant.userId?.trim(),
        'ownerId': normalizedOwnerId,
        'tenantName': currentTenant.name.trim(),
        'propertyId': normalizedPropertyId,
        'propertyName': propertyName,
        'propertyCode': propertyCode,
        'propertyAddress': propertyAddress != null && propertyAddress.isNotEmpty
            ? propertyAddress
            : null,
        'unitId': normalizedUnitId,
        'unitNumber': unitNumber,
        'unitName': unitName != null && unitName.isNotEmpty ? unitName : null,
        'floorNumber': floorNumber,
        'monthlyRent': currentRentRate.amount,
        'rentRateId': currentRentRate.id,
        'startedAt': Timestamp.fromDate(tenancyStartedAt),
        'endedAt': Timestamp.fromDate(endedAt),
        'status': 'ended',
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(rentRateDocument, {
        'effectiveTo': Timestamp.fromDate(endedAt),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final updatedTenant = currentTenant.copyWith(
        status: TenantStatus.inactive,
        updatedAt: endedAt,
      );

      transaction.update(
        tenantDocument,
        TenantModel.fromEntity(updatedTenant).toFirestore(),
      );

      transaction.update(unitDocument, {
        'status': UnitStatus.available.name,
        'tenantUserId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final tenantUserId = currentTenant.userId?.trim();
      if (tenantUserId != null && tenantUserId.isNotEmpty) {
        transaction.update(propertyDocument, {
          'tenantUserIds': FieldValue.arrayRemove([tenantUserId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.delete(_tenantAccess.doc(tenantUserId));
      }
    });

    final updatedSnapshot = await tenantDocument.get();
    if (!updatedSnapshot.exists) {
      throw StateError('Tenancy was ended but tenant could not be retrieved.');
    }

    return TenantModel.fromFirestore(updatedSnapshot);
  }

  // ==========================================================================
  // START NEW TENANCY (OWNER OR ACTIVE MANAGER)
  // ==========================================================================

  Future<TenantModel> startNewTenancy({
    required String tenantId,
    required String propertyId,
    required String unitId,
    required String ownerId,
    required double amount,
  }) async {
    final normalizedTenantId = tenantId.trim();
    final normalizedPropertyId = propertyId.trim();
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedTenantId.isEmpty ||
        normalizedPropertyId.isEmpty ||
        normalizedUnitId.isEmpty ||
        normalizedOwnerId.isEmpty) {
      throw ArgumentError(
        'Tenant, property, unit, and owner IDs are required.',
      );
    }

    if (amount <= 0) {
      throw ArgumentError('Rent amount must be greater than zero.');
    }

    final authorized = await _isOwnerOrActiveManager(
      ownerId: normalizedOwnerId,
      propertyId: normalizedPropertyId,
    );
    if (!authorized) {
      throw StateError(
        'Only the property owner or an active manager can start a tenancy.',
      );
    }

    final tenantDocument = _tenants.doc(normalizedTenantId);
    final propertyDocument = _properties.doc(normalizedPropertyId);
    final unitDocument = _units.doc(normalizedUnitId);
    final now = DateTime.now();

    final currentRentSnapshot = await _rentRates
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('unitId', isEqualTo: normalizedUnitId)
        .where('effectiveFrom', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('effectiveFrom', descending: true)
        .limit(1)
        .get();

    DocumentReference<JsonMap>? currentRentRateDocument;
    if (currentRentSnapshot.docs.isNotEmpty) {
      final document = currentRentSnapshot.docs.first;
      final rate = RentRateModel.fromFirestore(document);
      if (rate.isApplicableAt(now)) {
        currentRentRateDocument = document.reference;
      }
    }

    final futureRentSnapshot = await _rentRates
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('unitId', isEqualTo: normalizedUnitId)
        .where('effectiveFrom', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('effectiveFrom', descending: false)
        .limit(1)
        .get();

    await _firestore.runTransaction((transaction) async {
      final tenantSnapshot = await transaction.get(tenantDocument);
      final propertySnapshot = await transaction.get(propertyDocument);
      final unitSnapshot = await transaction.get(unitDocument);

      DocumentSnapshot<JsonMap>? transactionCurrentRentSnapshot;
      if (currentRentRateDocument != null) {
        transactionCurrentRentSnapshot = await transaction.get(
          currentRentRateDocument,
        );
      }

      if (!tenantSnapshot.exists) {
        throw StateError('Tenant $normalizedTenantId does not exist.');
      }

      final tenant = TenantModel.fromFirestore(tenantSnapshot);
      if (tenant.ownerId != normalizedOwnerId) {
        throw StateError('This tenant does not belong to the property owner.');
      }
      if (tenant.status != TenantStatus.inactive) {
        throw StateError('Only an inactive tenant can start a new tenancy.');
      }
      if (tenant.accountStatus != TenantAccountStatus.registered) {
        throw StateError(
          'Tenant account must be registered before starting a new tenancy.',
        );
      }

      final tenantUserId = tenant.userId?.trim();
      if (tenantUserId == null || tenantUserId.isEmpty) {
        throw StateError('Tenant account is not linked.');
      }

      if (!propertySnapshot.exists || propertySnapshot.data() == null) {
        throw StateError('Property $normalizedPropertyId does not exist.');
      }
      if ((propertySnapshot.data()!['ownerId'] as String?)?.trim() !=
          normalizedOwnerId) {
        throw StateError(
          'The selected property does not belong to the property owner.',
        );
      }

      if (!unitSnapshot.exists || unitSnapshot.data() == null) {
        throw StateError('Unit $normalizedUnitId does not exist.');
      }
      final unitData = unitSnapshot.data()!;
      if ((unitData['propertyId'] as String?)?.trim() != normalizedPropertyId) {
        throw StateError(
          'The selected unit does not belong to the selected property.',
        );
      }
      if (unitData['status'] != UnitStatus.available.name) {
        throw StateError('The selected unit is not available.');
      }

      final existingTenantUserId = unitData['tenantUserId'];
      if (existingTenantUserId is String &&
          existingTenantUserId.trim().isNotEmpty) {
        throw StateError('The selected unit already has a tenant.');
      }

      RentRateModel? transactionCurrentRentRate;
      if (transactionCurrentRentSnapshot != null) {
        if (!transactionCurrentRentSnapshot.exists) {
          throw StateError('The current rent rate no longer exists.');
        }
        final rate = RentRateModel.fromFirestore(
          transactionCurrentRentSnapshot,
        );
        if (rate.isApplicableAt(now)) {
          transactionCurrentRentRate = rate;
        }
      }

      final shouldCreateNewRate =
          transactionCurrentRentRate == null ||
          transactionCurrentRentRate.amount != amount;

      if (shouldCreateNewRate && futureRentSnapshot.docs.isNotEmpty) {
        throw StateError(
          'A future rent rate is already scheduled for this unit. '
          'Please review or cancel the scheduled rent change first.',
        );
      }

      DocumentReference<JsonMap>? newRentRateDocument;
      RentRateModel? newRentRate;

      if (shouldCreateNewRate) {
        newRentRateDocument = _rentRates.doc();
        final source = transactionCurrentRentRate == null
            ? RentRateSource.initial
            : RentRateSource.unit;

        newRentRate = RentRateModel(
          id: newRentRateDocument.id,
          ownerId: normalizedOwnerId,
          propertyId: normalizedPropertyId,
          unitId: normalizedUnitId,
          amount: amount,
          effectiveFrom: now,
          effectiveTo: null,
          source: source,
          previousRentRateId: transactionCurrentRentRate?.id,
          nextRentRateId: null,
          createdAt: now,
          updatedAt: now,
        );
      }

      final updatedTenant = tenant.copyWith(
        propertyId: normalizedPropertyId,
        unitId: normalizedUnitId,
        status: TenantStatus.active,
        tenancyStartedAt: now,
        updatedAt: now,
      );

      transaction.update(
        tenantDocument,
        TenantModel.fromEntity(updatedTenant).toFirestore(),
      );

      transaction.update(unitDocument, {
        'status': UnitStatus.occupied.name,
        'tenantUserId': tenantUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(propertyDocument, {
        'tenantUserIds': FieldValue.arrayUnion([tenantUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final tenantAccessDocument = _tenantAccess.doc(tenantUserId);
      transaction.set(tenantAccessDocument, {
        'userId': tenantUserId,
        'tenantId': normalizedTenantId,
        'ownerId': normalizedOwnerId,
        'propertyId': normalizedPropertyId,
        'unitId': normalizedUnitId,
        'invitationId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (shouldCreateNewRate) {
        if (transactionCurrentRentRate != null &&
            currentRentRateDocument != null) {
          transaction.update(currentRentRateDocument, {
            'effectiveTo': Timestamp.fromDate(now),
            'nextRentRateId': newRentRateDocument!.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        transaction.set(newRentRateDocument!, newRentRate!.toFirestore());
      }
    });

    final updatedSnapshot = await tenantDocument.get();
    if (!updatedSnapshot.exists) {
      throw StateError(
        'New tenancy was started but tenant could not be retrieved.',
      );
    }

    return TenantModel.fromFirestore(updatedSnapshot);
  }

  // ==========================================================================
  // DELETE INACTIVE TENANT
  // ==========================================================================

  Future<void> deleteTenant(String tenantId) async {
    final normalizedTenantId = tenantId.trim();
    if (normalizedTenantId.isEmpty) return;

    final tenantDocument = _tenants.doc(normalizedTenantId);

    await _firestore.runTransaction((transaction) async {
      final tenantSnapshot = await transaction.get(tenantDocument);
      if (!tenantSnapshot.exists) return;

      final tenant = TenantModel.fromFirestore(tenantSnapshot);

      if (tenant.status == TenantStatus.active) {
        throw StateError(
          'Active tenant cannot be deleted directly. End the tenancy first.',
        );
      }

      final propertyId = tenant.propertyId.trim();
      final unitId = tenant.unitId.trim();
      final tenantUserId = tenant.userId?.trim();

      final propertyDocument = propertyId.isEmpty
          ? null
          : _properties.doc(propertyId);
      final unitDocument = unitId.isEmpty ? null : _units.doc(unitId);
      final tenantAccessDocument =
          tenantUserId != null && tenantUserId.isNotEmpty
          ? _tenantAccess.doc(tenantUserId)
          : null;

      DocumentSnapshot<JsonMap>? propertySnapshot;
      if (propertyDocument != null) {
        propertySnapshot = await transaction.get(propertyDocument);
      }

      DocumentSnapshot<JsonMap>? unitSnapshot;
      if (unitDocument != null) {
        unitSnapshot = await transaction.get(unitDocument);
      }

      DocumentSnapshot<JsonMap>? tenantAccessSnapshot;
      if (tenantAccessDocument != null) {
        tenantAccessSnapshot = await transaction.get(tenantAccessDocument);
      }

      transaction.delete(tenantDocument);

      if (unitDocument != null && unitSnapshot != null && unitSnapshot.exists) {
        final unitData = unitSnapshot.data();
        if (unitData != null) {
          final currentTenantUserId = unitData['tenantUserId'];
          final isLinkedToThisTenant =
              tenantUserId != null &&
              tenantUserId.isNotEmpty &&
              currentTenantUserId is String &&
              currentTenantUserId.trim() == tenantUserId;

          if (isLinkedToThisTenant) {
            transaction.update(unitDocument, {
              'status': UnitStatus.available.name,
              'tenantUserId': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      if (propertyDocument != null &&
          propertySnapshot != null &&
          propertySnapshot.exists &&
          tenantUserId != null &&
          tenantUserId.isNotEmpty) {
        transaction.update(propertyDocument, {
          'tenantUserIds': FieldValue.arrayRemove([tenantUserId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (tenantAccessDocument != null &&
          tenantAccessSnapshot != null &&
          tenantAccessSnapshot.exists) {
        transaction.delete(tenantAccessDocument);
      }
    });
  }

  // ==========================================================================
  // SEARCH REGISTERED TENANT BY GRIHO ID / PHONE
  // ==========================================================================

  Future<TenantSearchResult?> searchRegisteredTenantByPublicId({
    required String publicId,
    required String ownerId,
  }) async {
    final normalizedPublicId = publicId.trim().toUpperCase();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedPublicId.isEmpty || normalizedOwnerId.isEmpty) {
      return null;
    }

    final publicIdSnapshot = await _publicIds.doc(normalizedPublicId).get();
    if (!publicIdSnapshot.exists) return null;

    return _buildTenantSearchResult(
      userData: publicIdSnapshot.data(),
      ownerId: normalizedOwnerId,
    );
  }

  Future<TenantSearchResult?> searchRegisteredTenantByPhone({
    required String phone,
    required String ownerId,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    if (normalizedOwnerId.isEmpty) return null;

    final normalizedPhone = PhoneNumberUtils.normalizeAndValidate(phone);
    final phoneLookupSnapshot = await _phoneLookups.doc(normalizedPhone).get();
    if (!phoneLookupSnapshot.exists) return null;

    return _buildTenantSearchResult(
      userData: phoneLookupSnapshot.data(),
      ownerId: normalizedOwnerId,
    );
  }

  Future<TenantSearchResult?> _buildTenantSearchResult({
    required JsonMap? userData,
    required String ownerId,
  }) async {
    if (userData == null) return null;

    final userId = userData['uid'];
    final publicId = userData['publicId'];
    final name = userData['name'];
    final phoneNumber = userData['phoneNumber'];
    final email = userData['email'];

    if (userId is! String || userId.trim().isEmpty) return null;
    if (publicId is! String || publicId.trim().isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;

    final normalizedUserId = userId.trim();
    final normalizedPublicId = publicId.trim();
    final normalizedName = name.trim();
    final normalizedPhone = phoneNumber is String ? phoneNumber.trim() : '';
    final normalizedEmail = email is String && email.trim().isNotEmpty
        ? email.trim()
        : null;

    final existingTenantSnapshot = await _tenants
        .where('ownerId', isEqualTo: ownerId)
        .where('userId', isEqualTo: normalizedUserId)
        .where('status', isEqualTo: TenantStatus.active.name)
        .limit(1)
        .get();

    TenantModel? existingTenant;
    if (existingTenantSnapshot.docs.isNotEmpty) {
      existingTenant = TenantModel.fromFirestore(
        existingTenantSnapshot.docs.first,
      );
    }

    return TenantSearchResult(
      userId: normalizedUserId,
      publicId: normalizedPublicId,
      name: normalizedName,
      phone: normalizedPhone,
      email: normalizedEmail,
      tenantId: existingTenant?.id,
      isExistingTenant: existingTenant != null,
    );
  }

  // ==========================================================================
  // FIND ACTIVE TENANT BY PHONE
  // ==========================================================================

  Future<TenantModel?> findTenantByPhone({
    required String phone,
    required String ownerId,
  }) async {
    final normalizedPhone = phone.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedPhone.isEmpty || normalizedOwnerId.isEmpty) {
      return null;
    }

    final snapshot = await _tenants
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('phone', isEqualTo: normalizedPhone)
        .where('status', isEqualTo: TenantStatus.active.name)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return TenantModel.fromFirestore(snapshot.docs.first);
  }
}
