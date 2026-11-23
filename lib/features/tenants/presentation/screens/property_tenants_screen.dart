// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/tenant.dart';
import '../providers/property_tenants_provider.dart';
import '../widgets/tenant_ui_helpers.dart';
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
    setState(() => _searchQuery = value);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _addTenant() async {
    final result = await context.push<Tenant>(RouteNames.addTenant);
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
        builder: (_) => TenantDetailsScreen(tenantId: tenant.id),
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
      appBar: AppBar(title: Text('${widget.propertyName} Residents')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTenant,
        icon: const Icon(Iconsax.user_add),
        label: const Text(
          'Add Tenant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: tenantsAsync.when(
        loading: () => const GrihoLoadingView(message: 'Loading residents...'),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load tenants',
              subtitle: error.toString(),
              actionLabel: 'Retry',
              onAction: () =>
                  ref.invalidate(propertyTenantsProvider(widget.propertyId)),
            ),
          ),
        ),
        data: (tenants) {
          final totalCount = tenants.length;
          final activeCount = tenants
              .where((t) => t.status == TenantStatus.active)
              .length;
          final inactiveCount = totalCount - activeCount;

          final sortedTenants = _sortTenants(_filterTenants(tenants));
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
                _PropertyOverviewCard(
                  propertyName: widget.propertyName,
                  totalCount: totalCount,
                  activeCount: activeCount,
                  inactiveCount: inactiveCount,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search residents in this building...',
                    prefixIcon: const Icon(
                      Iconsax.search_normal_1,
                      size: 19,
                      color: GrihoColors.emerald,
                    ),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                      onPressed: _searchController.clear,
                      icon: const Icon(Iconsax.close_circle, size: 19),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
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
                        onPressed: _searchController.clear,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('Reset'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (tenants.isEmpty)
                  GrihoStatusState(
                    icon: Iconsax.people,
                    title: 'No Residents in this Property',
                    subtitle:
                    'Assign a resident to an available unit in this building and send an onboarding invitation.',
                    actionLabel: 'Add Tenant',
                    onAction: _addTenant,
                  )
                else if (sortedTenants.isEmpty)
                  GrihoStatusState(
                    icon: Iconsax.search_normal_1,
                    title: 'No matching residents found',
                    subtitle:
                    'No resident matches "$_searchQuery" in this building.',
                  )
                else ...[
                    if (activeTenants.isNotEmpty) ...[
                      TenantSectionHeader(
                        title: 'Active Residents',
                        count: activeTenants.length,
                        icon: Iconsax.verify,
                        color: GrihoColors.emerald,
                      ),
                      const SizedBox(height: 10),
                      for (final tenant in activeTenants)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TenantListCard(
                            tenant: tenant,
                            onTap: () => _openTenantDetails(tenant),
                          ),
                        ),
                    ],
                    if (inactiveTenants.isNotEmpty) ...[
                      if (activeTenants.isNotEmpty) const SizedBox(height: 12),
                      TenantSectionHeader(
                        title: 'Inactive / Vacated',
                        count: inactiveTenants.length,
                        icon: Iconsax.clock,
                        color: GrihoColors.warning,
                      ),
                      const SizedBox(height: 10),
                      for (final tenant in inactiveTenants)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TenantListCard(
                            tenant: tenant,
                            onTap: () => _openTenantDetails(tenant),
                          ),
                        ),
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
                  Iconsax.buildings_2,
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
                child: TenantMetricBadge(
                  label: 'Total Tenants',
                  value: '$totalCount',
                  icon: Iconsax.people,
                  filled: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TenantMetricBadge(
                  label: 'Active',
                  value: '$activeCount',
                  icon: Iconsax.tick_circle,
                  highlightColor: GrihoColors.emerald,
                  filled: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TenantMetricBadge(
                  label: 'Inactive',
                  value: '$inactiveCount',
                  icon: Iconsax.pause_circle,
                  highlightColor: GrihoColors.warning,
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
