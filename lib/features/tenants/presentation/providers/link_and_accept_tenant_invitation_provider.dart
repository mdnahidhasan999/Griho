import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/link_and_accept_tenant_invitation.dart';
import 'tenant_invitation_provider.dart';

// ================================================================
// LINK AND ACCEPT TENANT INVITATION
// ================================================================

final linkAndAcceptTenantInvitationProvider =
Provider<LinkAndAcceptTenantInvitation>((ref) {
  return LinkAndAcceptTenantInvitation(
    invitationRepository: ref.read(
      tenantInvitationRepositoryProvider,
    ),
  );
});