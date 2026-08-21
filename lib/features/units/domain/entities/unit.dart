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
  final double? monthlyRent;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Unit({
    required this.id,
    required this.propertyId,
    required this.floorNumber,
    required this.unitNumber,
    this.name,
    required this.status,
    this.monthlyRent,
    required this.createdAt,
    required this.updatedAt,
  });

  Unit copyWith({
    String? id,
    String? propertyId,
    int? floorNumber,
    String? unitNumber,
    String? name,
    UnitStatus? status,
    double? monthlyRent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Unit(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      floorNumber: floorNumber ?? this.floorNumber,
      unitNumber: unitNumber ?? this.unitNumber,
      name: name ?? this.name,
      status: status ?? this.status,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}