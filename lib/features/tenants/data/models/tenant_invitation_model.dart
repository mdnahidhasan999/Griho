import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/tenant_invitation.dart';

class TenantInvitationModel extends TenantInvitation {
  const TenantInvitationModel({
    required super.id,
    required super.ownerId,
    required super.propertyId,
    required super.unitId,
    required super.rentAmount,
    required super.status,
    required super.token,
    required super.createdAt,
    required super.expiresAt,
    super.tenantId,
    super.phone,
    super.targetName,
    super.targetEmail,
    super.targetGrihoId,
    super.propertyName,
    super.propertyCode,
    super.unitNumber,
    super.unitName,
    super.acceptedAt,
    super.rejectedAt,
    super.cancelledAt,
    super.updatedAt,
  });

  /// Converts a domain entity into a Firestore model.
  factory TenantInvitationModel.fromEntity(TenantInvitation entity) {
    return TenantInvitationModel(
      id: entity.id,
      ownerId: entity.ownerId,
      tenantId: entity.tenantId,
      propertyId: entity.propertyId,
      unitId: entity.unitId,
      phone: entity.phone,
      targetName: entity.targetName,
      targetEmail: entity.targetEmail,
      targetGrihoId: entity.targetGrihoId,
      propertyName: entity.propertyName,
      propertyCode: entity.propertyCode,
      unitNumber: entity.unitNumber,
      unitName: entity.unitName,
      rentAmount: entity.rentAmount,
      status: entity.status,
      token: entity.token,
      createdAt: entity.createdAt,
      expiresAt: entity.expiresAt,
      acceptedAt: entity.acceptedAt,
      rejectedAt: entity.rejectedAt,
      cancelledAt: entity.cancelledAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Creates a model from a Firestore document.
  factory TenantInvitationModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,) {
    final data = snapshot.data();

    if (data == null) {
      throw StateError(
        'Tenant invitation document "${snapshot.id}" has no data.',
      );
    }

    return TenantInvitationModel.fromMap(
      data,
      id: snapshot.id,
    );
  }

  /// Creates a model from a map.
  ///
  /// The document ID is passed separately because Firestore document
  /// IDs are not necessarily stored inside the document data.
  factory TenantInvitationModel.fromMap(Map<String, dynamic> map, {
    String? id,
  }) {
    final resolvedId = _readString(map, 'id', fallback: id);

    if (resolvedId == null || resolvedId.isEmpty) {
      throw const FormatException(
        'Tenant invitation is missing its document ID.',
      );
    }

    final ownerId = _readString(map, 'ownerId');
    final propertyId = _readString(map, 'propertyId');
    final unitId = _readString(map, 'unitId');
    final token = _readString(map, 'token');

    if (ownerId == null ||
        propertyId == null ||
        unitId == null ||
        token == null) {
      throw FormatException(
        'Tenant invitation "$resolvedId" is missing a required field.',
      );
    }

    return TenantInvitationModel(
      id: resolvedId,
      ownerId: ownerId,
      tenantId: _readOptionalString(map, 'tenantId'),
      propertyId: propertyId,
      unitId: unitId,
      phone: _readOptionalString(map, 'phone'),
      targetName: _readOptionalString(map, 'targetName'),
      targetEmail: _readOptionalString(map, 'targetEmail'),
      targetGrihoId: _readOptionalString(map, 'targetGrihoId'),
      propertyName: _readOptionalString(
        map,
        'propertyName',
        fallbackKey: 'name',
      ),
      propertyCode: _readOptionalString(map, 'propertyCode'),
      unitNumber: _readOptionalString(map, 'unitNumber'),
      unitName: _readOptionalString(map, 'unitName'),
      rentAmount: _readDouble(map, 'rentAmount'),
      status: _parseStatus(map['status']),
      token: token,
      createdAt: _readDateTime(map, 'createdAt'),
      expiresAt: _readDateTime(map, 'expiresAt'),
      acceptedAt: _readOptionalDateTime(map, 'acceptedAt'),
      rejectedAt: _readOptionalDateTime(map, 'rejectedAt'),
      cancelledAt: _readOptionalDateTime(map, 'cancelledAt'),
      updatedAt: _readOptionalDateTime(map, 'updatedAt'),
    );
  }

  /// Converts this model into a Firestore-compatible map.
  ///
  /// The document ID is managed by Firestore and is not written
  /// into the document fields.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'ownerId': ownerId,
      'tenantId': tenantId,
      'propertyId': propertyId,
      'unitId': unitId,
      'phone': phone,
      'targetName': targetName,
      'targetEmail': targetEmail,
      'targetGrihoId': targetGrihoId,
      'propertyName': propertyName,
      'propertyCode': propertyCode,
      'unitNumber': unitNumber,
      'unitName': unitName,
      'rentAmount': rentAmount,
      'status': status.name,
      'token': token,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'acceptedAt': _toTimestamp(acceptedAt),
      'rejectedAt': _toTimestamp(rejectedAt),
      'cancelledAt': _toTimestamp(cancelledAt),
      'updatedAt': _toTimestamp(updatedAt),
    };
  }

  /// Converts this model into a Firestore map with server timestamps
  /// for fields that should be updated by the server.
  ///
  /// Use this only when creating/updating a document where server
  /// timestamps are appropriate. Do not use it to preserve historical
  /// timestamps when copying an existing document.
  Map<String, dynamic> toMapWithServerTimestamps({
    bool setCreatedAt = false,
    bool setUpdatedAt = true,
  }) {
    final data = toMap();

    if (setCreatedAt) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    if (setUpdatedAt) {
      data['updatedAt'] = FieldValue.serverTimestamp();
    }

    return data;
  }

  static String? _readString(Map<String, dynamic> map,
      String key, {
        String? fallback,
      }) {
    final value = map[key];

    if (value is String && value
        .trim()
        .isNotEmpty) {
      return value.trim();
    }

    if (fallback != null &&
        fallback
            .trim()
            .isNotEmpty &&
        value == null) {
      return fallback.trim();
    }

    return null;
  }

  static String? _readOptionalString(Map<String, dynamic> map,
      String key, {
        String? fallbackKey,
      }) {
    final value = map[key];

    if (value is String && value
        .trim()
        .isNotEmpty) {
      return value.trim();
    }

    if (fallbackKey != null) {
      final fallbackValue = map[fallbackKey];

      if (fallbackValue is String && fallbackValue
          .trim()
          .isNotEmpty) {
        return fallbackValue.trim();
      }
    }

    return null;
  }

  static double _readDouble(Map<String, dynamic> map,
      String key,) {
    final value = map[key];

    if (value is num && value.isFinite) {
      return value.toDouble();
    }

    throw FormatException(
      'Tenant invitation has an invalid "$key" value.',
    );
  }

  static DateTime _readDateTime(Map<String, dynamic> map,
      String key,) {
    final value = map[key];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }

    throw FormatException(
      'Tenant invitation has an invalid "$key" timestamp.',
    );
  }

  static DateTime? _readOptionalDateTime(Map<String, dynamic> map,
      String key,) {
    final value = map[key];

    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static Timestamp? _toTimestamp(DateTime? value) {
    if (value == null) return null;
    return Timestamp.fromDate(value);
  }

  static TenantInvitationStatus _parseStatus(dynamic value) {
    if (value is TenantInvitationStatus) {
      return value;
    }

    if (value is String) {
      for (final status in TenantInvitationStatus.values) {
        if (status.name == value) {
          return status;
        }
      }
    }

    return TenantInvitationStatus.pending;
  }
}