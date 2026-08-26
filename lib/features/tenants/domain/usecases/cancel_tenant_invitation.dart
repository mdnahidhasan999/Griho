import '../entities/repositories/tenant_invitation_repository.dart';

class CancelTenantInvitation {
  final TenantInvitationRepository _repository;

  const CancelTenantInvitation({
    required this._repository,
  });

  Future<void> call(
      String invitationId,
      ) {
    return _repository.cancelInvitation(
      invitationId,
    );
  }
}