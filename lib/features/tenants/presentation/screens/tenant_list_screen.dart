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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(propertyTenantsProvider(propertyId));

    return Scaffold(
      appBar: AppBar(title: Text('$propertyName Tenants')),
      body: tenantsAsync.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stackTrace) {
          return _TenantErrorView(
            onRetry: () {
              ref.invalidate(propertyTenantsProvider(propertyId));
            },
          );
        },
        data: (tenants) {
          if (tenants.isEmpty) {
            return const _EmptyTenantsView();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(propertyTenantsProvider(propertyId));

              await ref.read(propertyTenantsProvider(propertyId).future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              itemCount: tenants.length,
              separatorBuilder: (context, index) {
                return const SizedBox(height: 12);
              },
              itemBuilder: (context, index) {
                return _TenantCard(tenant: tenants[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  final Tenant tenant;

  const _TenantCard({required this.tenant});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push(
            RouteNames.tenantDetails.replaceFirst(':tenantId', tenant.id),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
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
}

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
        _statusLabel(status),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }

  String _statusLabel(TenantStatus status) {
    switch (status) {
      case TenantStatus.active:
        return 'Active';

      case TenantStatus.inactive:
        return 'Inactive';
    }
  }
}

class _EmptyTenantsView extends StatelessWidget {
  const _EmptyTenantsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 56),

            const SizedBox(height: 16),

            Text(
              'No tenants yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 8),

            const Text(
              'No tenants have been added to this property yet.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _TenantErrorView({required this.onRetry});

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

            const Text('Unable to load tenants.', textAlign: TextAlign.center),

            const SizedBox(height: 16),

            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
