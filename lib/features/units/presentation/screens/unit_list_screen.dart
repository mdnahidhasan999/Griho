import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../domain/entities/unit.dart';
import '../providers/property_units_provider.dart';

class UnitListScreen extends ConsumerWidget {
  final String propertyId;
  final String propertyName;
  final int numberOfFloors;

  const UnitListScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
    required this.numberOfFloors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(propertyUnitsProvider(propertyId));

    return Scaffold(
      appBar: AppBar(title: Text('$propertyName Units')),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push<Unit>(
            RouteNames.addUnit.replaceFirst(':propertyId', propertyId),
            extra: numberOfFloors,
          );

          if (result != null && context.mounted) {
            ref.invalidate(propertyUnitsProvider(propertyId));
          }
        },

        icon: const Icon(Icons.add),

        label: const Text('Add Unit'),
      ),

      body: unitsAsync.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },

        error: (error, stackTrace) {
          return _UnitErrorView(
            onRetry: () {
              ref.invalidate(propertyUnitsProvider(propertyId));
            },
          );
        },

        data: (units) {
          if (units.isEmpty) {
            return _EmptyUnitsView(
              onAddUnit: () async {
                final result = await context.push<Unit>(
                  RouteNames.addUnit.replaceFirst(':propertyId', propertyId),
                  extra: numberOfFloors,
                );

                if (result != null && context.mounted) {
                  ref.invalidate(propertyUnitsProvider(propertyId));
                }
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(propertyUnitsProvider(propertyId));

              await ref.read(propertyUnitsProvider(propertyId).future);
            },

            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),

              itemCount: units.length,

              separatorBuilder: (context, index) {
                return const SizedBox(height: 12);
              },

              itemBuilder: (context, index) {
                return _UnitCard(unit: units[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final Unit unit;

  const _UnitCard({required this.unit});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push(RouteNames.unitDetails.replaceFirst(':unitId', unit.id));
        },

        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const CircleAvatar(child: Icon(Icons.apartment_outlined)),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.unitNumber,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Floor ${unit.floorNumber}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),

                    if (unit.name != null && unit.name!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),

                      Text(
                        unit.name!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],

                    if (unit.monthlyRent != null) ...[
                      const SizedBox(height: 4),

                      Text(
                        '৳ ${unit.monthlyRent!.toStringAsFixed(0)} / month',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],

                    const SizedBox(height: 8),

                    _UnitStatusChip(status: unit.status),
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

class _UnitStatusChip extends StatelessWidget {
  final UnitStatus status;

  const _UnitStatusChip({required this.status});

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

  String _statusLabel(UnitStatus status) {
    switch (status) {
      case UnitStatus.available:
        return 'Available';

      case UnitStatus.occupied:
        return 'Occupied';

      case UnitStatus.reserved:
        return 'Reserved';

      case UnitStatus.inactive:
        return 'Inactive';
    }
  }
}

class _EmptyUnitsView extends StatelessWidget {
  final VoidCallback onAddUnit;

  const _EmptyUnitsView({required this.onAddUnit});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.apartment_outlined, size: 56),

            const SizedBox(height: 16),

            Text('No units yet', style: Theme.of(context).textTheme.titleLarge),

            const SizedBox(height: 8),

            const Text(
              'Add your first unit to this property.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: onAddUnit,
              icon: const Icon(Icons.add),
              label: const Text('Add Unit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _UnitErrorView({required this.onRetry});

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

            const Text('Unable to load units.', textAlign: TextAlign.center),

            const SizedBox(height: 16),

            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
