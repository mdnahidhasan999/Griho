import '../entities/repositories/tenant_invitation_repository.dart';

class AcceptTenantInvitation {
  final TenantInvitationRepository _repository;

  const AcceptTenantInvitation({
    required TenantInvitationRepository repository,
  }) : _repository = repository;

  Future<void> call(
      String invitationId,
      ) {
    return _repository.acceptInvitation(
      invitationId,
    );
  }
}