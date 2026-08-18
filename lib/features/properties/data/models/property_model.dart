import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/property.dart';

class PropertyModel extends Property {
  const PropertyModel({
    required super.id,
    required super.ownerId,
    required super.name,
    super.address,
    super.description,
    required super.type,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
  });

  factory PropertyModel.fromEntity(Property property) {
    return PropertyModel(
      id: property.id,
      ownerId: property.ownerId,
      name: property.name,
      address: property.address,
      description: property.description,
      type: property.type,
      status: property.status,
      createdAt: property.createdAt,
      updatedAt: property.updatedAt,
    );
  }

  factory PropertyModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Property document ${document.id} contains no data.',
      );
    }

    return PropertyModel(
      id: document.id,
      ownerId: _readRequiredString(
        data,
        'ownerId',
      ),
      name: _readRequiredString(
        data,
        'name',
      ),
      address: _readOptionalString(
        data,
        'address',
      ),
      description: _readOptionalString(
        data,
        'description',
      ),
      type: _propertyTypeFromString(
        _readRequiredString(data, 'type'),
      ),
      status: _propertyStatusFromString(
        _readRequiredString(data, 'status'),
      ),
      createdAt: _readDateTime(
        data,
        'createdAt',
      ),
      updatedAt: _readDateTime(
        data,
        'updatedAt',
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'name': name,
      'address': address,
      'description': description,
      'type': type.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static String _readRequiredString(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw StateError(
        'Property field "$field" is missing or invalid.',
      );
    }

    return value;
  }

  static String? _readOptionalString(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw StateError(
        'Property field "$field" is invalid.',
      );
    }

    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime _readDateTime(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    throw StateError(
      'Property field "$field" is missing or invalid.',
    );
  }

  static PropertyType _propertyTypeFromString(
      String value,
      ) {
    return PropertyType.values.firstWhere(
          (type) => type.name == value,
      orElse: () {
        throw StateError(
          'Unknown property type: $value',
        );
      },
    );
  }

  static PropertyStatus _propertyStatusFromString(
      String value,
      ) {
    return PropertyStatus.values.firstWhere(
          (status) => status.name == value,
      orElse: () {
        throw StateError(
          'Unknown property status: $value',
        );
      },
    );
  }
}