// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/unit.dart';
import '../providers/property_units_provider.dart';
import '../widgets/unit_ui_helpers.dart';

class UnitListScreen extends ConsumerStatefulWidget {
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
  ConsumerState<UnitListScreen> createState() => _UnitListScreenState();
}

class _UnitListScreenState extends ConsumerState<UnitListScreen> {
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
    setState(() => _searchQuery = value);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _addUnit() async {
    final result = await context.push<Unit>(
      RouteNames.addUnit.replaceFirst(':propertyId', widget.propertyId),
      extra: widget.numberOfFloors,
    );

    if (!mounted) {
      return;
    }

    if (result != null) {
      ref.invalidate(propertyUnitsProvider(widget.propertyId));
    }
  }

  Future<void> _openUnitDetails(Unit unit) async {
    // UnitDetailsScreen invalidates propertyUnitsProvider only on edit/delete,
    // avoiding unnecessary full-list Firestore reads on simple back navigation.
    await context.push(RouteNames.unitDetails.replaceFirst(':unitId', unit.id));
  }

  List<Unit> _filterUnits(List<Unit> units) {
    if (_searchQuery.isEmpty) {
      return List<Unit>.from(units);
    }

    return units.where((unit) {
      final unitNumber = unit.unitNumber.toLowerCase();
      final name = unit.name?.toLowerCase() ?? '';
      final floor = 'floor ${unit.floorNumber}'.toLowerCase();
      final status = unitStatusLabel(unit.status).toLowerCase();

      return unitNumber.contains(_searchQuery) ||
          name.contains(_searchQuery) ||
          floor.contains(_searchQuery) ||
          status.contains(_searchQuery);
    }).toList();
  }

  List<Unit> _sortUnits(List<Unit> units) {
    final sorted = List<Unit>.from(units);

    sorted.sort((a, b) {
      if (a.floorNumber != b.floorNumber) {
        return a.floorNumber.compareTo(b.floorNumber);
      }
      return a.unitNumber.toLowerCase().compareTo(b.unitNumber.toLowerCase());
    });

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitsAsync = ref.watch(propertyUnitsProvider(widget.propertyId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: Text('${widget.propertyName} Units')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUnit,
        icon: const Icon(Iconsax.building_4),
        label: const Text(
          'Add Unit',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: unitsAsync.when(
          loading: () => const GrihoLoadingView(message: 'Loading units...'),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GrihoStatusState(
                icon: Iconsax.warning_2,
                title: 'Unable to load units',
                subtitle: 'Please check your connection and try again.',
                actionLabel: 'Retry',
                onAction: () =>
                    ref.invalidate(propertyUnitsProvider(widget.propertyId)),
              ),
            ),
          ),
          data: (units) {
            final totalUnits = units.length;
            final occupiedUnits = units
                .where((u) => u.status == UnitStatus.occupied)
                .length;
            final availableUnits = units
                .where((u) => u.status == UnitStatus.available)
                .length;
            final otherUnits = totalUnits - occupiedUnits - availableUnits;

            final filteredUnits = _filterUnits(units);
            final sortedUnits = _sortUnits(filteredUnits);

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(propertyUnitsProvider(widget.propertyId));
                await ref.read(propertyUnitsProvider(widget.propertyId).future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  _PropertyUnitsOverviewCard(
                    propertyName: widget.propertyName,
                    numberOfFloors: widget.numberOfFloors,
                    totalCount: totalUnits,
                    availableCount: availableUnits,
                    occupiedCount: occupiedUnits,
                    otherCount: otherUnits,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText:
                          'Search units by number, label, floor, status...',
                      prefixIcon: const Icon(
                        Iconsax.search_normal_1,
                        size: 19,
                        color: GrihoColors.emerald,
                      ),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _searchController.clear,
                              icon: const Icon(Iconsax.close_circle, size: 19),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _searchQuery.isEmpty
                            ? 'All Spaces ($totalUnits)'
                            : 'Matching Results (${sortedUnits.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        TextButton(
                          onPressed: _searchController.clear,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text('Reset'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (units.isEmpty)
                    GrihoStatusState(
                      icon: Iconsax.home_2,
                      title: 'No Units Registered Yet',
                      subtitle:
                          'Add the first residential flat or commercial space to start assigning tenants and tracking leases.',
                      actionLabel: 'Add First Unit',
                      onAction: _addUnit,
                    )
                  else if (sortedUnits.isEmpty)
                    GrihoStatusState(
                      icon: Iconsax.search_normal_1,
                      title: 'No matching units found',
                      subtitle:
                          'No space matches "$_searchQuery" in this building.',
                    )
                  else
                    for (final unit in sortedUnits)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _UnitCard(
                          unit: unit,
                          onTap: () => _openUnitDetails(unit),
                        ),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// OVERVIEW CARD
// ============================================================================

class _PropertyUnitsOverviewCard extends StatelessWidget {
  final String propertyName;
  final int numberOfFloors;
  final int totalCount;
  final int availableCount;
  final int occupiedCount;
  final int otherCount;

  const _PropertyUnitsOverviewCard({
    required this.propertyName,
    required this.numberOfFloors,
    required this.totalCount,
    required this.availableCount,
    required this.occupiedCount,
    required this.otherCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Iconsax.buildings_2,
                  size: 24,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      propertyName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Unit & Flat Directory ($numberOfFloors${numberOfFloors == 1 ? 'Floor' : 'Floors'})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricBadge(
                  label: 'Total',
                  value: '$totalCount',
                  icon: Iconsax.building,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBadge(
                  label: 'Available',
                  value: '$availableCount',
                  icon: Iconsax.tick_circle,
                  highlightColor: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBadge(
                  label: 'Occupied',
                  value: '$occupiedCount',
                  icon: Iconsax.user,
                  highlightColor: GrihoColors.emerald,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBadge(
                  label: 'Other',
                  value: '$otherCount',
                  icon: Iconsax.pause_circle,
                  highlightColor: GrihoColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 16,
            color: highlightColor ?? theme.colorScheme.primary,
          ),
          const SizedBox(height: 4),
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
// UNIT CARD
// ============================================================================

class _UnitCard extends StatelessWidget {
  final Unit unit;
  final VoidCallback onTap;

  const _UnitCard({required this.unit, required this.onTap});

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
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Iconsax.building,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Unit ${unit.unitNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        UnitStatusChip(status: unit.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (unit.name != null && unit.name!.trim().isNotEmpty) ...[
                      Text(
                        unit.name!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        Icon(
                          Iconsax.layer,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          formatUnitFloorLabel(unit.floorNumber),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(
                  Iconsax.arrow_right_3,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
