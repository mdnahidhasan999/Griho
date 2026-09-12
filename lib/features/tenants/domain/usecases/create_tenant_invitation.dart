import '../entities/repositories/tenant_invitation_repository.dart';
import '../entities/tenant_invitation.dart';

class CreateTenantInvitation {
  final TenantInvitationRepository repository;

  const CreateTenantInvitation({required this.repository});

  Future<TenantInvitation> call({
    required String tenantId,
    required String propertyId,
    required String unitId,
    required String phone,
    required double rentAmount,
  }) async {
    final normalizedTenantId = tenantId.trim();
    final normalizedPropertyId = propertyId.trim();
    final normalizedUnitId = unitId.trim();
    final normalizedPhone = phone.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError('Tenant ID cannot be empty.');
    }

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }

    if (normalizedPhone.isEmpty) {
      throw ArgumentError('Phone number cannot be empty.');
    }

    if (rentAmount <= 0) {
      throw ArgumentError('Monthly rent must be greater than zero.');
    }

    return repository.createInvitation(
      tenantId: normalizedTenantId,
      propertyId: normalizedPropertyId,
      unitId: normalizedUnitId,
      phone: normalizedPhone,
      rentAmount: rentAmount,
    );
  }
}
