import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../rents/presentation/providers/rent_rate_provider.dart';
import '../../../tenants/domain/entities/tenancy_history.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/controllers/tenant_controller.dart';
import '../../../tenants/presentation/providers/tenancy_history_provider.dart';
import '../../domain/entities/unit.dart';
import '../controllers/unit_controller.dart';
import '../providers/property_units_provider.dart';
import '../providers/unit_usecase_provider.dart';

class UnitDetailsScreen extends ConsumerStatefulWidget {
  final String unitId;

  const UnitDetailsScreen({
    super.key,
    required this.unitId,
  });

  @override
  ConsumerState<UnitDetailsScreen> createState() => _UnitDetailsScreenState();
}

class _UnitDetailsScreenState extends ConsumerState<UnitDetailsScreen> {
  Unit? _unit;
  List<Tenant> _activeTenants = [];

  bool _isLoading = true;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUnit();
  }

  // ============================================================
  // LOAD UNIT + ACTIVE TENANTS
  // ============================================================

  Future<void> _loadUnit() async {
    try {
      final getUnit = ref.read(getUnitProvider);
      final getActiveTenantsByUnitId = ref.read(
        getActiveTenantsByUnitIdProvider,
      );

      final unit = await getUnit(widget.unitId);

      if (!mounted) {
        return;
      }

      List<Tenant> activeTenants = [];

      if (unit != null) {
        activeTenants = await getActiveTenantsByUnitId(unit.id);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _unit = unit;
        _activeTenants = activeTenants;
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

  // ============================================================
  // EDIT UNIT
  // ============================================================

  Future<void> _editUnit() async {
    final unit = _unit;

    if (unit == null || _isDeleting) {
      return;
    }

    final updatedUnit = await context.push<Unit>(
      RouteNames.editUnit.replaceFirst(':unitId', unit.id),
      extra: unit,
    );

    if (!mounted || updatedUnit == null) {
      return;
    }

    setState(() {
      _unit = updatedUnit;
    });

    ref.invalidate(propertyUnitsProvider(updatedUnit.propertyId));

    await _loadUnit();
  }

  // ============================================================
  // DELETE UNIT
  // ============================================================

  Future<void> _deleteUnit() async {
    final unit = _unit;

    if (unit == null || _isDeleting) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Unit?'),
          content: Text(
            'Are you sure you want to permanently delete "${unit
                .unitNumber}"?\n\n'
                'Associated billing rules and past tenancy references will be affected. This action cannot be undone.',
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

    final controller = ref.read(unitControllerProvider.notifier);
    final success = await controller.deleteUnit(
      unitId: unit.id,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ref.invalidate(propertyUnitsProvider(unit.propertyId));
      context.pop();
      return;
    }

    setState(() {
      _isDeleting = false;
    });

    final errorMessage = ref
        .read(unitControllerProvider)
        .errorMessage;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage ?? 'Unable to delete unit.',
        ),
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Unit Details'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Unit Details'),
        ),
        body: _ErrorView(
          message: _errorMessage!,
          onRetry: _loadUnit,
        ),
      );
    }

    final unit = _unit;

    if (unit == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Unit Details'),
        ),
        body: const _NotFoundView(),
      );
    }

    final propertyAsync = ref.watch(
      propertyByIdProvider(unit.propertyId),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Unit Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit Unit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _isDeleting ? null : _editUnit,
          ),
          IconButton(
            tooltip: 'Delete Unit',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _isDeleting ? null : _deleteUnit,
          ),
        ],
      ),
      body: Stack(
        children: [
          propertyAsync.when(
            loading: () {
              return _UnitDetails(
                unit: unit,
                activeTenants: _activeTenants,
                property: null,
                historyAsync: null,
                onReload: _loadUnit,
              );
            },
            error: (_, _) {
              return _UnitDetails(
                unit: unit,
                activeTenants: _activeTenants,
                property: null,
                historyAsync: null,
                propertyLoadError: true,
                onReload: _loadUnit,
              );
            },
            data: (Property? property) {
              if (property == null) {
                return _UnitDetails(
                  unit: unit,
                  activeTenants: _activeTenants,
                  property: null,
                  historyAsync: null,
                  propertyLoadError: true,
                  onReload: _loadUnit,
                );
              }

              final historyAsync = ref.watch(
                unitHistoryProvider((
                unitId: unit.id,
                ownerId: property.ownerId,
                )),
              );

              return _UnitDetails(
                unit: unit,
                activeTenants: _activeTenants,
                property: property,
                historyAsync: historyAsync,
                onReload: _loadUnit,
              );
            },
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
                          Text('Deleting unit...'),
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
// UNIT DETAILS VIEW
// ============================================================================

class _UnitDetails extends ConsumerWidget {
  final Unit unit;
  final List<Tenant> activeTenants;
  final Property? property;
  final AsyncValue<List<TenancyHistory>>? historyAsync;
  final bool propertyLoadError;
  final VoidCallback onReload;

  const _UnitDetails({
    required this.unit,
    required this.activeTenants,
    required this.property,
    required this.historyAsync,
    required this.onReload,
    this.propertyLoadError = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(propertyByIdProvider(unit.propertyId));
        if (property != null) {
          ref.invalidate(
            unitHistoryProvider((
            unitId: unit.id,
            ownerId: property!.ownerId,
            )),
          );
          ref.invalidate(
            currentRentRateProvider((
            unitId: unit.id,
            ownerId: property!.ownerId,
            )),
          );
        }
        onReload();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // 1. Hero Unit Header
          _HeroUnitHeader(
            unit: unit,
            property: property,
          ),

          const SizedBox(height: 16),

          // 2. Unit Information Specifications
          _buildSectionCard(
            context,
            title: 'Unit Specifications',
            subtitle: 'Location and space identifiers',
            icon: Icons.meeting_room_outlined,
            children: [
              _InfoRow(
                label: 'Unit Number',
                value: unit.unitNumber,
              ),
              const SizedBox(height: 10),
              _InfoRow(
                label: 'Floor Level',
                value: _floorLabel(unit.floorNumber),
              ),
              const SizedBox(height: 10),
              _InfoRow(
                label: 'Custom Name',
                value: unit.name
                    ?.trim()
                    .isNotEmpty == true
                    ? unit.name!
                    : 'Not provided',
              ),
              const SizedBox(height: 10),
              _InfoRow(
                label: 'Status',
                value: _statusLabel(unit.status),
              ),
              const SizedBox(height: 10),
              if (property != null)
                _CurrentRentInfo(
                  unitId: unit.id,
                  ownerId: property!.ownerId,
                )
              else
                const _InfoRow(
                  label: 'Current Rent',
                  value: 'Unavailable',
                ),
            ],
          ),

          const SizedBox(height: 18),

          // 3. Current Occupants Section
          _TenantSection(
            unit: unit,
            tenants: activeTenants,
          ),

          const SizedBox(height: 18),

          // 4. Rent Rate Management Card
          _ManageRentCard(
            unit: unit,
          ),

          const SizedBox(height: 18),

          // 5. Tenancy History Section
          _UnitHistorySection(
            historyAsync: historyAsync,
            propertyLoadError: propertyLoadError,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
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
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

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

  String _statusLabel(UnitStatus status) {
    switch (status) {
      case UnitStatus.available:
        return 'Available / Vacant';
      case UnitStatus.occupied:
        return 'Occupied';
      case UnitStatus.reserved:
        return 'Reserved';
      case UnitStatus.inactive:
        return 'Inactive / Maintenance';
    }
  }
}

// ============================================================================
// HERO UNIT HEADER CARD
// ============================================================================

class _HeroUnitHeader extends StatelessWidget {
  final Unit unit;
  final Property? property;

  const _HeroUnitHeader({
    required this.unit,
    required this.property,
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

    final (label, color) = switch (unit.status) {
      UnitStatus.available => ('Available', Colors.blue.shade800),
      UnitStatus.occupied => ('Occupied', Colors.green.shade800),
      UnitStatus.reserved => ('Reserved', Colors.amber.shade900),
      UnitStatus.inactive => ('Inactive', Colors.grey.shade800),
    };

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
                  Icons.door_front_door_rounded,
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
                      'Unit ${unit.unitNumber}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unit.name
                          ?.trim()
                          .isNotEmpty == true
                          ? unit.name!
                          : 'Residential Unit Space',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
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
                Icons.apartment_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  property != null
                      ? '${property!.name} (${property!.propertyCode})'
                      : 'Property Building Loading...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _floorLabel(unit.floorNumber),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
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
}

// ============================================================================
// CURRENT RENT INFO
// ============================================================================

class _CurrentRentInfo extends ConsumerWidget {
  final String unitId;
  final String ownerId;

  const _CurrentRentInfo({
    required this.unitId,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rentAsync = ref.watch(
      currentRentRateProvider((
      unitId: unitId,
      ownerId: ownerId,
      )),
    );

    return rentAsync.when(
      loading: () => const _LoadingInfoRow(label: 'Current Rent'),
      error: (error, _) =>
      const _InfoRow(
        label: 'Current Rent',
        value: 'Unable to load rent rate',
      ),
      data: (rentRate) {
        if (rentRate == null) {
          return const _InfoRow(
            label: 'Current Rent',
            value: 'Not configured',
          );
        }

        return _InfoRow(
          label: 'Current Rent',
          value: '৳ ${_formatRent(rentRate.amount)} / month',
          valueStyle: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.primary,
          ),
        );
      },
    );
  }

  String _formatRent(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}

// ============================================================================
// TENANT SECTION
// ============================================================================

class _TenantSection extends StatelessWidget {
  final Unit unit;
  final List<Tenant> tenants;

  const _TenantSection({
    required this.unit,
    required this.tenants,
  });

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Current Residents',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (tenants.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tenants.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Active tenants linked to this residential unit',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (tenants.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_off_outlined,
                      size: 22,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This unit is currently vacant with no active tenants assigned.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (var i = 0; i < tenants.length; i++) ...[
                _TenantTile(tenant: tenants[i]),
                if (i != tenants.length - 1) ...[
                  const SizedBox(height: 10),
                ],
              ],
          ],
        ),
      ),
    );
  }
}

class _TenantTile extends StatelessWidget {
  final Tenant tenant;

  const _TenantTile({
    required this.tenant,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push(
            RouteNames.tenantDetails.replaceFirst(
              ':tenantId',
              tenant.id,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  _initial(tenant.name),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tenant.phone,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _TenantStatusChip(status: tenant.status),
                        const SizedBox(width: 6),
                        _AccountStatusChip(
                          label: tenant.userId != null
                              ? 'Registered'
                              : 'Not registered',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 20),
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
// MANAGE RENT CARD
// ============================================================================

class _ManageRentCard extends StatelessWidget {
  final Unit unit;

  const _ManageRentCard({
    required this.unit,
  });

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
                    Icons.payments_outlined,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Rent Rate Management',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Update current rent terms, set scheduled adjustments, and view complete historical rental rates for this unit.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  context.push(
                    RouteNames.unitRentManagement.replaceFirst(
                      ':unitId',
                      unit.id,
                    ),
                  );
                },
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text(
                  'Configure Rent Rates',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// UNIT HISTORY SECTION
// ============================================================================

class _UnitHistorySection extends StatelessWidget {
  final AsyncValue<List<TenancyHistory>>? historyAsync;
  final bool propertyLoadError;

  const _UnitHistorySection({
    required this.historyAsync,
    required this.propertyLoadError,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (propertyLoadError) {
      return _buildHistoryContainer(
        context,
        children: const [
          Text('Unable to load property information for historical records.'),
        ],
      );
    }

    if (historyAsync == null) {
      return _buildHistoryContainer(
        context,
        children: const [
          LinearProgressIndicator(),
        ],
      );
    }

    return historyAsync!.when(
      loading: () =>
          _buildHistoryContainer(
            context,
            children: const [
              LinearProgressIndicator(),
            ],
          ),
      error: (_, _) =>
          _buildHistoryContainer(
            context,
            children: const [
              Text('Unable to load historical tenancy records.'),
            ],
          ),
      data: (histories) {
        if (histories.isEmpty) {
          return _buildHistoryContainer(
            context,
            children: [
              Text(
                'No previous completed tenancies recorded for this unit.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }

        return _buildHistoryContainer(
          context,
          count: histories.length,
          children: [
            for (var index = 0; index < histories.length; index++) ...[
              _UnitHistoryItem(
                history: histories[index],
              ),
              if (index != histories.length - 1) ...[
                const Divider(height: 24),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _buildHistoryContainer(BuildContext context, {
    int? count,
    required List<Widget> children,
  }) {
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tenancy History',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (count != null)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Past lease agreements and previous residents',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _UnitHistoryItem extends StatelessWidget {
  final TenancyHistory history;

  const _UnitHistoryItem({
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    _initial(history.tenantName),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  history.tenantName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Text(
                'Ended Lease',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _HistoryDetailRow(
          label: 'Monthly Rent',
          value: history.monthlyRent == null
              ? 'Not recorded'
              : '৳ ${_formatRent(history.monthlyRent!)} / mo',
        ),
        _HistoryDetailRow(
          label: 'Duration',
          value: _formatDuration(history.startedAt, history.endedAt),
        ),
        _HistoryDetailRow(
          label: 'Stayed',
          value:
          '${_formatDate(history.startedAt)} – ${_formatDate(history.endedAt)}',
        ),
      ],
    );
  }

  String _initial(String name) {
    final value = name.trim();
    if (value.isEmpty) {
      return '?';
    }
    return value.characters.first.toUpperCase();
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  String _formatDuration(DateTime startedAt, DateTime endedAt) {
    final difference = endedAt.difference(startedAt);
    final days = difference.inDays;

    if (days <= 0) {
      return 'Less than 1 day';
    }

    return '$days ${days == 1 ? 'day' : 'days'}';
  }

  String _formatRent(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}

// ============================================================================
// STATUS & ACCOUNT CHIPS
// ============================================================================

class _TenantStatusChip extends StatelessWidget {
  final TenantStatus status;

  const _TenantStatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = status == TenantStatus.active;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isActive
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.12),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isActive ? Colors.green.shade800 : Colors.orange.shade800,
        ),
      ),
    );
  }
}

class _AccountStatusChip extends StatelessWidget {
  final String label;

  const _AccountStatusChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isRegistered = label.toLowerCase().contains('registered') &&
        !label.toLowerCase().contains('not');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isRegistered
            ? Colors.teal.withValues(alpha: 0.12)
            : Theme
            .of(context)
            .colorScheme
            .surfaceContainerHighest,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isRegistered
              ? Colors.teal.shade800
              : Theme
              .of(context)
              .colorScheme
              .onSurfaceVariant,
        ),
      ),
    );
  }
}

// ============================================================================
// DETAIL & HELPER ROWS
// ============================================================================

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: valueStyle ??
                theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _HistoryDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _HistoryDetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingInfoRow extends StatelessWidget {
  final String label;

  const _LoadingInfoRow({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Spacer(),
        const SizedBox(
          height: 12,
          width: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      ],
    );
  }
}

// ============================================================================
// ERROR & NOT FOUND VIEWS
// ============================================================================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
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
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
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

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.door_sliding_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Unit Not Found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The requested unit record does not exist or may have been deleted.',
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
