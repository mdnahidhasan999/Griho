import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tenant_invitation.dart';
import '../providers/tenant_dashboard_provider.dart';
import '../providers/tenant_invitation_provider.dart';
import 'tenant_invitation_receive_screen.dart';

class TenantInvitationsScreen extends ConsumerWidget {
  const TenantInvitationsScreen({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final tenantAsync = ref.watch(
      currentTenantProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitations'),
      ),
      body: tenantAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) {
          return _ErrorView(
            message: 'Unable to load tenant information.',
          );
        },
        data: (tenant) {
          if (tenant == null) {
            return const _EmptyView(
              icon: Icons.person_outline,
              title: 'Tenant profile not found',
              message:
              'Your tenant profile could not be found.',
            );
          }

          return _InvitationList(
            tenantId: tenant.id,
          );
        },
      ),
    );
  }
}

class _InvitationList extends ConsumerWidget {
  final String tenantId;

  const _InvitationList({
    required this.tenantId,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final invitationsAsync = ref.watch(
      tenantInvitationsProvider(tenantId),
    );

    return invitationsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stackTrace) {
        return const _ErrorView(
          message: 'Unable to load invitations.',
        );
      },
      data: (invitations) {
        if (invitations.isEmpty) {
          return const _EmptyView(
            icon: Icons.mail_outline,
            title: 'No invitations',
            message:
            'You do not have any tenancy invitations yet.',
          );
        }

        final sortedInvitations =
        List<TenantInvitation>.from(invitations)
          ..sort(
                (a, b) =>
                b.createdAt.compareTo(a.createdAt),
          );

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(
              tenantInvitationsProvider(tenantId),
            );

            await ref.read(
              tenantInvitationsProvider(tenantId).future,
            );
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sortedInvitations.length,
            separatorBuilder: (_, _) =>
            const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final invitation =
              sortedInvitations[index];

              return _InvitationCard(
                invitation: invitation,
              );
            },
          ),
        );
      },
    );
  }
}

class _InvitationCard extends StatelessWidget {
  final TenantInvitation invitation;

  const _InvitationCard({
    required this.invitation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isPending =
        invitation.status ==
            TenantInvitationStatus.pending &&
            !invitation.isExpired;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    invitation.propertyName ??
                        'Property',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusChip(
                  status: invitation.status,
                  isExpired: invitation.isExpired,
                ),
              ],
            ),

            const SizedBox(height: 12),

            _InfoRow(
              icon: Icons.home_work_outlined,
              label: 'Property',
              value:
              invitation.propertyName ??
                  invitation.propertyCode ??
                  '—',
            ),

            const SizedBox(height: 8),

            _InfoRow(
              icon: Icons.meeting_room_outlined,
              label: 'Unit',
              value:
              invitation.unitName ??
                  invitation.unitNumber ??
                  '—',
            ),

            const SizedBox(height: 8),

            _InfoRow(
              icon: Icons.payments_outlined,
              label: 'Monthly Rent',
              value:
              '৳${invitation.rentAmount.toStringAsFixed(0)}',
            ),

            const SizedBox(height: 8),

            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Created',
              value: _formatDate(
                invitation.createdAt,
              ),
            ),

            if (isPending) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            TenantInvitationReceiveScreen(
                              invitationId:
                              invitation.id,
                            ),
                      ),
                    );
                  },
                  child: const Text(
                    'View Invitation',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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
    isExpired &&
        status ==
            TenantInvitationStatus.pending
        ? TenantInvitationStatus.expired
        : status;

    final config = switch (effectiveStatus) {
      TenantInvitationStatus.pending => (
      'Pending',
      Icons.schedule,
      ),
      TenantInvitationStatus.accepted => (
      'Accepted',
      Icons.check_circle_outline,
      ),
      TenantInvitationStatus.cancelled => (
      'Cancelled',
      Icons.cancel_outlined,
      ),
      TenantInvitationStatus.rejected => (
      'Rejected',
      Icons.block_outlined,
      ),
      TenantInvitationStatus.expired => (
      'Expired',
      Icons.timer_off_outlined,
      ),
    };

    return Chip(
      avatar: Icon(
        config.$2,
        size: 17,
      ),
      label: Text(
        config.$1,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

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
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

String _formatDate(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final year = dateTime.year.toString();

  return '$day/$month/$year';
}