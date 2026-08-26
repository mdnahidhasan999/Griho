import '../entities/repositories/tenant_invitation_repository.dart';

class CancelTenantInvitation {
  final TenantInvitationRepository _repository;

  const CancelTenantInvitation({
    required TenantInvitationRepository repository,
  }) : _repository = repository;

  Future<void> call(
      String invitationId,
      ) {
    return _repository.cancelInvitation(
      invitationId,
    );
  }
}