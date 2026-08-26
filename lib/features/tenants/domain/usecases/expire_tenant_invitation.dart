import '../entities/repositories/tenant_invitation_repository.dart';

class ExpireTenantInvitation {
  final TenantInvitationRepository _repository;

  const ExpireTenantInvitation({
    required TenantInvitationRepository repository,
  }) : _repository = repository;

  Future<void> call(
      String invitationId,
      ) {
    return _repository.expireInvitation(
      invitationId,
    );
  }
}