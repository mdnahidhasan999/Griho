import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/tenant.dart';
import '../models/tenant_model.dart';

class TenantDataSource {
  final FirebaseFirestore _firestore;

  TenantDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'tenants';

  CollectionReference<Map<String, dynamic>> get _tenants {
    return _firestore.collection(_collectionName);
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
  // ============================================================

// ============================================================
// GET TENANTS BY PROPERTY
// CURRENT OWNER ONLY
// ============================================================

  Future<List<TenantModel>> getTenantsByPropertyId({
    required String propertyId,
    required String ownerId,
  }) async {
    final snapshot = await _tenants
        .where(
      'propertyId',
      isEqualTo: propertyId,
    )
        .where(
      'ownerId',
      isEqualTo: ownerId,
    )
        .orderBy(
      'createdAt',
      descending: true,
    )
        .get();

    return snapshot.docs
        .map(TenantModel.fromFirestore)
        .toList();
  }

// ============================================================
// GET ACTIVE TENANT BY UNIT
// CURRENT OWNER ONLY
// ============================================================

  Future<TenantModel?> getTenantByUnitId({
    required String unitId,
    required String ownerId,
  }) async {
    final snapshot = await _tenants
        .where(
      'unitId',
      isEqualTo: unitId,
    )
        .where(
      'ownerId',
      isEqualTo: ownerId,
    )
        .where(
      'status',
      isEqualTo: TenantStatus.active.name,
    )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return TenantModel.fromFirestore(
      snapshot.docs.first,
    );
  }

  // ============================================================
  // CREATE TENANT
  // ============================================================

  Future<TenantModel> createTenant({
    required TenantModel tenant,
  }) async {
    final document = _tenants.doc(tenant.id);

    await document.set(
      tenant.toFirestore(),
    );

    return tenant;
  }

  // ============================================================
  // UPDATE TENANT
  // ============================================================

  Future<TenantModel> updateTenant(TenantModel tenant,) async {
    final document = _tenants.doc(tenant.id);

    await document.update(
      tenant.toFirestore(),
    );

    final updatedDocument = await document.get();

    if (!updatedDocument.exists) {
      throw StateError(
        'Tenant was updated but could not be retrieved.',
      );
    }

    return TenantModel.fromFirestore(
      updatedDocument,
    );
  }

  // ============================================================
  // DELETE TENANT
  // ============================================================

  Future<void> deleteTenant(String tenantId,) async {
    await _tenants.doc(tenantId).delete();
  }

  // ============================================================
  // SEARCH TENANTS
  // ============================================================

  Future<List<TenantModel>> searchTenants(String search,) async {
    final normalizedSearch = search.trim().toLowerCase();

    if (normalizedSearch.isEmpty) {
      return [];
    }

    final results = <String, TenantModel>{};

    // ----------------------------------------------------------
    // NAME SEARCH
    // ----------------------------------------------------------

    final nameQuery = await _tenants
        .where(
      'name',
      isGreaterThanOrEqualTo: normalizedSearch,
    )
        .where(
      'name',
      isLessThan: '$normalizedSearch\uf8ff',
    )
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
        .where(
      'phone',
      isGreaterThanOrEqualTo: normalizedSearch,
    )
        .where(
      'phone',
      isLessThan: '$normalizedSearch\uf8ff',
    )
        .limit(20)
        .get();

    for (final document in phoneQuery.docs) {
      final tenant = TenantModel.fromFirestore(document);

      results[tenant.id] = tenant;
    }

    return results.values.toList();
  }

  // ============================================================
  // FIND TENANT BY PHONE — CURRENT OWNER ONLY
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
        .where(
      'ownerId',
      isEqualTo: ownerId,
    )
        .where(
      'phone',
      isEqualTo: normalizedPhone,
    )
        .where(
      'status',
      isEqualTo: TenantStatus.active.name,
    )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return TenantModel.fromFirestore(
      snapshot.docs.first,
    );
  }
}