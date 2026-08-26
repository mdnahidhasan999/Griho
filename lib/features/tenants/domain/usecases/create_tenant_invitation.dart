import '../entities/repositories/tenant_invitation_repository.dart';
import '../entities/tenant_invitation.dart';

class CreateTenantInvitation {
  final TenantInvitationRepository _repository;

  const CreateTenantInvitation({
    required this._repository,
  });

  Future<TenantInvitation> call({
    required String tenantId,
    required String propertyId,
    required String unitId,
    required String phone,
  }) {
    return _repository.createInvitation(
      tenantId: tenantId,
      propertyId: propertyId,
      unitId: unitId,
      phone: phone,
    );
  }
}