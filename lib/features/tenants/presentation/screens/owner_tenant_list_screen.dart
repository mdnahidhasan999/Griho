import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class _OwnerTenantListScreenState
    extends ConsumerState<OwnerTenantListScreen> {
  final TextEditingController _searchController =
  TextEditingController();

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
        return 0;
      }

      return aIsActive ? -1 : 1;
    });

    return sorted;
  }

  Future<void> _openTenantDetails(Tenant tenant) async {
    final shouldRefresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TenantDetailsScreen(
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

  Future<void> _refreshTenants() async {
    ref.invalidate(ownerTenantsProvider);

    await ref.read(ownerTenantsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(ownerTenantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tenants'),
      ),
      body: tenantsAsync.when(
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          return _ErrorView(
            message: 'Unable to load your tenants.',
            onRetry: _refreshTenants,
          );
        },
        data: (tenants) {
          final filteredTenants = _filterTenants(tenants);
          final sortedTenants = _sortTenants(filteredTenants);

          final activeTenants = sortedTenants
              .where(
                (tenant) =>
            tenant.status == TenantStatus.active,
          )
              .toList();

          final inactiveTenants = sortedTenants
              .where(
                (tenant) =>
            tenant.status == TenantStatus.inactive,
          )
              .toList();

          return RefreshIndicator(
            onRefresh: _refreshTenants,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Search Tenant',
                    hintText: 'Name, phone, email, NID...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                      onPressed: () {
                        _searchController.clear();
                      },
                      icon: const Icon(Icons.clear),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  _searchQuery.isEmpty
                      ? '${tenants.length} tenants'
                      : '${sortedTenants.length} result(s)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                const SizedBox(height: 20),

                if (tenants.isEmpty)
                  const _EmptyTenantView()
                else if (sortedTenants.isEmpty)
                  const _NoSearchResultView()
                else ...[
                    if (activeTenants.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'Active Tenants',
                        count: activeTenants.length,
                        icon: Icons.people_outline,
                      ),
                      const SizedBox(height: 12),
                      ...activeTenants.map(
                            (tenant) {
                          return Padding(
                            padding:
                            const EdgeInsets.only(bottom: 12),
                            child: _TenantCard(
                              tenant: tenant,
                              onTap: () {
                                _openTenantDetails(tenant);
                              },
                            ),
                          );
                        },
                      ),
                    ],

                    if (inactiveTenants.isNotEmpty) ...[
                      if (activeTenants.isNotEmpty)
                        const SizedBox(height: 8),

                      _SectionHeader(
                        title: 'Inactive Tenants',
                        count: inactiveTenants.length,
                        icon: Icons.person_off_outlined,
                      ),
                      const SizedBox(height: 12),
                      ...inactiveTenants.map(
                            (tenant) {
                          return Padding(
                            padding:
                            const EdgeInsets.only(bottom: 12),
                            child: _TenantCard(
                              tenant: tenant,
                              onTap: () {
                                _openTenantDetails(tenant);
                              },
                            ),
                          );
                        },
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

// ============================================================================
// SECTION HEADER
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 21,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
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
    final propertyAsync = ref.watch(
      propertyByIdProvider(tenant.propertyId),
    );

    final unitAsync = ref.watch(
      unitByIdProvider(tenant.unitId),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                child: Icon(
                  tenant.status == TenantStatus.active
                      ? Icons.person_outline
                      : Icons.person_off_outlined,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.name,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      tenant.phone,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),

                    if (tenant.email != null &&
                        tenant.email!
                            .trim()
                            .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tenant.email!,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),
                    ],

                    const SizedBox(height: 10),

                    propertyAsync.when(
                      loading: () =>
                      const _SmallLoadingRow(
                        icon: Icons.home_outlined,
                      ),
                      error: (_, _) =>
                      const _LocationRow(
                        icon: Icons.home_outlined,
                        text:
                        'Property unavailable',
                      ),
                      data: (Property? property) {
                        return _LocationRow(
                          icon: Icons.home_outlined,
                          text: property?.name ??
                              'Property not found',
                        );
                      },
                    ),

                    const SizedBox(height: 5),

                    unitAsync.when(
                      loading: () =>
                      const _SmallLoadingRow(
                        icon:
                        Icons.meeting_room_outlined,
                      ),
                      error: (_, _) =>
                      const _LocationRow(
                        icon:
                        Icons.meeting_room_outlined,
                        text: 'Unit unavailable',
                      ),
                      data: (Unit? unit) {
                        return _LocationRow(
                          icon:
                          Icons.meeting_room_outlined,
                          text:
                          _unitDisplayName(unit),
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    _TenantStatusChip(
                      status: tenant.status,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Padding(
                padding:
                const EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
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
      return name;
    }

    return unit.unitNumber;
  }
}

// ============================================================================
// LOCATION ROW
// ============================================================================

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _LocationRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SMALL LOADING
// ============================================================================

class _SmallLoadingRow extends StatelessWidget {
  final IconData icon;

  const _SmallLoadingRow({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
        ),
        const SizedBox(width: 7),
        const SizedBox(
          height: 14,
          width: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// STATUS
// ============================================================================

class _TenantStatusChip extends StatelessWidget {
  final TenantStatus status;

  const _TenantStatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isActive =
        status == TenantStatus.active;

    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY
// ============================================================================

class _EmptyTenantView extends StatelessWidget {
  const _EmptyTenantView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        vertical: 80,
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 60,
          ),
          SizedBox(height: 16),
          Text(
            'No tenants yet.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SEARCH EMPTY
// ============================================================================

class _NoSearchResultView extends StatelessWidget {
  const _NoSearchResultView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        vertical: 60,
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 56,
          ),
          SizedBox(height: 16),
          Text(
            'No tenant found.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR
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
              Icons.error_outline,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
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