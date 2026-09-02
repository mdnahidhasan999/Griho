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
  /// Internal Firestore document ID.
  ///
  /// Never display this value directly in the UI.
  final String id;

  /// Human-readable property ID shown to users.
  ///
  /// Example:
  /// PROP-0001
  final String propertyCode;

  /// Internal owner reference.
  ///
  /// Never display Firebase UID directly in the UI.
  final String ownerId;

  final String name;
  final String? address;
  final String? description;

  final PropertyType type;
  final PropertyStatus status;

  /// Total number of floors in this property.
  final int numberOfFloors;

  /// Firebase UIDs of tenants currently assigned to this property.
  ///
  /// This field is used only for access control and relationship
  /// management. It must never be displayed directly in the UI.
  final List<String> tenantUserIds;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Property({
    required this.id,
    required this.propertyCode,
    required this.ownerId,
    required this.name,
    this.address,
    this.description,
    required this.type,
    required this.status,
    required this.numberOfFloors,
    this.tenantUserIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Property copyWith({
    String? id,
    String? propertyCode,
    String? ownerId,
    String? name,
    String? address,
    String? description,
    PropertyType? type,
    PropertyStatus? status,
    int? numberOfFloors,
    List<String>? tenantUserIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Property(
      id: id ?? this.id,
      propertyCode: propertyCode ?? this.propertyCode,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      address: address ?? this.address,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      numberOfFloors: numberOfFloors ?? this.numberOfFloors,
      tenantUserIds: tenantUserIds ?? this.tenantUserIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}