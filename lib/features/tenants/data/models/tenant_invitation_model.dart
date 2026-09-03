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
    required super.status,
    required super.token,
    required super.createdAt,
    required super.updatedAt,
    required super.expiresAt,
  });

  // ============================================================
  // FROM ENTITY
  // ============================================================

  factory TenantInvitationModel.fromEntity(TenantInvitation invitation) {
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
      status: invitation.status,
      token: invitation.token,
      createdAt: invitation.createdAt,
      updatedAt: invitation.updatedAt,
      expiresAt: invitation.expiresAt,
    );
  }

  // ============================================================
  // FROM FIRESTORE
  // ============================================================

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

      // --------------------------------------------------------
      // OWNER
      // --------------------------------------------------------

      ownerId: _readRequiredString(data, 'ownerId'),

      // --------------------------------------------------------
      // TENANT
      // --------------------------------------------------------

      tenantId: _readRequiredString(data, 'tenantId'),

      phone: _readRequiredString(data, 'phone'),

      // --------------------------------------------------------
      // PROPERTY
      //
      // propertyId remains required because it is part of the
      // invitation relationship.
      //
      // propertyName/propertyCode are nullable because older
      // invitation documents may not contain these snapshots.
      // --------------------------------------------------------

      propertyId: _readRequiredString(data, 'propertyId'),

      propertyName: _readOptionalString(data, 'propertyName'),

      propertyCode: _readOptionalString(data, 'propertyCode'),

      // --------------------------------------------------------
      // UNIT
      // --------------------------------------------------------

      unitId: _readRequiredString(data, 'unitId'),

      unitNumber: _readOptionalString(data, 'unitNumber'),

      unitName: _readOptionalString(data, 'unitName'),

      // --------------------------------------------------------
      // INVITATION
      // --------------------------------------------------------

      status: TenantInvitationStatus.values.firstWhere(
            (status) => status.name == data['status'],
        orElse: () => TenantInvitationStatus.pending,
      ),

      token: _readRequiredString(data, 'token'),

      // --------------------------------------------------------
      // DATES
      // --------------------------------------------------------

      createdAt: _readDateTime(data, 'createdAt'),

      updatedAt: _readDateTime(data, 'updatedAt'),

      expiresAt: _readDateTime(data, 'expiresAt'),
    );
  }

  // ============================================================
  // TO FIRESTORE
  // ============================================================

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'tenantId': tenantId,
      'phone': phone,

      // --------------------------------------------------------
      // INTERNAL IDs
      // --------------------------------------------------------

      'propertyId': propertyId,
      'unitId': unitId,

      // --------------------------------------------------------
      // HUMAN-READABLE SNAPSHOTS
      //
      // New invitations will save these fields.
      // --------------------------------------------------------

      'propertyName': propertyName,
      'propertyCode': propertyCode,
      'unitNumber': unitNumber,
      'unitName': unitName,

      // --------------------------------------------------------
      // INVITATION
      // --------------------------------------------------------

      'status': status.name,
      'token': token,

      'createdAt': Timestamp.fromDate(createdAt),

      'updatedAt': Timestamp.fromDate(updatedAt),

      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  // ============================================================
  // REQUIRED STRING
  // ============================================================

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

  // ============================================================
  // OPTIONAL STRING
  // ============================================================

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

  // ============================================================
  // DATE TIME
  // ============================================================

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