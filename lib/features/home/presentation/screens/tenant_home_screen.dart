import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../rents/presentation/providers/rent_rate_provider.dart';
import '../../../tenants/domain/entities/tenancy_history.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/domain/entities/tenant_invitation.dart';
import '../../../tenants/presentation/providers/tenant_dashboard_provider.dart';

class TenantHomeScreen extends ConsumerStatefulWidget {
  const TenantHomeScreen({super.key});

  @override
  ConsumerState<TenantHomeScreen> createState() =>
      _TenantHomeScreenState();
}

class _TenantHomeScreenState
    extends ConsumerState<TenantHomeScreen> {
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
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .signOut();
  }

  void _openInvitation(
      TenantInvitation invitation,
      ) {
    context.push(
      RouteNames.tenantInvitationPath(
        invitation.id,
      ),
    );
  }

  void _openInvitations() {
    context.push(
      RouteNames.tenantInvitations,
    );
  }

  Future<void> _openEditProfile(
      TenantDashboardData dashboard,
      ) async {
    final user = dashboard.appUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile information is not available.',
          ),
        ),
      );

      return;
    }

    final result = await context.push(
      RouteNames.editProfile,
      extra: user,
    );

    if (!mounted) {
      return;
    }

    if (result != null) {
      ref.invalidate(tenantDashboardProvider);

      try {
        await ref.read(
          tenantDashboardProvider.future,
        );
      } catch (_) {
        // Dashboard displays its own error state.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(
      tenantDashboardProvider,
    );

    return Scaffold(
      backgroundColor:
      Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Griho',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        actions: [
          dashboardAsync.maybeWhen(
            data: (dashboard) {
              if (!dashboard.hasPendingInvitation) {
                return const SizedBox.shrink();
              }

              final invitation =
                  dashboard.pendingInvitation;

              if (invitation == null) {
                return const SizedBox.shrink();
              }

              return IconButton(
                tooltip: 'New invitation',
                onPressed: () {
                  _openInvitation(invitation);
                },
                icon: Badge(
                  smallSize: 9,
                  child: const Icon(
                    Icons.notifications_outlined,
                  ),
                ),
              );
            },
            orElse: () =>
            const SizedBox.shrink(),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            onSelected: (value) {
              if (value == 'edit_profile') {
                dashboardAsync.maybeWhen(
                  data: (dashboard) {
                    _openEditProfile(dashboard);
                  },
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
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 12),
                      Text('Edit Profile'),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 12),
                      Text('Logout'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          return _DashboardErrorView(
            error: error,
            onRetry: _refresh,
          );
        },
        data: (dashboard) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _TenantDashboardContent(
              dashboard: dashboard,
              onOpenInvitation:
              _openInvitation,
              onOpenInvitations:
              _openInvitations,
              onEditProfile: () {
                _openEditProfile(dashboard);
              },
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

class _TenantDashboardContent
    extends StatelessWidget {
  final TenantDashboardData dashboard;

  final ValueChanged<TenantInvitation>
  onOpenInvitation;

  final VoidCallback onOpenInvitations;

  final VoidCallback onEditProfile;

  const _TenantDashboardContent({
    required this.dashboard,
    required this.onOpenInvitation,
    required this.onOpenInvitations,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        32,
      ),
      children: [
        _WelcomeHeader(
          name: dashboard.displayName,
          hasActiveTenancy:
          dashboard.hasActiveTenancy,
        ),

        const SizedBox(height: 20),

        // ========================================================
        // PENDING INVITATION
        // ========================================================

        if (dashboard.hasPendingInvitation) ...[
          _PendingInvitationCard(
            invitation:
            dashboard.pendingInvitation!,
            onReview: () {
              onOpenInvitation(
                dashboard.pendingInvitation!,
              );
            },
          ),
          const SizedBox(height: 20),
        ],

        // ========================================================
        // INVITATIONS
        // ========================================================

        _InvitationsCard(
          hasPendingInvitation:
          dashboard.hasPendingInvitation,
          onOpen: onOpenInvitations,
        ),

        const SizedBox(height: 20),

        // ========================================================
        // CURRENT TENANCY
        // ========================================================

        if (dashboard.hasActiveTenancy) ...[
          _CurrentTenancyCard(
            dashboard: dashboard,
          ),
          const SizedBox(height: 20),
        ] else ...[
          _NoActiveTenancyCard(
            hasHistory:
            dashboard.hasTenancyHistory,
            hasPendingInvitation:
            dashboard.hasPendingInvitation,
          ),
          const SizedBox(height: 20),
        ],

        // ========================================================
        // ACCOUNT
        // ========================================================

        _AccountOverviewCard(
          dashboard: dashboard,
          onEditProfile: onEditProfile,
        ),

        const SizedBox(height: 20),

        const _SectionHeader(
          title: 'Tenancy History',
        ),

        const SizedBox(height: 10),

        if (dashboard.hasTenancyHistory)
          _TenancyHistoryPreview(
            history: dashboard.tenancyHistory,
          )
        else
          const _EmptyHistoryCard(),

        const SizedBox(height: 20),

        const _SectionHeader(
          title: 'Recent Activity',
        ),

        const SizedBox(height: 10),

        _RecentActivityCard(
          dashboard: dashboard,
        ),
      ],
    );
  }
}

// ============================================================================
// INVITATIONS CARD
// ============================================================================

class _InvitationsCard
    extends StatelessWidget {
  final bool hasPendingInvitation;
  final VoidCallback onOpen;

  const _InvitationsCard({
    required this.hasPendingInvitation,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                hasPendingInvitation
                    ? theme
                    .colorScheme
                    .primaryContainer
                    : theme
                    .colorScheme
                    .surfaceContainerHighest,
                child: Icon(
                  hasPendingInvitation
                      ? Icons
                      .mark_email_unread_outlined
                      : Icons.mail_outline,
                  color:
                  hasPendingInvitation
                      ? theme
                      .colorScheme
                      .onPrimaryContainer
                      : theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Invitations',
                            style: theme
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                        ),

                        if (hasPendingInvitation)
                          Container(
                            padding:
                            const EdgeInsets
                                .symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration:
                            BoxDecoration(
                              color: theme
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius:
                              BorderRadius
                                  .circular(
                                20,
                              ),
                            ),
                            child: Text(
                              'Pending',
                              style: theme
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                fontWeight:
                                FontWeight.w700,
                                color: theme
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      hasPendingInvitation
                          ? 'You have a new tenancy invitation.'
                          : 'View your tenancy invitation history.',
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: theme
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.chevron_right,
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// WELCOME HEADER
// ============================================================================

class _WelcomeHeader extends StatelessWidget {
  final String name;
  final bool hasActiveTenancy;

  const _WelcomeHeader({
    required this.name,
    required this.hasActiveTenancy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          _greeting(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color:
            theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$name 👋',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall
              ?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hasActiveTenancy
              ? 'Here is an overview of your current home.'
              : 'Manage your Griho account and tenancy from here.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color:
            theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning';
    }

    if (hour < 17) {
      return 'Good afternoon';
    }

    return 'Good evening';
  }
}

// ============================================================================
// PENDING INVITATION
// ============================================================================

class _PendingInvitationCard
    extends StatelessWidget {
  final TenantInvitation invitation;
  final VoidCallback onReview;

  const _PendingInvitationCard({
    required this.invitation,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final propertyName =
    invitation.propertyName?.trim();

    final unitName =
    invitation.unitNumber?.trim();

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.primary
                .withValues(alpha: 0.35),
          ),
          borderRadius:
          BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                  theme.colorScheme
                      .primaryContainer,
                  child: Icon(
                    Icons.mail_outline,
                    color: theme.colorScheme
                        .onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New tenancy invitation',
                        style: theme.textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'An owner has invited you to a property.',
                        style: theme.textTheme
                            .bodySmall
                            ?.copyWith(
                          color: theme.colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            if (propertyName != null &&
                propertyName.isNotEmpty)
              _InfoRow(
                icon: Icons.apartment_outlined,
                label: 'Property',
                value: propertyName,
              ),
            if (unitName != null &&
                unitName.isNotEmpty)
              _InfoRow(
                icon:
                Icons.home_work_outlined,
                label: 'Unit',
                value: unitName,
              ),
            _InfoRow(
              icon: Icons.payments_outlined,
              label: 'Monthly rent',
              value:
              '৳ ${_formatAmount(invitation.rentAmount)}',
            ),
            _InfoRow(
              icon: Icons.event_outlined,
              label: 'Expires',
              value: _formatDate(
                invitation.expiresAt,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onReview,
                icon: const Icon(
                  Icons.arrow_forward,
                ),
                label: const Text(
                  'Review Invitation',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CURRENT TENANCY
// ============================================================================

class _CurrentTenancyCard
    extends ConsumerWidget {
  final TenantDashboardData dashboard;

  const _CurrentTenancyCard({
    required this.dashboard,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final theme = Theme.of(context);

    final propertyName =
        dashboard.currentPropertyName;

    final unitDisplayName =
        dashboard.currentUnitDisplayName;

    final tenant = dashboard.tenant;

    final unitId = tenant?.unitId.trim();

    final hasValidUnitId =
        unitId != null && unitId.isNotEmpty;

    final rentAsync = hasValidUnitId
        ? ref.watch(
      currentTenantRentRateProvider(
        unitId,
      ),
    )
        : null;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                  theme.colorScheme
                      .primaryContainer,
                  child: Icon(
                    Icons.home_outlined,
                    color: theme.colorScheme
                        .onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Home',
                        style: theme.textTheme
                            .titleLarge
                            ?.copyWith(
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Current tenancy',
                        style: theme.textTheme
                            .bodySmall
                            ?.copyWith(
                          color: theme.colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green
                        .withValues(alpha: 0.10),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight:
                      FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _InfoRow(
              icon: Icons.apartment_outlined,
              label: 'Property',
              value: propertyName ??
                  'Property information unavailable',
            ),
            _InfoRow(
              icon:
              Icons.door_front_door_outlined,
              label: 'Unit',
              value: unitDisplayName ??
                  'Unit information unavailable',
            ),
            _CurrentTenantRentRow(
              rentAsync: rentAsync,
              hasValidUnitId: hasValidUnitId,
            ),
            if (dashboard.tenant
                ?.tenancyStartedAt !=
                null)
              _InfoRow(
                icon:
                Icons.calendar_month_outlined,
                label: 'Started',
                value: _formatDate(
                  dashboard.tenant!
                      .tenancyStartedAt!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CURRENT TENANT RENT ROW
// ============================================================================

class _CurrentTenantRentRow
    extends StatelessWidget {
  final AsyncValue<dynamic>? rentAsync;
  final bool hasValidUnitId;

  const _CurrentTenantRentRow({
    required this.rentAsync,
    required this.hasValidUnitId,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasValidUnitId ||
        rentAsync == null) {
      return const _InfoRow(
        icon: Icons.payments_outlined,
        label: 'Monthly Rent',
        value: 'Not available',
      );
    }

    return rentAsync!.when(
      loading: () {
        return const _LoadingTenantRentRow();
      },
      error: (_, _) {
        return const _InfoRow(
          icon: Icons.payments_outlined,
          label: 'Monthly Rent',
          value: 'Unable to load',
        );
      },
      data: (rentRate) {
        if (rentRate == null) {
          return const _InfoRow(
            icon: Icons.payments_outlined,
            label: 'Monthly Rent',
            value: 'Not set',
          );
        }

        return _InfoRow(
          icon: Icons.payments_outlined,
          label: 'Monthly Rent',
          value:
          '৳ ${_formatAmount(rentRate.amount)}',
          emphasized: true,
        );
      },
    );
  }
}

class _LoadingTenantRentRow
    extends StatelessWidget {
  const _LoadingTenantRentRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          Icon(
            Icons.payments_outlined,
            size: 20,
            color:
            theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              'Monthly Rent',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(
                color: theme.colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// NO ACTIVE TENANCY
// ============================================================================

class _NoActiveTenancyCard
    extends StatelessWidget {
  final bool hasHistory;
  final bool hasPendingInvitation;

  const _NoActiveTenancyCard({
    required this.hasHistory,
    required this.hasPendingInvitation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme
                    .secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasPendingInvitation
                    ? Icons
                    .mark_email_unread_outlined
                    : Icons.home_outlined,
                size: 30,
                color: theme.colorScheme
                    .onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasPendingInvitation
                  ? 'You have a new invitation'
                  : 'No active tenancy',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasPendingInvitation
                  ? 'Review the invitation above to see the property and tenancy details.'
                  : hasHistory
                  ? 'You currently do not have an active tenancy. Your previous tenancy records are still available below.'
                  : 'Your account is ready. When an owner sends you an invitation, it will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(
                color: theme.colorScheme
                    .onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ACCOUNT OVERVIEW
// ============================================================================

class _AccountOverviewCard
    extends StatelessWidget {
  final TenantDashboardData dashboard;
  final VoidCallback onEditProfile;

  const _AccountOverviewCard({
    required this.dashboard,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = dashboard.appUser;

    return Card(
      elevation: 0,
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
                    'My Account',
                    style: theme.textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onEditProfile,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                  ),
                  label: const Text(
                    'Edit Profile',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (profile != null) ...[
              _InfoRow(
                icon: Icons.badge_outlined,
                label: 'Griho ID',
                value: profile.publicId,
              ),
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Name',
                value: profile.name,
              ),
              if (profile.phoneNumber != null &&
                  profile.phoneNumber!
                      .trim()
                      .isNotEmpty)
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: profile.phoneNumber!,
                ),
              if (profile.email != null &&
                  profile.email!
                      .trim()
                      .isNotEmpty)
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: profile.email!,
                ),
            ] else
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Profile',
                value:
                'Profile information unavailable',
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TENANCY HISTORY
// ============================================================================

class _TenancyHistoryPreview
    extends StatelessWidget {
  final List<TenancyHistory> history;

  const _TenancyHistoryPreview({
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final preview =
    history.take(3).toList();

    return Column(
      children: [
        for (var index = 0;
        index < preview.length;
        index++) ...[
          _HistoryItem(
            history: preview[index],
          ),
          if (index != preview.length - 1)
            const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _HistoryItem
    extends StatelessWidget {
  final TenancyHistory history;

  const _HistoryItem({
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final propertyName =
    history.propertyName.trim();

    final unitNumber =
    history.unitNumber.trim();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme
                  .surfaceContainerHighest,
              child: Icon(
                Icons.history,
                color: theme.colorScheme
                    .onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    propertyName.isNotEmpty
                        ? propertyName
                        : 'Previous tenancy',
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: theme.textTheme
                        .titleSmall
                        ?.copyWith(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unitNumber.isNotEmpty
                        ? 'Unit $unitNumber'
                        : 'Unit information unavailable',
                    style: theme.textTheme
                        .bodySmall
                        ?.copyWith(
                      color: theme.colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDate(
                    history.startedAt,
                  ),
                  style: theme.textTheme
                      .bodySmall
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'to ${_formatDate(history.endedAt)}',
                  style: theme.textTheme
                      .bodySmall
                      ?.copyWith(
                    color: theme.colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistoryCard
    extends StatelessWidget {
  const _EmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.history_outlined,
              color: theme.colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your previous tenancy records will appear here.',
                style: theme.textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: theme.colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// RECENT ACTIVITY
// ============================================================================

class _RecentActivityCard
    extends StatelessWidget {
  final TenantDashboardData dashboard;

  const _RecentActivityCard({
    required this.dashboard,
  });

  @override
  Widget build(BuildContext context) {
    final activities =
    _buildActivities(dashboard);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var index = 0;
            index < activities.length;
            index++) ...[
              _ActivityItem(
                activity: activities[index],
              ),
              if (index != activities.length - 1)
                const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  List<_ActivityData> _buildActivities(
      TenantDashboardData dashboard,
      ) {
    final activities = <_ActivityData>[];

    final invitation =
        dashboard.pendingInvitation;

    if (invitation != null &&
        invitation.isValid) {
      activities.add(
        _ActivityData(
          icon: Icons.mail_outline,
          title: 'New invitation received',
          subtitle: invitation.propertyName ??
              'A property owner sent you an invitation.',
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
          icon: Icons.home_outlined,
          title: 'Current tenancy started',
          subtitle:
          'You currently have an active tenancy.',
          date: tenant.tenancyStartedAt!,
        ),
      );
    }

    for (final history
    in dashboard.tenancyHistory.take(3)) {
      activities.add(
        _ActivityData(
          icon: Icons.history,
          title: 'Tenancy ended',
          subtitle: history.propertyName
              .trim()
              .isNotEmpty
              ? history.propertyName
              : 'Previous tenancy',
          date: history.endedAt,
        ),
      );
    }

    activities.sort(
          (a, b) => b.date.compareTo(a.date),
    );

    if (activities.length > 5) {
      return activities.take(5).toList();
    }

    if (activities.isEmpty) {
      return [
        _ActivityData(
          icon: Icons.check_circle_outline,
          title: 'Account ready',
          subtitle:
          'Your Griho account is ready to use.',
          date: dashboard.appUser?.createdAt ??
              dashboard.firebaseUser?.metadata
                  .creationTime ??
              DateTime.now(),
        ),
      ];
    }

    return activities;
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

  const _ActivityItem({
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: theme.colorScheme
              .surfaceContainerHighest,
          child: Icon(
            activity.icon,
            size: 20,
            color: theme.colorScheme
                .onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                style: theme.textTheme
                    .titleSmall
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                activity.subtitle,
                maxLines: 2,
                overflow:
                TextOverflow.ellipsis,
                style: theme.textTheme
                    .bodySmall
                    ?.copyWith(
                  color: theme.colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _relativeDate(activity.date),
          style: theme.textTheme.labelSmall
              ?.copyWith(
            color: theme.colorScheme
                .onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
// ============================================================================
// SECTION HEADER
// ============================================================================

class _SectionHeader
    extends StatelessWidget {
  final String title;

  const _SectionHeader({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      title,
      style: theme.textTheme.titleMedium
          ?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

// ============================================================================
// INFO ROW
// ============================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme
                .onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme
                  .bodyMedium
                  ?.copyWith(
                color: theme.colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme
                  .bodyMedium
                  ?.copyWith(
                fontWeight: emphasized
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DASHBOARD ERROR
// ============================================================================

class _DashboardErrorView
    extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _DashboardErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load your dashboard',
              textAlign: TextAlign.center,
              style: theme.textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              maxLines: 4,
              overflow:
              TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme
                  .bodySmall
                  ?.copyWith(
                color: theme.colorScheme
                    .onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HELPERS
// ============================================================================

String _formatDate(DateTime date) {
  final day =
  date.day.toString().padLeft(2, '0');

  final month =
  date.month.toString().padLeft(2, '0');

  final year = date.year.toString();

  return '$day/$month/$year';
}

String _formatAmount(double amount) {
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }

  return amount.toStringAsFixed(2);
}

String _relativeDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.isNegative) {
    return 'Upcoming';
  }

  if (difference.inMinutes < 1) {
    return 'Now';
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