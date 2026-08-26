import '../entities/repositories/tenant_invitation_repository.dart';
import '../entities/tenant_invitation.dart';

class GetPendingTenantInvitation {
  final TenantInvitationRepository _repository;

  const GetPendingTenantInvitation({
    required this._repository,
  });

  Future<TenantInvitation?> call(
      String tenantId,
      ) {
    return _repository.getPendingInvitationByTenantId(
      tenantId,
    );
  }
}