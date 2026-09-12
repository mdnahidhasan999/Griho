enum TenantInvitationStatus {
  pending,
  accepted,
  expired,
  cancelled,
  rejected,
}

class TenantInvitation {
  final String id;

  final String ownerId;

  final String tenantId;
  final String phone;

  final String propertyId;
  final String? propertyName;
  final String? propertyCode;

  final String unitId;
  final String? unitNumber;
  final String? unitName;

  /// Agreed initial monthly rent.
  ///
  /// This amount is fixed into the invitation and becomes the
  /// initial RentRate when the tenant accepts the invitation.
  final double rentAmount;

  final TenantInvitationStatus status;

  final String token;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;

  const TenantInvitation({
    required this.id,
    required this.ownerId,
    required this.tenantId,
    required this.phone,
    required this.propertyId,
    this.propertyName,
    this.propertyCode,
    required this.unitId,
    this.unitNumber,
    this.unitName,
    required this.rentAmount,
    required this.status,
    required this.token,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
  });

  TenantInvitation copyWith({
    String? id,
    String? ownerId,
    String? tenantId,
    String? phone,
    String? propertyId,
    String? propertyName,
    String? propertyCode,
    String? unitId,
    String? unitNumber,
    String? unitName,
    double? rentAmount,
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
      propertyName: propertyName ?? this.propertyName,
      propertyCode: propertyCode ?? this.propertyCode,
      unitId: unitId ?? this.unitId,
      unitNumber: unitNumber ?? this.unitNumber,
      unitName: unitName ?? this.unitName,
      rentAmount: rentAmount ?? this.rentAmount,
      status: status ?? this.status,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  bool get isValid {
    return status == TenantInvitationStatus.pending && !isExpired;
  }
}