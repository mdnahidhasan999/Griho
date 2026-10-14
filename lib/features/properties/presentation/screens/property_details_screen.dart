import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_arguments.dart';
import '../../../../app/router/route_names.dart';
import '../../../rents/domain/entities/rent_adjustment.dart';
import '../../../rents/presentation/providers/rent_rate_provider.dart';
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
            'Are you sure you want to delete "${property.name}"?\n\n'
                'All associated units, resident assignments, and recurring billing rules will be permanently affected.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme
                    .of(context)
                    .colorScheme
                    .error,
              ),
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
      SnackBar(
        content: Text(errorMessage ?? 'Unable to delete property.'),
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Property Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit Property',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _isDeleting ? null : _editProperty,
          ),
          IconButton(
            tooltip: 'Delete Property',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _isDeleting ? null : _deleteProperty,
          ),
        ],
      ),
      body: Stack(
        children: [
          _PropertyDetailsContent(
            property: property,
            onReload: _loadProperty,
          ),
          if (_isDeleting)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Deleting property records...'),
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

// ============================================================================
// MAIN DETAILS VIEW
// ============================================================================

class _PropertyDetailsContent extends ConsumerWidget {
  final Property property;
  final VoidCallback onReload;

  const _PropertyDetailsContent({
    required this.property,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(propertyUnitsProvider(property.id));
    final tenantsAsync = ref.watch(propertyTenantsProvider(property.id));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(propertyUnitsProvider(property.id));
        ref.invalidate(propertyTenantsProvider(property.id));
        onReload();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // 1. Hero Property Card
          _HeroPropertyHeader(property: property),

          const SizedBox(height: 14),

          // 2. Metric Counters (Floors, Units, Occupied, Vacant)
          _PropertyMetricRow(
            numberOfFloors: property.numberOfFloors,
            unitsAsync: unitsAsync,
          ),

          const SizedBox(height: 20),

          // 3. Units Section
          _UnitsSection(
            propertyId: property.id,
            propertyName: property.name,
            numberOfFloors: property.numberOfFloors,
            unitsAsync: unitsAsync,
          ),

          const SizedBox(height: 20),

          // 4. Tenants Section
          _TenantsSection(
            propertyId: property.id,
            propertyName: property.name,
            tenantsAsync: tenantsAsync,
          ),

          const SizedBox(height: 20),

          // 5. Bulk Rent Management Card
          _PropertyRentManagementCard(property: property),

          const SizedBox(height: 20),

          // 6. Property Guidelines & Address Overview
          _PropertyInfoOverview(property: property),
        ],
      ),
    );
  }
}

// ============================================================================
// HERO PROPERTY HEADER CARD
// ============================================================================

class _HeroPropertyHeader extends StatelessWidget {
  final Property property;

  const _HeroPropertyHeader({required this.property});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = property.status == PropertyStatus.active;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _propertyTypeIcon(property.type),
                  size: 28,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Code: ${property.propertyCode}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          tooltip: 'Copy Property Code',
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: property.propertyCode),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Property code copied to clipboard.',
                                ),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
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
                  color: isActive
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  property.address
                      ?.trim()
                      .isNotEmpty == true
                      ? property.address!
                      : 'No physical address provided',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _propertyTypeIcon(PropertyType type) {
    switch (type) {
      case PropertyType.residential:
        return Icons.apartment_rounded;
      case PropertyType.commercial:
        return Icons.storefront_rounded;
      case PropertyType.mixedUse:
        return Icons.domain_rounded;
    }
  }
}

// ============================================================================
// METRIC CARDS ROW
// ============================================================================

class _PropertyMetricRow extends StatelessWidget {
  final int numberOfFloors;
  final AsyncValue<List<Unit>> unitsAsync;

  const _PropertyMetricRow({
    required this.numberOfFloors,
    required this.unitsAsync,
  });

