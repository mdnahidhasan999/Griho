// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/tenant.dart';
import '../providers/property_tenants_provider.dart';
import '../widgets/tenant_ui_helpers.dart';

class TenantListScreen extends ConsumerStatefulWidget {
  final String propertyId;
  final String propertyName;

  const TenantListScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  @override
  ConsumerState<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends ConsumerState<TenantListScreen> {
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
    final result = await context.push<bool>(
      RouteNames.tenantDetails.replaceFirst(':tenantId', tenant.id),
    );
    if (!mounted) {
      return;
    }
    if (result == true) {
      ref.invalidate(propertyTenantsProvider(widget.propertyId));
    }
  }

  List<Tenant> _filterAndSort(List<Tenant> tenants) {
    final filtered = _searchQuery.isEmpty
        ? List<Tenant>.from(tenants)
        : tenants.where((tenant) {
      final name = tenant.name.toLowerCase();
      final phone = tenant.phone.toLowerCase();
      final email = tenant.email?.toLowerCase() ?? '';
      final nid = tenant.nidNumber?.toLowerCase() ?? '';

      return name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          nid.contains(_searchQuery);
    }).toList();

    filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return filtered;
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
      body: SafeArea(
        child: tenantsAsync.when(
          loading: () => const GrihoLoadingView(message: 'Loading residents...'),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GrihoStatusState(
                icon: Iconsax.warning_2,
                title: 'Unable to load residents',
                subtitle: error.toString(),
                actionLabel: 'Retry',
                onAction: () =>
                    ref.invalidate(propertyTenantsProvider(widget.propertyId)),
              ),
            ),
          ),
          data: (tenants) {
            final activeTenants = tenants
                .where((tenant) => tenant.status == TenantStatus.active)
                .toList();
            final filteredTenants = _filterAndSort(activeTenants);

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(propertyTenantsProvider(widget.propertyId));
                await ref.read(
                  propertyTenantsProvider(widget.propertyId).future,
                );
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
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
                                widget.propertyName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Active Tenancy Directory',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: GrihoColors.emerald.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Iconsax.people,
                                size: 14,
                                color: GrihoColors.emerald,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${activeTenants.length} Active',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: GrihoColors.emerald,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText:
                      'Search active residents by name, phone, NID...',
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
                            ? 'Active Residents (${activeTenants.length})'
                            : 'Matching Results (${filteredTenants.length})',
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
                  if (activeTenants.isEmpty)
                    GrihoStatusState(
                      icon: Iconsax.people,
                      title: 'No Active Residents',
                      subtitle:
                      'There are currently no active residents occupying units in this property.',
                      actionLabel: 'Add Resident',
                      onAction: _addTenant,
                    )
                  else if (filteredTenants.isEmpty)
                    GrihoStatusState(
                      icon: Iconsax.search_normal_1,
                      title: 'No matching residents found',
                      subtitle:
                      'No resident matches "$_searchQuery" in this building.',
                    )
                  else
                    for (final tenant in filteredTenants)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TenantListCard(
                          tenant: tenant,
                          onTap: () => _openTenantDetails(tenant),
                        ),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
