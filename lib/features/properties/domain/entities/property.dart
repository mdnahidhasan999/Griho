enum PropertyType {
  residential,
  commercial,
  mixedUse,
}

enum PropertyStatus {
  active,
  inactive,
}

class Property {
  final String id;
  final String ownerId;

  final String name;
  final String? address;
  final String? description;

  final PropertyType type;
  final PropertyStatus status;

  /// Total number of floors in this property.
  final int numberOfFloors;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Property({
    required this.id,
    required this.ownerId,
    required this.name,
    this.address,
    this.description,
    required this.type,
    required this.status,
    required this.numberOfFloors,
    required this.createdAt,
    required this.updatedAt,
  });

  Property copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? address,
    String? description,
    PropertyType? type,
    PropertyStatus? status,
    int? numberOfFloors,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Property(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      address: address ?? this.address,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      numberOfFloors:
      numberOfFloors ?? this.numberOfFloors,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}