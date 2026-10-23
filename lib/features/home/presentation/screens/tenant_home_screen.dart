import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../billing/presentation/widgets/tenant_current_bills_card.dart';
import '../../../rents/presentation/providers/rent_rate_provider.dart';
import '../../../tenants/domain/entities/tenancy_history.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/domain/entities/tenant_invitation.dart';
import '../../../tenants/presentation/providers/tenant_dashboard_provider.dart';
import '../../../tenants/presentation/screens/tenant_tenancy_history_screen.dart';

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
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign out of Griho?'),
          content: const Text(
            'Are you sure you want to sign out of your resident account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign Out'),
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

  void _openTenancyHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TenantTenancyHistoryScreen()),
    );
  }

  Future<void> _openEditProfile(TenantDashboardData dashboard) async {
    final user = dashboard.appUser;

    if (user == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile information is not currently available.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await context.push(RouteNames.editProfile, extra: user);
    if (!mounted) {
      return;
    }

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
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.apartment_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Griho',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Resident Portal',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          // Invitation Inbox Button with Active Badge
          dashboardAsync.maybeWhen(
            data: (dashboard) {
              final hasPending = dashboard.hasPendingInvitation;
              return IconButton(
                tooltip: 'All Invitations',
                onPressed: _openInvitations,
                icon: Badge(
                  isLabelVisible: hasPending,
                  backgroundColor: theme.colorScheme.error,
                  smallSize: 8,
                  child: const Icon(Icons.mail_outline_rounded),
                ),
              );
            },
            orElse: () => IconButton(
              tooltip: 'All Invitations',
              onPressed: _openInvitations,
              icon: const Icon(Icons.mail_outline_rounded),
            ),
          ),

          // User Profile Menu
          PopupMenuButton<String>(
            tooltip: 'Account Settings',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'edit_profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 20),
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
                    Icon(
                      Icons.logout_rounded,
                      size: 20,
                      color: Colors.redAccent,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: dashboardAsync.maybeWhen(
                data: (dashboard) => CircleAvatar(
                  radius: 19,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    dashboard.displayName.isNotEmpty
                        ? dashboard.displayName[0].toUpperCase()
                        : 'T',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                orElse: () => const CircleAvatar(
                  radius: 19,
                  child: Icon(Icons.person_outline_rounded, size: 18),
                ),
              ),
            ),
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
              onOpenTenancyHistory: _openTenancyHistory,
            ),
          );
        },
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.home,
        onHomeTap: () {
          context.go(RouteNames.tenantHome);
        },
        onMoreTap: () {
          context.push(RouteNames.more);
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
  final VoidCallback onOpenTenancyHistory;

  const _TenantDashboardContent({
    required this.dashboard,
    required this.onOpenInvitation,
    required this.onOpenInvitations,
    required this.onOpenTenancyHistory,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // 1. Personalized Header & Quick Copy ID
        _HeaderSection(dashboard: dashboard),

        const SizedBox(height: 18),

        // 2. Urgent Action: Pending Invitation Banner
        if (dashboard.hasPendingInvitation) ...[
          _PendingInvitationCard(
            invitation: dashboard.pendingInvitation!,
            onReview: () => onOpenInvitation(dashboard.pendingInvitation!),
          ),
          const SizedBox(height: 18),
        ],

        // 3. Digital Residency Pass or Unassigned Passport
        if (dashboard.hasActiveTenancy) ...[
          _DigitalResidencyPass(dashboard: dashboard),
        ] else ...[
          _NoActiveTenancyPassport(
            userPublicId: dashboard.appUser?.publicId ?? '',
            hasPendingInvitation: dashboard.hasPendingInvitation,
            onOpenInvitations: onOpenInvitations,
          ),
        ],

        const SizedBox(height: 24),

        // 4. Resident Quick Command Actions
        const _SectionHeader(
          title: 'Resident Shortcuts',
          subtitle: 'Direct management and tenancy utilities',
        ),
        const SizedBox(height: 12),
        _TenantCommandGrid(
          userPublicId: dashboard.appUser?.publicId ?? '',
          onOpenInvitations: onOpenInvitations,
          onOpenTenancyHistory: onOpenTenancyHistory,
        ),

        const SizedBox(height: 24),

        // 5. Billing & Invoices Section
        if (dashboard.hasActiveTenancy) ...[
          const _SectionHeader(
            title: 'Invoices & Current Dues',
            subtitle: 'Real-time rent statements and utility tariff rates',
          ),
          const SizedBox(height: 12),
          const TenantCurrentBillsCard(),
          const SizedBox(height: 24),
        ],

        // 6. Recent Operational Activity
        const _SectionHeader(
          title: 'Recent Activity',
          subtitle: 'Milestones, invitations, and occupancy updates',
        ),
        const SizedBox(height: 12),
        _RecentActivityCard(dashboard: dashboard),

        // 7. Previous Stays Section
        if (dashboard.hasTenancyHistory) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionHeader(
                title: 'Past Residences',
                subtitle: 'Completed lease agreements and stay records',
              ),
              TextButton(
                onPressed: onOpenTenancyHistory,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TenancyHistoryPreview(
            history: dashboard.tenancyHistory,
            onViewItem: onOpenTenancyHistory,
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// 1. EXECUTIVE HEADER
// ============================================================================

class _HeaderSection extends StatelessWidget {
  final TenantDashboardData dashboard;

  const _HeaderSection({required this.dashboard});

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    }
    if (hour < 17) {
      return 'Good Afternoon';
    }
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = dashboard.appUser;
    final publicId = user?.publicId ?? '';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _greetingText(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dashboard.hasActiveTenancy
                          ? Colors.green
                          : Colors.amber.shade800,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                dashboard.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        if (publicId.isNotEmpty)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Clipboard.setData(ClipboardData(text: publicId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Griho Tenant ID copied to clipboard.'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 15,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    publicId,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// 2. HERO DIGITAL RESIDENCY PASS (KEYCARD)
// ============================================================================

class _DigitalResidencyPass extends ConsumerWidget {
  final TenantDashboardData dashboard;

  const _DigitalResidencyPass({required this.dashboard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final propertyName = dashboard.currentPropertyName ?? 'Assigned Property';
    final unitDisplayName = dashboard.currentUnitDisplayName ?? 'Unit';
    final tenant = dashboard.tenant;
    final unitId = tenant?.unitId.trim();
    final hasValidUnitId = unitId != null && unitId.isNotEmpty;
    final rentAsync = hasValidUnitId
        ? ref.watch(currentTenantRentRateProvider(unitId))
        : null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2232), Color(0xFF131722)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ambient Glow Element
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Badge Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.key_rounded,
                            size: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'DIGITAL RESIDENCY PASS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 3.5,
                            backgroundColor: Colors.greenAccent,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Active Stay',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Property & Unit Title
                Text(
                  propertyName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.door_front_door_outlined,
                      size: 16,
                      color: Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      unitDisplayName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
                const SizedBox(height: 14),

                // Financial & Occupancy Sub-Metrics
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agreed Monthly Rent',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        rentAsync == null
                            ? const Text(
                                '—',
                                style: TextStyle(color: Colors.white),
                              )
                            : rentAsync.when(
                                loading: () => const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Colors.white70,
                                  ),
                                ),
                                error: (_, _) => const Text(
                                  'Not set',
                                  style: TextStyle(color: Colors.white),
                                ),
                                data: (rent) => Text(
                                  rent != null
                                      ? '৳ ${_formatAmount(rent.amount)}'
                                      : 'Not Set',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Moved In',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tenant?.tenancyStartedAt != null
                              ? _formatDate(tenant!.tenancyStartedAt!)
                              : 'Recent',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. PENDING INVITATION BANNER
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
    final propertyName = invitation.propertyName?.trim() ?? 'Assigned Property';
    final unitName = invitation.unitNumber?.trim() ?? 'Designated Unit';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onTertiaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mail_rounded,
                  size: 18,
                  color: theme.colorScheme.tertiaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'New Tenancy Invitation Received',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onTertiaryContainer.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Action Required',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'You are invited to finalize lease terms for "$propertyName" ($unitName) with agreed monthly rent of ৳ ${_formatAmount(invitation.rentAmount)}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.onTertiaryContainer,
                foregroundColor: theme.colorScheme.tertiaryContainer,
              ),
              onPressed: onReview,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text(
                'Review & Accept Invitation',
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
// 4. DIGITAL TENANT PASSPORT (EMPTY RESIDENCY STATE)
// ============================================================================

class _NoActiveTenancyPassport extends StatelessWidget {
  final String userPublicId;
  final bool hasPendingInvitation;
  final VoidCallback onOpenInvitations;

  const _NoActiveTenancyPassport({
    required this.userPublicId,
    required this.hasPendingInvitation,
    required this.onOpenInvitations,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.45,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasPendingInvitation
                    ? Icons.mark_email_unread_rounded
                    : Icons.home_work_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasPendingInvitation
                  ? 'Awaiting Tenancy Acceptance'
                  : 'Ready to Move In?',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasPendingInvitation
                  ? 'You have received a new tenancy offer. Review the details above to activate your tenancy.'
                  : 'Share your Griho Public ID with your property manager or landlord to receive your unit onboarding invitation.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (userPublicId.isNotEmpty && !hasPendingInvitation) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR GRIHO ID',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userPublicId,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: userPublicId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Griho ID copied to clipboard.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy ID'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 5. RESIDENT COMMAND GRID (SHORTCUTS)
// ============================================================================

class _TenantCommandGrid extends StatelessWidget {
  final String userPublicId;
  final VoidCallback onOpenInvitations;
  final VoidCallback onOpenTenancyHistory;

  const _TenantCommandGrid({
    required this.userPublicId,
    required this.onOpenInvitations,
    required this.onOpenTenancyHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CommandTile(
            icon: Icons.mark_email_read_outlined,
            title: 'Invitations',
            subtitle: 'Lease Offers',
            color: Colors.blueAccent,
            onTap: onOpenInvitations,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CommandTile(
            icon: Icons.history_rounded,
            title: 'History',
            subtitle: 'Past Stays',
            color: Colors.teal,
            onTap: onOpenTenancyHistory,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CommandTile(
            icon: Icons.share_rounded,
            title: 'Share ID',
            subtitle: 'Fast Link',
            color: Colors.deepPurpleAccent,
            onTap: () {
              if (userPublicId.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: userPublicId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Griho ID copied to clipboard.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

class _CommandTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _CommandTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

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
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
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
// 6. RECENT ACTIVITY TIMELINE
// ============================================================================

class _RecentActivityCard extends StatelessWidget {
  final TenantDashboardData dashboard;

  const _RecentActivityCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activities = _buildActivities(dashboard);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
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
          icon: Icons.mail_outline_rounded,
          title: 'Invitation Received',
          subtitle: invitation.propertyName ?? 'New unit tenancy offered',
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
          title: 'Moved in to New Space',
          subtitle: dashboard.currentPropertyName ?? 'Tenancy active',
          date: tenant.tenancyStartedAt!,
        ),
      );
    }

    for (final history in dashboard.tenancyHistory.take(2)) {
      activities.add(
        _ActivityData(
          icon: Icons.history_rounded,
          title: 'Tenancy Concluded',
          subtitle: history.propertyName,
          date: history.endedAt,
        ),
      );
    }

    activities.sort((a, b) => b.date.compareTo(a.date));

    if (activities.isEmpty) {
      return [
        _ActivityData(
          icon: Icons.check_circle_outline_rounded,
          title: 'Griho Account Active',
          subtitle: 'Welcome to your verified resident portal',
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            activity.icon,
            size: 16,
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
                  fontSize: 13,
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
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 7. PREVIOUS RESIDENCES PREVIEW
// ============================================================================

class _TenancyHistoryPreview extends StatelessWidget {
  final List<TenancyHistory> history;
  final VoidCallback onViewItem;

  const _TenancyHistoryPreview({
    required this.history,
    required this.onViewItem,
  });

  @override
  Widget build(BuildContext context) {
    final preview = history.take(2).toList();
    final theme = Theme.of(context);

    return Column(
      children: [
        for (final item in preview)
          Material(
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onViewItem,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.apartment_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.propertyName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Unit ${item.unitNumber} • ৳ ${_formatAmount(item.monthlyRent)} / mo',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatDate(item.endedAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
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
              fontSize: 11,
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
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load resident portal',
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
// HELPERS (NULL-SAFE)
// ============================================================================

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

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
