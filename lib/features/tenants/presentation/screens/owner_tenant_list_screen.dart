// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/tenant.dart';
import '../providers/owner_tenants_provider.dart';
import '../widgets/tenant_ui_helpers.dart';
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
    setState(() => _searchQuery = value);
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
        builder: (_) => TenantDetailsScreen(tenantId: tenant.id),
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
    final created = await context.push<Tenant>(RouteNames.addTenant);
    if (!mounted) {
      return;
    }
    // Only invalidate if a new tenant was actually created.
    if (created != null) {
      ref.invalidate(ownerTenantsProvider);
    }
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
      appBar: AppBar(title: const Text('My Tenants')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTenant,
        icon: const Icon(Iconsax.user_add),
        label: const Text(
          'Add Tenant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: tenantsAsync.when(
        loading: () => const GrihoLoadingView(message: 'Loading tenants...'),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load tenants',
              subtitle: 'Please check your connection and try again.',
              actionLabel: 'Retry',
              onAction: _refreshTenants,
            ),
          ),
        ),
        data: (tenants) {
          final totalCount = tenants.length;
          final totalActive = tenants
              .where((t) => t.status == TenantStatus.active)
              .length;
          final totalInactive = totalCount - totalActive;

          final sortedTenants = _sortTenants(_filterTenants(tenants));
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
                Row(
                  children: [
                    Expanded(
                      child: TenantMetricBadge(
                        label: 'Total Tenants',
                        value: '$totalCount',
                        icon: Iconsax.people,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TenantMetricBadge(
                        label: 'Active',
                        value: '$totalActive',
                        icon: Iconsax.tick_circle,
                        highlightColor: GrihoColors.emerald,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TenantMetricBadge(
                        label: 'Inactive',
                        value: '$totalInactive',
                        icon: Iconsax.pause_circle,
                        highlightColor: GrihoColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, email, NID...',
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
                          ? 'All Residents ($totalCount)'
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
                    title: 'No Tenants Assigned Yet',
                    subtitle:
                    'Add your first resident to allocate an apartment space and dispatch onboarding links.',
                    actionLabel: 'Add Tenant',
                    onAction: _openAddTenant,
                  )
                else if (sortedTenants.isEmpty)
                  GrihoStatusState(
                    icon: Iconsax.search_normal_1,
                    title: 'No matching residents found',
                    subtitle:
                    'No resident matches "$_searchQuery". Check for typos or try searching by phone or NID.',
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
                            showPropertyBadge: true,
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
                            showPropertyBadge: true,
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
