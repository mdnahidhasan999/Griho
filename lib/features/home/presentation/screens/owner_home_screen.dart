import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/providers/owner_tenants_provider.dart';

class OwnerHomeScreen extends ConsumerWidget {
  const OwnerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
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
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
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
                  'Owner Console',
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
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          message: 'Unable to load owner account information.',
          onRetry: () => ref.invalidate(currentUserProfileProvider),
        ),
        data: (profile) {
          if (profile == null) {
            return _ErrorView(
              message: 'Owner profile not found.',
              onRetry: () => ref.invalidate(currentUserProfileProvider),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentUserProfileProvider);
              ref.invalidate(currentOwnerPropertiesProvider);
              ref.invalidate(ownerTenantsProvider);
              await ref.read(currentUserProfileProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                // 1. Personalized Executive Greeting Header
                _ExecutiveHeader(
                  name: profile.name,
                  publicId: profile.publicId,
                ),

                const SizedBox(height: 18),

                // 2. Portfolio Vault & Financial Intelligence Card
                const _PortfolioVaultCard(),

                const SizedBox(height: 16),

                // 3. Operational Pulse Metrics
                const _OperationalPulseRow(),

                const SizedBox(height: 24),

                // 4. Command Strip (Quick Action Matrix)
                const _SectionTitle(
                  title: 'Command Center',
                  subtitle: 'Quick operational actions and workflows',
                ),
                const SizedBox(height: 12),
                const _CommandGrid(),
                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: () {
                    context.push(RouteNames.ownerPayments);
                  },
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Payment Management'),
                ),
                const SizedBox(height: 24),

                // 5. Active Property Portfolio Snapshot (Horizontal Deck)
                const _PropertySnapshotSection(),

                const SizedBox(height: 24),

                // 6. Management Hub (Navigation Modules)
                const _SectionTitle(
                  title: 'Enterprise Management',
                  subtitle:
                      'In-depth directory records and automated billing rules',
                ),
                const SizedBox(height: 12),
                const _EnterpriseHub(),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.home,
        onHomeTap: () {
          context.go(RouteNames.ownerHome);
        },
        onMoreTap: () {
          context.push(RouteNames.more);
        },
      ),
    );
  }
}

// ============================================================================
// 1. EXECUTIVE HEADER
// ============================================================================

class _ExecutiveHeader extends StatelessWidget {
  final String name;
  final String publicId;

  const _ExecutiveHeader({required this.name, required this.publicId});

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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
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
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  name,
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
                    content: Text('Owner ID copied to clipboard.'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fingerprint_rounded,
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
      ),
    );
  }
}

// ============================================================================
// 2. PORTFOLIO VAULT & FINANCIAL HERO CARD
// ============================================================================

