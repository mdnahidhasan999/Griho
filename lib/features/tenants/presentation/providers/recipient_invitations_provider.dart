// noinspection SpellCheckingInspection
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/tenant_invitation.dart';
import 'tenant_invitation_provider.dart';

final recipientInvitationsProvider = StreamProvider<List<TenantInvitation>>((
  ref,
) {
  ref.watch(authStateProvider);
  final authUser = FirebaseAuth.instance.currentUser;

  // Do not expose recipient invitations before email verification.
  if (authUser == null || !authUser.emailVerified) {
    return Stream.value(const <TenantInvitation>[]);
  }

  final profileAsync = ref.watch(currentUserProfileProvider);

  return profileAsync.when(
    loading: () => const Stream<List<TenantInvitation>>.empty(),
    error: (error, stackTrace) =>
        Stream<List<TenantInvitation>>.error(error, stackTrace),
    data: (profile) {
      if (profile == null) {
        return Stream.value(const <TenantInvitation>[]);
      }

      return ref
          .watch(tenantInvitationDataSourceProvider)
          .watchInvitationsForRecipient(
            phone: profile.phoneNumber,
            email: authUser.email,
            grihoId: profile.publicId,
          )
          .map(
            (invitations) => invitations.where((invitation) {
              return invitation.status == TenantInvitationStatus.pending ||
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
    Provider<AsyncValue<List<TenantInvitation>>>((ref) {
      return ref
          .watch(recipientInvitationsProvider)
          .whenData(
            (items) => items
                .where(
                  (invitation) =>
                      invitation.status == TenantInvitationStatus.pending &&
                      !invitation.isExpired,
                )
                .toList(),
          );
    });
