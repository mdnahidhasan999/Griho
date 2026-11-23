// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import 'griho_home_components.dart';

// ============================================================================
// 1. INTERACTIVE UNITS & VACANCY EXPLORER SHEET
// ============================================================================

void showManagerUnitsSheet({
  required BuildContext context,
  required HomeDocList unitDocs,
  required Map<String, String> propertyNames,
  String initialFilter = 'all',
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ManagerUnitsSheetContent(
      unitDocs: unitDocs,
      propertyNames: propertyNames,
      initialFilter: initialFilter,
    ),
  );
}

class _ManagerUnitsSheetContent extends StatefulWidget {
  final HomeDocList unitDocs;
  final Map<String, String> propertyNames;
  final String initialFilter;

  const _ManagerUnitsSheetContent({
    required this.unitDocs,
    required this.propertyNames,
    required this.initialFilter,
  });

  @override
  State<_ManagerUnitsSheetContent> createState() =>
      _ManagerUnitsSheetContentState();
}

class _ManagerUnitsSheetContentState extends State<_ManagerUnitsSheetContent> {
  late String _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filteredDocs = widget.unitDocs.where((doc) {
      final d = homeAsMap(doc.data());
      final status = (d['status'] ?? 'available').toString();
      if (_filter == 'available') {
        return status == 'available';
      }
      if (_filter == 'occupied') {
        return status != 'available';
      }
      return true;
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.94,
      builder: (_, controller) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Units & Vacancy (${filteredDocs.length})',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Tap any unit to inspect details, rent, or assign a tenant',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Iconsax.close_circle),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All Units')),
                  ButtonSegment(value: 'available', label: Text('Vacant')),
                  ButtonSegment(value: 'occupied', label: Text('Occupied')),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
            ),
            const Divider(height: 12),
            Expanded(
              child: filteredDocs.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: GrihoStatusState(
                          icon: Iconsax.buildings_2,
                          title: 'No matching units',
                          subtitle:
                              'No matching units found in assigned properties.',
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredDocs.length,
                      itemBuilder: (_, i) {
                        final doc = filteredDocs[i];
                        final d = homeAsMap(doc.data());
                        final unitId = doc.id;
                        final unitNum = (d['unitNumber'] ?? '').toString();
                        final name = (d['name'] ?? '').toString();
                        final floor = d['floorNumber'] ?? 1;
                        final status = (d['status'] ?? 'available').toString();
                        final propId = (d['propertyId'] ?? '').toString();
                        final propName =
                            widget.propertyNames[propId] ?? 'Assigned Building';
                        final isAvailable = status == 'available';
                        final badgeColor = isAvailable
                            ? GrihoColors.emerald
                            : theme.colorScheme.onSurfaceVariant;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: theme.colorScheme.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isAvailable
                                    ? GrihoColors.emerald.withValues(alpha: 0.5)
                                    : theme.colorScheme.outlineVariant,
                                width: isAvailable ? 1.4 : 1.0,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      Navigator.pop(context);
                                      context.push(
                                        RouteNames.unitDetails.replaceFirst(
                                          ':unitId',
                                          unitId,
                                        ),
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color:
                                                (isAvailable
                                                        ? GrihoColors.emerald
                                                        : Colors.indigo)
                                                    .withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            isAvailable
                                                ? Iconsax.home_2
                                                : Iconsax.building,
                                            size: 20,
                                            color: isAvailable
                                                ? GrihoColors.emerald
                                                : Colors.indigo,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name.isNotEmpty
                                                    ? '$name (Unit $unitNum)'
                                                    : 'Unit $unitNum',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$propName • Floor $floor',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withValues(
                                              alpha: 0.14,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            isAvailable ? 'VACANT' : 'OCCUPIED',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: badgeColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            context.push(
                                              RouteNames.unitDetails
                                                  .replaceFirst(
                                                    ':unitId',
                                                    unitId,
                                                  ),
                                            );
                                          },
                                          icon: const Icon(
                                            Iconsax.info_circle,
                                            size: 16,
                                          ),
                                          label: const Text('Unit & Rent Info'),
                                          style: OutlinedButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ),
                                      ),
                                      if (isAvailable) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FilledButton.tonalIcon(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              context.push(
                                                RouteNames.addTenant,
                                              );
                                            },
                                            icon: const Icon(
                                              Iconsax.user_add,
                                              size: 16,
                                            ),
                                            label: const Text('Assign Tenant'),
                                            style: FilledButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// 2. INTERACTIVE TENANTS & LEASES DIRECTORY SHEET
// ============================================================================

void showManagerTenantsSheet({
  required BuildContext context,
  required HomeDocList tenantDocs,
  required Map<String, String> propertyNames,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ManagerTenantsSheetContent(
      tenantDocs: tenantDocs,
      propertyNames: propertyNames,
    ),
  );
}

class _ManagerTenantsSheetContent extends StatefulWidget {
  final HomeDocList tenantDocs;
  final Map<String, String> propertyNames;

  const _ManagerTenantsSheetContent({
    required this.tenantDocs,
    required this.propertyNames,
  });

  @override
  State<_ManagerTenantsSheetContent> createState() =>
      _ManagerTenantsSheetContentState();
}

class _ManagerTenantsSheetContentState
    extends State<_ManagerTenantsSheetContent> {
  String _statusFilter = 'active';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filtered = widget.tenantDocs.where((doc) {
      final d = homeAsMap(doc.data());
      final status = (d['status'] ?? 'inactive').toString();
      if (_statusFilter == 'active') {
        return status == 'active';
      }
      if (_statusFilter == 'inactive') {
        return status != 'active';
      }
      return true;
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.94,
      builder: (_, controller) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tenants Directory (${filtered.length})',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Tap a resident to view lease, edit details, or end tenancy',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Iconsax.close_circle),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'active', label: Text('Active Leases')),
                  ButtonSegment(value: 'inactive', label: Text('Past / Ended')),
                  ButtonSegment(value: 'all', label: Text('All')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (s) =>
                    setState(() => _statusFilter = s.first),
              ),
            ),
            const Divider(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: GrihoStatusState(
                          icon: Iconsax.people,
                          title: 'No residents found',
                          subtitle: 'No residents match the selected filter.',
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final doc = filtered[i];
                        final d = homeAsMap(doc.data());
                        final tenantId = doc.id;
                        final name = (d['name'] ?? 'Resident').toString();
                        final phone = (d['phone'] ?? '').toString();
                        final status = (d['status'] ?? 'inactive').toString();
                        final propId = (d['propertyId'] ?? '').toString();
                        final propName =
                            widget.propertyNames[propId] ?? 'Assigned Building';
                        final isActive = status == 'active';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: theme.colorScheme.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text('$propName • $phone'),
                                  const SizedBox(height: 2),
                                  Text(
                                    isActive
                                        ? 'Active Tenancy • Tap to Manage / End Lease'
                                        : 'Former Tenant • Tap to View / Re-activate',
                                    style: TextStyle(
                                      color: isActive
                                          ? GrihoColors.emerald
                                          : theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: const Icon(
                                Iconsax.arrow_right_3,
                                size: 18,
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                context.push(
                                  RouteNames.tenantDetails.replaceFirst(
                                    ':tenantId',
                                    tenantId,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GrihoPrimaryButton(
                label: 'Register New Resident',
                icon: Iconsax.user_add,
                onPressed: () {
                  Navigator.pop(context);
                  context.push(RouteNames.addTenant);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
