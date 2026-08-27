import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/tenant.dart';
import '../models/tenant_model.dart';

class TenantDataSource {
  final FirebaseFirestore _firestore;

  TenantDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _tenantCollectionName = 'tenants';

  static const String _unitCollectionName = 'units';

  CollectionReference<Map<String, dynamic>> get _tenants {
    return _firestore.collection(_tenantCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _units {
    return _firestore.collection(_unitCollectionName);
  }

  // ============================================================
  // GET TENANT BY ID
  // ============================================================

  Future<TenantModel?> getTenantById(String tenantId) async {
    final document = await _tenants.doc(tenantId).get();

    if (!document.exists) {
      return null;
    }

    return TenantModel.fromFirestore(document);
  }

  // ============================================================
  // GET TENANTS BY PROPERTY
  // CURRENT OWNER ONLY
  // ============================================================

  Future<List<TenantModel>> getTenantsByPropertyId({
    required String propertyId,
    required String ownerId,
  }) async {
    final snapshot = await _tenants
        .where('propertyId', isEqualTo: propertyId)
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map(TenantModel.fromFirestore).toList();
  }

  // ============================================================
  // GET TENANT BY UNIT
  // CURRENT OWNER ONLY
  //
  // Returns only one active tenant.
  // ============================================================

  Future<TenantModel?> getTenantByUnitId({
    required String unitId,
    required String ownerId,
  }) async {
    final snapshot = await _tenants
        .where('unitId', isEqualTo: unitId)
        .where('ownerId', isEqualTo: ownerId)
        .where('status', isEqualTo: TenantStatus.active.name)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return TenantModel.fromFirestore(snapshot.docs.first);
  }

  // ============================================================
  // GET ALL ACTIVE TENANTS BY UNIT
  // CURRENT OWNER ONLY
  //
  // IMPORTANT:
  // Returns ALL active tenants.
  // Useful for detecting duplicate old data.
  // ============================================================

  Future<List<TenantModel>> getActiveTenantsByUnitId({
    required String unitId,
    required String ownerId,
  }) async {
    final snapshot = await _tenants
        .where('unitId', isEqualTo: unitId)
        .where('ownerId', isEqualTo: ownerId)
        .where('status', isEqualTo: TenantStatus.active.name)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map(TenantModel.fromFirestore).toList();
  }

  // ============================================================
  // CREATE TENANT
  //
  // RULES:
  //
  // 1. Same owner + same phone
  //    => cannot create another tenant.
  //
  // 2. Same owner + same unit + active tenant
  //    => cannot create another active tenant.
  //
  // 3. Tenant creation + unit status update
  //    => same transaction.
  // ============================================================

  Future<TenantModel> createTenant({required TenantModel tenant}) async {
    final normalizedPhone = tenant.phone.trim();

    if (normalizedPhone.isEmpty) {
      throw StateError('Tenant phone number cannot be empty.');
    }

    // ==========================================================
    // CHECK DUPLICATE PHONE
    // ==========================================================

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

    // ==========================================================
    // CHECK DUPLICATE ACTIVE TENANT IN SAME UNIT
    // ==========================================================

    if (tenant.status == TenantStatus.active) {
      final activeUnitSnapshot = await _tenants
          .where('unitId', isEqualTo: tenant.unitId)
          .where('ownerId', isEqualTo: tenant.ownerId)
          .where('status', isEqualTo: TenantStatus.active.name)
          .limit(1)
          .get();

      if (activeUnitSnapshot.docs.isNotEmpty) {
        final existingTenant = TenantModel.fromFirestore(
          activeUnitSnapshot.docs.first,
        );

        throw StateError(
          'This unit already has an active tenant: '
              '${existingTenant.name} '
              '(${existingTenant.phone}).',
        );
      }
    }

    // ==========================================================
    // FIRESTORE DOCUMENTS
    // ==========================================================

    final tenantDocument = _tenants.doc(tenant.id);

    final unitDocument = _units.doc(tenant.unitId);

    // ==========================================================
    // CREATE TENANT + UPDATE UNIT
    // SAME TRANSACTION
    // ==========================================================

    await _firestore.runTransaction((transaction) async {
      // ------------------------------------------------------
      // READ UNIT
      // ------------------------------------------------------

      final unitSnapshot = await transaction.get(unitDocument);

      if (!unitSnapshot.exists) {
        throw StateError('Unit ${tenant.unitId} does not exist.');
      }

      // ------------------------------------------------------
      // CREATE TENANT
      // ------------------------------------------------------

      transaction.set(tenantDocument, tenant.toFirestore());

      // ------------------------------------------------------
      // UPDATE UNIT STATUS
      // ------------------------------------------------------

      transaction.update(unitDocument, {
        'status': tenant.status == TenantStatus.active
            ? 'occupied'
            : 'available',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return tenant;
  }

// ============================================================
// LINK TENANT ACCOUNT
// ============================================================
//
// Links a Firebase Auth UID to a tenant.
//
// Rules:
// 1. Tenant must exist.
// 2. Tenant cannot already belong to another account.
// 3. One Firebase Auth UID cannot be linked to another tenant.
// ============================================================

  Future<TenantModel> linkTenantAccount({
    required String tenantId,
    required String userId,
  }) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      throw ArgumentError(
        'Tenant user ID cannot be empty.',
      );
    }

    final tenantDocument = _tenants.doc(tenantId);

    // ----------------------------------------------------------
    // READ TENANT
    // ----------------------------------------------------------

    final tenantSnapshot =
    await tenantDocument.get();

    if (!tenantSnapshot.exists) {
      throw StateError(
        'Tenant $tenantId does not exist.',
      );
    }

    final tenant =
    TenantModel.fromFirestore(
      tenantSnapshot,
    );

    // ----------------------------------------------------------
    // ALREADY LINKED
    // ----------------------------------------------------------

    if (tenant.userId != null &&
        tenant.userId!.trim().isNotEmpty) {
      if (tenant.userId == normalizedUserId) {
        return tenant;
      }

      throw StateError(
        'This tenant is already linked to another account.',
      );
    }

    // ----------------------------------------------------------
    // CHECK WHETHER THIS USER ID IS ALREADY LINKED
    // ----------------------------------------------------------
    //
    // Query cannot be used directly inside transaction.get().
    // Therefore this check is performed before the transaction.
    // ----------------------------------------------------------

    final existingUserSnapshot = await _tenants
        .where(
      'userId',
      isEqualTo: normalizedUserId,
    )
        .limit(1)
        .get();

    if (existingUserSnapshot.docs.isNotEmpty) {
      final existingTenant =
      TenantModel.fromFirestore(
        existingUserSnapshot.docs.first,
      );

      if (existingTenant.id != tenantId) {
        throw StateError(
          'This account is already linked to another tenant.',
        );
      }

      return existingTenant;
    }

    // ----------------------------------------------------------
    // CREATE UPDATED MODEL
    // ----------------------------------------------------------

    final updatedTenant =
    tenant.copyWith(
      userId: normalizedUserId,
      updatedAt: DateTime.now(),
    );

    final updatedModel =
    TenantModel.fromEntity(
      updatedTenant,
    );

    // ----------------------------------------------------------
    // UPDATE TENANT
    // ----------------------------------------------------------

    await _firestore.runTransaction(
          (transaction) async {
        final currentSnapshot =
        await transaction.get(
          tenantDocument,
        );

        if (!currentSnapshot.exists) {
          throw StateError(
            'Tenant $tenantId no longer exists.',
          );
        }

        final currentTenant =
        TenantModel.fromFirestore(
          currentSnapshot,
        );

        // Prevent overwriting a link created by another request.
        if (currentTenant.userId != null &&
            currentTenant.userId!.trim().isNotEmpty &&
            currentTenant.userId != normalizedUserId) {
          throw StateError(
            'This tenant is already linked to another account.',
          );
        }

        transaction.update(
          tenantDocument,
          updatedModel.toFirestore(),
        );
      },
    );

    return updatedModel;
  }

  // ============================================================
  // UPDATE TENANT
  // TENANT + OLD UNIT + NEW UNIT
  // SAME TRANSACTION
  // ============================================================

  Future<TenantModel> updateTenant(TenantModel tenant) async {
    final tenantDocument = _tenants.doc(tenant.id);

    final existingTenantSnapshot = await tenantDocument.get();

    if (!existingTenantSnapshot.exists) {
      throw StateError('Tenant ${tenant.id} does not exist.');
    }

    final existingTenant = TenantModel.fromFirestore(existingTenantSnapshot);

    final oldUnitId = existingTenant.unitId;

    final newUnitId = tenant.unitId;

    final oldUnitDocument = _units.doc(oldUnitId);

    final newUnitDocument = _units.doc(newUnitId);

    // ==========================================================
    // PHONE DUPLICATE CHECK
    // ==========================================================

    final phoneSnapshot = await _tenants
        .where('ownerId', isEqualTo: tenant.ownerId)
        .where('phone', isEqualTo: tenant.phone.trim())
        .limit(2)
        .get();

    for (final document in phoneSnapshot.docs) {
      if (document.id != tenant.id) {
        final existingPhoneTenant = TenantModel.fromFirestore(document);

        throw StateError(
          'A tenant with this phone number already exists: '
              '${existingPhoneTenant.name} '
              '(${existingPhoneTenant.phone}).',
        );
      }
    }

    // ==========================================================
    // ACTIVE TENANT DUPLICATE CHECK
    //
    // Only necessary when tenant is active.
    // Ignore current tenant itself.
    // ==========================================================

    if (tenant.status == TenantStatus.active) {
      final activeUnitSnapshot = await _tenants
          .where('unitId', isEqualTo: newUnitId)
          .where('ownerId', isEqualTo: tenant.ownerId)
          .where('status', isEqualTo: TenantStatus.active.name)
          .limit(2)
          .get();

      for (final document in activeUnitSnapshot.docs) {
        if (document.id != tenant.id) {
          final existingActiveTenant = TenantModel.fromFirestore(document);

          throw StateError(
            'This unit already has an active tenant: '
                '${existingActiveTenant.name} '
                '(${existingActiveTenant.phone}).',
          );
        }
      }
    }

    // ==========================================================
    // TRANSACTION
    // ==========================================================

    await _firestore.runTransaction((transaction) async {
      // ------------------------------------------------------
      // READ NEW UNIT
      // ------------------------------------------------------

      final newUnitSnapshot = await transaction.get(newUnitDocument);

      if (!newUnitSnapshot.exists) {
        throw StateError('Unit $newUnitId does not exist.');
      }

      // ------------------------------------------------------
      // READ OLD UNIT IF CHANGED
      // ------------------------------------------------------

      if (oldUnitId != newUnitId) {
        final oldUnitSnapshot = await transaction.get(oldUnitDocument);

        if (!oldUnitSnapshot.exists) {
          throw StateError('Previous unit $oldUnitId does not exist.');
        }
      }

      // ------------------------------------------------------
      // UPDATE TENANT
      // ------------------------------------------------------

      transaction.update(tenantDocument, tenant.toFirestore());

      // ------------------------------------------------------
      // UNIT CHANGED
      // ------------------------------------------------------

      if (oldUnitId != newUnitId) {
        // Old unit becomes available.
        transaction.update(oldUnitDocument, {
          'status': 'available',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // New unit status follows tenant status.
        transaction.update(newUnitDocument, {
          'status': tenant.status == TenantStatus.active
              ? 'occupied'
              : 'available',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // ----------------------------------------------------
        // SAME UNIT
        // ----------------------------------------------------

        transaction.update(newUnitDocument, {
          'status': tenant.status == TenantStatus.active
              ? 'occupied'
              : 'available',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    // ==========================================================
    // RETURN UPDATED TENANT
    // ==========================================================

    final updatedDocument = await tenantDocument.get();

    if (!updatedDocument.exists) {
      throw StateError('Tenant was updated but could not be retrieved.');
    }

    return TenantModel.fromFirestore(updatedDocument);
  }

  // ============================================================
  // CLEANUP DUPLICATE ACTIVE TENANTS
  //
  // Keeps one tenant and changes the others to inactive.
  // ============================================================

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

    final now = FieldValue.serverTimestamp();

    for (final document in duplicateDocuments) {
      batch.update(document.reference, {
        'status': TenantStatus.inactive.name,
        'updatedAt': now,
      });
    }

    await batch.commit();
  }

  // ============================================================
  // DELETE TENANT
  //
  // Deletes tenant and keeps unit status consistent.
  // ============================================================

  Future<void> deleteTenant(String tenantId) async {
    final tenantDocument = _tenants.doc(tenantId);

    final tenantSnapshot = await tenantDocument.get();

    if (!tenantSnapshot.exists) {
      return;
    }

    final tenant = TenantModel.fromFirestore(tenantSnapshot);

    final unitDocument = _units.doc(tenant.unitId);

    // ==========================================================
    // DELETE TENANT
    // ==========================================================

    await _firestore.runTransaction((transaction) async {
      final unitSnapshot = await transaction.get(unitDocument);

      // ------------------------------------------------------
      // DELETE TENANT
      // ------------------------------------------------------

      transaction.delete(tenantDocument);

      // ------------------------------------------------------
      // UNIT DOES NOT EXIST
      // ------------------------------------------------------

      if (!unitSnapshot.exists) {
        return;
      }

      // ------------------------------------------------------
      // IF DELETED TENANT WAS INACTIVE
      //
      // Do not change unit status.
      // ------------------------------------------------------

      if (tenant.status != TenantStatus.active) {
        return;
      }

      // ------------------------------------------------------
      // ACTIVE TENANT WAS DELETED
      //
      // Because duplicate active tenants are prevented during
      // creation, normally there cannot be another active
      // tenant here.
      //
      // Therefore the unit becomes available.
      // ------------------------------------------------------

      transaction.update(unitDocument, {
        'status': 'available',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ============================================================
  // SEARCH TENANTS
  // ============================================================

  Future<List<TenantModel>> searchTenants(String search) async {
    final normalizedSearch = search.trim().toLowerCase();

    if (normalizedSearch.isEmpty) {
      return [];
    }

    final results = <String, TenantModel>{};

    // ----------------------------------------------------------
    // NAME SEARCH
    // ----------------------------------------------------------

    final nameQuery = await _tenants
        .where('name', isGreaterThanOrEqualTo: normalizedSearch)
        .where('name', isLessThan: '$normalizedSearch\uf8ff')
        .limit(20)
        .get();

    for (final document in nameQuery.docs) {
      final tenant = TenantModel.fromFirestore(document);

      results[tenant.id] = tenant;
    }

    // ----------------------------------------------------------
    // PHONE SEARCH
    // ----------------------------------------------------------

    final phoneQuery = await _tenants
        .where('phone', isGreaterThanOrEqualTo: normalizedSearch)
        .where('phone', isLessThan: '$normalizedSearch\uf8ff')
        .limit(20)
        .get();

    for (final document in phoneQuery.docs) {
      final tenant = TenantModel.fromFirestore(document);

      results[tenant.id] = tenant;
    }

    return results.values.toList();
  }

  // ============================================================
  // FIND TENANT BY PHONE
  // CURRENT OWNER ONLY
  // ============================================================

  Future<TenantModel?> findTenantByPhone({
    required String phone,
    required String ownerId,
  }) async {
    final normalizedPhone = phone.trim();

    if (normalizedPhone.isEmpty) {
      return null;
    }

    final snapshot = await _tenants
        .where('ownerId', isEqualTo: ownerId)
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