import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/tenant.dart';
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

  CollectionReference<Map<String, dynamic>> get _tenants {
    return _firestore.collection(_tenantCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _units {
    return _firestore.collection(_unitCollectionName);
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

    if (normalizedPhone.isEmpty) {
      throw StateError('Tenant phone number cannot be empty.');
    }

    if (tenant.ownerId.trim().isEmpty) {
      throw StateError('Tenant owner ID cannot be empty.');
    }

    if (tenant.propertyId.trim().isEmpty) {
      throw StateError('Tenant property ID cannot be empty.');
    }

    if (tenant.unitId.trim().isEmpty) {
      throw StateError('Tenant unit ID cannot be empty.');
    }

    // ------------------------------------------------------------------------
    // DUPLICATE PHONE
    // ------------------------------------------------------------------------

    final phoneSnapshot = await _tenants
        .where('ownerId', isEqualTo: tenant.ownerId)
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
          .where('unitId', isEqualTo: tenant.unitId)
          .where('ownerId', isEqualTo: tenant.ownerId)
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
    final unitDocument = _units.doc(tenant.unitId);

    // ------------------------------------------------------------------------
    // TENANT + UNIT
    // ------------------------------------------------------------------------

    await _firestore.runTransaction((transaction) async {
      final unitSnapshot = await transaction.get(unitDocument);

      if (!unitSnapshot.exists) {
        throw StateError('Unit ${tenant.unitId} does not exist.');
      }

      transaction.set(tenantDocument, tenant.toFirestore());

      transaction.update(unitDocument, {
        'status': tenant.status == TenantStatus.active
            ? 'occupied'
            : 'available',
        'updatedAt': FieldValue.serverTimestamp(),
      });
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

    final updatedTenant = tenant.copyWith(
      userId: normalizedUserId,
      accountStatus: TenantAccountStatus.registered,
      updatedAt: DateTime.now(),
    );

    final updatedModel = TenantModel.fromEntity(updatedTenant);

    await _firestore.runTransaction((transaction) async {
      final currentSnapshot = await transaction.get(tenantDocument);

      if (!currentSnapshot.exists) {
        throw StateError('Tenant $normalizedTenantId no longer exists.');
      }

      final currentTenant = TenantModel.fromFirestore(currentSnapshot);

      final currentUserId = currentTenant.userId?.trim();

      if (currentUserId != null &&
          currentUserId.isNotEmpty &&
          currentUserId != normalizedUserId) {
        throw StateError('This tenant is already linked to another account.');
      }

      transaction.update(tenantDocument, updatedModel.toFirestore());
    });

    return updatedModel;
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

    final oldUnitId = existingTenant.unitId;
    final newUnitId = tenant.unitId.trim();

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

    final oldUnitDocument = _units.doc(oldUnitId);
    final newUnitDocument = _units.doc(newUnitId);

    // ------------------------------------------------------------------------
    // TRANSACTION
    // ------------------------------------------------------------------------

    await _firestore.runTransaction((transaction) async {
      final newUnitSnapshot = await transaction.get(newUnitDocument);

      if (!newUnitSnapshot.exists) {
        throw StateError('Unit $newUnitId does not exist.');
      }

      if (oldUnitId != newUnitId) {
        final oldUnitSnapshot = await transaction.get(oldUnitDocument);

        if (!oldUnitSnapshot.exists) {
          throw StateError('Previous unit $oldUnitId does not exist.');
        }
      }

      transaction.update(tenantDocument, tenant.toFirestore());

      if (oldUnitId != newUnitId) {
        transaction.update(oldUnitDocument, {
          'status': 'available',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.update(newUnitDocument, {
        'status': tenant.status == TenantStatus.active
            ? 'occupied'
            : 'available',
        'updatedAt': FieldValue.serverTimestamp(),
      });
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

    final unitDocument = _units.doc(tenant.unitId);

    await _firestore.runTransaction((transaction) async {
      final unitSnapshot = await transaction.get(unitDocument);

      transaction.delete(tenantDocument);

      if (!unitSnapshot.exists) {
        return;
      }

      if (tenant.status != TenantStatus.active) {
        return;
      }

      transaction.update(unitDocument, {
        'status': 'available',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ==========================================================================
  // SEARCH TENANTS
  // ==========================================================================

  Future<List<TenantModel>> searchTenants(String search) async {
    final normalizedSearch = search.trim().toLowerCase();

    if (normalizedSearch.isEmpty) {
      return [];
    }

    final results = <String, TenantModel>{};

    // ------------------------------------------------------------------------
    // NAME
    // ------------------------------------------------------------------------

    final nameSnapshot = await _tenants
        .where('name', isGreaterThanOrEqualTo: normalizedSearch)
        .where('name', isLessThan: '$normalizedSearch\uf8ff')
        .limit(20)
        .get();

    for (final document in nameSnapshot.docs) {
      final tenant = TenantModel.fromFirestore(document);

      results[tenant.id] = tenant;
    }

    // ------------------------------------------------------------------------
    // PHONE
    // ------------------------------------------------------------------------

    final phoneSnapshot = await _tenants
        .where('phone', isGreaterThanOrEqualTo: normalizedSearch)
        .where('phone', isLessThan: '$normalizedSearch\uf8ff')
        .limit(20)
        .get();

    for (final document in phoneSnapshot.docs) {
      final tenant = TenantModel.fromFirestore(document);

      results[tenant.id] = tenant;
    }

    return results.values.toList();
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
