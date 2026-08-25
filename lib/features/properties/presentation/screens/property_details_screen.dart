import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_arguments.dart';
import '../../../../app/router/route_names.dart';

import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/providers/property_tenants_provider.dart';

import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';

import '../../domain/entities/property.dart';
import '../controllers/property_controller.dart';
import '../providers/current_owner_properties_provider.dart';
import '../providers/property_usecase_provider.dart';

class PropertyDetailsScreen extends ConsumerStatefulWidget {
  final String propertyId;

  const PropertyDetailsScreen({super.key, required this.propertyId});

  @override
  ConsumerState<PropertyDetailsScreen> createState() =>
      _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends ConsumerState<PropertyDetailsScreen> {
  Property? _property;

  bool _isLoading = true;
  bool _isDeleting = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadProperty();
  }

  Future<void> _loadProperty() async {
    try {
      final getProperty = ref.read(getPropertyProvider);

      final property = await getProperty(widget.propertyId);

      if (!mounted) {
        return;
      }

      setState(() {
        _property = property;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _editProperty() async {
    final property = _property;

    if (property == null || _isDeleting) {
      return;
    }

    final route = RouteNames.editProperty.replaceFirst(
      ':propertyId',
      property.id,
    );

    final result = await context.push<Property>(route, extra: property);

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _property = result;
    });

    ref.invalidate(currentOwnerPropertiesProvider);

    ref.invalidate(propertyUnitsProvider(result.id));

    ref.invalidate(propertyTenantsProvider(result.id));

    await _loadProperty();
  }

  Future<void> _deleteProperty() async {
    final property = _property;

    if (property == null || _isDeleting) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Property?'),
          content: Text(
            'Are you sure you want to delete '
                '"${property.name}"?\n\n'
                'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    final controller = ref.read(propertyControllerProvider.notifier);

    final success = await controller.deleteProperty(propertyId: property.id);

    if (!mounted) {
      return;
    }

    if (success) {
      ref.invalidate(currentOwnerPropertiesProvider);

      context.pop();

      return;
    }

    setState(() {
      _isDeleting = false;
    });

    final errorMessage = ref
        .read(propertyControllerProvider)
        .errorMessage;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage ?? 'Unable to delete property.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Property Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Property Details')),
        body: _ErrorView(message: _errorMessage!, onRetry: _loadProperty),
      );
    }

    final property = _property;

