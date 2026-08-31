import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tenant.dart';
import '../providers/owner_tenants_provider.dart';

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
      return tenants;
    }

    return tenants.where((tenant) {
      final name = tenant.name.toLowerCase();

      final phone = tenant.phone.toLowerCase();

      final email = tenant.email?.toLowerCase() ?? '';

      final nid = tenant.nidNumber?.toLowerCase() ?? '';

      final propertyId = tenant.propertyId.toLowerCase();

      final unitId = tenant.unitId.toLowerCase();

      return name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          nid.contains(_searchQuery) ||
          propertyId.contains(_searchQuery) ||
          unitId.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(ownerTenantsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Tenants')),
      body: tenantsAsync.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stackTrace) {
          return _ErrorView(
            message: 'Unable to load your tenants.',
            onRetry: () {
              ref.invalidate(ownerTenantsProvider);
            },
          );
        },
        data: (tenants) {
          final filteredTenants = _filterTenants(tenants);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(ownerTenantsProvider);

              await ref.read(ownerTenantsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Search Tenant',
                    hintText: 'Name, phone, email, property ID...',
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
                      : '${filteredTenants.length} result(s)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (tenants.isEmpty)
                  const _EmptyTenantView()
                else if (filteredTenants.isEmpty)
                  const _NoSearchResultView()
                else
                  ...filteredTenants.map((tenant) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TenantCard(tenant: tenant),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==================================================================
// TENANT CARD
// ==================================================================

class _TenantCard extends StatelessWidget {
  final Tenant tenant;

  const _TenantCard({required this.tenant});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.person_outline)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tenant.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tenant.phone,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (tenant.email != null &&
                      tenant.email!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      tenant.email!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Property ID: ${tenant.propertyId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unit ID: ${tenant.unitId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  _TenantStatusChip(status: tenant.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// STATUS
// ==================================================================

class _TenantStatusChip extends StatelessWidget {
  final TenantStatus status;

  const _TenantStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        status == TenantStatus.active ? 'Active' : 'Inactive',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

// ==================================================================
// EMPTY
// ==================================================================

class _EmptyTenantView extends StatelessWidget {
  const _EmptyTenantView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 60),
          SizedBox(height: 16),
          Text('No tenants yet.', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ==================================================================
// SEARCH EMPTY
// ==================================================================

class _NoSearchResultView extends StatelessWidget {
  const _NoSearchResultView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 56),
          SizedBox(height: 16),
          Text('No tenant found.', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ==================================================================
// ERROR
// ==================================================================

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
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
