import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/unit.dart';

class UnitModel extends Unit {
  const UnitModel({
    required super.id,
    required super.propertyId,
    required super.floorNumber,
    required super.unitNumber,
    super.name,
    required super.status,
    super.monthlyRent,
    super.tenantUserId,
    required super.createdAt,
    required super.updatedAt,
  });

  factory UnitModel.fromEntity(Unit unit) {
    return UnitModel(
      id: unit.id,
      propertyId: unit.propertyId,
      floorNumber: unit.floorNumber,
      unitNumber: unit.unitNumber,
      name: unit.name,
      status: unit.status,
      monthlyRent: unit.monthlyRent,
      tenantUserId: unit.tenantUserId,
      createdAt: unit.createdAt,
      updatedAt: unit.updatedAt,
    );
  }

  factory UnitModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Unit document ${document.id} contains no data.',
      );
    }

    return UnitModel(
      id: document.id,
      propertyId: _readRequiredString(
        data,
        'propertyId',
      ),
      floorNumber: _readRequiredInt(
        data,
        'floorNumber',
      ),
      unitNumber: _readRequiredString(
        data,
        'unitNumber',
      ),
      name: _readOptionalString(
        data,
        'name',
      ),
      status: _unitStatusFromString(
        _readRequiredString(
          data,
          'status',
        ),
      ),
      monthlyRent: _readOptionalDouble(
        data,
        'monthlyRent',
      ),
      tenantUserId: _readOptionalString(
        data,
        'tenantUserId',
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
      'propertyId': propertyId,
      'floorNumber': floorNumber,
      'unitNumber': unitNumber,
      'name': name,
      'status': status.name,
      'monthlyRent': monthlyRent,
      'tenantUserId': tenantUserId,
      'createdAt': Timestamp.fromDate(
        createdAt,
      ),
      'updatedAt': Timestamp.fromDate(
        updatedAt,
      ),
    };
  }

  static String _readRequiredString(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw StateError(
        'Unit field "$field" is missing or invalid.',
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
        'Unit field "$field" is invalid.',
      );
    }

    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  static int _readRequiredInt(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    throw StateError(
      'Unit field "$field" is missing or invalid.',
    );
  }

  static double? _readOptionalDouble(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    throw StateError(
      'Unit field "$field" is invalid.',
    );
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
      'Unit field "$field" is missing or invalid.',
    );
  }

  static UnitStatus _unitStatusFromString(
      String value,
      ) {
    return UnitStatus.values.firstWhere(
          (status) => status.name == value,
      orElse: () {
        throw StateError(
          'Unknown unit status: $value',
        );
      },
    );
  }
}