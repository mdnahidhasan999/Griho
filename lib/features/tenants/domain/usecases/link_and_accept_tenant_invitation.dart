import '../entities/repositories/tenant_invitation_repository.dart';

class LinkAndAcceptTenantInvitation {
  final TenantInvitationRepository _invitationRepository;

  const LinkAndAcceptTenantInvitation({
    required this._invitationRepository,
  });

  Future<void> call({
    required String invitationId,
  }) async {
    await _invitationRepository.acceptInvitation(
      invitationId,
    );
  }
}