import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/screens/tenant_home_screen.dart';
import '../providers/current_tenant_pending_invitation_provider.dart';
import 'tenant_invitation_receive_screen.dart';

class TenantHomeInvitationGateScreen extends ConsumerWidget {
  const TenantHomeInvitationGateScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationAsync = ref.watch(
      currentTenantPendingInvitationProvider,
    );

    return invitationAsync.when(
      // ==========================================================
      // LOADING
      // ==========================================================

      loading: () {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },

      // ==========================================================
      // ERROR
      // ==========================================================

      error: (error, stackTrace) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 52,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to load your invitation.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ref.invalidate(
                        currentTenantPendingInvitationProvider,
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        );
      },

      // ==========================================================
      // DATA
      // ==========================================================

      data: (invitation) {
        // --------------------------------------------------------
        // NO PENDING INVITATION
        // --------------------------------------------------------

        if (invitation == null) {
          return const TenantHomeScreen();
        }

        // --------------------------------------------------------
        // PENDING INVITATION FOUND
        // --------------------------------------------------------
        //
        // Do NOT load:
        // - tenantAccess
        // - currentTenant
        // - unit
        // - property
        //
        // The existing invitation receive screen will handle:
        // - invitation details
        // - validation
        // - accept
        // - decline
        //

        return TenantInvitationReceiveScreen(
          invitationId: invitation.id,
        );
      },
    );
  }
}