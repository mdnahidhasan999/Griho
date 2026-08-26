import 'tenant.dart';

class CreateTenantRequest {
  final String? userId;

  final String propertyId;
  final String unitId;

  final String name;
  final String phone;
  final String? email;
  final String? nidNumber;

  final TenantStatus status;

  const CreateTenantRequest({
    this.userId,

    required this.propertyId,
    required this.unitId,

    required this.name,
    required this.phone,

    this.email,
    this.nidNumber,

    this.status = TenantStatus.active,
  });

  // ============================================================
  // COPY WITH
  // ============================================================

  CreateTenantRequest copyWith({
    Object? userId = _keep,

    String? propertyId,
    String? unitId,

    String? name,
    String? phone,

    Object? email = _keep,
    Object? nidNumber = _keep,

    TenantStatus? status,
  }) {
    return CreateTenantRequest(
      userId: userId == _keep ? this.userId : userId as String?,

      propertyId: propertyId ?? this.propertyId,
      unitId: unitId ?? this.unitId,

      name: name ?? this.name,
      phone: phone ?? this.phone,

      email: email == _keep ? this.email : email as String?,

      nidNumber: nidNumber == _keep ? this.nidNumber : nidNumber as String?,

      status: status ?? this.status,
    );
  }

  static const Object _keep = Object();
}
