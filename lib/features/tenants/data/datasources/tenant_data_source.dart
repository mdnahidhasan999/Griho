import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/phone_number_utils.dart';
import '../../../rents/data/models/rent_rate_model.dart';
import '../../../rents/domain/entities/rent_rate.dart';
import '../../../units/domain/entities/unit.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/tenant_search_result.dart';
import '../models/tenant_model.dart';

class TenantDataSource {
  final FirebaseFirestore _firestore;

  TenantDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

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

  CollectionReference<Map<String, dynamic>> get _tenants {
    return _firestore.collection(_tenantCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _units {
    return _firestore.collection(_unitCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _properties {
    return _firestore.collection(_propertyCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _publicIds {
    return _firestore.collection(_publicIdCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _phoneLookups {
    return _firestore.collection(_phoneLookupCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _tenantAccess {
    return _firestore.collection(_tenantAccessCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _tenancyHistories {
    return _firestore.collection(_tenancyHistoryCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _rentRates {
    return _firestore.collection(_rentRateCollectionName);
  }

  // ==========================================================================
  // GET TENANT BY ID
  // ==========================================================================

  Future<TenantModel?> getTenantById(String tenantId) async {
    final normalizedId = tenantId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    final snapshot = await _tenants.doc(normalizedId).get();

    if (!snapshot.exists) {
      return null;
    }

    return TenantModel.fromFirestore(snapshot);
  }

  // ==========================================================================
  // GET TENANT BY USER ID
  // ==========================================================================

  Future<TenantModel?> getTenantByUserId(String userId) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return null;
    }

    final snapshot = await _tenants
        .where('userId', isEqualTo: normalizedUserId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return TenantModel.fromFirestore(snapshot.docs.first);
  }

  // ==========================================================================
  // GET TENANTS BY PROPERTY
  // CURRENT OWNER ONLY
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
  // CURRENT OWNER ONLY
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

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return TenantModel.fromFirestore(snapshot.docs.first);
  }

  // ==========================================================================
  // GET ALL ACTIVE TENANTS BY UNIT
  // CURRENT OWNER ONLY
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

    final phoneSnapshot = await _tenants
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('phone', isEqualTo: normalizedPhone)
        .limit(1)
        .get();

    if (phoneSnapshot.docs.isNotEmpty) {
      final existingTenant = TenantModel.fromFirestore(
        phoneSnapshot.docs.first,
      );

      throw StateError(
        'A tenant with this phone number already exists: '
        '${existingTenant.name} (${existingTenant.phone}).',
      );
    }

    if (tenant.status == TenantStatus.active) {
      final activeSnapshot = await _tenants
          .where('unitId', isEqualTo: normalizedUnitId)
          .where('ownerId', isEqualTo: normalizedOwnerId)
          .where('status', isEqualTo: TenantStatus.active.name)
          .limit(1)
          .get();

      if (activeSnapshot.docs.isNotEmpty) {
        final existingTenant = TenantModel.fromFirestore(
          activeSnapshot.docs.first,
        );

        throw StateError(
          'This unit already has an active tenant: '
          '${existingTenant.name} (${existingTenant.phone}).',
        );
      }
    }

    final tenantDocument = _tenants.doc(tenant.id);
    final propertyDocument = _properties.doc(normalizedPropertyId);
    final unitDocument = _units.doc(normalizedUnitId);

    await _firestore.runTransaction((transaction) async {
      final propertySnapshot = await transaction.get(propertyDocument);
      final unitSnapshot = await transaction.get(unitDocument);

      if (!propertySnapshot.exists) {
        throw StateError('Property $normalizedPropertyId does not exist.');
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

      transaction.set(tenantDocument, tenant.toFirestore());

      if (tenant.status == TenantStatus.active) {
        transaction.update(unitDocument, {
          'status': 'occupied',
          'tenantUserId': tenant.userId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final tenantUserId = tenant.userId?.trim();

        if (tenantUserId != null && tenantUserId.isNotEmpty) {
          transaction.update(propertyDocument, {
            'tenantUserIds': FieldValue.arrayUnion([tenantUserId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        transaction.update(unitDocument, {
          'status': 'available',
          'tenantUserId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    return tenant;
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

    final existingUserSnapshot = await _tenants
        .where('userId', isEqualTo: normalizedUserId)
        .limit(1)
        .get();

    if (existingUserSnapshot.docs.isNotEmpty) {
      final existingTenant = TenantModel.fromFirestore(
        existingUserSnapshot.docs.first,
      );

      if (existingTenant.id != normalizedTenantId) {
        throw StateError('This account is already linked to another tenant.');
      }

      return existingTenant;
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

      final updatedModel = TenantModel.fromEntity(updatedTenant);

      transaction.update(tenantDocument, updatedModel.toFirestore());

      if (currentTenant.status == TenantStatus.active) {
        transaction.update(tenantUnitDocument, {
          'tenantUserId': normalizedUserId,
          'status': 'occupied',
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

    final oldPropertyId = existingTenant.propertyId.trim();
    final newPropertyId = tenant.propertyId.trim();
    final oldUnitId = existingTenant.unitId.trim();
    final newUnitId = tenant.unitId.trim();

    if (newPropertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    if (newUnitId.isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }

    final normalizedPhone = tenant.phone.trim();

    if (normalizedPhone.isEmpty) {
      throw ArgumentError('Tenant phone number cannot be empty.');
    }

    final phoneSnapshot = await _tenants
        .where('ownerId', isEqualTo: tenant.ownerId)
        .where('phone', isEqualTo: normalizedPhone)
        .limit(2)
        .get();

    for (final document in phoneSnapshot.docs) {
      if (document.id == tenantId) {
        continue;
      }

      final duplicate = TenantModel.fromFirestore(document);

      throw StateError(
        'A tenant with this phone number already exists: '
        '${duplicate.name} (${duplicate.phone}).',
      );
    }

    if (tenant.status == TenantStatus.active) {
      final activeSnapshot = await _tenants
          .where('unitId', isEqualTo: newUnitId)
          .where('ownerId', isEqualTo: tenant.ownerId)
          .where('status', isEqualTo: TenantStatus.active.name)
          .limit(2)
          .get();

      for (final document in activeSnapshot.docs) {
        if (document.id == tenantId) {
          continue;
        }

        final duplicate = TenantModel.fromFirestore(document);

        throw StateError(
          'This unit already has an active tenant: '
          '${duplicate.name} (${duplicate.phone}).',
        );
      }
    }

    final oldPropertyDocument = _properties.doc(oldPropertyId);
    final newPropertyDocument = _properties.doc(newPropertyId);
    final oldUnitDocument = _units.doc(oldUnitId);
    final newUnitDocument = _units.doc(newUnitId);

    await _firestore.runTransaction((transaction) async {
      final currentTenantSnapshot = await transaction.get(tenantDocument);

      final oldPropertySnapshot = await transaction.get(oldPropertyDocument);

      final newPropertySnapshot = oldPropertyId == newPropertyId
          ? oldPropertySnapshot
          : await transaction.get(newPropertyDocument);

      final oldUnitSnapshot = await transaction.get(oldUnitDocument);

      final newUnitSnapshot = oldUnitId == newUnitId
          ? oldUnitSnapshot
          : await transaction.get(newUnitDocument);

      if (!currentTenantSnapshot.exists) {
        throw StateError('Tenant $tenantId no longer exists.');
      }

      if (!oldPropertySnapshot.exists) {
        throw StateError('Previous property $oldPropertyId does not exist.');
      }

      if (!newPropertySnapshot.exists) {
        throw StateError('New property $newPropertyId does not exist.');
      }

      if (!oldUnitSnapshot.exists) {
        throw StateError('Previous unit $oldUnitId does not exist.');
      }

      if (!newUnitSnapshot.exists) {
        throw StateError('New unit $newUnitId does not exist.');
      }

      final newUnitData = newUnitSnapshot.data();

      if (newUnitData == null) {
        throw StateError('New unit $newUnitId contains no data.');
      }

      final newUnitPropertyId = (newUnitData['propertyId'] as String?)?.trim();

      if (newUnitPropertyId != newPropertyId) {
        throw StateError(
          'The new unit does not belong to the selected property.',
        );
      }

      final currentTenant = TenantModel.fromFirestore(currentTenantSnapshot);

      transaction.update(tenantDocument, tenant.toFirestore());

      final oldUserId = currentTenant.userId?.trim();

      if (oldUserId != null && oldUserId.isNotEmpty) {
        if (currentTenant.status == TenantStatus.active) {
          transaction.update(oldUnitDocument, {
            'tenantUserId': null,
            'status': 'available',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          transaction.update(oldPropertyDocument, {
            'tenantUserIds': FieldValue.arrayRemove([oldUserId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else if (oldUnitId != newUnitId) {
        transaction.update(oldUnitDocument, {
          'status': 'available',
          'tenantUserId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final newUserId = tenant.userId?.trim();

      if (tenant.status == TenantStatus.active) {
        transaction.update(newUnitDocument, {
          'status': 'occupied',
          'tenantUserId': newUserId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (newUserId != null && newUserId.isNotEmpty) {
          transaction.update(newPropertyDocument, {
            'tenantUserIds': FieldValue.arrayUnion([newUserId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        transaction.update(newUnitDocument, {
          'status': 'available',
          'tenantUserId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (newUserId != null && newUserId.isNotEmpty) {
          transaction.update(newPropertyDocument, {
            'tenantUserIds': FieldValue.arrayRemove([newUserId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
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
    final snapshot = await _tenants
        .where('unitId', isEqualTo: unitId)
        .where('ownerId', isEqualTo: ownerId)
        .where('status', isEqualTo: TenantStatus.active.name)
        .get();

    final duplicateDocuments = snapshot.docs
        .where((document) => document.id != keepTenantId)
        .toList();

    if (duplicateDocuments.isEmpty) {
      return;
    }

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
  // END TENANCY
  // ==========================================================================
  //
  // Atomically:
  //
  // 1. Validates active tenant.
  // 2. Validates property and unit.
  // 3. Finds the current RentRate before the transaction.
  // 4. Re-reads that RentRate inside the transaction.
  // 5. Snapshots RentRate.amount into tenancy history.
  // 6. Closes the current RentRate.
  // 7. Makes tenant inactive.
  // 8. Makes unit available.
  // 9. Removes tenant user from property.
  // 10. Deletes tenantAccess.
  //
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

    // ------------------------------------------------------------------------
    // FIND CURRENT RENT RATE BEFORE TRANSACTION
    // ------------------------------------------------------------------------
    //
    // Firestore Transaction.get() does not accept a Query.
    // Therefore we first discover the current rate, then re-read its
    // specific document inside the transaction.
    //
    // ------------------------------------------------------------------------

    await _firestore.runTransaction((transaction) async {
      // ----------------------------------------------------------------------
      // READ TENANT FIRST
      // ----------------------------------------------------------------------

      final tenantSnapshot = await transaction.get(tenantDocument);

      if (!tenantSnapshot.exists) {
        throw StateError('Tenant $normalizedTenantId does not exist.');
      }

      final tenant = TenantModel.fromFirestore(tenantSnapshot);

      // ----------------------------------------------------------------------
      // OWNER VALIDATION
      // ----------------------------------------------------------------------

      if (tenant.ownerId != normalizedOwnerId) {
        throw StateError('This tenant does not belong to the current owner.');
      }

      // ----------------------------------------------------------------------
      // ALREADY INACTIVE
      // ----------------------------------------------------------------------

      if (tenant.status == TenantStatus.inactive) {
        return;
      }

      // ----------------------------------------------------------------------
      // TENANCY START DATE
      // ----------------------------------------------------------------------

      final tenancyStartedAt = tenant.tenancyStartedAt;

      if (tenancyStartedAt == null) {
        throw StateError(
          'Tenancy start date is missing. '
          'This tenancy cannot be ended until its start date is available.',
        );
      }

      // ----------------------------------------------------------------------
      // END DATE
      // ----------------------------------------------------------------------

      final endedAt = DateTime.now();

      if (endedAt.isBefore(tenancyStartedAt)) {
        throw StateError('Tenancy end date cannot be before its start date.');
      }

      // ----------------------------------------------------------------------
      // DOCUMENT REFERENCES
      // ----------------------------------------------------------------------

      final propertyDocument = _properties.doc(tenant.propertyId.trim());

      final unitDocument = _units.doc(tenant.unitId.trim());

      // ----------------------------------------------------------------------
      // READ PROPERTY + UNIT
      // ----------------------------------------------------------------------

      final propertySnapshot = await transaction.get(propertyDocument);

      final unitSnapshot = await transaction.get(unitDocument);

      // ----------------------------------------------------------------------
      // FIND CURRENT RENT RATE FOR THIS TENANT
      // ----------------------------------------------------------------------
      //
      // The query above must be based on the actual tenant's unit.
      // Since the query cannot be changed after transaction.get() starts,
      // the current rate is discovered using a normal Firestore query
      // before this transaction.
      //
      // ----------------------------------------------------------------------

      final rentRateSnapshot = await _rentRates
          .where('ownerId', isEqualTo: normalizedOwnerId)
          .where('unitId', isEqualTo: tenant.unitId.trim())
          .where('effectiveTo', isNull: true)
          .limit(2)
          .get();

      // ----------------------------------------------------------------------
      // PROPERTY VALIDATION
      // ----------------------------------------------------------------------

      if (!propertySnapshot.exists) {
        throw StateError('Tenant property no longer exists.');
      }

      // ----------------------------------------------------------------------
      // UNIT VALIDATION
      // ----------------------------------------------------------------------

      if (!unitSnapshot.exists) {
        throw StateError('Tenant unit no longer exists.');
      }

      final propertyData = propertySnapshot.data();

      if (propertyData == null) {
        throw StateError('Tenant property contains no data.');
      }

      final unitData = unitSnapshot.data();

      if (unitData == null) {
        throw StateError('Tenant unit contains no data.');
      }

      // ----------------------------------------------------------------------
      // PROPERTY OWNER VALIDATION
      // ----------------------------------------------------------------------

      final propertyOwnerId = (propertyData['ownerId'] as String?)?.trim();

      if (propertyOwnerId != normalizedOwnerId) {
        throw StateError(
          'Tenant property does not belong to the current owner.',
        );
      }

      // ----------------------------------------------------------------------
      // UNIT PROPERTY VALIDATION
      // ----------------------------------------------------------------------

      final unitPropertyId = (unitData['propertyId'] as String?)?.trim();

      if (unitPropertyId != tenant.propertyId.trim()) {
        throw StateError('Tenant unit does not belong to the tenant property.');
      }

      // ----------------------------------------------------------------------
      // PROPERTY SNAPSHOT FIELDS
      // ----------------------------------------------------------------------

      final propertyName = propertyData['name'];

      if (propertyName is! String || propertyName.trim().isEmpty) {
        throw StateError('Tenant property name is missing or invalid.');
      }

      final propertyCode = propertyData['propertyCode'];

      if (propertyCode is! String || propertyCode.trim().isEmpty) {
        throw StateError('Tenant property code is missing or invalid.');
      }

      final propertyAddressValue = propertyData['address'];

      String? propertyAddress;

      if (propertyAddressValue != null) {
        if (propertyAddressValue is! String) {
          throw StateError('Tenant property address is invalid.');
        }

        final trimmedAddress = propertyAddressValue.trim();

        if (trimmedAddress.isNotEmpty) {
          propertyAddress = trimmedAddress;
        }
      }

      // ----------------------------------------------------------------------
      // UNIT SNAPSHOT FIELDS
      // ----------------------------------------------------------------------

      final unitNumber = unitData['unitNumber'];

      if (unitNumber is! String || unitNumber.trim().isEmpty) {
        throw StateError('Tenant unit number is missing or invalid.');
      }

      final unitNameValue = unitData['name'];

      String? unitName;

      if (unitNameValue != null) {
        if (unitNameValue is! String) {
          throw StateError('Tenant unit name is invalid.');
        }

        final trimmedUnitName = unitNameValue.trim();

        if (trimmedUnitName.isNotEmpty) {
          unitName = trimmedUnitName;
        }
      }

      final floorNumberValue = unitData['floorNumber'];

      if (floorNumberValue is! num) {
        throw StateError('Tenant unit floor number is missing or invalid.');
      }

      final floorNumber = floorNumberValue.toInt();

      if (floorNumber < 1) {
        throw StateError('Tenant unit floor number is invalid.');
      }

      // ----------------------------------------------------------------------
      // CURRENT RENT RATE DISCOVERY
      // ----------------------------------------------------------------------

      if (rentRateSnapshot.docs.isEmpty) {
        throw StateError('No current rent rate was found for this tenancy.');
      }

      if (rentRateSnapshot.docs.length > 1) {
        throw StateError(
          'Multiple current rent rates were found for this tenancy.',
        );
      }

      final rentRateQueryDocument = rentRateSnapshot.docs.first;

      final rentRateDocument = rentRateQueryDocument.reference;

      // ----------------------------------------------------------------------
      // RE-READ CURRENT RENT RATE INSIDE TRANSACTION
      // ----------------------------------------------------------------------

      final currentRentRateSnapshot = await transaction.get(rentRateDocument);

      if (!currentRentRateSnapshot.exists) {
        throw StateError('The current rent rate no longer exists.');
      }

      final currentRentRate = RentRateModel.fromFirestore(
        currentRentRateSnapshot,
      );

      // ----------------------------------------------------------------------
      // CURRENT RENT RATE VALIDATION
      // ----------------------------------------------------------------------

      if (currentRentRate.ownerId != normalizedOwnerId) {
        throw StateError(
          'Current rent rate does not belong to the current owner.',
        );
      }

      if (currentRentRate.propertyId != tenant.propertyId.trim()) {
        throw StateError(
          'Current rent rate does not belong to the tenant property.',
        );
      }

      if (currentRentRate.unitId != tenant.unitId.trim()) {
        throw StateError(
          'Current rent rate does not belong to the tenant unit.',
        );
      }

      if (currentRentRate.tenantId != normalizedTenantId) {
        throw StateError('Current rent rate does not belong to this tenant.');
      }

      if (currentRentRate.effectiveTo != null) {
        throw StateError('The selected rent rate is no longer current.');
      }

      if (currentRentRate.amount <= 0) {
        throw StateError('Current rent rate amount is invalid.');
      }

      // ----------------------------------------------------------------------
      // CREATE TENANCY HISTORY SNAPSHOT
      // ----------------------------------------------------------------------

      final historyDocument = _tenancyHistories.doc();

      transaction.set(historyDocument, {
        'tenantId': normalizedTenantId,
        'tenantUserId': tenant.userId?.trim(),
        'ownerId': normalizedOwnerId,
        'tenantName': tenant.name.trim(),
        'propertyId': tenant.propertyId.trim(),
        'propertyName': propertyName.trim(),
        'propertyCode': propertyCode.trim(),
        'propertyAddress': propertyAddress,
        'unitId': tenant.unitId.trim(),
        'unitNumber': unitNumber.trim(),
        'unitName': unitName,
        'floorNumber': floorNumber,
        'monthlyRent': currentRentRate.amount,
        'startedAt': Timestamp.fromDate(tenancyStartedAt),
        'endedAt': Timestamp.fromDate(endedAt),
        'status': 'ended',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ----------------------------------------------------------------------
      // CLOSE CURRENT RENT RATE
      // ----------------------------------------------------------------------

      transaction.update(rentRateDocument, {
        'effectiveTo': Timestamp.fromDate(endedAt),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ----------------------------------------------------------------------
      // UPDATE TENANT
      // ----------------------------------------------------------------------

      final updatedTenant = tenant.copyWith(
        status: TenantStatus.inactive,
        updatedAt: endedAt,
      );

      transaction.update(
        tenantDocument,
        TenantModel.fromEntity(updatedTenant).toFirestore(),
      );

      // ----------------------------------------------------------------------
      // MAKE UNIT AVAILABLE
      // ----------------------------------------------------------------------

      transaction.update(unitDocument, {
        'status': UnitStatus.available.name,
        'tenantUserId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ----------------------------------------------------------------------
      // REMOVE TENANT FROM PROPERTY
      // ----------------------------------------------------------------------

      final tenantUserId = tenant.userId?.trim();

      if (tenantUserId != null && tenantUserId.isNotEmpty) {
        transaction.update(propertyDocument, {
          'tenantUserIds': FieldValue.arrayRemove([tenantUserId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // --------------------------------------------------------------------
        // DELETE TENANT ACCESS
        // --------------------------------------------------------------------

        transaction.delete(_tenantAccess.doc(tenantUserId));
      }
    });

    // ------------------------------------------------------------------------
    // RETURN UPDATED TENANT
    // ------------------------------------------------------------------------

    final updatedSnapshot = await tenantDocument.get();

    if (!updatedSnapshot.exists) {
      throw StateError('Tenancy was ended but tenant could not be retrieved.');
    }

    return TenantModel.fromFirestore(updatedSnapshot);
  }

  // ==========================================================================
  // START NEW TENANCY
  // ==========================================================================
  //
  // Atomically:
  //
  // 1. Validates inactive tenant.
  // 2. Validates property.
  // 3. Validates available unit.
  // 4. Activates tenant.
  // 5. Occupies unit.
  // 6. Adds tenant to property.
  // 7. Creates tenantAccess.
  // 8. Creates INITIAL rent rate.
  //
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

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError('Tenant ID cannot be empty.');
    }

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }

    if (amount <= 0) {
      throw ArgumentError('Rent amount must be greater than zero.');
    }

    final tenantDocument = _tenants.doc(normalizedTenantId);
    final propertyDocument = _properties.doc(normalizedPropertyId);
    final unitDocument = _units.doc(normalizedUnitId);

    await _firestore.runTransaction((transaction) async {
      // --------------------------------------------------------------------
      // READ TENANT
      // --------------------------------------------------------------------

      final tenantSnapshot = await transaction.get(tenantDocument);

      if (!tenantSnapshot.exists) {
        throw StateError('Tenant $normalizedTenantId does not exist.');
      }

      final tenant = TenantModel.fromFirestore(tenantSnapshot);

      // --------------------------------------------------------------------
      // OWNER VALIDATION
      // --------------------------------------------------------------------

      if (tenant.ownerId != normalizedOwnerId) {
        throw StateError('This tenant does not belong to the current owner.');
      }

      // --------------------------------------------------------------------
      // TENANT MUST BE INACTIVE
      // --------------------------------------------------------------------

      if (tenant.status != TenantStatus.inactive) {
        throw StateError('Only an inactive tenant can start a new tenancy.');
      }

      // --------------------------------------------------------------------
      // TENANT ACCOUNT MUST BE REGISTERED
      // --------------------------------------------------------------------

      if (tenant.accountStatus != TenantAccountStatus.registered) {
        throw StateError(
          'Tenant account must be registered before starting a new tenancy.',
        );
      }

      // --------------------------------------------------------------------
      // TENANT USER ID REQUIRED
      // --------------------------------------------------------------------

      final tenantUserId = tenant.userId?.trim();

      if (tenantUserId == null || tenantUserId.isEmpty) {
        throw StateError('Tenant account is not linked.');
      }

      // --------------------------------------------------------------------
      // READ PROPERTY + UNIT
      // --------------------------------------------------------------------

      final propertySnapshot = await transaction.get(propertyDocument);
      final unitSnapshot = await transaction.get(unitDocument);

      if (!propertySnapshot.exists) {
        throw StateError('Property $normalizedPropertyId does not exist.');
      }

      if (!unitSnapshot.exists) {
        throw StateError('Unit $normalizedUnitId does not exist.');
      }

      // --------------------------------------------------------------------
      // PROPERTY VALIDATION
      // --------------------------------------------------------------------

      final propertyData = propertySnapshot.data();

      if (propertyData == null) {
        throw StateError('Property $normalizedPropertyId contains no data.');
      }

      final propertyOwnerId = (propertyData['ownerId'] as String?)?.trim();

      if (propertyOwnerId != normalizedOwnerId) {
        throw StateError(
          'The selected property does not belong to the current owner.',
        );
      }

      // --------------------------------------------------------------------
      // UNIT VALIDATION
      // --------------------------------------------------------------------

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

      // --------------------------------------------------------------------
      // UNIT MUST BE AVAILABLE
      // --------------------------------------------------------------------

      final unitStatus = unitData['status'];

      if (unitStatus != UnitStatus.available.name) {
        throw StateError('The selected unit is not available.');
      }

      // --------------------------------------------------------------------
      // UNIT MUST NOT ALREADY HAVE TENANT
      // --------------------------------------------------------------------

      final existingTenantUserId = unitData['tenantUserId'];

      if (existingTenantUserId != null) {
        if (existingTenantUserId is! String ||
            existingTenantUserId.trim().isNotEmpty) {
          throw StateError('The selected unit already has a tenant.');
        }
      }

      // --------------------------------------------------------------------
      // ONE TIMESTAMP FOR TENANCY + RENT RATE
      // --------------------------------------------------------------------

      final now = DateTime.now();

      // --------------------------------------------------------------------
      // BUILD UPDATED TENANT
      // --------------------------------------------------------------------

      final updatedTenant = tenant.copyWith(
        propertyId: normalizedPropertyId,
        unitId: normalizedUnitId,
        status: TenantStatus.active,
        tenancyStartedAt: now,
        updatedAt: now,
      );

      final updatedTenantModel = TenantModel.fromEntity(updatedTenant);

      // --------------------------------------------------------------------
      // CREATE INITIAL RENT RATE
      // --------------------------------------------------------------------

      final rentRateDocument = _rentRates.doc();

      final initialRentRate = RentRateModel(
        id: rentRateDocument.id,
        ownerId: normalizedOwnerId,
        propertyId: normalizedPropertyId,
        unitId: normalizedUnitId,
        tenantId: normalizedTenantId,
        tenantUserId: tenantUserId,
        amount: amount,
        effectiveFrom: now,
        effectiveTo: null,
        source: RentRateSource.initial,
        createdAt: now,
        updatedAt: now,
      );

      // --------------------------------------------------------------------
      // UPDATE TENANT
      // --------------------------------------------------------------------

      transaction.update(tenantDocument, updatedTenantModel.toFirestore());

      // --------------------------------------------------------------------
      // OCCUPY UNIT
      // --------------------------------------------------------------------

      transaction.update(unitDocument, {
        'status': UnitStatus.occupied.name,
        'tenantUserId': tenantUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // --------------------------------------------------------------------
      // ADD TENANT TO PROPERTY
      // --------------------------------------------------------------------

      transaction.update(propertyDocument, {
        'tenantUserIds': FieldValue.arrayUnion([tenantUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // --------------------------------------------------------------------
      // CREATE TENANT ACCESS
      // --------------------------------------------------------------------

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

      // --------------------------------------------------------------------
      // CREATE INITIAL RENT RATE
      // --------------------------------------------------------------------

      transaction.set(rentRateDocument, initialRentRate.toFirestore());
    });

    // ------------------------------------------------------------------------
    // RETURN UPDATED TENANT
    // ------------------------------------------------------------------------

    final updatedSnapshot = await tenantDocument.get();

    if (!updatedSnapshot.exists) {
      throw StateError(
        'New tenancy was started but tenant could not be retrieved.',
      );
    }

    return TenantModel.fromFirestore(updatedSnapshot);
  }

  // ==========================================================================
  // DELETE TENANT
  // ==========================================================================

  Future<void> deleteTenant(String tenantId) async {
    final normalizedTenantId = tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      return;
    }

    final tenantDocument = _tenants.doc(normalizedTenantId);

    final tenantSnapshot = await tenantDocument.get();

    if (!tenantSnapshot.exists) {
      return;
    }

    final tenant = TenantModel.fromFirestore(tenantSnapshot);

    final propertyDocument = _properties.doc(tenant.propertyId);
    final unitDocument = _units.doc(tenant.unitId);
    final tenantUserId = tenant.userId?.trim();

    await _firestore.runTransaction((transaction) async {
      final propertySnapshot = await transaction.get(propertyDocument);
      final unitSnapshot = await transaction.get(unitDocument);

      transaction.delete(tenantDocument);

      if (unitSnapshot.exists) {
        transaction.update(unitDocument, {
          'status': 'available',
          'tenantUserId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (propertySnapshot.exists &&
          tenantUserId != null &&
          tenantUserId.isNotEmpty) {
        transaction.update(propertyDocument, {
          'tenantUserIds': FieldValue.arrayRemove([tenantUserId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ==========================================================================
  // SEARCH REGISTERED TENANT BY GRIHO ID
  // CURRENT OWNER SCOPE
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

    if (!publicIdSnapshot.exists) {
      return null;
    }

    return _buildTenantSearchResult(
      userData: publicIdSnapshot.data(),
      ownerId: normalizedOwnerId,
    );
  }

  // ==========================================================================
  // SEARCH REGISTERED TENANT BY PHONE
  // CURRENT OWNER SCOPE
  // ==========================================================================

  Future<TenantSearchResult?> searchRegisteredTenantByPhone({
    required String phone,
    required String ownerId,
  }) async {
    final normalizedOwnerId = ownerId.trim();

    if (normalizedOwnerId.isEmpty) {
      return null;
    }

    final normalizedPhone = PhoneNumberUtils.normalizeAndValidate(phone);

    final phoneLookupSnapshot = await _phoneLookups.doc(normalizedPhone).get();

    if (!phoneLookupSnapshot.exists) {
      return null;
    }

    return _buildTenantSearchResult(
      userData: phoneLookupSnapshot.data(),
      ownerId: normalizedOwnerId,
    );
  }

  // ==========================================================================
  // BUILD SEARCH RESULT
  // ==========================================================================

  Future<TenantSearchResult?> _buildTenantSearchResult({
    required Map<String, dynamic>? userData,
    required String ownerId,
  }) async {
    if (userData == null) {
      return null;
    }

    final userId = userData['uid'];
    final publicId = userData['publicId'];
    final name = userData['name'];
    final phoneNumber = userData['phoneNumber'];
    final email = userData['email'];

    if (userId is! String || userId.trim().isEmpty) {
      return null;
    }

    if (publicId is! String || publicId.trim().isEmpty) {
      return null;
    }

    if (name is! String || name.trim().isEmpty) {
      return null;
    }

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
  // FIND TENANT BY PHONE
  // CURRENT OWNER ONLY
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

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return TenantModel.fromFirestore(snapshot.docs.first);
  }
}
