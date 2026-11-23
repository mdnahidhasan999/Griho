// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../home/presentation/screens/tenant_home_screen.dart';
import '../providers/recipient_invitations_provider.dart';
import '../providers/tenant_dashboard_provider.dart';
import 'tenant_invitation_receive_screen.dart';

class TenantHomeInvitationGateScreen extends ConsumerWidget {
  const TenantHomeInvitationGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(recipientPendingInvitationsProvider);

    return pendingAsync.when(
      loading: () => const _GateScaffold(
        child: GrihoLoadingView(message: 'Checking pending invitations...'),
      ),
      error: (e, _) => _GateScaffold(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to Check Invitations',
              subtitle: e.toString(),
              actionLabel: 'Try Again',
              onAction: () => ref.invalidate(recipientInvitationsProvider),
            ),
          ),
        ),
      ),
      data: (pending) {
        if (pending.isNotEmpty) {
          return TenantInvitationReceiveScreen(
            invitationToken: pending.first.token,
          );
        }

        final tenantAsync = ref.watch(currentTenantProvider);
        return tenantAsync.when(
          loading: () => const _GateScaffold(
            child: GrihoLoadingView(message: 'Verifying residency records...'),
          ),
          error: (e, _) => _GateScaffold(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: GrihoStatusState(
                  icon: Iconsax.warning_2,
                  title: 'Unable to Load Profile',
                  subtitle: e.toString(),
                  actionLabel: 'Try Again',
                  onAction: () => ref.invalidate(currentTenantProvider),
                ),
              ),
            ),
          ),
          data: (tenant) => tenant == null
              ? _GateScaffold(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: GrihoStatusState(
                        icon: Iconsax.user_search,
                        title: 'Resident Profile Not Found',
                        subtitle:
                            'We could not find an active resident profile linked to this account. If your property manager dispatched an invitation link, please open the link to join.',
                        actionLabel: 'Check Again',
                        onAction: () {
                          ref.invalidate(currentTenantProvider);
                          ref.invalidate(recipientInvitationsProvider);
                        },
                      ),
                    ),
                  ),
                )
              : const TenantHomeScreen(),
        );
      },
    );
  }
}

class _GateScaffold extends StatelessWidget {
  final Widget child;

  const _GateScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(child: child),
    );
  }
}
