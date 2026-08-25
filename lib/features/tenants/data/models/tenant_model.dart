import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/tenant.dart';

class TenantModel extends Tenant {
  const TenantModel({
    required super.id,
    required super.ownerId,
    super.userId,
    required super.propertyId,
    required super.unitId,
    required super.name,
    required super.phone,
    super.email,
    super.nidNumber,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
  });

  factory TenantModel.fromEntity(Tenant tenant) {
    return TenantModel(
      id: tenant.id,
      ownerId: tenant.ownerId,
      userId: tenant.userId,
      propertyId: tenant.propertyId,
      unitId: tenant.unitId,
      name: tenant.name,
      phone: tenant.phone,
      email: tenant.email,
      nidNumber: tenant.nidNumber,
      status: tenant.status,
      createdAt: tenant.createdAt,
      updatedAt: tenant.updatedAt,
    );
  }

  factory TenantModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Tenant document ${document.id} contains no data.',
      );
    }

    return TenantModel(
      id: document.id,

      ownerId: _readRequiredString(
        data,
        'ownerId',
      ),

      userId: _readOptionalString(
        data,
        'userId',
      ),

      propertyId: _readRequiredString(
        data,
        'propertyId',
      ),

      unitId: _readRequiredString(
        data,
        'unitId',
      ),

      name: _readRequiredString(
        data,
        'name',
      ),

      phone: _readRequiredString(
        data,
        'phone',
      ),

      email: _readOptionalString(
        data,
        'email',
      ),

      nidNumber: _readOptionalString(
        data,
        'nidNumber',
      ),

      status: TenantStatus.values.firstWhere(
            (status) =>
        status.name == data['status'],
        orElse: () => TenantStatus.active,
      ),

      createdAt: _readDateTime(
        data,
        'createdAt',
      ),

      updatedAt: _readDateTime(
        data,
        'updatedAt',
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'userId': userId,
      'propertyId': propertyId,
      'unitId': unitId,
      'name': name,
      'phone': phone,
      'email': email,
      'nidNumber': nidNumber,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static String _readRequiredString(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw StateError(
        'Tenant field "$field" is missing or invalid.',
      );
    }

    return value;
  }

  static String? _readOptionalString(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw StateError(
        'Tenant field "$field" is invalid.',
      );
    }

    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime _readDateTime(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is Timestamp) {
      return value.toDate();
    }

    throw StateError(
      'Tenant field "$field" is missing or invalid.',
    );
  }
}