import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../domain/entities/property.dart';
import '../providers/current_owner_properties_provider.dart';

class PropertyListScreen extends ConsumerWidget {
  const PropertyListScreen({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final propertiesAsync = ref.watch(
      currentOwnerPropertiesProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Properties'),
      ),
      body: propertiesAsync.when(
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          return _ErrorView(
            onRetry: () {
              ref.invalidate(
                currentOwnerPropertiesProvider,
              );
            },
          );
        },
        data: (properties) {
          if (properties.isEmpty) {
            return const _EmptyPropertiesView();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                currentOwnerPropertiesProvider,
              );

              await ref.read(
                currentOwnerPropertiesProvider.future,
              );
            },
            child: ListView.separated(
              physics:
              const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: properties.length,
              separatorBuilder: (context, index) {
                return const SizedBox(
                  height: 12,
                );
              },
              itemBuilder: (context, index) {
                final property =
                properties[index];

                return _PropertyCard(
                  propertyId: property.id,
                  name: property.name,
                  address: property.address,
                  type: property.type,
                  status: property.status,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final String propertyId;
  final String name;
  final String? address;
  final PropertyType type;
  final PropertyStatus status;

  const _PropertyCard({
    required this.propertyId,
    required this.name,
    required this.address,
    required this.type,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final route =
          RouteNames.propertyDetails
              .replaceFirst(
            ':propertyId',
            propertyId,
          );

          context.push(route);
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(
                Icons.home_work_outlined,
                size: 34,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium,
                    ),
                    if (address != null &&
                        address!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        address!,
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _propertyTypeLabel(type),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall,
                        ),
                        const SizedBox(width: 8),
                        const Text('•'),
                        const SizedBox(width: 8),
                        Text(
                          _propertyStatusLabel(status),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _propertyTypeLabel(
      PropertyType type,
      ) {
    switch (type) {
      case PropertyType.residential:
        return 'Residential';

      case PropertyType.commercial:
        return 'Commercial';

      case PropertyType.mixedUse:
        return 'Mixed Use';
    }
  }

  String _propertyStatusLabel(
      PropertyStatus status,
      ) {
    switch (status) {
      case PropertyStatus.active:
        return 'Active';

      case PropertyStatus.inactive:
        return 'Inactive';
    }
  }
}

class _EmptyPropertiesView
    extends StatelessWidget {
  const _EmptyPropertiesView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.home_work_outlined,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              'No properties yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first property to get started.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({
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
            const Text(
              'Unable to load your properties.',
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