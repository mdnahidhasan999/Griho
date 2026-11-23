// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../rents/presentation/providers/rent_rate_provider.dart';
import '../../../tenants/data/models/tenant_model.dart';
import '../../../tenants/domain/entities/tenancy_history.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/controllers/tenant_controller.dart';
import '../../../tenants/presentation/providers/tenancy_history_provider.dart';
import '../../domain/entities/unit.dart';
import '../controllers/unit_controller.dart';
import '../providers/property_units_provider.dart';
import '../providers/unit_provider.dart';
import '../providers/unit_usecase_provider.dart';
import '../widgets/unit_ui_helpers.dart';

class UnitDetailsScreen extends ConsumerStatefulWidget {
  final String unitId;

  const UnitDetailsScreen({super.key, required this.unitId});

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
    _loadUnit(forceRefresh: false);
  }

  Future<void> _loadUnit({bool forceRefresh = true}) async {
    try {
      final unit = forceRefresh
          ? await ref.read(getUnitProvider)(widget.unitId)
          : await ref.read(unitByIdProvider(widget.unitId).future);

      if (!mounted) {
        return;
      }

      List<Tenant> activeTenants = [];

      if (unit != null) {
        final getActiveTenantsByUnitId = ref.read(
          getActiveTenantsByUnitIdProvider,
        );
        activeTenants = await getActiveTenantsByUnitId(unit.id);

        if (activeTenants.isEmpty && unit.status == UnitStatus.occupied) {
          final snap = await FirebaseFirestore.instance
              .collection('tenants')
              .where('unitId', isEqualTo: unit.id)
              .where('status', isEqualTo: 'active')
              .limit(10)
              .get();

          activeTenants = snap.docs
              .map((doc) => TenantModel.fromFirestore(doc))
              .toList();
        }
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

    // Update local state directly and invalidate caches without extra immediate read.
    setState(() => _unit = updatedUnit);
    ref.invalidate(unitByIdProvider(updatedUnit.id));
    ref.invalidate(propertyUnitsProvider(updatedUnit.propertyId));
  }

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
            'Are you sure you want to permanently delete "${unit.unitNumber}"?\n\n'
            'Associated billing rules and past tenancy references will be affected. This action cannot be undone.',
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

    final controller = ref.read(unitControllerProvider.notifier);
    final success = await controller.deleteUnit(unitId: unit.id);

    if (!mounted) {
      return;
    }

    if (success) {
      ref.invalidate(unitByIdProvider(unit.id));
      ref.invalidate(propertyUnitsProvider(unit.propertyId));
      GrihoFeedback.showSuccess(context, 'Unit deleted.');
      context.pop();
      return;
    }

    setState(() => _isDeleting = false);

    final errorMessage = ref.read(unitControllerProvider).errorMessage;
    GrihoFeedback.showError(context, errorMessage ?? 'Unable to delete unit.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Unit Details')),
        body: const GrihoLoadingView(message: 'Loading unit details...'),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Unit Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load unit',
              subtitle: _errorMessage!,
              actionLabel: 'Retry',
              onAction: () => _loadUnit(forceRefresh: true),
            ),
          ),
        ),
      );
    }

    final unit = _unit;

    if (unit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Unit Details')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.home_2,
              title: 'Unit Not Found',
              subtitle:
                  'The requested unit record does not exist or may have been deleted.',
            ),
          ),
        ),
      );
    }

    final propertyAsync = ref.watch(propertyByIdProvider(unit.propertyId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Unit Details'),
        actions: [
          IconButton(
            tooltip: 'Edit Unit',
            icon: const Icon(Iconsax.edit_2),
            onPressed: _isDeleting ? null : _editUnit,
          ),
          IconButton(
            tooltip: 'Delete Unit',
            icon: const Icon(Iconsax.trash),
            onPressed: _isDeleting ? null : _deleteUnit,
          ),
        ],
      ),
      body: Stack(
        children: [
          propertyAsync.when(
            loading: () => _UnitDetails(
              unit: unit,
              activeTenants: _activeTenants,
              property: null,
              historyAsync: null,
              onReload: () => _loadUnit(forceRefresh: true),
            ),
            error: (_, _) => _UnitDetails(
              unit: unit,
              activeTenants: _activeTenants,
              property: null,
              historyAsync: null,
              propertyLoadError: true,
              onReload: () => _loadUnit(forceRefresh: true),
            ),
            data: (Property? property) {
              if (property == null) {
                return _UnitDetails(
                  unit: unit,
                  activeTenants: _activeTenants,
                  property: null,
                  historyAsync: null,
                  propertyLoadError: true,
                  onReload: () => _loadUnit(forceRefresh: true),
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
                onReload: () => _loadUnit(forceRefresh: true),
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
                      child: GrihoLoadingView(message: 'Deleting unit...'),
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
        ref.invalidate(unitByIdProvider(unit.id));
        ref.invalidate(propertyByIdProvider(unit.propertyId));
        if (property != null) {
          ref.invalidate(
            unitHistoryProvider((unitId: unit.id, ownerId: property!.ownerId)),
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
          _HeroUnitHeader(unit: unit, property: property),
          const SizedBox(height: 16),
          GrihoSectionCard(
            title: 'Unit Specifications',
            subtitle: 'Location and space identifiers',
            icon: Iconsax.home_2,
            children: [
              _InfoRow(label: 'Unit Number', value: unit.unitNumber),
              const SizedBox(height: 10),
              _InfoRow(
                label: 'Floor Level',
                value: formatUnitFloorLabel(unit.floorNumber),
              ),
              const SizedBox(height: 10),
              _InfoRow(
                label: 'Custom Name',
                value: unit.name?.trim().isNotEmpty == true
                    ? unit.name!
                    : 'Not provided',
              ),
              const SizedBox(height: 10),
              _InfoRow(
                label: 'Status',
                value: unitStatusLabel(unit.status, detailed: true),
              ),
              const SizedBox(height: 10),
              if (property != null)
                _CurrentRentInfo(unitId: unit.id, ownerId: property!.ownerId)
              else
                const _InfoRow(label: 'Current Rent', value: 'Unavailable'),
            ],
          ),
          const SizedBox(height: 18),
          _TenantSection(tenants: activeTenants),
          const SizedBox(height: 18),
          _ManageRentCard(
            unit: unit,
            ownerId: property?.ownerId,
            hasActiveTenant: activeTenants.isNotEmpty,
          ),
          const SizedBox(height: 18),
          _UnitHistorySection(
            historyAsync: historyAsync,
            propertyLoadError: propertyLoadError,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HERO UNIT HEADER CARD
// ============================================================================

class _HeroUnitHeader extends StatelessWidget {
  final Unit unit;
  final Property? property;

  const _HeroUnitHeader({required this.unit, required this.property});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  Iconsax.home_2,
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
                      'Unit ${unit.unitNumber}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unit.name?.trim().isNotEmpty == true
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
              UnitStatusChip(status: unit.status),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Iconsax.buildings_2,
                size: 17,
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
                  formatUnitFloorLabel(unit.floorNumber),
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

  const _CurrentRentInfo({required this.unitId, required this.ownerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rentAsync = ref.watch(
      currentRentRateProvider((unitId: unitId, ownerId: ownerId)),
    );

    return rentAsync.when(
      loading: () => const _LoadingInfoRow(label: 'Current Rent'),
      error: (_, _) => const _InfoRow(
        label: 'Current Rent',
        value: 'Unable to load rent rate',
      ),
      data: (rentRate) {
        if (rentRate == null) {
          return const _InfoRow(label: 'Current Rent', value: 'Not configured');
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
  final List<Tenant> tenants;

  const _TenantSection({required this.tenants});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GrihoSectionCard(
      title: tenants.isEmpty
          ? 'Current Residents'
          : 'Current Residents (${tenants.length})',
      subtitle: 'Active tenants linked to this residential unit',
      icon: Iconsax.people,
      children: [
        if (tenants.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.user_remove,
                  size: 20,
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
            if (i != tenants.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _TenantTile extends StatelessWidget {
  final Tenant tenant;

  const _TenantTile({required this.tenant});

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
            RouteNames.tenantDetails.replaceFirst(':tenantId', tenant.id),
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
              const Icon(Iconsax.arrow_right_3, size: 16),
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
// MANAGE RENT & INVOICES QUICK ACTIONS CARD
// ============================================================================

class _ManageRentCard extends ConsumerWidget {
  final Unit unit;
  final String? ownerId;
  final bool hasActiveTenant;

  const _ManageRentCard({
    required this.unit,
    required this.ownerId,
    required this.hasActiveTenant,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GrihoSectionCard(
      title: 'Rent & Billing Operations',
      subtitle:
          'Generate monthly rent invoices, update recurring rent, or view rate changes.',
      icon: Iconsax.wallet_check,
      children: [
        GrihoPrimaryButton(
          label: 'Monthly Rent Invoices',
          icon: Iconsax.receipt_item,
          onPressed: () {
            context.push(
              RouteNames.unitMonthlyRent.replaceFirst(':unitId', unit.id),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: hasActiveTenant
                    ? () async {
                        await context.push(
                          RouteNames.changeUnitRent.replaceFirst(
                            ':unitId',
                            unit.id,
                          ),
                        );
                        if (ownerId != null && ownerId!.isNotEmpty) {
                          ref.invalidate(
                            currentRentRateProvider((
                              unitId: unit.id,
                              ownerId: ownerId!,
                            )),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Iconsax.edit_2, size: 16),
                label: const Text(
                  'Update Rent',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  context.push(
                    RouteNames.unitRentRateHistory.replaceFirst(
                      ':unitId',
                      unit.id,
                    ),
                  );
                },
                icon: const Icon(Iconsax.clock, size: 16),
                label: const Text(
                  'Rate History',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
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
      return const GrihoSectionCard(
        title: 'Tenancy History',
        subtitle: 'Past lease agreements and previous residents',
        icon: Iconsax.clock,
        children: [
          Text('Unable to load property information for historical records.'),
        ],
      );
    }

    if (historyAsync == null) {
      return const GrihoSectionCard(
        title: 'Tenancy History',
        subtitle: 'Past lease agreements and previous residents',
        icon: Iconsax.clock,
        children: [LinearProgressIndicator()],
      );
    }

    return historyAsync!.when(
      loading: () => const GrihoSectionCard(
        title: 'Tenancy History',
        subtitle: 'Past lease agreements and previous residents',
        icon: Iconsax.clock,
        children: [LinearProgressIndicator()],
      ),
      error: (_, _) => const GrihoSectionCard(
        title: 'Tenancy History',
        subtitle: 'Past lease agreements and previous residents',
        icon: Iconsax.clock,
        children: [Text('Unable to load historical tenancy records.')],
      ),
      data: (histories) {
        if (histories.isEmpty) {
          return GrihoSectionCard(
            title: 'Tenancy History',
            subtitle: 'Past lease agreements and previous residents',
            icon: Iconsax.clock,
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

        return GrihoSectionCard(
          title: 'Tenancy History (${histories.length})',
          subtitle: 'Past lease agreements and previous residents',
          icon: Iconsax.clock,
          children: [
            for (var index = 0; index < histories.length; index++) ...[
              _UnitHistoryItem(history: histories[index]),
              if (index != histories.length - 1) const Divider(height: 24),
            ],
          ],
        );
      },
    );
  }
}

class _UnitHistoryItem extends StatelessWidget {
  final TenancyHistory history;

  const _UnitHistoryItem({required this.history});

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
    final days = endedAt.difference(startedAt).inDays;
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
// STATUS & HELPER ROWS
// ============================================================================

class _TenantStatusChip extends StatelessWidget {
  final TenantStatus status;

  const _TenantStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == TenantStatus.active;
    final color = isActive ? GrihoColors.emerald : GrihoColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.14),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _AccountStatusChip extends StatelessWidget {
  final String label;

  const _AccountStatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final isRegistered =
        label.toLowerCase().contains('registered') &&
        !label.toLowerCase().contains('not');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isRegistered
            ? GrihoColors.emerald.withValues(alpha: 0.14)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isRegistered
              ? GrihoColors.emerald
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _InfoRow({required this.label, required this.value, this.valueStyle});

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
            style:
                valueStyle ??
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

  const _HistoryDetailRow({required this.label, required this.value});

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

  const _LoadingInfoRow({required this.label});

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
