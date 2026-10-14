import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../domain/entities/unit.dart';
import '../providers/property_units_provider.dart';

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
    await context.push(
      RouteNames.unitDetails.replaceFirst(':unitId', unit.id),
    );

    if (!mounted) {
      return;
    }

    ref.invalidate(propertyUnitsProvider(widget.propertyId));
  }

  List<Unit> _filterUnits(List<Unit> units) {
    if (_searchQuery.isEmpty) {
      return List<Unit>.from(units);
    }

    return units.where((unit) {
      final unitNumber = unit.unitNumber.toLowerCase();
      final name = unit.name?.toLowerCase() ?? '';
      final floor = 'floor ${unit.floorNumber}'.toLowerCase();
      final status = _statusLabel(unit.status).toLowerCase();

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

  static String _statusLabel(UnitStatus status) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitsAsync = ref.watch(propertyUnitsProvider(widget.propertyId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          '${widget.propertyName} Units',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUnit,
        icon: const Icon(Icons.add_home_work_rounded),
        label: const Text(
          'Add Unit',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: unitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              _UnitErrorView(
                onRetry: () {
                  ref.invalidate(propertyUnitsProvider(widget.propertyId));
                },
              ),
          data: (units) {
            final totalUnits = units.length;
            final occupiedUnits =
                units
                    .where((u) => u.status == UnitStatus.occupied)
                    .length;
            final availableUnits =
                units
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
                  // 1. Property Overview Header Card
                  _PropertyUnitsOverviewCard(
                    propertyName: widget.propertyName,
                    numberOfFloors: widget.numberOfFloors,
                    totalCount: totalUnits,
                    availableCount: availableUnits,
                    occupiedCount: occupiedUnits,
                    otherCount: otherUnits,
                  ),

                  const SizedBox(height: 16),

                  // 2. Search Input Field
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search units by number, label, floor, status...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                        onPressed: () {
                          _searchController.clear();
                        },
                        icon: const Icon(Icons.clear_rounded, size: 20),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 3. Section Title & Results Header
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
                          onPressed: () {
                            _searchController.clear();
                          },
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text('Reset'),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 4. Content Streams
                  if (units.isEmpty)
                    _EmptyUnitsView(onAddUnit: _addUnit)
                  else
                    if (sortedUnits.isEmpty)
                      _NoSearchResultView(query: _searchQuery)
                    else
                      for (final unit in sortedUnits) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _UnitCard(
                            unit: unit,
                            onTap: () {
                              _openUnitDetails(unit);
                            },
                          ),
                        ),
                      ],
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
                  Icons.domain_rounded,
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
                      propertyName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Unit & Flat Directory ($numberOfFloors ${numberOfFloors ==
                          1 ? 'Floor' : 'Floors'})',
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
                  icon: Icons.door_front_door_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBadge(
                  label: 'Available',
                  value: '$availableCount',
                  icon: Icons.check_circle_outline_rounded,
                  highlightColor: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBadge(
                  label: 'Occupied',
                  value: '$occupiedCount',
                  icon: Icons.person_outline_rounded,
                  highlightColor: Colors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBadge(
                  label: 'Other',
                  value: '$otherCount',
                  icon: Icons.pause_circle_outline_rounded,
                  highlightColor: Colors.amber.shade900,
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

  const _UnitCard({
    required this.unit,
    required this.onTap,
  });

  String _floorLabel(int floor) {
    if (floor == 0) {
      return 'Ground Floor';
    }
    if (floor == 1) {
      return '1st Floor';
    }
    if (floor == 2) {
      return '2nd Floor';
    }
    if (floor == 3) {
      return '3rd Floor';
    }
    return '$floor-th Floor';
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
                  Icons.apartment_rounded,
                  size: 22,
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
                        _UnitStatusChip(status: unit.status),
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
                          Icons.layers_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _floorLabel(unit.floorNumber),
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
                  Icons.chevron_right_rounded,
                  size: 20,
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

// ============================================================================
// STATUS CHIP
// ============================================================================

class _UnitStatusChip extends StatelessWidget {
  final UnitStatus status;

  const _UnitStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      UnitStatus.available => ('Available', Colors.blue.shade800),
      UnitStatus.occupied => ('Occupied', Colors.green.shade800),
      UnitStatus.reserved => ('Reserved', Colors.amber.shade900),
      UnitStatus.inactive => ('Inactive', Colors.grey.shade800),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY & ERROR VIEWS
// ============================================================================

class _EmptyUnitsView extends StatelessWidget {
  final VoidCallback onAddUnit;

  const _EmptyUnitsView({required this.onAddUnit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.door_front_door_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Units Registered Yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add the first residential flat or commercial space to start assigning tenants and tracking leases.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAddUnit,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add First Unit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSearchResultView extends StatelessWidget {
  final String query;

  const _NoSearchResultView({required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              'No matching units found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No space matches "$query" in this building.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load units for this property.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
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
