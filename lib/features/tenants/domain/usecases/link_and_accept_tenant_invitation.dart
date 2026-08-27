import '../entities/repositories/tenant_repository.dart';
import '../entities/repositories/tenant_invitation_repository.dart';
import '../entities/tenant.dart';

class LinkAndAcceptTenantInvitation {
  final TenantRepository _tenantRepository;
  final TenantInvitationRepository _invitationRepository;

  const LinkAndAcceptTenantInvitation({
    required this._tenantRepository,
    required this._invitationRepository,
  });

  Future<Tenant> call({
    required String tenantId,
    required String userId,
    required String invitationId,
  }) async {
    // ----------------------------------------------------------
    // LINK FIREBASE ACCOUNT TO TENANT
    // ----------------------------------------------------------

    final tenant = await _tenantRepository.linkTenantAccount(
      tenantId: tenantId,
      userId: userId,
    );

    // ----------------------------------------------------------
    // ACCEPT INVITATION
    // ----------------------------------------------------------
    //
    // IMPORTANT:
    // acceptInvitation() নিজেই Firebase currentUser
    // যাচাই করবে।
    //
    // ----------------------------------------------------------

    await _invitationRepository.acceptInvitation(
      invitationId,
    );

    return tenant;
  }
}