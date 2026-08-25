import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/property.dart';

class PropertyModel extends Property {
  const PropertyModel({
    required super.id,
    required super.propertyCode,
    required super.ownerId,
    required super.name,
    super.address,
    super.description,
    required super.type,
    required super.status,
    required super.numberOfFloors,
    required super.createdAt,
    required super.updatedAt,
  });

  factory PropertyModel.fromEntity(
      Property property,
      ) {
    return PropertyModel(
      id: property.id,
      propertyCode: property.propertyCode,
      ownerId: property.ownerId,
      name: property.name,
      address: property.address,
      description: property.description,
      type: property.type,
      status: property.status,
      numberOfFloors: property.numberOfFloors,
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

      propertyCode: _readPropertyCode(
        data,
        document.id,
      ),

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
        _readRequiredString(
          data,
          'type',
        ),
      ),

      status: _propertyStatusFromString(
        _readRequiredString(
          data,
          'status',
        ),
      ),

      numberOfFloors: _readNumberOfFloors(
        data,
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
      'propertyCode': propertyCode,
      'ownerId': ownerId,
      'name': name,
      'address': address,
      'description': description,
      'type': type.name,
      'status': status.name,
      'numberOfFloors': numberOfFloors,
      'createdAt': Timestamp.fromDate(
        createdAt,
      ),
      'updatedAt': Timestamp.fromDate(
        updatedAt,
      ),
    };
  }

  // ============================================================
  // PROPERTY CODE
  // ============================================================

  static String _readPropertyCode(
      Map<String, dynamic> data,
      String documentId,
      ) {
    final value = data['propertyCode'];

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    // ----------------------------------------------------------
    // Backward compatibility
    // ----------------------------------------------------------
    //
    // Existing properties created before propertyCode was added
    // do not have a propertyCode.
    //
    // We temporarily generate a readable code from the document
    // ID so old documents do not crash the application.
    //
    // New properties will always receive a proper sequential code.
    // ----------------------------------------------------------

    return 'PROP-${_legacyCodeFromDocumentId(documentId)}';
  }

  static String _legacyCodeFromDocumentId(
      String documentId,
      ) {
    final cleaned = documentId
        .replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '',
    )
        .toUpperCase();

    if (cleaned.length <= 8) {
      return cleaned.padLeft(
        8,
        '0',
      );
    }

    return cleaned.substring(
      0,
      8,
    );
  }

  // ============================================================
  // STRING READERS
  // ============================================================

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

    return value.trim();
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

  // ============================================================
  // NUMBER OF FLOORS
  // ============================================================

  static int _readNumberOfFloors(
      Map<String, dynamic> data,
      ) {
    final value = data['numberOfFloors'];

    // Backward compatibility:
    // old properties may not have this field yet.
    if (value == null) {
      return 1;
    }

    if (value is num) {
      final floors = value.toInt();

      if (floors < 1) {
        throw StateError(
          'Property field "numberOfFloors" must be at least 1.',
        );
      }

      return floors;
    }

    throw StateError(
      'Property field "numberOfFloors" is invalid.',
    );
  }

  // ============================================================
  // DATE
  // ============================================================

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

  // ============================================================
  // PROPERTY TYPE
  // ============================================================

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

  // ============================================================
  // PROPERTY STATUS
  // ============================================================

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