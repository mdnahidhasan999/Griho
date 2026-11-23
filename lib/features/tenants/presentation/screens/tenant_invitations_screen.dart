// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/tenant_invitation.dart';
import '../providers/recipient_invitations_provider.dart';
import '../widgets/tenant_ui_helpers.dart';
import 'tenant_invitation_receive_screen.dart';

class TenantInvitationsScreen extends ConsumerWidget {
  const TenantInvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Tenancy Invitations')),
      body: const SafeArea(child: _InvitationList()),
    );
  }
}

class _InvitationList extends ConsumerWidget {
  const _InvitationList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(recipientInvitationsProvider);

    return invitationsAsync.when(
      loading: () => const GrihoLoadingView(message: 'Loading invitations...'),
      error: (_, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GrihoStatusState(
            icon: Iconsax.warning_2,
            title: 'Unable to load invitations',
            subtitle: 'Please check your connection and try again.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(recipientInvitationsProvider),
          ),
        ),
      ),
      data: (invitations) {
        if (invitations.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(recipientInvitationsProvider);
              await ref.read(recipientInvitationsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 60),
                GrihoStatusState(
                  icon: Iconsax.sms,
                  title: 'No Invitations Yet',
                  subtitle:
                      'You do not have any tenancy invitations. When a property manager invites you, it will appear here.',
                ),
              ],
            ),
          );
        }

        final sorted = List<TenantInvitation>.from(invitations)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final pendingInvitations = sorted
            .where(
              (inv) =>
                  inv.status == TenantInvitationStatus.pending &&
                  !inv.isExpired,
            )
            .toList();

        final historicalInvitations = sorted
            .where(
              (inv) =>
                  inv.status != TenantInvitationStatus.pending || inv.isExpired,
            )
            .toList();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recipientInvitationsProvider);
            await ref.read(recipientInvitationsProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              _InvitationsOverviewCard(
                totalCount: sorted.length,
                pendingCount: pendingInvitations.length,
                resolvedCount: historicalInvitations.length,
              ),
              const SizedBox(height: 20),
              if (pendingInvitations.isNotEmpty) ...[
                TenantSectionHeader(
                  title: 'Action Required',
                  count: pendingInvitations.length,
                  icon: Iconsax.clock,
                  color: GrihoColors.warning,
                ),
                const SizedBox(height: 10),
                for (final invitation in pendingInvitations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PendingInvitationCard(invitation: invitation),
                  ),
                const SizedBox(height: 12),
              ],
              if (historicalInvitations.isNotEmpty) ...[
                TenantSectionHeader(
                  title: 'Past Invitations',
                  count: historicalInvitations.length,
                  icon: Iconsax.document_text,
                ),
                const SizedBox(height: 10),
                for (final invitation in historicalInvitations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _HistoricalInvitationCard(invitation: invitation),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _InvitationsOverviewCard extends StatelessWidget {
  final int totalCount;
  final int pendingCount;
  final int resolvedCount;

  const _InvitationsOverviewCard({
    required this.totalCount,
    required this.pendingCount,
    required this.resolvedCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Iconsax.sms_notification,
                  size: 22,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invitations Hub',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Review property offers and manage tenancy invitations.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TenantMetricBadge(
                  label: 'Total',
                  value: '$totalCount',
                  icon: Iconsax.sms,
                  filled: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TenantMetricBadge(
                  label: 'Pending',
                  value: '$pendingCount',
                  icon: Iconsax.clock,
                  highlightColor: GrihoColors.warning,
                  filled: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TenantMetricBadge(
                  label: 'Resolved',
                  value: '$resolvedCount',
                  icon: Iconsax.tick_circle,
                  highlightColor: GrihoColors.emerald,
                  filled: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingInvitationCard extends StatelessWidget {
  final TenantInvitation invitation;

  const _PendingInvitationCard({required this.invitation});

  void _openReceiveScreen(BuildContext context) {
    // Live stream provider updates automatically if accepted/declined — no manual invalidation needed.
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            TenantInvitationReceiveScreen(invitationToken: invitation.token),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openReceiveScreen(context),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Iconsax.buildings_2,
                      size: 20,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invitation.propertyName ?? 'Property Invitation',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatInvitationUnit(invitation),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _InvitationStatusChip(
                    status: invitation.status,
                    isExpired: invitation.isExpired,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Offered Monthly Rent',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '৳ ${formatTenantAmount(invitation.rentAmount)} / mo',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Iconsax.clock,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Expires: ${formatTenantDate(invitation.expiresAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GrihoPrimaryButton(
                label: 'Review & Respond',
                icon: Iconsax.arrow_right_3,
                onPressed: () => _openReceiveScreen(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoricalInvitationCard extends StatelessWidget {
  final TenantInvitation invitation;

  const _HistoricalInvitationCard({required this.invitation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => TenantInvitationReceiveScreen(
                invitationToken: invitation.token,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invitation.propertyName ?? 'Property',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatInvitationUnit(invitation),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _InvitationStatusChip(
                    status: invitation.status,
                    isExpired: invitation.isExpired,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '৳ ${formatTenantAmount(invitation.rentAmount)} / month',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Sent ${formatTenantDate(invitation.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationStatusChip extends StatelessWidget {
  final TenantInvitationStatus status;
  final bool isExpired;

  const _InvitationStatusChip({required this.status, required this.isExpired});

  @override
  Widget build(BuildContext context) {
    final effectiveStatus =
        isExpired && status == TenantInvitationStatus.pending
        ? TenantInvitationStatus.expired
        : status;

    final (label, icon, color) = switch (effectiveStatus) {
      TenantInvitationStatus.pending => (
        'Pending',
        Iconsax.clock,
        GrihoColors.warning,
      ),
      TenantInvitationStatus.accepted => (
        'Accepted',
        Iconsax.tick_circle,
        GrihoColors.emerald,
      ),
      TenantInvitationStatus.cancelled => (
        'Cancelled',
        Iconsax.close_circle,
        Colors.blueGrey,
      ),
      TenantInvitationStatus.rejected => (
        'Declined',
        Iconsax.close_circle,
        GrihoColors.error,
      ),
      TenantInvitationStatus.expired => (
        'Expired',
        Iconsax.timer_1,
        Colors.blueGrey,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
