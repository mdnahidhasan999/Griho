import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/tenant.dart';
import '../models/tenant_model.dart';

class TenantDataSource {
  final FirebaseFirestore _firestore;

  TenantDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore =
      firestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'tenants';

  CollectionReference<Map<String, dynamic>>
  get _tenants =>
      _firestore.collection(_collectionName);

  Future<TenantModel?> getTenantById(
      String tenantId,
      ) async {
    final document =
    await _tenants.doc(tenantId).get();

    if (!document.exists) {
      return null;
    }

    return TenantModel.fromFirestore(
      document,
    );
  }

  Future<List<TenantModel>> getTenantsByPropertyId(
      String propertyId,
      ) async {
    final snapshot = await _tenants
        .where(
      'propertyId',
      isEqualTo: propertyId,
    )
        .orderBy(
      'createdAt',
      descending: true,
    )
        .get();

    return snapshot.docs
        .map(
      TenantModel.fromFirestore,
    )
        .toList();
  }

  Future<TenantModel?> getTenantByUnitId(
      String unitId,
      ) async {
    final snapshot = await _tenants
        .where(
      'unitId',
      isEqualTo: unitId,
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

  Future<TenantModel> createTenant({
    required TenantModel tenant,
  }) async {
    final document = _tenants.doc(tenant.id);

    await document.set(
      tenant.toFirestore(),
    );

    return tenant;
  }

  Future<TenantModel> updateTenant(
      TenantModel tenant,
      ) async {
    final document =
    _tenants.doc(tenant.id);

    await document.update(
      tenant.toFirestore(),
    );

    final updatedDocument =
    await document.get();

    if (!updatedDocument.exists) {
      throw StateError(
        'Tenant was updated but could not be retrieved.',
      );
    }

    return TenantModel.fromFirestore(
      updatedDocument,
    );
  }

  Future<void> deleteTenant(
      String tenantId,
      ) async {
    await _tenants.doc(tenantId).delete();
  }
}