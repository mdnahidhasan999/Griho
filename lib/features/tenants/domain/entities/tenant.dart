enum TenantStatus {
  active,
  inactive,
}

class Tenant {
  final String id;

  // Tenant-এর property owner-এর Firebase Auth UID
  final String ownerId;

  // Tenant-এর নিজের Griho account থাকলে Firebase Auth UID
  final String? userId;

  final String propertyId;
  final String unitId;

  final String name;
  final String phone;
  final String? email;
  final String? nidNumber;

  final TenantStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Tenant({
    required this.id,
    required this.ownerId,
    this.userId,
    required this.propertyId,
    required this.unitId,
    required this.name,
    required this.phone,
    this.email,
    this.nidNumber,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  // ============================================================
  // COPY WITH
  // ============================================================

  Tenant copyWith({
    String? id,
    String? ownerId,
    String? userId,
    String? propertyId,
    String? unitId,
    String? name,
    String? phone,

    // Nullable fields
    Object? email = _keep,
    Object? nidNumber = _keep,

    TenantStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tenant(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      userId: userId ?? this.userId,

      propertyId: propertyId ?? this.propertyId,
      unitId: unitId ?? this.unitId,

      name: name ?? this.name,
      phone: phone ?? this.phone,

      email: email == _keep
          ? this.email
          : email as String?,

      nidNumber: nidNumber == _keep
          ? this.nidNumber
          : nidNumber as String?,

      status: status ?? this.status,

      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const Object _keep = Object();
}