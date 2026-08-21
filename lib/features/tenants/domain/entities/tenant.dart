enum TenantStatus {
  active,
  inactive,
}

class Tenant {
  final String id;
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

  Tenant copyWith({
    String? id,
    String? userId,
    String? propertyId,
    String? unitId,
    String? name,
    String? phone,
    String? email,
    String? nidNumber,
    TenantStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tenant(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      propertyId: propertyId ?? this.propertyId,
      unitId: unitId ?? this.unitId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      nidNumber: nidNumber ?? this.nidNumber,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}