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
  ConsumerState<UnitDetailsScreen> createState() =>
      _UnitDetailsScreenState();
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
            'Are you sure you want to delete '
                '"${unit.unitNumber}"?\n\n'
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

    final errorMessage =
        ref.read(unitControllerProvider).errorMessage;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage ?? 'Unable to delete unit.',
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(
        title: const Text('Unit Details'),
        actions: [
          IconButton(
            tooltip: 'Edit Unit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _isDeleting ? null : _editUnit,
          ),
          IconButton(
            tooltip: 'Delete Unit',
            icon: const Icon(Icons.delete_outline),
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
              );
            },
            error: (_, _) {
              return _UnitDetails(
                unit: unit,
                activeTenants: _activeTenants,
                property: null,
                historyAsync: null,
                propertyLoadError: true,
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
              );
            },
          ),
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
// UNIT DETAILS
// ============================================================================

class _UnitDetails extends StatelessWidget {
  final Unit unit;
  final List<Tenant> activeTenants;
  final Property? property;
  final AsyncValue<List<TenancyHistory>>? historyAsync;
  final bool propertyLoadError;

  const _UnitDetails({
    required this.unit,
    required this.activeTenants,
    required this.property,
    required this.historyAsync,
    this.propertyLoadError = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.apartment_outlined,
                  size: 52,
                ),
                const SizedBox(height: 16),
                Text(
                  unit.unitNumber,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  unit.name?.trim().isNotEmpty == true
                      ? unit.name!
                      : 'Unit',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium,
                ),
                if (property != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    property!.name,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ==========================================================
        // UNIT INFORMATION
        // ==========================================================

        _InfoCard(
          title: 'Unit Information',
          children: [
            _InfoRow(
              label: 'Floor',
              value: unit.floorNumber.toString(),
            ),
            _InfoRow(
              label: 'Unit Number',
              value: unit.unitNumber,
            ),
            _InfoRow(
              label: 'Status',
              value: _statusLabel(unit.status),
            ),
            _InfoRow(
              label: 'Unit Name',
              value: unit.name?.trim().isNotEmpty == true
                  ? unit.name!
                  : 'Not provided',
            ),

            // ------------------------------------------------------
            // CURRENT RENT
            // ------------------------------------------------------
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

        const SizedBox(height: 20),

        // ==========================================================
        // CURRENT TENANTS
        // ==========================================================

        _TenantSection(
          tenants: activeTenants,
        ),

        const SizedBox(height: 20),

        // ==========================================================
        // MANAGE RENT
        // ==========================================================

        _ManageRentCard(
          unit: unit,
        ),

        const SizedBox(height: 20),

        // ==========================================================
        // TENANCY HISTORY
        // ==========================================================

        _UnitHistorySection(
          historyAsync: historyAsync,
          propertyLoadError: propertyLoadError,
        ),
      ],
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
    final rentAsync = ref.watch(
      currentRentRateProvider((
      unitId: unitId,
      ownerId: ownerId,
      )),
    );

    return rentAsync.when(
      loading: () {
        return const _LoadingInfoRow(
          label: 'Current Rent',
        );
      },
      error: (error, _) {
        return const _InfoRow(
          label: 'Current Rent',
          value: 'Unable to load',
        );
      },
      data: (rentRate) {
        if (rentRate == null) {
          return const _InfoRow(
            label: 'Current Rent',
            value: 'Not set',
          );
        }

        return _InfoRow(
          label: 'Current Rent',
          value: '৳ ${_formatRent(rentRate.amount)} / month',
          valueStyle: const TextStyle(
            fontWeight: FontWeight.w800,
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
    if (propertyLoadError) {
      return const _InfoCard(
        title: 'Tenancy History',
        children: [
          _InfoRow(
            label: 'History',
            value: 'Unable to load property information.',
          ),
        ],
      );
    }

    if (historyAsync == null) {
      return const _InfoCard(
        title: 'Tenancy History',
        children: [
          _LoadingInfoRow(
            label: 'Previous tenants',
          ),
        ],
      );
    }

    return historyAsync!.when(
      loading: () {
        return const _InfoCard(
          title: 'Tenancy History',
          children: [
            _LoadingInfoRow(
              label: 'Previous tenants',
            ),
          ],
        );
      },
      error: (_, _) {
        return const _InfoCard(
          title: 'Tenancy History',
          children: [
            _InfoRow(
              label: 'History',
              value: 'Unable to load.',
            ),
          ],
        );
      },
      data: (histories) {
        if (histories.isEmpty) {
          return const _InfoCard(
            title: 'Tenancy History',
            children: [
              _InfoRow(
                label: 'History',
                value: 'No previous tenant.',
              ),
            ],
          );
        }

        return _UnitHistoryCard(
          histories: histories,
        );
      },
    );
  }
}

// ============================================================================
// UNIT HISTORY CARD
// ============================================================================

class _UnitHistoryCard extends StatelessWidget {
  final List<TenancyHistory> histories;

  const _UnitHistoryCard({
    required this.histories,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Tenancy History',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${histories.length} previous '
                  '${histories.length == 1 ? 'tenancy' : 'tenancies'}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
            const SizedBox(height: 16),
            ...List.generate(
              histories.length,
                  (index) {
                final history = histories[index];

                return Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    if (index > 0)
                      const Divider(height: 28),
                    _UnitHistoryItem(
                      history: history,
                    ),
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

// ============================================================================
// UNIT HISTORY ITEM
// ============================================================================

class _UnitHistoryItem extends StatelessWidget {
  final TenancyHistory history;

  const _UnitHistoryItem({
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              child: Text(
                _initial(history.tenantName),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    history.tenantName,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    history.propertyName,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _HistoryDetailRow(
          label: 'Property Code',
          value: history.propertyCode,
        ),
        _HistoryDetailRow(
          label: 'Unit',
          value: history.unitName?.trim().isNotEmpty == true
              ? history.unitName!
              : history.unitNumber,
        ),
        _HistoryDetailRow(
          label: 'Floor',
          value: history.floorNumber.toString(),
        ),
        _HistoryDetailRow(
          label: 'Monthly Rent',
          value: history.monthlyRent == null
              ? 'Not provided'
              : '৳ ${_formatRent(history.monthlyRent!)}',
        ),
        _HistoryDetailRow(
          label: 'Started',
          value: _formatDate(history.startedAt),
        ),
        _HistoryDetailRow(
          label: 'Ended',
          value: _formatDate(history.endedAt),
        ),
        _HistoryDetailRow(
          label: 'Duration',
          value: _formatDuration(
            history.startedAt,
            history.endedAt,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
          ),
          child: Text(
            'Ended',
            style: Theme.of(context)
                .textTheme
                .labelMedium,
          ),
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

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  String _formatDuration(
      DateTime startedAt,
      DateTime endedAt,
      ) {
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
// INFO CARD
// ============================================================================

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TENANT SECTION
// ============================================================================

class _TenantSection extends StatelessWidget {
  final List<Tenant> tenants;

  const _TenantSection({
    required this.tenants,
  });

  @override
  Widget build(BuildContext context) {
    if (tenants.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Current Tenants',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No active tenant assigned to this unit.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Current Tenants',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium,
                  ),
                ),
                Text(
                  tenants.length.toString(),
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...tenants.map(
                  (tenant) => Padding(
                padding:
                const EdgeInsets.only(bottom: 12),
                child: _TenantTile(
                  tenant: tenant,
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
// TENANT TILE
// ============================================================================

class _TenantTile extends StatelessWidget {
  final Tenant tenant;

  const _TenantTile({
    required this.tenant,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                child: Text(
                  _initial(tenant.name),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium,
                ),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 5),
                    Text(
                      tenant.phone,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _TenantStatusChip(
                          status: tenant.status,
                        ),
                        const SizedBox(width: 8),
                        if (tenant.userId == null)
                          const _AccountStatusChip(
                            label: 'Not registered',
                          )
                        else
                          const _AccountStatusChip(
                            label: 'Registered',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
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
// TENANT STATUS CHIP
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

    final isActive =
        status == TenantStatus.active;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(20),
        color: isActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(
          color: isActive
              ? colorScheme
              .onPrimaryContainer
              : colorScheme
              .onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================================
// ACCOUNT STATUS CHIP
// ============================================================================

class _AccountStatusChip extends StatelessWidget {
  final String label;

  const _AccountStatusChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(20),
        color: colorScheme
            .surfaceContainerHighest,
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(
          color:
          colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================================
// INFO ROW
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
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 14,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: valueStyle ??
                  Theme.of(context)
                      .textTheme
                      .bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HISTORY DETAIL ROW
// ============================================================================

class _HistoryDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _HistoryDetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LOADING INFO
// ============================================================================

class _LoadingInfoRow extends StatelessWidget {
  final String label;

  const _LoadingInfoRow({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 14,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium,
            ),
          ),
          const SizedBox(width: 12),
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        ],
      ),
    );
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Rent Management',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Change the unit rent and view the complete '
                  'rent rate history.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  context.push(
                    RouteNames.unitRentManagement
                        .replaceFirst(
                      ':unitId',
                      unit.id,
                    ),
                  );
                },
                icon: const Icon(
                  Icons.payments_outlined,
                ),
                label: const Text(
                  'Manage Rent',
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
// ERROR VIEW
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
              Icons.error_outline,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
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

// ============================================================================
// NOT FOUND VIEW
// ============================================================================

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Unit not found.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}