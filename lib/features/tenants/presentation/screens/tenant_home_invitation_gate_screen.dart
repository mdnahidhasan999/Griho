import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/screens/tenant_home_screen.dart';
import '../providers/recipient_invitations_provider.dart';
import '../providers/tenant_dashboard_provider.dart';
import 'tenant_invitation_receive_screen.dart';

class TenantHomeInvitationGateScreen extends ConsumerWidget {
  const TenantHomeInvitationGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pendingAsync = ref.watch(recipientPendingInvitationsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: pendingAsync.when(
          loading: () =>
          const _GateLoadingView(message: 'Checking pending invitations...'),
          error: (e, s) => const TenantHomeScreen(),
          data: (pending) {
            if (pending.isNotEmpty) {
              return TenantInvitationReceiveScreen(
                  invitationToken: pending.first.token);
            }
            final tenantAsync = ref.watch(currentTenantProvider);
            return tenantAsync.when(
              loading: () =>
              const _GateLoadingView(message: 'Verifying residency records...'),
              error: (e, s) =>
                  _GateErrorView(
                    title: 'Unable to Load Profile',
                    message: e.toString(),
                    onRetry: () => ref.invalidate(currentTenantProvider),
                  ),
              data: (tenant) =>
              tenant == null
                  ? _GateEmptyProfileView(onRetry: () {
                ref.invalidate(currentTenantProvider);
                ref.invalidate(recipientInvitationsProvider);
              })
                  : const TenantHomeScreen(),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// GATE LOADING VIEW
// ============================================================================

class _GateLoadingView extends StatelessWidget {
  final String message;

  const _GateLoadingView({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.apartment_rounded,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GATE ERROR VIEW
// ============================================================================

class _GateErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _GateErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GATE EMPTY PROFILE VIEW
// ============================================================================

class _GateEmptyProfileView extends StatelessWidget {
  final VoidCallback onRetry;

  const _GateEmptyProfileView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_search_rounded,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Resident Profile Not Found',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We could not find an active resident profile linked to this account. If your property manager dispatched an invitation link, please open the link to join.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Check Again'),
            ),
          ],
        ),
      ),
    );
  }
}
