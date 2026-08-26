enum TenantInvitationStatus {
  pending,
  accepted,
  expired,
  cancelled,
}

class TenantInvitation {
  final String id;

  // ============================================================
  // OWNER
  // ============================================================

  final String ownerId;

  // ============================================================
  // TENANT
  // ============================================================

  final String tenantId;
  final String phone;

  // ============================================================
  // PROPERTY / UNIT
  // ============================================================

  final String propertyId;
  final String unitId;

  // ============================================================
  // INVITATION
  // ============================================================

  final TenantInvitationStatus status;

  final String token;

  // ============================================================
  // DATES
  // ============================================================

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;

  const TenantInvitation({
    required this.id,
    required this.ownerId,
    required this.tenantId,
    required this.phone,
    required this.propertyId,
    required this.unitId,
    required this.status,
    required this.token,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
  });

  // ============================================================
  // COPY WITH
  // ============================================================

  TenantInvitation copyWith({
    String? id,
    String? ownerId,
    String? tenantId,
    String? phone,
    String? propertyId,
    String? unitId,
    TenantInvitationStatus? status,
    String? token,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
  }) {
    return TenantInvitation(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      tenantId: tenantId ?? this.tenantId,
      phone: phone ?? this.phone,
      propertyId: propertyId ?? this.propertyId,
      unitId: unitId ?? this.unitId,
      status: status ?? this.status,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  // ============================================================
  // IS EXPIRED
  // ============================================================

  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  // ============================================================
  // IS VALID
  // ============================================================

  bool get isValid {
    return status == TenantInvitationStatus.pending &&
        !isExpired;
  }
}