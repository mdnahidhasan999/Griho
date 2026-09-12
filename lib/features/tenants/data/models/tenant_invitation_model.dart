import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/tenant_invitation.dart';

class TenantInvitationModel extends TenantInvitation {
  const TenantInvitationModel({
    required super.id,
    required super.ownerId,
    required super.tenantId,
    required super.phone,
    required super.propertyId,
    super.propertyName,
    super.propertyCode,
    required super.unitId,
    super.unitNumber,
    super.unitName,
    required super.rentAmount,
    required super.status,
    required super.token,
    required super.createdAt,
    required super.updatedAt,
    required super.expiresAt,
  });

  factory TenantInvitationModel.fromEntity(
      TenantInvitation invitation,
      ) {
    return TenantInvitationModel(
      id: invitation.id,
      ownerId: invitation.ownerId,
      tenantId: invitation.tenantId,
      phone: invitation.phone,
      propertyId: invitation.propertyId,
      propertyName: invitation.propertyName,
      propertyCode: invitation.propertyCode,
      unitId: invitation.unitId,
      unitNumber: invitation.unitNumber,
      unitName: invitation.unitName,
      rentAmount: invitation.rentAmount,
      status: invitation.status,
      token: invitation.token,
      createdAt: invitation.createdAt,
      updatedAt: invitation.updatedAt,
      expiresAt: invitation.expiresAt,
    );
  }

  factory TenantInvitationModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Tenant invitation document ${document.id} contains no data.',
      );
    }

    return TenantInvitationModel(
      id: document.id,
      ownerId: _readRequiredString(data, 'ownerId'),
      tenantId: _readRequiredString(data, 'tenantId'),
      phone: _readRequiredString(data, 'phone'),
      propertyId: _readRequiredString(data, 'propertyId'),
      propertyName: _readOptionalString(data, 'propertyName'),
      propertyCode: _readOptionalString(data, 'propertyCode'),
      unitId: _readRequiredString(data, 'unitId'),
      unitNumber: _readOptionalString(data, 'unitNumber'),
      unitName: _readOptionalString(data, 'unitName'),
      rentAmount: _readRequiredPositiveNumber(
        data,
        'rentAmount',
      ),
      status: TenantInvitationStatus.values.firstWhere(
            (status) => status.name == data['status'],
        orElse: () => TenantInvitationStatus.pending,
      ),
      token: _readRequiredString(data, 'token'),
      createdAt: _readDateTime(data, 'createdAt'),
      updatedAt: _readDateTime(data, 'updatedAt'),
      expiresAt: _readDateTime(data, 'expiresAt'),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'tenantId': tenantId,
      'phone': phone,
      'propertyId': propertyId,
      'unitId': unitId,
      'propertyName': propertyName,
      'propertyCode': propertyCode,
      'unitNumber': unitNumber,
      'unitName': unitName,
      'rentAmount': rentAmount,
      'status': status.name,
      'token': token,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  static String _readRequiredString(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw StateError(
        'Tenant invitation field "$field" is missing or invalid.',
      );
    }

    return value.trim();
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
        'Tenant invitation field "$field" is invalid.',
      );
    }

    final normalizedValue = value.trim();

    if (normalizedValue.isEmpty) {
      return null;
    }

    return normalizedValue;
  }

  static double _readRequiredPositiveNumber(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is! num || value <= 0) {
      throw StateError(
        'Tenant invitation field "$field" must be a positive number.',
      );
    }

    return value.toDouble();
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
      'Tenant invitation field "$field" is missing or invalid.',
    );
  }
}