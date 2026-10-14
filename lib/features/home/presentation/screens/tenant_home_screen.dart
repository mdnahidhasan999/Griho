import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../billing/presentation/widgets/tenant_current_bills_card.dart';
import '../../../rents/presentation/providers/rent_rate_provider.dart';
import '../../../tenants/domain/entities/tenancy_history.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/domain/entities/tenant_invitation.dart';
import '../../../tenants/presentation/providers/tenant_dashboard_provider.dart';

class TenantHomeScreen extends ConsumerStatefulWidget {
  const TenantHomeScreen({super.key});

  @override
  ConsumerState<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends ConsumerState<TenantHomeScreen> {
  Future<void> _refresh() async {
    ref.invalidate(tenantDashboardProvider);
    await ref.read(tenantDashboardProvider.future);
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    await ref.read(authControllerProvider.notifier).signOut();
  }

  void _openInvitation(TenantInvitation invitation) {
    context.push(RouteNames.tenantInvitationPath(invitation.id));
  }

  void _openInvitations() {
    context.push(RouteNames.tenantInvitations);
  }

  Future<void> _openEditProfile(TenantDashboardData dashboard) async {
    final user = dashboard.appUser;

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile information is not available.')),
      );
      return;
    }

    final result = await context.push(RouteNames.editProfile, extra: user);
    if (!mounted) return;

