import '../entities/repositories/tenant_invitation_repository.dart';
import '../entities/tenant_invitation.dart';

class GetTenantInvitation {
  final TenantInvitationRepository _repository;

  const GetTenantInvitation({
    required this._repository,
  });

  Future<TenantInvitation?> call(
      String invitationId,
      ) {
    return _repository.getInvitationById(
      invitationId,
    );
  }
}