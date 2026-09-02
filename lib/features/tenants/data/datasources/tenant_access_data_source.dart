import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tenant_access_model.dart';

class TenantAccessDataSource {
  final FirebaseFirestore _firestore;

  TenantAccessDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // ============================================================
  // COLLECTION
  // ============================================================

  static const String _collectionName = 'tenantAccess';

  CollectionReference<Map<String, dynamic>> get _tenantAccess {
    return _firestore.collection(_collectionName);
  }

  // ============================================================
  // GET BY USER ID
  // ============================================================

  Future<TenantAccessModel?> getTenantAccessByUserId(
      String userId,
      ) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return null;
    }

    final document = await _tenantAccess
        .doc(normalizedUserId)
        .get();

    if (!document.exists) {
      return null;
    }

    return TenantAccessModel.fromFirestore(document);
  }

  // ============================================================
  // CREATE OR UPDATE
  // ============================================================

  Future<void> createOrUpdateTenantAccess(
      TenantAccessModel access,
      ) async {
    final normalizedUserId = access.userId.trim();

    if (normalizedUserId.isEmpty) {
      throw ArgumentError(
        'Tenant user ID cannot be empty.',
      );
    }

    if (access.id.trim() != normalizedUserId) {
      throw ArgumentError(
        'Tenant access document ID must match the user ID.',
      );
    }

    await _tenantAccess
        .doc(normalizedUserId)
        .set(
      access.toFirestore(),
      SetOptions(merge: false),
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> deleteTenantAccess(
      String userId,
      ) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return;
    }

    await _tenantAccess
        .doc(normalizedUserId)
        .delete();
  }
}