  @override
  Widget build(BuildContext context) {
    return unitsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (units) {
        final totalUnits = units.length;
        final occupiedUnits =
            units
                .where((u) => u.status == UnitStatus.occupied)
                .length;
        final vacantUnits = totalUnits - occupiedUnits;

        return Row(
          children: [
            Expanded(
              child: _MetricBadge(
                label: 'Floors',
                value: '$numberOfFloors',
                icon: Icons.layers_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricBadge(
                label: 'Total Units',
                value: '$totalUnits',
                icon: Icons.door_front_door_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricBadge(
                label: 'Occupied',
                value: '$occupiedUnits',
                icon: Icons.person_outline,
                highlightColor: Colors.teal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricBadge(
                label: 'Vacant',
                value: '$vacantUnits',
                icon: Icons.check_circle_outline,
                highlightColor: Colors.blueAccent,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? highlightColor;

  const _MetricBadge({
    required this.label,
    required this.value,
    required this.icon,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 18,
            color: highlightColor ?? theme.colorScheme.primary,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// UNITS SECTION
// ============================================================================

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
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Units & Flats',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Add Unit',
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      onPressed: () {
                        _addUnit(context, ref);
                      },
                    ),
                    TextButton(
                      onPressed: () {
                        _openUnitList(context);
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            unitsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => Text('Unable to load units: $error'),
              data: (units) {
                if (units.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.door_front_door_outlined,
                            size: 36,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          const Text('No units added to this property yet.'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () {
                              _addUnit(context, ref);
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add First Unit'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final previewUnits = units.take(4).toList();

                return Column(
                  children: [
                    for (var i = 0; i < previewUnits.length; i++) ...[
                      _UnitCard(unit: previewUnits[i]),
                      if (i != previewUnits.length - 1)
                        const Divider(height: 1, indent: 56),
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
    final theme = Theme.of(context);
    final isOccupied = unit.status == UnitStatus.occupied;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.apartment_rounded,
          size: 20,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text(
        'Unit ${unit.unitNumber}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('Floor ${unit.floorNumber}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isOccupied
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isOccupied ? 'Occupied' : 'Available',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isOccupied
                    ? Colors.green.shade800
                    : Colors.blue.shade800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
      onTap: () {
        context.push(RouteNames.unitDetails.replaceFirst(':unitId', unit.id));
      },
    );
  }
}

// ============================================================================
// TENANTS SECTION
// ============================================================================

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
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Residents',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Assign Tenant',
                      icon: const Icon(
                          Icons.person_add_alt_1_outlined, size: 20),
                      onPressed: () {
                        _addTenant(context, ref);
                      },
                    ),
                    TextButton(
                      onPressed: () {
                        _openTenantList(context);
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            tenantsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (err, stack) => Text('Unable to load tenants: $err'),
              data: (tenants) {
                final activeTenants = tenants
                    .where((t) => t.status == TenantStatus.active)
                    .toList();

                if (activeTenants.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 36,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          const Text('No active tenants assigned yet.'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () {
                              _addTenant(context, ref);
                            },
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('Assign Tenant'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final previewTenants = activeTenants.take(4).toList();

                return Column(
                  children: [
                    for (var i = 0; i < previewTenants.length; i++) ...[
                      _TenantCard(tenant: previewTenants[i]),
                      if (i != previewTenants.length - 1)
                        const Divider(height: 1, indent: 56),
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

class _TenantCard extends StatelessWidget {
  final Tenant tenant;

  const _TenantCard({required this.tenant});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          tenant.name.isNotEmpty ? tenant.name[0].toUpperCase() : 'T',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(
        tenant.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(tenant.phone),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () {
        context.push(
          RouteNames.tenantDetails.replaceFirst(':tenantId', tenant.id),
        );
      },
    );
  }
}

// ============================================================================
// PROPERTY RENT MANAGEMENT CARD
// ============================================================================

class _PropertyRentManagementCard extends ConsumerStatefulWidget {
  final Property property;

  const _PropertyRentManagementCard({required this.property});

  @override
  ConsumerState<_PropertyRentManagementCard> createState() =>
      _PropertyRentManagementCardState();
}

class _PropertyRentManagementCardState
    extends ConsumerState<_PropertyRentManagementCard> {
  bool _isChanging = false;

  Future<void> _changePropertyRent() async {
    final result = await showDialog<_PropertyRentChangeResult>(
      context: context,
      builder: (dialogContext) {
        return const _PropertyRentAdjustmentDialog();
      },
    );

    if (!mounted || result == null) {
      return;
    }

    await _submitPropertyRentChange(
      amount: result.amount,
      adjustmentType: result.adjustmentType,
      effectiveFrom: result.effectiveFrom,
    );
  }

  Future<void> _submitPropertyRentChange({
    required double amount,
    required RentAdjustmentType adjustmentType,
    required DateTime effectiveFrom,
  }) async {
    if (_isChanging) {
      return;
    }

    setState(() {
      _isChanging = true;
    });

    final controller = ref.read(rentRateControllerProvider.notifier);

    final rentRates = await controller.changePropertyRent(
      propertyId: widget.property.id,
      ownerId: widget.property.ownerId,
      amount: amount,
      adjustmentType: adjustmentType,
      effectiveFrom: effectiveFrom,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isChanging = false;
    });

    if (rentRates == null) {
      final error = ref
          .read(rentRateControllerProvider)
          .whenOrNull(error: (err, stack) => err.toString());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Unable to adjust property rent.'),
          backgroundColor: Theme
              .of(context)
              .colorScheme
              .error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final action = adjustmentType == RentAdjustmentType.increase
        ? 'increased'
        : 'decreased';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Rent $action by ৳${_formatPropertyRentAmount(amount)} for ${rentRates
              .length} occupied unit(s).',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.currency_exchange_rounded,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Bulk Rent Adjustment',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Apply an increase or reduction in monthly rent across all occupied units simultaneously.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isChanging ? null : _changePropertyRent,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Adjust Rent Rates'),
              ),
            ),
            if (_isChanging) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PROPERTY RENT ADJUSTMENT DIALOG
// ============================================================================

class _PropertyRentAdjustmentDialog extends StatefulWidget {
  const _PropertyRentAdjustmentDialog();

  @override
  State<_PropertyRentAdjustmentDialog> createState() =>
      _PropertyRentAdjustmentDialogState();
}

class _PropertyRentAdjustmentDialogState
    extends State<_PropertyRentAdjustmentDialog> {
  late final TextEditingController _amountController;
  DateTime _effectiveFrom = DateTime.now();
  RentAdjustmentType _adjustmentType = RentAdjustmentType.increase;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectEffectiveDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _effectiveFrom = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid adjustment amount.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _PropertyRentChangeResult(
        amount: amount,
        adjustmentType: _adjustmentType,
        effectiveFrom: _effectiveFrom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncrease = _adjustmentType == RentAdjustmentType.increase;

    return AlertDialog(
      title: const Text('Adjust Property Rent'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select adjustment type and amount to apply across all occupied units.',
            ),
            const SizedBox(height: 20),
            SegmentedButton<RentAdjustmentType>(
              segments: const [
                ButtonSegment(
                  value: RentAdjustmentType.increase,
                  icon: Icon(Icons.arrow_upward),
                  label: Text('Increase'),
                ),
                ButtonSegment(
                  value: RentAdjustmentType.decrease,
                  icon: Icon(Icons.arrow_downward),
                  label: Text('Decrease'),
                ),
              ],
              selected: {_adjustmentType},
              onSelectionChanged: (selection) {
                setState(() {
                  _adjustmentType = selection.first;
                });
              },
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Adjustment Amount',
                hintText: 'e.g. 1000',
                prefixText: '৳ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _selectEffectiveDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Effective Date',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(_formatPropertyRentDate(_effectiveFrom)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme
                    .of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isIncrease ? Icons.trending_up : Icons.trending_down,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isIncrease
                          ? 'Example: An apartment renting at ৳12,000 will become ৳13,000 with a ৳1,000 increase.'
                          : 'Example: An apartment renting at ৳12,000 will become ৳11,000 with a ৳1,000 reduction.',
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Apply Changes')),
      ],
    );
  }
}

class _PropertyRentChangeResult {
  final double amount;
  final RentAdjustmentType adjustmentType;
  final DateTime effectiveFrom;

  const _PropertyRentChangeResult({
    required this.amount,
    required this.adjustmentType,
    required this.effectiveFrom,
  });
}

// ============================================================================
// PROPERTY OVERVIEW CARD
// ============================================================================

class _PropertyInfoOverview extends StatelessWidget {
  final Property property;

  const _PropertyInfoOverview({required this.property});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Property Notes & Guidelines',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              property.description
                  ?.trim()
                  .isNotEmpty == true
                  ? property.description!
                  : 'No instructions or description added for this property.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HELPERS & ERROR VIEWS
// ============================================================================

String _formatPropertyRentDate(DateTime dateTime) {
  final date = dateTime.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month
      .toString()
      .padLeft(2, '0')}/${date.year}';
}

String _formatPropertyRentAmount(double amount) {
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toStringAsFixed(2);
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
            const Icon(
                Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
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
