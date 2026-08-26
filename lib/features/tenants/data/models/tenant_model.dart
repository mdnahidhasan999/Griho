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

  // ============================================================
  // FROM ENTITY
  // ============================================================

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

  // ============================================================
  // FROM FIRESTORE
  // ============================================================

  factory TenantModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Tenant document ${document.id} contains no data.',
      );
    }

    return TenantModel(
      id: document.id,

      // --------------------------------------------------------
      // OWNER
      // --------------------------------------------------------

      ownerId: _readRequiredString(
        data,
        'ownerId',
      ),

      // --------------------------------------------------------
      // USER ACCOUNT
      // --------------------------------------------------------

      userId: _readOptionalString(
        data,
        'userId',
      ),

      // --------------------------------------------------------
      // PROPERTY / UNIT
      // --------------------------------------------------------

      propertyId: _readRequiredString(
        data,
        'propertyId',
      ),

      unitId: _readRequiredString(
        data,
        'unitId',
      ),

      // --------------------------------------------------------
      // PERSONAL INFORMATION
      // --------------------------------------------------------

      name: _readRequiredString(
        data,
        'name',
      ),

      phone: _readRequiredString(
        data,
        'phone',
      ),

      email: _readOptionalString(
        data,
        'email',
      ),

      nidNumber: _readOptionalString(
        data,
        'nidNumber',
      ),

      // --------------------------------------------------------
      // TENANCY STATUS
      // --------------------------------------------------------

      status: TenantStatus.values.firstWhere(
            (status) => status.name == data['status'],
        orElse: () => TenantStatus.active,
      ),

      // --------------------------------------------------------
      // ACCOUNT STATUS
      //
      // Old documents may not have this field.
      // In that case we safely derive it from userId.
      // --------------------------------------------------------

      accountStatus: _readAccountStatus(
        data,
      ),

      // --------------------------------------------------------
      // CONFIRMATION STATUS
      //
      // Old tenant documents do not have this field.
      // They will therefore default to pending.
      // --------------------------------------------------------

      confirmationStatus: TenantConfirmationStatus.values.firstWhere(
            (status) => status.name == data['confirmationStatus'],
        orElse: () => TenantConfirmationStatus.pending,
      ),

      // --------------------------------------------------------
      // DATES
      // --------------------------------------------------------

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

  // ============================================================
  // TO FIRESTORE
  // ============================================================

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,

      // Tenant's Firebase Auth UID
      'userId': userId,

      'propertyId': propertyId,
      'unitId': unitId,

      'name': name,
      'phone': phone,
      'email': email,
      'nidNumber': nidNumber,

      // Tenant active/inactive
      'status': status.name,

      // Tenant account registration status
      'accountStatus': accountStatus.name,

      // Tenant tenancy confirmation status
      'confirmationStatus': confirmationStatus.name,

      'createdAt': Timestamp.fromDate(
        createdAt,
      ),

      'updatedAt': Timestamp.fromDate(
        updatedAt,
      ),
    };
  }

  // ============================================================
  // READ ACCOUNT STATUS
  // ============================================================

  static TenantAccountStatus _readAccountStatus(
      Map<String, dynamic> data,
      ) {
    final value = data['accountStatus'];

    // ----------------------------------------------------------
    // NEW DATA
    // ----------------------------------------------------------

    if (value is String) {
      return TenantAccountStatus.values.firstWhere(
            (status) => status.name == value,
        orElse: () {
          // If accountStatus is invalid, derive from userId.
          return _accountStatusFromUserId(data);
        },
      );
    }

    // ----------------------------------------------------------
    // OLD DATA
    // ----------------------------------------------------------

    return _accountStatusFromUserId(data);
  }

  // ============================================================
  // ACCOUNT STATUS FROM USER ID
  // ============================================================

  static TenantAccountStatus _accountStatusFromUserId(
      Map<String, dynamic> data,
      ) {
    final userId = data['userId'];

    if (userId is String && userId.trim().isNotEmpty) {
      return TenantAccountStatus.registered;
    }

    return TenantAccountStatus.notRegistered;
  }

  // ============================================================
  // REQUIRED STRING
  // ============================================================

  static String _readRequiredString(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw StateError(
        'Tenant field "$field" is missing or invalid.',
      );
    }

    return value;
  }

  // ============================================================
  // OPTIONAL STRING
  // ============================================================

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
        'Tenant field "$field" is invalid.',
      );
    }

    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  // ============================================================
  // DATE TIME
  // ============================================================

  static DateTime _readDateTime(
      Map<String, dynamic> data,
      String field,
      ) {
    final value = data[field];

    if (value is Timestamp) {
      return value.toDate();
    }

    throw StateError(
      'Tenant field "$field" is missing or invalid.',
    );
  }
}