    if (property == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Property Details')),
        body: const _NotFoundView(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Details'),
        actions: [
          IconButton(
            tooltip: 'Edit Property',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _isDeleting ? null : _editProperty,
          ),
          IconButton(
            tooltip: 'Delete Property',
            icon: const Icon(Icons.delete_outline),
            onPressed: _isDeleting ? null : _deleteProperty,
          ),
        ],
      ),
      body: Stack(
        children: [
          _PropertyDetails(property: property),
          if (_isDeleting)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Deleting property...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PropertyDetails extends ConsumerWidget {
  final Property property;

  const _PropertyDetails({required this.property});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(propertyUnitsProvider(property.id));

    final tenantsAsync = ref.watch(propertyTenantsProvider(property.id));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.home_work_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  property.name,
                  style: Theme
                      .of(context)
                      .textTheme
                      .headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _propertyTypeLabel(property.type),
                  style: Theme
                      .of(context)
                      .textTheme
                      .bodyMedium,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        _InfoCard(
          title: 'Property Information',
          children: [
            _InfoRow(
              label: 'Status',
              value: _propertyStatusLabel(property.status),
            ),
            _InfoRow(
              label: 'Number of Floors',
              value: property.numberOfFloors.toString(),
            ),
            _InfoRow(
              label: 'Address',
              value: property.address
                  ?.trim()
                  .isNotEmpty == true
                  ? property.address!
                  : 'Not provided',
            ),
            _InfoRow(
              label: 'Description',
              value: property.description
                  ?.trim()
                  .isNotEmpty == true
                  ? property.description!
                  : 'Not provided',
            ),
          ],
        ),

        const SizedBox(height: 20),

        _UnitsSection(
          propertyId: property.id,
          propertyName: property.name,
          numberOfFloors: property.numberOfFloors,
          unitsAsync: unitsAsync,
        ),

        const SizedBox(height: 20),

        _TenantsSection(
          propertyId: property.id,
          propertyName: property.name,
          tenantsAsync: tenantsAsync,
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  String _propertyTypeLabel(PropertyType type) {
    switch (type) {
      case PropertyType.residential:
        return 'Residential';

      case PropertyType.commercial:
        return 'Commercial';

      case PropertyType.mixedUse:
        return 'Mixed Use';
    }
  }

  String _propertyStatusLabel(PropertyStatus status) {
    switch (status) {
      case PropertyStatus.active:
        return 'Active';

      case PropertyStatus.inactive:
        return 'Inactive';
    }
  }
}

class _UnitsSection extends ConsumerWidget {
  final String propertyId;
  final String propertyName;
  final int numberOfFloors;

  final AsyncValue<List<Unit>> unitsAsync;

  const _UnitsSection({
    required this.propertyId,
    required this.propertyName,
    required this.numberOfFloors,
    required this.unitsAsync,
  });

  Future<void> _openUnitList(BuildContext context) async {
    await context.push(
      RouteNames.propertyUnits.replaceFirst(':propertyId', propertyId),
      extra: PropertyUnitsRouteArguments(
        propertyName: propertyName,
        numberOfFloors: numberOfFloors,
      ),
    );
  }

  Future<void> _addUnit(BuildContext context, WidgetRef ref) async {
    final result = await context.push<Unit>(
      RouteNames.addUnit.replaceFirst(':propertyId', propertyId),
      extra: numberOfFloors,
    );

    if (!context.mounted) {
      return;
    }

    if (result != null) {
      ref.invalidate(propertyUnitsProvider(propertyId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Units',
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _openUnitList(context);
                  },
                  child: const Text('View All'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            unitsAsync.when(
              loading: () {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              },

              error: (error, stackTrace) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Unable to load units.'),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodySmall,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(propertyUnitsProvider(propertyId));
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                );
              },

              data: (units) {
                if (units.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No units added yet.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          _addUnit(context, ref);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Unit'),
                      ),
                    ],
                  );
                }

                final previewUnits = units.take(5).toList();

                return Column(
                  children: [
                    for (
                    int index = 0;
                    index < previewUnits.length;
                    index++
                    ) ...[
                      _UnitCard(unit: previewUnits[index]),
                      if (index != previewUnits.length - 1)
                        const Divider(height: 24),
                    ],

                    if (units.length > 5) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            _openUnitList(context);
                          },
                          child: Text(
                            'View all '
                                '${units.length} units',
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final Unit unit;

  const _UnitCard({required this.unit});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: const CircleAvatar(child: Icon(Icons.apartment_outlined)),
      title: Text(
        unit.unitNumber,
        style: Theme
            .of(context)
            .textTheme
            .titleMedium,
      ),
      subtitle: Text('Floor ${unit.floorNumber}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        context.push(RouteNames.unitDetails.replaceFirst(':unitId', unit.id));
      },
    );
  }
}

class _TenantsSection extends ConsumerWidget {
  final String propertyId;
  final String propertyName;

  final AsyncValue<List<Tenant>> tenantsAsync;

  const _TenantsSection({
    required this.propertyId,
    required this.propertyName,
    required this.tenantsAsync,
  });

  Future<void> _openTenantList(BuildContext context) async {
    await context.push(
      RouteNames.propertyTenants.replaceFirst(':propertyId', propertyId),
      extra: PropertyTenantsRouteArguments(propertyName: propertyName),
    );
  }

  Future<void> _addTenant(BuildContext context, WidgetRef ref) async {
    await context.push(RouteNames.addTenant);

    if (!context.mounted) {
      return;
    }

    ref.invalidate(propertyTenantsProvider(propertyId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tenants',
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _openTenantList(context);
                  },
                  child: const Text('View All'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            tenantsAsync.when(
              loading: () {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              },

              error: (error, stackTrace) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unable to load tenants.',
                    ),

                    const SizedBox(height: 8),

                    SelectableText(
                      error.toString(),
                      style: TextStyle(
                        color: Theme
                            .of(context)
                            .colorScheme
                            .error,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 8),

                    SelectableText(
                      stackTrace.toString(),
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodySmall,
                    ),

                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(
                          propertyTenantsProvider(propertyId),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                );
              },

              data: (tenants) {
                if (tenants.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No tenants added yet.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          _addTenant(context, ref);
                        },
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Add Tenant'),
                      ),
                    ],
                  );
                }

                final previewTenants = tenants.take(5).toList();

                return Column(
                  children: [
                    for (
                    int index = 0;
                    index < previewTenants.length;
                    index++
                    ) ...[
                      _TenantPreviewCard(tenant: previewTenants[index]),
                      if (index != previewTenants.length - 1)
                        const Divider(height: 24),
                    ],

                    if (tenants.length > 5) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            _openTenantList(context);
                          },
                          child: Text(
                            'View all '
                                '${tenants.length} tenants',
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantPreviewCard extends StatelessWidget {
  final Tenant tenant;

  const _TenantPreviewCard({required this.tenant});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),

      leading: const CircleAvatar(child: Icon(Icons.person_outline)),

      title: Text(tenant.name, style: Theme
          .of(context)
          .textTheme
          .titleMedium),

      subtitle: Text(tenant.phone),

      trailing: _TenantStatusChip(status: tenant.status),
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
        color: Theme
            .of(context)
            .colorScheme
            .surfaceContainerHighest,
      ),
      child: Text(
        _statusLabel(status),
        style: Theme
            .of(context)
            .textTheme
            .labelSmall,
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

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme
                .of(context)
                .textTheme
                .titleMedium),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme
              .of(context)
              .textTheme
              .labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme
              .of(context)
              .textTheme
              .bodyMedium),
        ],
      ),
    );
  }
}

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

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Property not found.', textAlign: TextAlign.center),
      ),
    );
  }
}
