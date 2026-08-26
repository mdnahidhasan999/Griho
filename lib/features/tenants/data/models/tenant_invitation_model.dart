import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/tenant_invitation.dart';

class TenantInvitationModel extends TenantInvitation {
  const TenantInvitationModel({
    required super.id,
    required super.ownerId,
    required super.tenantId,
    required super.phone,
    required super.propertyId,
    required super.unitId,
    required super.status,
    required super.token,
    required super.createdAt,
    required super.updatedAt,
    required super.expiresAt,
  });

  // ============================================================
  // FROM ENTITY
  // ============================================================

  factory TenantInvitationModel.fromEntity(
      TenantInvitation invitation,
      ) {
    return TenantInvitationModel(
      id: invitation.id,
      ownerId: invitation.ownerId,
      tenantId: invitation.tenantId,
      phone: invitation.phone,
      propertyId: invitation.propertyId,
      unitId: invitation.unitId,
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

      ownerId: _readRequiredString(
        data,
        'ownerId',
      ),

      tenantId: _readRequiredString(
        data,
        'tenantId',
      ),

      phone: _readRequiredString(
        data,
        'phone',
      ),

      propertyId: _readRequiredString(
        data,
        'propertyId',
      ),

      unitId: _readRequiredString(
        data,
        'unitId',
      ),

      status: TenantInvitationStatus.values.firstWhere(
            (status) => status.name == data['status'],
        orElse: () => TenantInvitationStatus.pending,
      ),

      token: _readRequiredString(
        data,
        'token',
      ),

      createdAt: _readDateTime(
        data,
        'createdAt',
      ),

      updatedAt: _readDateTime(
        data,
        'updatedAt',
      ),

      expiresAt: _readDateTime(
        data,
        'expiresAt',
      ),
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
      'propertyId': propertyId,
      'unitId': unitId,
      'status': status.name,
      'token': token,

      'createdAt': Timestamp.fromDate(
        createdAt,
      ),

      'updatedAt': Timestamp.fromDate(
        updatedAt,
      ),

      'expiresAt': Timestamp.fromDate(
        expiresAt,
      ),
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