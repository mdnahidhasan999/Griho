import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/tenant_access.dart';

class TenantAccessModel extends TenantAccess {
  const TenantAccessModel({
    required super.id,
    required super.userId,
    required super.tenantId,
    required super.ownerId,
    required super.propertyId,
    required super.unitId,
    required super.invitationId,
    required super.createdAt,
    required super.updatedAt,
  });

  factory TenantAccessModel.fromEntity(TenantAccess access) {
    return TenantAccessModel(
      id: access.id,
      userId: access.userId,
      tenantId: access.tenantId,
      ownerId: access.ownerId,
      propertyId: access.propertyId,
      unitId: access.unitId,
      invitationId: access.invitationId,
      createdAt: access.createdAt,
      updatedAt: access.updatedAt,
    );
  }

  factory TenantAccessModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Tenant access document ${document.id} contains no data.',
      );
    }

    return TenantAccessModel(
      id: document.id,
      userId: _readRequiredString(data, 'userId'),
      tenantId: _readRequiredString(data, 'tenantId'),
      ownerId: _readRequiredString(data, 'ownerId'),
      propertyId: _readRequiredString(data, 'propertyId'),
      unitId: _readRequiredString(data, 'unitId'),
      invitationId: _readRequiredString(data, 'invitationId'),
      createdAt: _readDateTime(data, 'createdAt'),
      updatedAt: _readDateTime(data, 'updatedAt'),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'tenantId': tenantId,
      'ownerId': ownerId,
      'propertyId': propertyId,
      'unitId': unitId,
      'invitationId': invitationId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static String _readRequiredString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw StateError('Tenant access field "$field" is missing or invalid.');
    }

    return value.trim();
  }

  static DateTime _readDateTime(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is Timestamp) {
      return value.toDate();
    }

    throw StateError('Tenant access field "$field" is missing or invalid.');
  }
}
