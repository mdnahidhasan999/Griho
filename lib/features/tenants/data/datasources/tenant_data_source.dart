import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/tenant.dart';
import '../../domain/entities/tenant_search_result.dart';
import '../models/tenant_model.dart';

class TenantDataSource {
  final FirebaseFirestore _firestore;

  TenantDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // ==========================================================================
  // COLLECTIONS
  // ==========================================================================

  static const String _tenantCollectionName = 'tenants';
  static const String _unitCollectionName = 'units';
  static const String _propertyCollectionName = 'properties';
  static const String _publicIdCollectionName = 'public_ids';
  static const String _phoneLookupCollectionName = 'phone_lookups';

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

    // ------------------------------------------------------------------------
    // DUPLICATE PHONE
    // ------------------------------------------------------------------------

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

    // ------------------------------------------------------------------------
    // DUPLICATE ACTIVE TENANT IN UNIT
    // ------------------------------------------------------------------------

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

    // ------------------------------------------------------------------------
    // TENANT + PROPERTY + UNIT
    // ------------------------------------------------------------------------

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

    // ------------------------------------------------------------------------
    // READ TENANT
    // ------------------------------------------------------------------------

    final tenantSnapshot = await tenantDocument.get();

    if (!tenantSnapshot.exists) {
      throw StateError('Tenant $normalizedTenantId does not exist.');
    }

    final tenant = TenantModel.fromFirestore(tenantSnapshot);

    // ------------------------------------------------------------------------
    // EXISTING LINK
    // ------------------------------------------------------------------------

    if (tenant.userId != null && tenant.userId!.trim().isNotEmpty) {
      if (tenant.userId == normalizedUserId) {
        return tenant;
      }

      throw StateError('This tenant is already linked to another account.');
    }

    // ------------------------------------------------------------------------
    // CHECK USER ID
    // ------------------------------------------------------------------------

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

    // ------------------------------------------------------------------------
    // TRANSACTION
    // ------------------------------------------------------------------------

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

      transaction.update(
        tenantDocument,
        updatedModel.toFirestore(),
      );

      // Only an active tenant gets unit/property access.
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

    // ------------------------------------------------------------------------
    // PHONE DUPLICATE
    // ------------------------------------------------------------------------

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

    // ------------------------------------------------------------------------
    // ACTIVE TENANT DUPLICATE
    // ------------------------------------------------------------------------

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

    // ------------------------------------------------------------------------
    // TRANSACTION
    // ------------------------------------------------------------------------

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

      final newUnitPropertyId =
      (newUnitData['propertyId'] as String?)?.trim();

      if (newUnitPropertyId != newPropertyId) {
        throw StateError(
          'The new unit does not belong to the selected property.',
        );
      }

      final currentTenant =
      TenantModel.fromFirestore(currentTenantSnapshot);

      // ----------------------------------------------------------------------
      // UPDATE TENANT
      // ----------------------------------------------------------------------

      transaction.update(
        tenantDocument,
        tenant.toFirestore(),
      );

      // ----------------------------------------------------------------------
      // REMOVE OLD ACCESS
      // ----------------------------------------------------------------------

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

      // ----------------------------------------------------------------------
      // ADD NEW ACCESS
      // ----------------------------------------------------------------------

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

      // ----------------------------------------------------------------------
      // CLEAN UNIT ACCESS
      // ----------------------------------------------------------------------

      if (unitSnapshot.exists) {
        final unitData = unitSnapshot.data();

        if (unitData != null) {
          transaction.update(unitDocument, {
            'status': 'available',
            'tenantUserId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // ----------------------------------------------------------------------
      // CLEAN PROPERTY ACCESS
      // ----------------------------------------------------------------------

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
  // SEARCH REGISTERED TENANT
  //
  // Search by:
  // - Griho ID
  // - Phone number
  //
  // Search does NOT query the users collection.
  //
  // Registered Griho users may exist without a Tenant document.
  //
  // Firebase UID is internal only and is never shown in UI.
  // ==========================================================================

  Future<TenantSearchResult?> searchRegisteredTenant(String search) async {
    final normalizedSearch = search.trim();

    if (normalizedSearch.isEmpty) {
      return null;
    }

    Map<String, dynamic>? userData;

    // ------------------------------------------------------------------------
    // GRIHO ID SEARCH
    // ------------------------------------------------------------------------

    if (normalizedSearch.toUpperCase().startsWith('GRI-')) {
      final publicIdSnapshot =
      await _publicIds.doc(normalizedSearch.toUpperCase()).get();

      if (!publicIdSnapshot.exists) {
        return null;
      }

      userData = publicIdSnapshot.data();
    } else {
      // ----------------------------------------------------------------------
      // PHONE SEARCH
      // ----------------------------------------------------------------------

      final phoneLookupSnapshot =
      await _phoneLookups.doc(normalizedSearch).get();

      if (!phoneLookupSnapshot.exists) {
        return null;
      }

      userData = phoneLookupSnapshot.data();
    }

    if (userData == null) {
      return null;
    }

    final userId = userData['uid'];

    final publicId = userData['publicId'];

    final name = userData['name'];

    final phoneNumber = userData['phoneNumber'];

    final email = userData['email'];

    if (userId is! String || userId
        .trim()
        .isEmpty) {
      return null;
    }

    if (publicId is! String || publicId
        .trim()
        .isEmpty) {
      return null;
    }

    if (name is! String || name
        .trim()
        .isEmpty) {
      return null;
    }

    final normalizedUserId = userId.trim();
    final normalizedPublicId = publicId.trim();
    final normalizedName = name.trim();

    final normalizedPhone =
    phoneNumber is String ? phoneNumber.trim() : '';

    final normalizedEmail =
    email is String && email
        .trim()
        .isNotEmpty
        ? email.trim()
        : null;

    // ------------------------------------------------------------------------
    // CHECK WHETHER USER ALREADY HAS A TENANT
    // ------------------------------------------------------------------------

    final tenant = await getTenantByUserId(normalizedUserId);

    // ------------------------------------------------------------------------
    // RETURN SEARCH RESULT
    // ------------------------------------------------------------------------

    return TenantSearchResult(
      userId: normalizedUserId,
      publicId: normalizedPublicId,
      name: normalizedName,
      phone: normalizedPhone,
      email: normalizedEmail,
      tenantId: tenant?.id,
      isExistingTenant: tenant != null,
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