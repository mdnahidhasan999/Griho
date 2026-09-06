import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tenancy_history_model.dart';

class TenancyHistoryDataSource {
  final FirebaseFirestore _firestore;

  TenancyHistoryDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore =
      firestore ?? FirebaseFirestore.instance;

  static const String _collectionName =
      'tenancyHistories';

  CollectionReference<Map<String, dynamic>>
  get _collection =>
      _firestore.collection(_collectionName);

  // ========================================================================
  // TENANT HISTORY — OWNER SIDE
  // ========================================================================

  Future<List<TenancyHistoryModel>>
  getHistoryByTenantId({
    required String tenantId,
    required String ownerId,
  }) async {
    final normalizedTenantId = tenantId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    final snapshot = await _collection
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'tenantId',
      isEqualTo: normalizedTenantId,
    )
        .orderBy(
      'endedAt',
      descending: true,
    )
        .get();

    return snapshot.docs
        .map(
      TenancyHistoryModel.fromFirestore,
    )
        .toList();
  }

  // ========================================================================
  // UNIT HISTORY — OWNER SIDE
  // ========================================================================

  Future<List<TenancyHistoryModel>>
  getHistoryByUnitId({
    required String unitId,
    required String ownerId,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
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
        .orderBy(
      'endedAt',
      descending: true,
    )
        .get();

    return snapshot.docs
        .map(
      TenancyHistoryModel.fromFirestore,
    )
        .toList();
  }

  // ========================================================================
  // TENANT HISTORY — TENANT SIDE
  // ========================================================================

  Future<List<TenancyHistoryModel>>
  getHistoryByTenantUserId({
    required String tenantUserId,
  }) async {
    final normalizedTenantUserId =
    tenantUserId.trim();

    if (normalizedTenantUserId.isEmpty) {
      throw ArgumentError(
        'Tenant user ID cannot be empty.',
      );
    }

    final snapshot = await _collection
        .where(
      'tenantUserId',
      isEqualTo: normalizedTenantUserId,
    )
        .orderBy(
      'endedAt',
      descending: true,
    )
        .get();

    return snapshot.docs
        .map(
      TenancyHistoryModel.fromFirestore,
    )
        .toList();
  }
}