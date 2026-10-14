import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/unit_provider.dart';
import '../../domain/entities/tenant.dart';
import '../providers/property_tenants_provider.dart';
import 'tenant_details_screen.dart';

class PropertyTenantsScreen extends ConsumerStatefulWidget {
  final String propertyId;
  final String propertyName;

  const PropertyTenantsScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  @override
  ConsumerState<PropertyTenantsScreen> createState() =>
      _PropertyTenantsScreenState();
}

class _PropertyTenantsScreenState extends ConsumerState<PropertyTenantsScreen> {
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

  Future<void> _addTenant() async {
    final result = await context.push(RouteNames.addTenant);
    if (!mounted) {
      return;
    }

    if (result != null) {
      ref.invalidate(propertyTenantsProvider(widget.propertyId));
    }
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
      ref.invalidate(propertyTenantsProvider(widget.propertyId));
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tenantsAsync = ref.watch(propertyTenantsProvider(widget.propertyId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          '${widget.propertyName} Residents',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTenant,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Add Tenant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: tenantsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _TenantErrorView(
              error: error,
              onRetry: () {
                ref.invalidate(propertyTenantsProvider(widget.propertyId));
              },
            ),
        data: (tenants) {
          final totalCount = tenants.length;
          final activeCount =
              tenants
                  .where((t) => t.status == TenantStatus.active)
                  .length;
          final inactiveCount = totalCount - activeCount;

          final filteredTenants = _filterTenants(tenants);
          final sortedTenants = _sortTenants(filteredTenants);

          final activeTenants = sortedTenants
              .where((t) => t.status == TenantStatus.active)
              .toList();
          final inactiveTenants = sortedTenants
              .where((t) => t.status == TenantStatus.inactive)
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(propertyTenantsProvider(widget.propertyId));
              await ref.read(propertyTenantsProvider(widget.propertyId).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                // 1. Property Overview Header
                _PropertyOverviewCard(
                  propertyName: widget.propertyName,
                  totalCount: totalCount,
                  activeCount: activeCount,
                  inactiveCount: inactiveCount,
                ),

                const SizedBox(height: 16),

                // 2. Search Field
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search residents in this building...',
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
                      borderSide:
                      BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                      BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // 3. Results Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _searchQuery.isEmpty
                          ? 'Assigned Residents ($totalCount)'
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
                  _EmptyTenantView(onAddTenant: _addTenant)
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
// PROPERTY OVERVIEW CARD
// ============================================================================

class _PropertyOverviewCard extends StatelessWidget {
  final String propertyName;
  final int totalCount;
  final int activeCount;
  final int inactiveCount;

  const _PropertyOverviewCard({
    required this.propertyName,
    required this.totalCount,
    required this.activeCount,
    required this.inactiveCount,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.apartment_rounded,
                  size: 26,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      propertyName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Resident Directory & Tenancy Records',
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
                  label: 'Total Tenants',
                  value: '$totalCount',
                  icon: Icons.people_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBadge(
                  label: 'Active',
                  value: '$activeCount',
                  icon: Icons.check_circle_outline_rounded,
                  highlightColor: Colors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBadge(
                  label: 'Inactive',
                  value: '$inactiveCount',
                  icon: Icons.pause_circle_outline_rounded,
                  highlightColor: Colors.orange,
                ),
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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

              // Tenant Details
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

                    const SizedBox(height: 10),

                    // Unit Badge
                    unitAsync.when(
                      loading: () => const _MiniBadgeLoading(),
                      error: (_, _) =>
                      const _UnitBadge(
                        text: 'Unit unavailable',
                      ),
                      data: (Unit? unit) =>
                          _UnitBadge(
                            text: _unitDisplayName(unit),
                          ),
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
      return '$name • Floor ${unit.floorNumber}';
    }

    return 'Unit ${unit.unitNumber} • Floor ${unit.floorNumber}';
  }

  static String _initials(String name) {
    final value = name.trim();
    if (value.isEmpty) {
      return 'T';
    }

    final parts =
    value.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ============================================================================
// UNIT BADGE
// ============================================================================

class _UnitBadge extends StatelessWidget {
  final String text;

  const _UnitBadge({required this.text});

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
          Icon(
            Icons.door_front_door_outlined,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
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
  const _MiniBadgeLoading();

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
          Icon(
            Icons.door_front_door_outlined,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
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
// STATUS CHIP
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
                color:
                theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
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
              'No Residents in this Property',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Assign a resident to an available unit in this building and send an onboarding invitation.',
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
              'No resident matches "$query" in this building.',
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

class _TenantErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _TenantErrorView({
    required this.error,
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
            const Text(
              'Unable to load tenants for this property.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme
                  .of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: Theme
                    .of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
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
