import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/unit_provider.dart';
import '../../domain/entities/tenant.dart';
import '../providers/owner_tenants_provider.dart';
import 'tenant_details_screen.dart';

class OwnerTenantListScreen extends ConsumerStatefulWidget {
  const OwnerTenantListScreen({super.key});

  @override
  ConsumerState<OwnerTenantListScreen> createState() =>
      _OwnerTenantListScreenState();
}

class _OwnerTenantListScreenState extends ConsumerState<OwnerTenantListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final value = _searchController.text.trim().toLowerCase();
    if (value == _searchQuery) {
      return;
    }

    setState(() {
      _searchQuery = value;
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  List<Tenant> _filterTenants(List<Tenant> tenants) {
    if (_searchQuery.isEmpty) {
      return List<Tenant>.from(tenants);
    }

    return tenants.where((tenant) {
      final name = tenant.name.toLowerCase();
      final phone = tenant.phone.toLowerCase();
      final email = tenant.email?.toLowerCase() ?? '';
      final nid = tenant.nidNumber?.toLowerCase() ?? '';

      return name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          nid.contains(_searchQuery);
    }).toList();
  }

  List<Tenant> _sortTenants(List<Tenant> tenants) {
    final sorted = List<Tenant>.from(tenants);

    sorted.sort((a, b) {
      final aIsActive = a.status == TenantStatus.active;
      final bIsActive = b.status == TenantStatus.active;

      if (aIsActive == bIsActive) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }

      return aIsActive ? -1 : 1;
    });

    return sorted;
  }

  Future<void> _openTenantDetails(Tenant tenant) async {
    final shouldRefresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            TenantDetailsScreen(
              tenantId: tenant.id,
            ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (shouldRefresh == true) {
      ref.invalidate(ownerTenantsProvider);
    }
  }

  Future<void> _openAddTenant() async {
    await context.push(RouteNames.addTenant);
    if (!mounted) {
      return;
    }
    ref.invalidate(ownerTenantsProvider);
  }

  Future<void> _refreshTenants() async {
    ref.invalidate(ownerTenantsProvider);
    await ref.read(ownerTenantsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tenantsAsync = ref.watch(ownerTenantsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'My Tenants',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTenant,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Add Tenant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: tenantsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _ErrorView(
              message: 'Unable to load your tenants.',
              onRetry: _refreshTenants,
            ),
        data: (tenants) {
          final totalCount = tenants.length;
          final filteredTenants = _filterTenants(tenants);
          final sortedTenants = _sortTenants(filteredTenants);

          final activeTenants = sortedTenants
              .where((t) => t.status == TenantStatus.active)
              .toList();

          final inactiveTenants = sortedTenants
              .where((t) => t.status == TenantStatus.inactive)
              .toList();

          return RefreshIndicator(
            onRefresh: _refreshTenants,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                // 1. Overview Metric Badges
                Row(
                  children: [
                    Expanded(
                      child: _MetricBadge(
                        label: 'Total Tenants',
                        value: '$totalCount',
                        icon: Icons.people_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricBadge(
                        label: 'Active',
                        value: '${tenants
                            .where((t) => t.status == TenantStatus.active)
                            .length}',
                        icon: Icons.check_circle_outline_rounded,
                        highlightColor: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricBadge(
                        label: 'Inactive',
                        value: '${tenants
                            .where((t) => t.status == TenantStatus.inactive)
                            .length}',
                        icon: Icons.pause_circle_outline_rounded,
                        highlightColor: Colors.orange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 2. Search Input Field
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, email, NID...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                      onPressed: () {
                        _searchController.clear();
                      },
                      icon: const Icon(Icons.clear_rounded, size: 20),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // 3. Search Results Count Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _searchQuery.isEmpty
                          ? 'All Residents ($totalCount)'
                          : 'Search Results (${sortedTenants.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('Reset'),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // 4. Content Streams
                if (tenants.isEmpty)
                  _EmptyTenantView(onAddTenant: _openAddTenant)
                else
                  if (sortedTenants.isEmpty)
                    _NoSearchResultView(query: _searchQuery)
                  else
                    ...[
                      if (activeTenants.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'Active Residents',
                          count: activeTenants.length,
                          icon: Icons.verified_user_outlined,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(height: 10),
                        for (final tenant in activeTenants) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TenantCard(
                              tenant: tenant,
                              onTap: () {
                                _openTenantDetails(tenant);
                              },
                            ),
                          ),
                        ],
                      ],

                      if (inactiveTenants.isNotEmpty) ...[
                        if (activeTenants.isNotEmpty) const SizedBox(
                            height: 12),
                        _SectionHeader(
                          title: 'Inactive / Vacated',
                          count: inactiveTenants.length,
                          icon: Icons.history_rounded,
                          color: Colors.orange.shade800,
                        ),
                        const SizedBox(height: 10),
                        for (final tenant in inactiveTenants) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TenantCard(
                              tenant: tenant,
                              onTap: () {
                                _openTenantDetails(tenant);
                              },
                            ),
                          ),
                        ],
                      ],
                    ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// METRIC BADGE
// ============================================================================

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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 18,
            color: highlightColor ?? theme.colorScheme.primary,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
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
// SECTION HEADER
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color? color;

  const _SectionHeader({
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
        Icon(icon, size: 18, color: color ?? theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
// TENANT CARD
// ============================================================================

class _TenantCard extends ConsumerWidget {
  final Tenant tenant;
  final VoidCallback onTap;

  const _TenantCard({
    required this.tenant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final propertyAsync = ref.watch(propertyByIdProvider(tenant.propertyId));
    final unitAsync = ref.watch(unitByIdProvider(tenant.unitId));

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  _initials(tenant.name),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            tenant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TenantStatusChip(status: tenant.status),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tenant.phone,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    if (tenant.email != null &&
                        tenant.email!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.mail_outline_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              tenant.email!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Property & Unit Badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        propertyAsync.when(
                          loading: () =>
                          const _MiniBadgeLoading(
                            icon: Icons.apartment_rounded,
                          ),
                          error: (_, _) =>
                          const _MetaBadge(
                            icon: Icons.apartment_rounded,
                            text: 'Property unavailable',
                          ),
                          data: (Property? property) =>
                              _MetaBadge(
                                icon: Icons.apartment_rounded,
                                text: property?.name ?? 'Unknown Building',
                              ),
                        ),
                        unitAsync.when(
                          loading: () =>
                          const _MiniBadgeLoading(
                            icon: Icons.door_front_door_outlined,
                          ),
                          error: (_, _) =>
                          const _MetaBadge(
                            icon: Icons.door_front_door_outlined,
                            text: 'Unit unavailable',
                          ),
                          data: (Unit? unit) =>
                              _MetaBadge(
                                icon: Icons.door_front_door_outlined,
                                text: _unitDisplayName(unit),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 4),

              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _unitDisplayName(Unit? unit) {
    if (unit == null) {
      return 'Unit not found';
    }

    final name = unit.name?.trim();
    if (name != null && name.isNotEmpty) {
      return '$name (Unit ${unit.unitNumber})';
    }

    return 'Unit ${unit.unitNumber}';
  }

  static String _initials(String name) {
    final value = name.trim();
    if (value.isEmpty) {
      return 'T';
    }

    final parts = value
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ============================================================================
// META BADGE
// ============================================================================

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaBadge({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadgeLoading extends StatelessWidget {
  final IconData icon;

  const _MiniBadgeLoading({required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          const SizedBox(
            height: 10,
            width: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TENANT STATUS CHIP
// ============================================================================

class _TenantStatusChip extends StatelessWidget {
  final TenantStatus status;

  const _TenantStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == TenantStatus.active;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isActive
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.12),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isActive ? Colors.green.shade800 : Colors.orange.shade800,
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY VIEWS
// ============================================================================

class _EmptyTenantView extends StatelessWidget {
  final VoidCallback onAddTenant;

  const _EmptyTenantView({required this.onAddTenant});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Tenants Assigned Yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first resident to allocate an apartment space and dispatch onboarding links.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAddTenant,
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Add Tenant'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSearchResultView extends StatelessWidget {
  final String query;

  const _NoSearchResultView({required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              'No matching residents found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No resident matches "$query". Check for typos or try searching by phone number or NID.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
  final Future<void> Function() onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
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
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
