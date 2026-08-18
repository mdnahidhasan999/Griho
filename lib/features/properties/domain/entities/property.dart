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
    required this.createdAt,
    required this.updatedAt,
  });
}