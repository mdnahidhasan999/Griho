import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';

import '../../domain/entities/tenant.dart';

import '../providers/property_tenants_provider.dart';

class TenantListScreen extends ConsumerWidget {
  final String propertyId;
  final String propertyName;

  const TenantListScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  // ================================================================
  // ADD TENANT
  // ================================================================

  Future<void> _addTenant(BuildContext context, WidgetRef ref) async {
    final result = await context.push(RouteNames.addTenant);

    if (!context.mounted) {
      return;
    }

    if (result != null) {
      ref.invalidate(propertyTenantsProvider(propertyId));
    }
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(propertyTenantsProvider(propertyId));

    return Scaffold(
      appBar: AppBar(title: Text('$propertyName Tenants')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _addTenant(context, ref);
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Tenant'),
      ),
      body: tenantsAsync.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stackTrace) {
          return _TenantErrorView(
            error: error,
            onRetry: () {
              ref.invalidate(propertyTenantsProvider(propertyId));
            },
          );
        },
        data: (tenants) {
          if (tenants.isEmpty) {
            return _EmptyTenantsView(
              onAddTenant: () {
                _addTenant(context, ref);
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(propertyTenantsProvider(propertyId));

              await ref.read(propertyTenantsProvider(propertyId).future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: tenants.length,
              separatorBuilder: (context, index) {
                return const SizedBox(height: 12);
              },
              itemBuilder: (context, index) {
                final tenant = tenants[index];

                return _TenantCard(tenant: tenant, propertyId: propertyId);
              },
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// TENANT CARD
// ============================================================================

class _TenantCard extends ConsumerWidget {
  final Tenant tenant;
  final String propertyId;

  const _TenantCard({required this.tenant, required this.propertyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final result = await context.push(
            RouteNames.tenantDetails.replaceFirst(':tenantId', tenant.id),
          );

          if (!context.mounted) {
            return;
          }

          if (result == true) {
            ref.invalidate(propertyTenantsProvider(propertyId));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                child: Text(
                  _initial(tenant.name),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
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
                    _TenantStatusChip(status: tenant.status),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _initial(String name) {
    final value = name.trim();

    if (value.isEmpty) {
      return '?';
    }

    return value.characters.first.toUpperCase();
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
    final colorScheme = Theme.of(context).colorScheme;

    final isActive = status == TenantStatus.active;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isActive
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY TENANTS
// ============================================================================

class _EmptyTenantsView extends StatelessWidget {
  final VoidCallback onAddTenant;

  const _EmptyTenantsView({required this.onAddTenant});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 20),
            Text(
              'No tenants yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'No tenants have been added to this property yet.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddTenant,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Tenant'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR
// ============================================================================

class _TenantErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _TenantErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 52,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text('Unable to load tenants.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
