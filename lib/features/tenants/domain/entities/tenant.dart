// ============================================================
// TENANT STATUS
// ============================================================

enum TenantStatus {
  active,
  inactive,
}

// ============================================================
// TENANT ACCOUNT STATUS
//
// Indicates whether this tenant has linked their Griho
// account with the tenant record.
// ============================================================

enum TenantAccountStatus {
  notRegistered,
  registered,
}

// ============================================================
// TENANT CONFIRMATION STATUS
//
// Indicates whether the tenant has confirmed the tenancy.
// ============================================================

enum TenantConfirmationStatus {
  pending,
  confirmed,
  rejected,
}

// ============================================================
// TENANT ENTITY
// ============================================================

class Tenant {
  final String id;

  // Tenant-এর property owner-এর Firebase Auth UID
  final String ownerId;

  // Tenant-এর নিজের Griho account থাকলে Firebase Auth UID
  final String? userId;

  final String propertyId;
  final String unitId;

  final String name;
  final String phone;
  final String? email;
  final String? nidNumber;

  // Tenant বর্তমানে unit-এ active/inactive কি না
  final TenantStatus status;

  // Tenant-এর Griho account registration/linking status
  final TenantAccountStatus accountStatus;

  // Tenant tenancy confirm করেছে কি না
  final TenantConfirmationStatus confirmationStatus;

  // বর্তমান tenancy কবে শুরু হয়েছে
  //
  // Existing tenant records-এ এই field না থাকলে null হবে।
  final DateTime? tenancyStartedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Tenant({
    required this.id,
    required this.ownerId,
    this.userId,
    required this.propertyId,
    required this.unitId,
    required this.name,
    required this.phone,
    this.email,
    this.nidNumber,
    required this.status,
    required this.accountStatus,
    required this.confirmationStatus,
    this.tenancyStartedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  // ============================================================
  // COPY WITH
  // ============================================================

  Tenant copyWith({
    String? id,
    String? ownerId,
    String? userId,
    String? propertyId,
    String? unitId,
    String? name,
    String? phone,

    // Nullable fields
    Object? email = _keep,
    Object? nidNumber = _keep,
    Object? tenancyStartedAt = _keep,

    TenantStatus? status,
    TenantAccountStatus? accountStatus,
    TenantConfirmationStatus? confirmationStatus,

    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tenant(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      userId: userId ?? this.userId,

      propertyId: propertyId ?? this.propertyId,
      unitId: unitId ?? this.unitId,

      name: name ?? this.name,
      phone: phone ?? this.phone,

      email: email == _keep
          ? this.email
          : email as String?,

      nidNumber: nidNumber == _keep
          ? this.nidNumber
          : nidNumber as String?,

      status: status ?? this.status,

      accountStatus:
      accountStatus ?? this.accountStatus,

      confirmationStatus:
      confirmationStatus ?? this.confirmationStatus,

      tenancyStartedAt: tenancyStartedAt == _keep
          ? this.tenancyStartedAt
          : tenancyStartedAt as DateTime?,

      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const Object _keep = Object();
}