    if (result != null) {
      ref.invalidate(tenantDashboardProvider);
      try {
        await ref.read(tenantDashboardProvider.future);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(tenantDashboardProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.apartment_rounded,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Griho',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'All Invitations',
            onPressed: _openInvitations,
            icon: const Icon(Icons.mail_outline_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            onSelected: (value) {
              if (value == 'edit_profile') {
                dashboardAsync.maybeWhen(
                  data: (dashboard) => _openEditProfile(dashboard),
                  orElse: () {},
                );
              }
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<String>(
                  value: 'edit_profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline),
                      SizedBox(width: 12),
                      Text('My Profile'),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent),
                      SizedBox(width: 12),
                      Text('Logout', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _DashboardErrorView(error: error, onRetry: _refresh),
        data: (dashboard) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _TenantDashboardContent(
              dashboard: dashboard,
              onOpenInvitation: _openInvitation,
              onOpenInvitations: _openInvitations,
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// DASHBOARD CONTENT
// ============================================================================

class _TenantDashboardContent extends StatelessWidget {
  final TenantDashboardData dashboard;
  final ValueChanged<TenantInvitation> onOpenInvitation;
  final VoidCallback onOpenInvitations;

  const _TenantDashboardContent({
    required this.dashboard,
    required this.onOpenInvitation,
    required this.onOpenInvitations,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        _HeaderSection(dashboard: dashboard),

        const SizedBox(height: 16),

        if (dashboard.hasPendingInvitation) ...[
          _PendingInvitationCard(
            invitation: dashboard.pendingInvitation!,
            onReview: () => onOpenInvitation(dashboard.pendingInvitation!),
          ),
          const SizedBox(height: 16),
        ],

        if (dashboard.hasActiveTenancy) ...[
          _HeroTenancyCard(dashboard: dashboard),

          const SizedBox(height: 24),

          const _SectionHeader(
            title: 'My Bills & Dues',
            subtitle: 'Review monthly rent and utility charges',
          ),
          const SizedBox(height: 10),
          const TenantCurrentBillsCard(),
        ] else ...[
          _NoActiveTenancyCard(
            hasPendingInvitation: dashboard.hasPendingInvitation,
          ),
        ],

        const SizedBox(height: 28),

        const _SectionHeader(
          title: 'Recent Activity',
          subtitle: 'Latest updates and tenancy events',
        ),
        const SizedBox(height: 10),
        _RecentActivityCard(dashboard: dashboard),

        if (dashboard.hasTenancyHistory) ...[
          const SizedBox(height: 28),
          const _SectionHeader(
            title: 'Previous Homes',
            subtitle: 'Records from past tenancies',
          ),
          const SizedBox(height: 10),
          _TenancyHistoryPreview(history: dashboard.tenancyHistory),
        ],
      ],
    );
  }
}

// ============================================================================
// HEADER SECTION
// ============================================================================

class _HeaderSection extends StatelessWidget {
  final TenantDashboardData dashboard;

  const _HeaderSection({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = dashboard.appUser;

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            dashboard.displayName.isNotEmpty
                ? dashboard.displayName[0].toUpperCase()
                : 'T',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()},',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                dashboard.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (user != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.badge_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  user.publicId,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ============================================================================
// HERO TENANCY CARD
// ============================================================================

class _HeroTenancyCard extends ConsumerWidget {
  final TenantDashboardData dashboard;

  const _HeroTenancyCard({required this.dashboard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final propertyName = dashboard.currentPropertyName ?? 'Property Details';
    final unitDisplayName = dashboard.currentUnitDisplayName ?? 'Unit';
    final tenant = dashboard.tenant;
    final unitId = tenant?.unitId.trim();
    final hasValidUnitId = unitId != null && unitId.isNotEmpty;
    final rentAsync = hasValidUnitId
        ? ref.watch(currentTenantRentRateProvider(unitId))
        : null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
            theme.colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: Colors.green),
                    SizedBox(width: 6),
                    Text(
                      'Currently Staying',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.home_rounded, color: theme.colorScheme.primary),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            propertyName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.door_front_door_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                unitDisplayName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agreed Monthly Rent',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  rentAsync == null
                      ? const Text('—')
                      : rentAsync.when(
                          loading: () => const Text('Loading...'),
                          error: (_, _) => const Text('Not available'),
                          data: (rent) => Text(
                            rent != null
                                ? '৳ ${_formatAmount(rent.amount)}'
                                : 'Not Set',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                ],
              ),
              if (tenant?.tenancyStartedAt != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Moved In',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(tenant!.tenancyStartedAt!),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PENDING INVITATION BANNER
// ============================================================================

class _PendingInvitationCard extends StatelessWidget {
  final TenantInvitation invitation;
  final VoidCallback onReview;

  const _PendingInvitationCard({
    required this.invitation,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final propertyName = invitation.propertyName?.trim() ?? 'a property';
    final unitName = invitation.unitNumber?.trim() ?? 'Assigned Unit';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.onTertiaryContainer,
                child: Icon(
                  Icons.mail_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.tertiaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'New Tenancy Invitation!',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You have been invited to stay at "$propertyName" ($unitName) with monthly rent of ৳ ${_formatAmount(invitation.rentAmount)}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.onTertiaryContainer,
                foregroundColor: theme.colorScheme.tertiaryContainer,
              ),
              onPressed: onReview,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text(
                'Review & Accept',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// NO ACTIVE TENANCY CARD
// ============================================================================

class _NoActiveTenancyCard extends StatelessWidget {
  final bool hasPendingInvitation;

  const _NoActiveTenancyCard({required this.hasPendingInvitation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            hasPendingInvitation
                ? Icons.mark_email_unread_outlined
                : Icons.home_work_outlined,
            size: 52,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            hasPendingInvitation
                ? 'Action Required: New Invitation'
                : 'No Active Tenancy',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasPendingInvitation
                ? 'Please check the invitation banner above to confirm your tenancy.'
                : 'You are currently not registered under any property. Share your Griho ID or verified phone number with your landlord to get started.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// RECENT ACTIVITY CARD
// ============================================================================

class _RecentActivityCard extends StatelessWidget {
  final TenantDashboardData dashboard;

  const _RecentActivityCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activities = _buildActivities(dashboard);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var index = 0; index < activities.length; index++) ...[
              _ActivityItem(activity: activities[index]),
              if (index != activities.length - 1) const Divider(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  List<_ActivityData> _buildActivities(TenantDashboardData dashboard) {
    final activities = <_ActivityData>[];
    final invitation = dashboard.pendingInvitation;

    if (invitation != null && invitation.isValid) {
      activities.add(
        _ActivityData(
          icon: Icons.mail_outline,
          title: 'Invitation received',
          subtitle: invitation.propertyName ?? 'Property invitation waiting',
          date: invitation.createdAt,
        ),
      );
    }

    final tenant = dashboard.tenant;
    if (tenant != null &&
        tenant.status == TenantStatus.active &&
        tenant.tenancyStartedAt != null) {
      activities.add(
        _ActivityData(
          icon: Icons.key_rounded,
          title: 'Moved in to new home',
          subtitle: dashboard.currentPropertyName ?? 'Tenancy active',
          date: tenant.tenancyStartedAt!,
        ),
      );
    }

    for (final history in dashboard.tenancyHistory.take(2)) {
      activities.add(
        _ActivityData(
          icon: Icons.history_rounded,
          title: 'Tenancy completed',
          subtitle: history.propertyName,
          date: history.endedAt,
        ),
      );
    }

    activities.sort((a, b) => b.date.compareTo(a.date));

    if (activities.isEmpty) {
      return [
        _ActivityData(
          icon: Icons.check_circle_outline,
          title: 'Account active',
          subtitle: 'Welcome to Griho system',
          date: dashboard.appUser?.createdAt ?? DateTime.now(),
        ),
      ];
    }

    return activities.take(4).toList();
  }
}

class _ActivityData {
  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime date;

  const _ActivityData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.date,
  });
}

class _ActivityItem extends StatelessWidget {
  final _ActivityData activity;

  const _ActivityItem({required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            activity.icon,
            size: 18,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                activity.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _relativeDate(activity.date),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TENANCY HISTORY PREVIEW
// ============================================================================

class _TenancyHistoryPreview extends StatelessWidget {
  final List<TenancyHistory> history;

  const _TenancyHistoryPreview({required this.history});

  @override
  Widget build(BuildContext context) {
    final preview = history.take(2).toList();
    final theme = Theme.of(context);

    return Column(
      children: [
        for (final item in preview)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.home_outlined, size: 20),
              ),
              title: Text(
                item.propertyName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Unit: ${item.unitNumber} • ৳ ${_formatAmount(item.monthlyRent)}',
              ),
              trailing: Text(
                _formatDate(item.endedAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// SECTION HEADER
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// DASHBOARD ERROR VIEW
// ============================================================================

class _DashboardErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _DashboardErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Could not load your dashboard',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HELPERS (NULL-SAFE)
// ============================================================================

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

/// নালেবল `num?` সাপোর্ট করায় double? পাস করলেও কোনো এরর আসবে না
String _formatAmount(num? amount) {
  if (amount == null) {
    return '0.00';
  }
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toStringAsFixed(2);
}

String _relativeDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.isNegative || difference.inMinutes < 1) {
    return 'Just now';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  }
  return _formatDate(date);
}
