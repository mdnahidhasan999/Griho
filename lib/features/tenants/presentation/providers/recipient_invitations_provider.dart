import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:griho/features/tenants/domain/entities/tenant_invitation.dart';
import 'package:griho/features/tenants/presentation/providers/tenant_invitation_provider.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

final recipientInvitationsProvider =
StreamProvider<List>((ref) {
  final authUser = FirebaseAuth.instance.currentUser;

// Do not expose recipient invitations before email verification.
  if (authUser == null || !authUser.emailVerified) {
    return Stream.value(const []);
  }

  final profileAsync = ref.watch(currentUserProfileProvider);

  return profileAsync.when(
    loading: () => const Stream<List>.empty(),
    error: (error, stackTrace) =>
    Stream<List>.error(error, stackTrace),
    data: (profile) {
      if (profile == null) {
        return Stream.value(const []);
      }

      return ref
          .watch(tenantInvitationDataSourceProvider)
          .watchInvitationsForRecipient(
        phone: profile.phoneNumber,
        email: authUser.email,
        grihoId: profile.publicId,
      )
          .map(
            (invitations) =>
            invitations.where((invitation) {
              return invitation.status ==
                  TenantInvitationStatus.pending ||
                  invitation.status == TenantInvitationStatus.accepted ||
                  invitation.status == TenantInvitationStatus.rejected ||
                  invitation.status == TenantInvitationStatus.cancelled;
            }).toList(),
      );
    },

  );
});

/// Only pending invitations that have not expired.
final recipientPendingInvitationsProvider =
Provider<AsyncValue<List>>((ref) {
  return ref.watch(recipientInvitationsProvider).whenData(
        (items) =>
        items
            .where(
              (invitation) =>
          invitation.status == TenantInvitationStatus.pending &&
              !invitation.isExpired,
        )
            .toList(),
  );
});