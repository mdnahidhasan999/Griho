import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/tenant.dart';

class TenantModel extends Tenant {
  const TenantModel({
    required super.id,
    required super.ownerId,
    super.userId,
    required super.propertyId,
    required super.unitId,
    required super.name,
    required super.phone,
    super.email,
    super.nidNumber,
    required super.status,
    required super.accountStatus,
    required super.confirmationStatus,
    required super.createdAt,
    required super.updatedAt,
  });

  // ==========================================================================
  // FROM ENTITY
  // ==========================================================================

  factory TenantModel.fromEntity(Tenant tenant) {
    return TenantModel(
      id: tenant.id,
      ownerId: tenant.ownerId,
      userId: tenant.userId,
      propertyId: tenant.propertyId,
      unitId: tenant.unitId,
      name: tenant.name,
      phone: tenant.phone,
      email: tenant.email,
      nidNumber: tenant.nidNumber,
      status: tenant.status,
      accountStatus: tenant.accountStatus,
      confirmationStatus: tenant.confirmationStatus,
      createdAt: tenant.createdAt,
      updatedAt: tenant.updatedAt,
    );
  }

  // ==========================================================================
  // FROM FIRESTORE
  // ==========================================================================

  factory TenantModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Tenant document ${document.id} contains no data.');
    }

    return TenantModel(
      id: document.id,

      ownerId: _readRequiredString(data, 'ownerId'),

      userId: _readOptionalString(data, 'userId'),

      propertyId: _readRequiredString(data, 'propertyId'),

      unitId: _readRequiredString(data, 'unitId'),

      name: _readRequiredString(data, 'name'),

      phone: _readRequiredString(data, 'phone'),

      email: _readOptionalString(data, 'email'),

      nidNumber: _readOptionalString(data, 'nidNumber'),

      status: _readTenantStatus(data),

      accountStatus: _readAccountStatus(data),

      confirmationStatus: _readConfirmationStatus(data),

      createdAt: _readDateTime(data, 'createdAt'),

      updatedAt: _readDateTime(data, 'updatedAt'),
    );
  }

  // ==========================================================================
  // TO FIRESTORE
  // ==========================================================================

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'userId': userId,
      'propertyId': propertyId,
      'unitId': unitId,
      'name': name,
      'phone': phone,
      'email': email,
      'nidNumber': nidNumber,
      'status': status.name,
      'accountStatus': accountStatus.name,
      'confirmationStatus': confirmationStatus.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // ==========================================================================
  // TENANT STATUS
  // ==========================================================================

  static TenantStatus _readTenantStatus(Map<String, dynamic> data) {
    final value = data['status'];

    if (value is String) {
      return TenantStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => TenantStatus.active,
      );
    }

    return TenantStatus.active;
  }

  // ==========================================================================
  // ACCOUNT STATUS
  // ==========================================================================

  static TenantAccountStatus _readAccountStatus(Map<String, dynamic> data) {
    final value = data['accountStatus'];

    if (value is String) {
      final parsed = TenantAccountStatus.values.where(
        (status) => status.name == value,
      );

      if (parsed.isNotEmpty) {
        return parsed.first;
      }
    }

    return _accountStatusFromUserId(data);
  }

  // ==========================================================================
  // ACCOUNT STATUS FROM USER ID
  // ==========================================================================

  static TenantAccountStatus _accountStatusFromUserId(
    Map<String, dynamic> data,
  ) {
    final userId = data['userId'];

    if (userId is String && userId.trim().isNotEmpty) {
      return TenantAccountStatus.registered;
    }

    return TenantAccountStatus.notRegistered;
  }

  // ==========================================================================
  // CONFIRMATION STATUS
  // ==========================================================================

  static TenantConfirmationStatus _readConfirmationStatus(
    Map<String, dynamic> data,
  ) {
    final value = data['confirmationStatus'];

    if (value is String) {
      final parsed = TenantConfirmationStatus.values.where(
        (status) => status.name == value,
      );

      if (parsed.isNotEmpty) {
        return parsed.first;
      }
    }

    return TenantConfirmationStatus.pending;
  }

  // ==========================================================================
  // REQUIRED STRING
  // ==========================================================================

  static String _readRequiredString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw StateError('Tenant field "$field" is missing or invalid.');
    }

    return value.trim();
  }

  // ==========================================================================
  // OPTIONAL STRING
  // ==========================================================================

  static String? _readOptionalString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw StateError('Tenant field "$field" is invalid.');
    }

    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  // ==========================================================================
  // DATE TIME
  // ==========================================================================

  static DateTime _readDateTime(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);

      if (parsed != null) {
        return parsed;
      }
    }

    throw StateError('Tenant field "$field" is missing or invalid.');
  }
}
