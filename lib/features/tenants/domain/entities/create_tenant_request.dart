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
}