class _PortfolioVaultCard extends ConsumerWidget {
  const _PortfolioVaultCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tenantsAsync = ref.watch(ownerTenantsProvider);
    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [const Color(0xFF1E222D), const Color(0xFF141720)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ambient Glow Background Element
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.22),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            Icons.shield_outlined,
                            size: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PORTFOLIO REVENUE VAULT',
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
                        color: Colors.teal.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.teal.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Text(
                        'Live Run-Rate',
                        style: TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Primary Estimated Revenue
                Text(
                  'Projected Monthly Rent',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      '৳ ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '0.00',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '/ month',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                const SizedBox(height: 14),

                // Secondary Metrics Row: Occupancy Health
                propertiesAsync.when(
                  loading: () => const SizedBox(
                    height: 18,
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (properties) {
                    final totalProperties = properties.length;

                    return tenantsAsync.maybeWhen(
                      data: (tenants) {
                        final activeTenants = tenants
                            .where((t) => t.status == TenantStatus.active)
                            .length;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _VaultSubMetric(
                              label: 'Active Leases',
                              value: '$activeTenants Tenancies',
                              icon: Icons.verified_user_outlined,
                            ),
                            Container(
                              width: 1,
                              height: 28,
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            _VaultSubMetric(
                              label: 'Real Estate Estate',
                              value:
                                  '$totalProperties ${totalProperties == 1 ? 'Building' : 'Buildings'}',
                              icon: Icons.domain_rounded,
                            ),
                            Container(
                              width: 1,
                              height: 28,
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            const _VaultSubMetric(
                              label: 'Pending Invoices',
                              value: '0 Unsettled',
                              icon: Icons.receipt_long_outlined,
                            ),
                          ],
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultSubMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _VaultSubMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white60),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// 3. OPERATIONAL PULSE ROW
// ============================================================================

class _OperationalPulseRow extends ConsumerWidget {
  const _OperationalPulseRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);
    final tenantsAsync = ref.watch(ownerTenantsProvider);

    return Row(
      children: [
        Expanded(
          child: _PulseTile(
            title: 'Buildings',
            value: propertiesAsync.when(
              loading: () => '...',
              error: (_, _) => '0',
              data: (properties) => '${properties.length}',
            ),
            icon: Icons.domain_rounded,
            color: Colors.indigo,
            onTap: () => context.push(RouteNames.propertyList),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PulseTile(
            title: 'Residents',
            value: tenantsAsync.when(
              loading: () => '...',
              error: (_, _) => '0',
              data: (tenants) {
                final active = tenants
                    .where((t) => t.status == TenantStatus.active)
                    .length;
                return '$active';
              },
            ),
            icon: Icons.group_rounded,
            color: Colors.teal,
            onTap: () => context.push(RouteNames.ownerTenants),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PulseTile(
            title: 'Past Leases',
            value: tenantsAsync.when(
              loading: () => '...',
              error: (_, _) => '0',
              data: (tenants) {
                final inactive = tenants
                    .where((t) => t.status == TenantStatus.inactive)
                    .length;
                return '$inactive';
              },
            ),
            icon: Icons.history_rounded,
            color: Colors.amber.shade900,
            onTap: () => context.push(RouteNames.ownerTenants),
          ),
        ),
      ],
    );
  }
}

class _PulseTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PulseTile({
    required this.title,
    required this.value,
    required this.icon,
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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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
// 4. COMMAND GRID (ASYMMETRIC QUICK ACTIONS)
// ============================================================================

class _CommandGrid extends ConsumerWidget {
  const _CommandGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Primary Action Hero Strip: Register New Resident
        Material(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(RouteNames.addTenant),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Register New Resident',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Assign vacant units and dispatch tenancy invites',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Sub Actions (3 Horizontal Tiles)
        Row(
          children: [
            Expanded(
              child: _SubActionTile(
                icon: Icons.add_home_work_rounded,
                title: 'Add Building',
                color: Colors.teal,
                onTap: () async {
                  await context.push(RouteNames.addProperty);
                  if (!context.mounted) {
                    return;
                  }
                  ref.invalidate(currentOwnerPropertiesProvider);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SubActionTile(
                icon: Icons.receipt_long_rounded,
                title: 'Billing Rules',
                color: Colors.deepPurpleAccent,
                onTap: () => context.push(RouteNames.ownerBillingRules),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SubActionTile(
                icon: Icons.send_rounded,
                title: 'Invitations',
                color: Colors.amber.shade900,
                onTap: () => context.push(RouteNames.ownerTenants),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SubActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _SubActionTile({
    required this.icon,
    required this.title,
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
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
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
// 5. PROPERTY SNAPSHOT SECTION (HORIZONTAL PREVIEW CAROUSEL)
// ============================================================================

class _PropertySnapshotSection extends ConsumerWidget {
  const _PropertySnapshotSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle(
              title: 'Portfolio Buildings',
              subtitle: 'Active real estate assets and flat distribution',
            ),
            TextButton(
              onPressed: () => context.push(RouteNames.propertyList),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        propertiesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (err, stack) => Text('Unable to load properties: $err'),
          data: (properties) {
            if (properties.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.domain_disabled_rounded,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No properties onboarded yet.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Register your first building to start managing units and tenants.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => context.push(RouteNames.addProperty),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add First Building'),
                    ),
                  ],
                ),
              );
            }

            return SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: properties.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final property = properties[index];
                  return _PropertyMiniCard(property: property);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PropertyMiniCard extends StatelessWidget {
  final Property property;

  const _PropertyMiniCard({required this.property});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = property.status == PropertyStatus.active;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push(
            RouteNames.propertyDetails.replaceFirst(':propertyId', property.id),
          );
        },
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.apartment_rounded,
                      size: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                property.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${property.numberOfFloors} Floors • Code: ${property.propertyCode}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
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
// 6. ENTERPRISE MANAGEMENT HUB
// ============================================================================

class _EnterpriseHub extends StatelessWidget {
  const _EnterpriseHub();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _HubActionTile(
            icon: Icons.holiday_village_outlined,
            title: 'Property & Spaces Directory',
            subtitle: 'Buildings, residential units, and floor configurations',
            tag: 'View All',
            onTap: () => context.push(RouteNames.propertyList),
          ),
          const Divider(height: 1, indent: 64),
          _HubActionTile(
            icon: Icons.badge_outlined,
            title: 'Tenants & Residency Directory',
            subtitle:
                'Manage verified member accounts, agreements, and vacated records',
            tag: 'Residents',
            onTap: () => context.push(RouteNames.ownerTenants),
          ),
          const Divider(height: 1, indent: 64),
          _HubActionTile(
            icon: Icons.tune_rounded,
            title: 'Automated Billing & Invoicing Engine',
            subtitle:
                'Utility tariff rates, recurring rent cycles, and manual bill generation',
            tag: 'Billing',
            onTap: () => context.push(RouteNames.ownerBillingRules),
          ),
        ],
      ),
    );
  }
}

class _HubActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  final VoidCallback onTap;

  const _HubActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22, color: theme.colorScheme.primary),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.3,
          ),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}

// ============================================================================
// SECTION TITLE
// ============================================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

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
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// ERROR VIEW
// ============================================================================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

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
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
