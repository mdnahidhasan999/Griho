class TenantAccess {
  final String id;
  final String userId;
  final String tenantId;
  final String ownerId;
  final String propertyId;
  final String unitId;
  final String? invitationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TenantAccess({
    required this.id,
    required this.userId,
    required this.tenantId,
    required this.ownerId,
    required this.propertyId,
    required this.unitId,
    required this.invitationId,
    required this.createdAt,
    required this.updatedAt,
  });

  TenantAccess copyWith({
    String? id,
    String? userId,
    String? tenantId,
    String? ownerId,
    String? propertyId,
    String? unitId,
    String? invitationId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TenantAccess(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tenantId: tenantId ?? this.tenantId,
      ownerId: ownerId ?? this.ownerId,
      propertyId: propertyId ?? this.propertyId,
      unitId: unitId ?? this.unitId,
      invitationId: invitationId ?? this.invitationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}