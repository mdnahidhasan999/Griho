enum UnitStatus {
  available,
  occupied,
  reserved,
  inactive,
}

class Unit {
  final String id;
  final String propertyId;

  final int floorNumber;
  final String unitNumber;
  final String? name;

  final UnitStatus status;

  // Firebase UID of the currently assigned tenant.
  //
  // null means no Griho tenant account is currently linked
  // to this unit.
  final String? tenantUserId;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Unit({
    required this.id,
    required this.propertyId,
    required this.floorNumber,
    required this.unitNumber,
    this.name,
    required this.status,
    this.tenantUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  Unit copyWith({
    String? id,
    String? propertyId,
    int? floorNumber,
    String? unitNumber,
    Object? name = _keep,
    UnitStatus? status,
    Object? tenantUserId = _keep,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Unit(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      floorNumber: floorNumber ?? this.floorNumber,
      unitNumber: unitNumber ?? this.unitNumber,

      name: name == _keep
          ? this.name
          : name as String?,

      status: status ?? this.status,

      tenantUserId: tenantUserId == _keep
          ? this.tenantUserId
          : tenantUserId as String?,

      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const Object _keep = Object();
}