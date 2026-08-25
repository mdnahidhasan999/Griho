import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';

import '../../domain/entities/tenant.dart';
import '../providers/property_tenants_provider.dart';

class PropertyTenantsScreen extends ConsumerWidget {
  final String propertyId;
  final String propertyName;

  const PropertyTenantsScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  Future<void> _addTenant(
      BuildContext context,
      WidgetRef ref,
      ) async {
    final result = await context.push(
      RouteNames.addTenant,
    );

    if (!context.mounted) {
      return;
    }

    if (result != null) {
      ref.invalidate(
        propertyTenantsProvider(propertyId),
      );
    }
  }

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final tenantsAsync = ref.watch(
      propertyTenantsProvider(propertyId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$propertyName Tenants',
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _addTenant(context, ref);
        },
        icon: const Icon(
          Icons.person_add_alt_1,
        ),
        label: const Text(
          'Add Tenant',
        ),
      ),

      body: tenantsAsync.when(
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },

        error: (error, stackTrace) {
          return _TenantErrorView(
            error: error,
            onRetry: () {
              ref.invalidate(
                propertyTenantsProvider(propertyId),
              );
            },
          );
        },

        data: (tenants) {
          if (tenants.isEmpty) {
            return _EmptyTenantView(
              onAddTenant: () {
                _addTenant(
                  context,
                  ref,
                );
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                propertyTenantsProvider(propertyId),
              );

              await ref.read(
                propertyTenantsProvider(propertyId).future,
              );
            },

            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                100,
              ),

              itemCount: tenants.length,

              separatorBuilder: (
                  context,
                  index,
                  ) {
                return const SizedBox(
                  height: 12,
                );
              },

              itemBuilder: (
                  context,
                  index,
                  ) {
                final tenant = tenants[index];

                return _TenantCard(
                  tenant: tenant,
                  onTap: () {
                    // Tenant Details will be added
                    // in the next step.
                  },
                );
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

class _TenantCard extends StatelessWidget {
  final Tenant tenant;
  final VoidCallback onTap;

  const _TenantCard({
    required this.tenant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,

        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ------------------------------------------------------------
              // AVATAR
              // ------------------------------------------------------------

              CircleAvatar(
                radius: 26,
                child: Text(
                  _initial(
                    tenant.name,
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              // ------------------------------------------------------------
              // TENANT INFO
              // ------------------------------------------------------------

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
                          .titleMedium,
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      tenant.phone,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),

                    if (tenant.email != null &&
                        tenant.email!
                            .trim()
                            .isNotEmpty) ...[
                      const SizedBox(
                        height: 3,
                      ),

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

                    const SizedBox(
                      height: 8,
                    ),

                    _TenantStatusChip(
                      status: tenant.status,
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              const Icon(
                Icons.chevron_right,
              ),
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

  const _TenantStatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final bool isActive =
        status == TenantStatus.active;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),

      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,

        borderRadius:
        BorderRadius.circular(20),
      ),

      child: Text(
        isActive
            ? 'Active'
            : 'Inactive',

        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(
          color: isActive
              ? colorScheme
              .onPrimaryContainer
              : colorScheme
              .onSurfaceVariant,
          fontWeight:
          FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY VIEW
// ============================================================================

class _EmptyTenantView extends StatelessWidget {
  final VoidCallback onAddTenant;

  const _EmptyTenantView({
    required this.onAddTenant,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),

            const SizedBox(
              height: 20,
            ),

            Text(
              'No tenants yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              'Add a tenant to this property.',
              textAlign:
              TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),

            const SizedBox(
              height: 24,
            ),

            FilledButton.icon(
              onPressed: onAddTenant,
              icon: const Icon(
                Icons.person_add_alt_1,
              ),
              label: const Text(
                'Add Tenant',
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

class _TenantErrorView
    extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _TenantErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            Icon(
              Icons.error_outline,
              size: 52,
              color: Theme.of(context)
                  .colorScheme
                  .error,
            ),

            const SizedBox(
              height: 16,
            ),

            Text(
              'Unable to load tenants.',
              textAlign:
              TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),

            const SizedBox(
              height: 12,
            ),

            Text(
              error.toString(),
              textAlign:
              TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),

            const SizedBox(
              height: 20,
            ),

            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}