import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../tenants/domain/entities/tenancy_history.dart';

class TenancyHistoryModel extends TenancyHistory {
  const TenancyHistoryModel({
    required super.id,
    required super.tenantId,
    required super.tenantUserId,
    required super.ownerId,
    required super.propertyId,
    required super.tenantName,
    required super.propertyName,
    required super.propertyCode,
    required super.propertyAddress,
    required super.unitId,
    required super.unitNumber,
    required super.unitName,
    required super.floorNumber,
    required super.monthlyRent,
    required super.startedAt,
    required super.endedAt,
    required super.status,
    required super.createdAt,
  });

  factory TenancyHistoryModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,) {
    final data = snapshot.data();

    if (data == null) {
      throw StateError(
        'Tenancy history document is empty: ${snapshot.id}',
      );
    }

    return TenancyHistoryModel(
      id: snapshot.id,
      tenantId: _readRequiredString(data, 'tenantId'),
      tenantUserId: _readOptionalString(
        data,
        'tenantUserId',
      ),
      ownerId: _readRequiredString(
        data,
        'ownerId',
      ),
      propertyId: _readRequiredString(
        data,
        'propertyId',
      ),
      tenantName: _readRequiredString(
        data,
        'tenantName',
      ),
      propertyName: _readRequiredString(
        data,
        'propertyName',
      ),
      propertyCode: _readRequiredString(
        data,
        'propertyCode',
      ),
      propertyAddress: _readOptionalString(
        data,
        'propertyAddress',
      ),
      unitId: _readRequiredString(
        data,
        'unitId',
      ),
      unitNumber: _readRequiredString(
        data,
        'unitNumber',
      ),
      unitName: _readOptionalString(
        data,
        'unitName',
      ),
      floorNumber: _readRequiredInt(
        data,
        'floorNumber',
      ),
      monthlyRent: _readOptionalDouble(
        data,
        'monthlyRent',
      ),
      startedAt: _readRequiredDateTime(
        data,
        'startedAt',
      ),
      endedAt: _readRequiredDateTime(
        data,
        'endedAt',
      ),
      status: _readStatus(
        data['status'],
      ),
      createdAt: _readRequiredDateTime(
        data,
        'createdAt',
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tenantId': tenantId,
      'tenantUserId': tenantUserId,
      'ownerId': ownerId,
      'propertyId': propertyId,
      'tenantName': tenantName,
      'propertyName': propertyName,
      'propertyCode': propertyCode,
      'propertyAddress': propertyAddress,
      'unitId': unitId,
      'unitNumber': unitNumber,
      'unitName': unitName,
      'floorNumber': floorNumber,
      'monthlyRent': monthlyRent,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': Timestamp.fromDate(endedAt),
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static String _readRequiredString(Map<String, dynamic> data,
      String field,) {
    final value = data[field];

    if (value is! String || value
        .trim()
        .isEmpty) {
      throw StateError(
        'Invalid or missing "$field" in tenancy history.',
      );
    }

    return value.trim();
  }

  static String? _readOptionalString(Map<String, dynamic> data,
      String field,) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw StateError(
        'Invalid "$field" in tenancy history.',
      );
    }

    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  static int _readRequiredInt(Map<String, dynamic> data,
      String field,) {
    final value = data[field];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    throw StateError(
      'Invalid or missing "$field" in tenancy history.',
    );
  }

  static double? _readOptionalDouble(Map<String, dynamic> data,
      String field,) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    throw StateError(
      'Invalid "$field" in tenancy history.',
    );
  }

  static DateTime _readRequiredDateTime(Map<String, dynamic> data,
      String field,) {
    final value = data[field];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    throw StateError(
      'Invalid or missing "$field" in tenancy history.',
    );
  }

  static TenancyHistoryStatus _readStatus(dynamic value,) {
    if (value == 'ended') {
      return TenancyHistoryStatus.ended;
    }

    throw StateError(
      'Invalid tenancy history status.',
    );
  }
}