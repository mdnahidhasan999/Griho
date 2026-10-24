import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tenant_invitation.dart';
import '../providers/recipient_invitations_provider.dart';
import 'tenant_invitation_receive_screen.dart';

class TenantInvitationsScreen extends ConsumerWidget {
  const TenantInvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Tenancy Invitations',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: const SafeArea(
        child: _InvitationList(),
      ),
    );
  }
}

// ============================================================================
// INVITATION LIST
// ============================================================================

class _InvitationList extends ConsumerWidget {
  const _InvitationList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(recipientInvitationsProvider);

    return invitationsAsync.when(
      loading: () =>
      const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stackTrace) =>
          _ErrorView(
            message: 'Unable to load your invitations.',
            onRetry: () {
              ref.invalidate(recipientInvitationsProvider);
            },
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
              children: const [
                SizedBox(
                  height: 400,
                  child: _EmptyView(
                    icon: Icons.mail_outline_rounded,
                    title: 'No Invitations Yet',
                    message:
                    'You do not have any tenancy invitations. '
                        'When a property manager invites you, '
                        'it will appear here.',
                  ),
                ),
              ],
            ),
          );
        }

        final sorted = List<TenantInvitation>.from(invitations)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final pendingInvitations = sorted.where((invitation) {
          return invitation.status == TenantInvitationStatus.pending &&
              !invitation.isExpired;
        }).toList();

        final historicalInvitations = sorted.where((invitation) {
          return invitation.status != TenantInvitationStatus.pending ||
              invitation.isExpired;
        }).toList();

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
                _SectionTitle(
                  title: 'Action Required',
                  count: pendingInvitations.length,
                  icon: Icons.pending_actions_rounded,
                  color: Colors.amber.shade900,
                ),
                const SizedBox(height: 10),
                for (final invitation in pendingInvitations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PendingInvitationCard(
                      invitation: invitation,
                    ),
                  ),
                const SizedBox(height: 12),
              ],

              if (historicalInvitations.isNotEmpty) ...[
                _SectionTitle(
                  title: 'Past Invitations',
                  count: historicalInvitations.length,
                  icon: Icons.history_rounded,
                ),
                const SizedBox(height: 10),
                for (final invitation in historicalInvitations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _HistoricalInvitationCard(
                      invitation: invitation,
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// OVERVIEW CARD
// ============================================================================

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
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
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
                  Icons.mark_email_read_outlined,
                  size: 24,
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
                child: _MetricBadge(
                  label: 'Total',
                  value: '$totalCount',
                  icon: Icons.all_inbox_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBadge(
                  label: 'Pending',
                  value: '$pendingCount',
                  icon: Icons.schedule_rounded,
                  highlightColor: Colors.amber.shade900,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBadge(
                  label: 'Resolved',
                  value: '$resolvedCount',
                  icon: Icons.check_circle_outline_rounded,
                  highlightColor: Colors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? highlightColor;

  const _MetricBadge({
    required this.label,
    required this.value,
    required this.icon,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 16,
            color: highlightColor ?? theme.colorScheme.primary,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION TITLE
// ============================================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color? color;

  const _SectionTitle({
    required this.title,
    required this.count,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: color ?? theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color ?? theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// PENDING INVITATION CARD
// ============================================================================

class _PendingInvitationCard extends ConsumerWidget {
  final TenantInvitation invitation;

  const _PendingInvitationCard({
    required this.invitation,
  });

  Future<void> _openReceiveScreen(BuildContext context,
      WidgetRef ref,) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            TenantInvitationReceiveScreen(
              invitationToken: invitation.token,
            ),
      ),
    );

    if (context.mounted) {
      ref.invalidate(recipientInvitationsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        onTap: () => _openReceiveScreen(context, ref),
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
                      Icons.home_work_rounded,
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
                          invitation.propertyName ?? 'Property Invitation',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatUnit(invitation),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(
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
                      '৳ ${_formatAmount(invitation.rentAmount)} / mo',
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
                    Icons.schedule_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Expires: ${_formatDate(invitation.expiresAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: () => _openReceiveScreen(context, ref),
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Review & Respond',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HISTORICAL INVITATION CARD
// ============================================================================

class _HistoricalInvitationCard extends ConsumerWidget {
  final TenantInvitation invitation;

  const _HistoricalInvitationCard({
    required this.invitation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) =>
                  TenantInvitationReceiveScreen(
                    invitationToken: invitation.token,
                  ),
            ),
          );

          if (context.mounted) {
            ref.invalidate(recipientInvitationsProvider);
          }
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
                          _formatUnit(invitation),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(
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
                    '৳ ${_formatAmount(invitation.rentAmount)} / month',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Sent ${_formatDate(invitation.createdAt)}',
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

// ============================================================================
// STATUS CHIP
// ============================================================================

class _StatusChip extends StatelessWidget {
  final TenantInvitationStatus status;
  final bool isExpired;

  const _StatusChip({
    required this.status,
    required this.isExpired,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStatus =
    isExpired && status == TenantInvitationStatus.pending
        ? TenantInvitationStatus.expired
        : status;

    final (label, icon, color) = switch (effectiveStatus) {
      TenantInvitationStatus.pending =>
      (
      'Pending',
      Icons.schedule_rounded,
      Colors.amber.shade900,
      ),
      TenantInvitationStatus.accepted =>
      (
      'Accepted',
      Icons.check_circle_rounded,
      Colors.green.shade800,
      ),
      TenantInvitationStatus.cancelled =>
      (
      'Cancelled',
      Icons.cancel_outlined,
      Colors.grey.shade700,
      ),
      TenantInvitationStatus.rejected =>
      (
      'Declined',
      Icons.block_rounded,
      Colors.red.shade800,
      ),
      TenantInvitationStatus.expired =>
      (
      'Expired',
      Icons.timer_off_outlined,
      Colors.grey.shade700,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: color,
          ),
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

// ============================================================================
// EMPTY VIEW
// ============================================================================

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyView({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR VIEW
// ============================================================================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorView({
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HELPERS
// ============================================================================

String _formatUnit(TenantInvitation invitation) {
  final unitName = invitation.unitName?.trim();
  final unitNumber = invitation.unitNumber?.trim();

  if (unitName != null &&
      unitName.isNotEmpty &&
      unitNumber != null &&
      unitNumber.isNotEmpty) {
    return '$unitName (Unit $unitNumber)';
  }

  if (unitName != null && unitName.isNotEmpty) {
    return unitName;
  }

  if (unitNumber != null && unitNumber.isNotEmpty) {
    return 'Unit $unitNumber';
  }

  return 'Unit unassigned';
}

String _formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();

  return '$day/$month/$year';
}

String _formatAmount(num? amount) {
  if (amount == null) {
    return '0';
  }

  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }

  return amount.toStringAsFixed(2);
}