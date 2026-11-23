// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_arguments.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/controllers/property_controller.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../tenants/data/models/tenant_model.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/providers/property_tenants_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';

class PropertyDetailsScreen extends ConsumerStatefulWidget {
  final String propertyId;

  const PropertyDetailsScreen({super.key, required this.propertyId});

  @override
  ConsumerState<PropertyDetailsScreen> createState() =>
      _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends ConsumerState<PropertyDetailsScreen> {
  bool _isDeleting = false;

  Future<void> _editProperty(Property property) async {
    if (_isDeleting) {
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

    // Only invalidate property providers; editing property info does not alter units or tenants.
    ref.invalidate(currentOwnerPropertiesProvider);
    ref.invalidate(propertyByIdProvider(result.id));
  }

  Future<void> _deleteProperty(Property property) async {
    if (_isDeleting) {
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
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() => _isDeleting = true);

    final controller = ref.read(propertyControllerProvider.notifier);
    final success = await controller.deleteProperty(propertyId: property.id);

    if (!mounted) {
      return;
    }

    if (success) {
      ref.invalidate(currentOwnerPropertiesProvider);
      ref.invalidate(propertyByIdProvider(property.id));
      GrihoFeedback.showSuccess(context, 'Property deleted.');
      context.pop();
      return;
    }

    setState(() => _isDeleting = false);

    final errorMessage = ref.read(propertyControllerProvider).errorMessage;
    GrihoFeedback.showError(
      context,
      errorMessage ?? 'Unable to delete property.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final propertyAsync = ref.watch(propertyByIdProvider(widget.propertyId));

    return propertyAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Property Details')),
        body: const GrihoLoadingView(message: 'Loading property...'),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Property Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load property',
              subtitle: error.toString(),
              actionLabel: 'Retry',
              onAction: () =>
                  ref.invalidate(propertyByIdProvider(widget.propertyId)),
            ),
          ),
        ),
      ),
      data: (property) {
        if (property == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Property Details')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: GrihoStatusState(
                  icon: Iconsax.buildings_2,
                  title: 'Property not found',
                  subtitle: 'This property may have been removed.',
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            title: const Text('Property Details'),
            actions: [
              IconButton(
                tooltip: 'Edit Property',
                icon: const Icon(Iconsax.edit_2),
                onPressed: _isDeleting ? null : () => _editProperty(property),
              ),
              IconButton(
                tooltip: 'Delete Property',
                icon: const Icon(Iconsax.trash),
                onPressed: _isDeleting ? null : () => _deleteProperty(property),
              ),
            ],
          ),
          body: Stack(
            children: [
              _PropertyDetailsContent(property: property),
              if (_isDeleting)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: GrihoLoadingView(
                            message: 'Deleting property records...',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// MAIN DETAILS VIEW
// ============================================================================

class _PropertyDetailsContent extends ConsumerWidget {
  final Property property;

  const _PropertyDetailsContent({required this.property});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(propertyUnitsProvider(property.id));
    final tenantsAsync = ref.watch(propertyTenantsProvider(property.id));

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.refresh(propertyByIdProvider(property.id).future),
          ref.refresh(propertyUnitsProvider(property.id).future),
          ref.refresh(propertyTenantsProvider(property.id).future),
        ]).catchError((_) => const <Object?>[]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _HeroPropertyHeader(property: property),
          const SizedBox(height: 14),
          _PropertyMetricRow(
            numberOfFloors: property.numberOfFloors,
            unitsAsync: unitsAsync,
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
          _PropertyRentManagementCard(property: property),
          const SizedBox(height: 20),
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
    final statusColor = isActive ? GrihoColors.emerald : GrihoColors.warning;

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
                  size: 26,
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
                          icon: const Icon(Iconsax.copy),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: property.propertyCode),
                            );
                            GrihoFeedback.showSuccess(
                              context,
                              'Property code copied to clipboard.',
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
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
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
                Iconsax.location,
                size: 17,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  property.address?.trim().isNotEmpty == true
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

  IconData _propertyTypeIcon(PropertyType type) => switch (type) {
    PropertyType.residential => Iconsax.home_2,
    PropertyType.commercial => Iconsax.shop,
    PropertyType.mixedUse => Iconsax.buildings_2,
  };
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
      error: (_, _) => const SizedBox.shrink(),
      data: (units) {
        final totalUnits = units.length;
        final occupiedUnits = units
            .where((u) => u.status == UnitStatus.occupied)
            .length;
        final vacantUnits = units
            .where((u) => u.status == UnitStatus.available)
            .length;

        return Row(
          children: [
            Expanded(
              child: _MetricBadge(
                label: 'Floors',
                value: '$numberOfFloors',
                icon: Iconsax.layer,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricBadge(
                label: 'Total Units',
                value: '$totalUnits',
                icon: Iconsax.building,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricBadge(
                label: 'Occupied',
                value: '$occupiedUnits',
                icon: Iconsax.user,
                highlightColor: GrihoColors.emerald,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricBadge(
                label: 'Vacant',
                value: '$vacantUnits',
                icon: Iconsax.tick_circle,
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
                      icon: const Icon(Iconsax.add_circle, size: 20),
                      onPressed: () => _addUnit(context, ref),
                    ),
                    TextButton(
                      onPressed: () => _openUnitList(context),
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            unitsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Unable to load units: $error'),
              data: (units) {
                if (units.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Iconsax.home_2,
                            size: 34,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          const Text('No units added to this property yet.'),
                          const SizedBox(height: 12),
                          GrihoPrimaryButton(
                            label: 'Add First Unit',
                            icon: Iconsax.add,
                            fullWidth: false,
                            onPressed: () => _addUnit(context, ref),
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
    final isAvailable = unit.status == UnitStatus.available;
    final badgeColor = isOccupied
        ? GrihoColors.emerald
        : isAvailable
        ? Colors.blueAccent
        : GrihoColors.warning;
    final statusName = unit.status.name;
    final badgeLabel = isOccupied
        ? 'Occupied'
        : isAvailable
        ? 'Available'
        : statusName.isNotEmpty
        ? statusName[0].toUpperCase() + statusName.substring(1)
        : 'Other';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Iconsax.building,
          size: 18,
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
              color: badgeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Iconsax.arrow_right_3, size: 16),
        ],
      ),
      onTap: () {
        context.push(RouteNames.unitDetails.replaceFirst(':unitId', unit.id));
      },
    );
  }
}

// ============================================================================
// TENANTS SECTION (FALLBACK ONLY ON PROVIDER ERROR TO PREVENT EXTRA READS)
// ============================================================================

class _TenantsSection extends ConsumerStatefulWidget {
  final String propertyId;
  final String propertyName;
  final AsyncValue<List<Tenant>> tenantsAsync;

  const _TenantsSection({
    required this.propertyId,
    required this.propertyName,
    required this.tenantsAsync,
  });

  @override
  ConsumerState<_TenantsSection> createState() => _TenantsSectionState();
}

class _TenantsSectionState extends ConsumerState<_TenantsSection> {
  Future<List<Tenant>>? _fallbackFuture;

  @override
  void didUpdateWidget(covariant _TenantsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.propertyId != widget.propertyId) {
      _fallbackFuture = null;
    }
  }

  Future<List<Tenant>> _getFallbackTenants() {
    _fallbackFuture ??= FirebaseFirestore.instance
        .collection('tenants')
        .where('propertyId', isEqualTo: widget.propertyId)
        .where('status', isEqualTo: 'active')
        .limit(20)
        .get()
        .then((snap) => snap.docs.map(TenantModel.fromFirestore).toList());
    return _fallbackFuture!;
  }

  Future<void> _openTenantList() async {
    await context.push(
      RouteNames.propertyTenants.replaceFirst(':propertyId', widget.propertyId),
      extra: PropertyTenantsRouteArguments(propertyName: widget.propertyName),
    );
  }

  Future<void> _addTenant() async {
    await context.push(RouteNames.addTenant);
    if (!mounted) {
      return;
    }
    setState(() => _fallbackFuture = null);
    ref.invalidate(propertyTenantsProvider(widget.propertyId));
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Column(
          children: [
            Icon(
              Iconsax.people,
              size: 34,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            const Text('No active tenants assigned yet.'),
            const SizedBox(height: 12),
            GrihoPrimaryButton(
              label: 'Assign Tenant',
              icon: Iconsax.user_add,
              fullWidth: false,
              onPressed: _addTenant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewList(List<Tenant> activeTenants) {
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
                      icon: const Icon(Iconsax.user_add, size: 20),
                      onPressed: _addTenant,
                    ),
                    TextButton(
                      onPressed: _openTenantList,
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            widget.tenantsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => FutureBuilder<List<Tenant>>(
                future: _getFallbackTenants(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return const Text('Unable to load tenants.');
                  }
                  final fallbackList = snapshot.data ?? const <Tenant>[];
                  if (fallbackList.isEmpty) {
                    return _buildEmptyState(theme);
                  }
                  return _buildPreviewList(fallbackList);
                },
              ),
              data: (tenants) {
                final activeTenants = tenants
                    .where((t) => t.status == TenantStatus.active)
                    .toList();

                if (activeTenants.isEmpty) {
                  return _buildEmptyState(theme);
                }

                return _buildPreviewList(activeTenants);
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
    final trimmedName = tenant.name.trim();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          trimmedName.isNotEmpty ? trimmedName[0].toUpperCase() : 'T',
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
      trailing: const Icon(Iconsax.arrow_right_3, size: 16),
      onTap: () {
        context.push(
          RouteNames.tenantDetails.replaceFirst(':tenantId', tenant.id),
        );
      },
    );
  }
}

// ============================================================================
// UNIFIED PROPERTY RENT & TARIFF MANAGEMENT CARD
// ============================================================================

class _PropertyRentManagementCard extends StatelessWidget {
  final Property property;

  const _PropertyRentManagementCard({required this.property});

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
                    Iconsax.money_change,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Rent & Tariff Control',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Adjust recurring monthly rent across all occupied units in "${property.name}", specific floors, or individual units, and generate monthly rent invoices.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            GrihoPrimaryButton(
              label: 'Open Rent & Tariff Control Hub',
              icon: Iconsax.setting_4,
              onPressed: () => context.push(RouteNames.centralRentControl),
            ),
          ],
        ),
      ),
    );
  }
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
              property.description?.trim().isNotEmpty == true
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
