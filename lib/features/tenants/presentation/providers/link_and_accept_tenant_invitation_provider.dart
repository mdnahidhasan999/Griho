import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/link_and_accept_tenant_invitation.dart';
import '../controllers/tenant_controller.dart';
import 'tenant_invitation_provider.dart';

// ================================================================
// LINK + ACCEPT TENANT INVITATION
// ================================================================

final linkAndAcceptTenantInvitationProvider =
Provider<LinkAndAcceptTenantInvitation>((ref) {
  return LinkAndAcceptTenantInvitation(
    tenantRepository: ref.read(
      tenantRepositoryProvider,
    ),
    invitationRepository: ref.read(
      tenantInvitationRepositoryProvider,
    ),
  );
});