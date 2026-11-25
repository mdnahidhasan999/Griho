// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';
import '../../../units/presentation/providers/unit_provider.dart';
import '../../domain/entities/tenancy_history.dart';
import '../../domain/entities/tenant.dart';
import '../controllers/tenant_controller.dart';
import '../providers/owner_tenants_provider.dart';
import '../providers/property_tenants_provider.dart';
import '../providers/tenancy_history_provider.dart';
import '../widgets/tenant_ui_helpers.dart';
import 'start_new_tenancy_screen.dart';

class TenantDetailsScreen extends ConsumerStatefulWidget {
  final String tenantId;

  const TenantDetailsScreen({super.key, required this.tenantId});

  @override
  ConsumerState<TenantDetailsScreen> createState() =>
      _TenantDetailsScreenState();
}

class _TenantDetailsScreenState extends ConsumerState<TenantDetailsScreen> {
  Tenant? _tenant;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTenant();
  }

  Future<void> _loadTenant() async {
    try {
      final getTenant = ref.read(getTenantProvider);
      final tenant = await getTenant(widget.tenantId);

      if (!mounted) {
        return;
      }

      setState(() {
        _tenant = tenant;
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

  Future<void> _endTenancy() async {
    final tenant = _tenant;
    if (tenant == null || tenant.status != TenantStatus.active) {
      return;
    }

    final shouldEndTenancy = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('End Current Tenancy?'),
          content: Text(
            'Are you sure you want to end the active tenancy of "${tenant.name}"?\n\n'
            'The resident will be marked as inactive and the assigned unit will immediately become vacant and available.',
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
              child: const Text('End Tenancy'),
            ),
          ],
        );
      },
    );

    if (shouldEndTenancy != true || !mounted) {
      return;
    }

    final endedTenant = await ref
        .read(tenantControllerProvider.notifier)
        .endTenancy(tenant.id);

    if (!mounted) {
      return;
    }

    if (endedTenant == null) {
      final state = ref.read(tenantControllerProvider);
      GrihoFeedback.showError(
        context,
        state.error?.toString().replaceFirst('Bad state: ', '') ??
            'Unable to end tenancy agreement.',
      );
      return;
    }

    setState(() => _tenant = endedTenant);

    ref.invalidate(ownerTenantsProvider);
    ref.invalidate(propertyTenantsProvider(tenant.propertyId));
    ref.invalidate(propertyUnitsProvider(tenant.propertyId));
    ref.invalidate(propertyByIdProvider(tenant.propertyId));
    ref.invalidate(unitByIdProvider(tenant.unitId));
    ref.invalidate(
      tenantHistoryProvider((tenantId: tenant.id, ownerId: tenant.ownerId)),
    );

    GrihoFeedback.showSuccess(context, 'Tenancy agreement ended successfully.');
  }

  Future<void> _startNewTenancy() async {
    final tenant = _tenant;
    if (tenant == null ||
        tenant.status != TenantStatus.inactive ||
        tenant.accountStatus != TenantAccountStatus.registered) {
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => StartNewTenancyScreen(tenant: tenant)),
    );

    if (!mounted || result != true) {
      return;
    }

    await _loadTenant();
  }

  Future<void> _deleteTenant() async {
    final tenant = _tenant;
    if (tenant == null) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Resident Record?'),
          content: Text(
            'Are you sure you want to permanently delete "${tenant.name}"?\n\n'
            'This action cannot be undone and will detach all associated history.',
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

    final success = await ref
        .read(tenantControllerProvider.notifier)
        .deleteTenant(tenant.id);

    if (!mounted) {
      return;
    }

    if (!success) {
      final state = ref.read(tenantControllerProvider);
      GrihoFeedback.showError(
        context,
        state.error?.toString().replaceFirst('Bad state: ', '') ??
            'Unable to delete resident record.',
      );
      return;
    }

    ref.invalidate(ownerTenantsProvider);
    ref.invalidate(propertyTenantsProvider(tenant.propertyId));
    ref.invalidate(propertyUnitsProvider(tenant.propertyId));

    GrihoFeedback.showSuccess(context, 'Resident record deleted.');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resident Details')),
        body: const GrihoLoadingView(message: 'Loading resident details...'),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resident Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load resident',
              subtitle: _errorMessage!,
              actionLabel: 'Retry',
              onAction: _loadTenant,
            ),
          ),
        ),
      );
    }

    final tenant = _tenant;
    if (tenant == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resident Details')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.user_remove,
              title: 'Resident Not Found',
              subtitle: 'Resident information could not be found.',
            ),
          ),
        ),
      );
    }

    final tenantState = ref.watch(tenantControllerProvider);
    final propertyAsync = ref.watch(propertyByIdProvider(tenant.propertyId));
    final unitAsync = ref.watch(unitByIdProvider(tenant.unitId));
    final historyAsync = ref.watch(
      tenantHistoryProvider((tenantId: tenant.id, ownerId: tenant.ownerId)),
    );

    final isActive = tenant.status == TenantStatus.active;
    final canStartNewTenancy =
        tenant.status == TenantStatus.inactive &&
        tenant.accountStatus == TenantAccountStatus.registered;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Resident Details'),
        actions: [
          IconButton(
            tooltip: 'Edit Resident',
            onPressed: tenantState.isLoading
                ? null
                : () async {
                    final result = await context.push<Tenant>(
                      RouteNames.editTenant.replaceFirst(
                        ':tenantId',
                        tenant.id,
                      ),
                      extra: tenant,
                    );

                    if (!context.mounted || result == null) {
                      return;
                    }

                    setState(() => _tenant = result);

                    ref.invalidate(ownerTenantsProvider);
                    ref.invalidate(propertyTenantsProvider(result.propertyId));
                    ref.invalidate(propertyByIdProvider(result.propertyId));
                    ref.invalidate(unitByIdProvider(result.unitId));
                    ref.invalidate(
                      tenantHistoryProvider((
                        tenantId: result.id,
                        ownerId: result.ownerId,
                      )),
                    );
                  },
            icon: const Icon(Iconsax.edit_2),
          ),
          IconButton(
            tooltip: 'Delete Resident',
            onPressed: tenantState.isLoading ? null : _deleteTenant,
            icon: const Icon(Iconsax.trash),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadTenant();
          if (mounted) {
            final currentTenant = _tenant;
            if (currentTenant != null) {
              ref.invalidate(
                tenantHistoryProvider((
                  tenantId: currentTenant.id,
                  ownerId: currentTenant.ownerId,
                )),
              );
            }
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            _TenantHeroCard(tenant: tenant),
            const SizedBox(height: 18),
            if (isActive) ...[
              _ActiveTenancyActionCard(
                isLoading: tenantState.isLoading,
                onEndTenancy: _endTenancy,
              ),
              const SizedBox(height: 18),
            ] else if (canStartNewTenancy) ...[
              _NewTenancyActionCard(
                isLoading: tenantState.isLoading,
                onStartNewTenancy: _startNewTenancy,
              ),
              const SizedBox(height: 18),
            ],
            GrihoSectionCard(
              title: 'Current Allocation',
              subtitle: 'Assigned property and residential space',
              icon: Iconsax.buildings_2,
              children: [
                propertyAsync.when(
                  loading: () => const _LoadingDetailRow(label: 'Property'),
                  error: (_, _) => const _DetailRow(
                    label: 'Property',
                    value: 'Property information unavailable',
                  ),
                  data: (property) => _DetailRow(
                    label: 'Property',
                    value: property != null
                        ? '${property.name} (${property.propertyCode})'
                        : 'Property record not found',
                  ),
                ),
                const SizedBox(height: 10),
                unitAsync.when(
                  loading: () => const _LoadingDetailRow(label: 'Unit / Floor'),
                  error: (_, _) => const _DetailRow(
                    label: 'Unit / Floor',
                    value: 'Unit information unavailable',
                  ),
                  data: (Unit? unit) => _DetailRow(
                    label: 'Unit / Floor',
                    value: formatUnitDisplay(unit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GrihoSectionCard(
              title: 'Contact & Identification',
              subtitle: 'Phone, email, and verified identity records',
              icon: Iconsax.personalcard,
              children: [
                _DetailRow(
                  label: 'Phone Number',
                  value: tenant.phone,
                  isSelectable: true,
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Email Address',
                  value: tenant.email?.trim().isNotEmpty == true
                      ? tenant.email!.trim()
                      : 'Email not linked',
                  isSelectable: true,
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'National ID (NID)',
                  value: tenant.nidNumber?.trim().isNotEmpty == true
                      ? tenant.nidNumber!
                      : 'Not provided',
                  isSelectable: true,
                ),
              ],
            ),
            const SizedBox(height: 18),
            historyAsync.when(
              loading: () => const GrihoSectionCard(
                title: 'Tenancy History',
                subtitle: 'Past agreements and occupancy snapshots',
                icon: Iconsax.clock,
                children: [LinearProgressIndicator()],
              ),
              error: (_, _) => const GrihoSectionCard(
                title: 'Tenancy History',
                subtitle: 'Past agreements and occupancy snapshots',
                icon: Iconsax.clock,
                children: [Text('Unable to load tenancy history records.')],
              ),
              data: (histories) {
                if (histories.isEmpty) {
                  return GrihoSectionCard(
                    title: 'Tenancy History',
                    subtitle: 'Past agreements and occupancy snapshots',
                    icon: Iconsax.clock,
                    children: [
                      Text(
                        'No previous historical tenancies recorded for this resident.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                }

                return GrihoSectionCard(
                  title: 'Tenancy History (${histories.length})',
                  subtitle: 'Past lease terms and occupancy records',
                  icon: Iconsax.clock,
                  children: [
                    for (var index = 0; index < histories.length; index++) ...[
                      _TenancyHistoryItem(history: histories[index]),
                      if (index != histories.length - 1)
                        const Divider(height: 24),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            GrihoSectionCard(
              title: 'Account Information',
              subtitle: 'System registration and account lifecycle status',
              icon: Iconsax.shield_tick,
              children: [
                _DetailRow(
                  label: 'Griho Account',
                  value: tenant.accountStatus == TenantAccountStatus.registered
                      ? 'Registered Griho User'
                      : 'Not Registered',
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Onboarding Status',
                  value: _confirmationStatusLabel(tenant.confirmationStatus),
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Record Created',
                  value: formatTenantDate(tenant.createdAt, includeTime: true),
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Last Updated',
                  value: formatTenantDate(tenant.updatedAt, includeTime: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _confirmationStatusLabel(TenantConfirmationStatus status) {
    switch (status) {
      case TenantConfirmationStatus.pending:
        return 'Pending Invitation Acceptance';
      case TenantConfirmationStatus.confirmed:
        return 'Confirmed & Verified';
      case TenantConfirmationStatus.rejected:
        return 'Declined Invitation';
    }
  }
}

class _TenantHeroCard extends StatelessWidget {
  final Tenant tenant;

  const _TenantHeroCard({required this.tenant});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRegistered = tenant.accountStatus == TenantAccountStatus.registered;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  tenantInitials(tenant.name),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tenant.phone,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              TenantStatusChip(status: tenant.status),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isRegistered
                      ? GrihoColors.emerald.withValues(alpha: 0.14)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRegistered ? Iconsax.verify : Iconsax.user,
                      size: 13,
                      color: isRegistered
                          ? GrihoColors.emerald
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isRegistered ? 'Registered User' : 'Unregistered',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isRegistered
                            ? GrihoColors.emerald
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveTenancyActionCard extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onEndTenancy;

  const _ActiveTenancyActionCard({
    required this.isLoading,
    required this.onEndTenancy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GrihoSectionCard(
      title: 'End Active Lease',
      subtitle:
          'Concluding this tenancy will finalize occupancy records and mark the assigned unit available.',
      icon: Iconsax.logout,
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
            onPressed: isLoading ? null : onEndTenancy,
            icon: const Icon(Iconsax.logout, size: 18),
            label: const Text(
              'End Tenancy Agreement',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _NewTenancyActionCard extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onStartNewTenancy;

  const _NewTenancyActionCard({
    required this.isLoading,
    required this.onStartNewTenancy,
  });

  @override
  Widget build(BuildContext context) {
    return GrihoSectionCard(
      title: 'Initiate New Tenancy',
      subtitle:
          'This resident is currently inactive. Assign them to a vacant apartment and establish recurring rent terms.',
      icon: Iconsax.building_4,
      children: [
        GrihoPrimaryButton(
          label: 'Assign Unit & Start Tenancy',
          icon: Iconsax.add,
          isLoading: isLoading,
          onPressed: onStartNewTenancy,
        ),
      ],
    );
  }
}

class _TenancyHistoryItem extends StatelessWidget {
  final TenancyHistory history;

  const _TenancyHistoryItem({required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitDisplay = history.unitName?.trim().isNotEmpty == true
        ? '${history.unitName!} (Unit${history.unitNumber})'
        : 'Unit ${history.unitNumber}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                history.propertyName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
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
        const SizedBox(height: 10),
        _HistoryDataRow(
          label: 'Unit / Floor',
          value: '$unitDisplay • Floor ${history.floorNumber}',
        ),
        _HistoryDataRow(
          label: 'Monthly Rent',
          value: history.monthlyRent != null
              ? '৳ ${formatTenantAmount(history.monthlyRent)}'
              : 'Not recorded',
        ),
        _HistoryDataRow(
          label: 'Commenced',
          value: formatTenantDate(history.startedAt, includeTime: true),
        ),
        _HistoryDataRow(
          label: 'Vacated',
          value: formatTenantDate(history.endedAt, includeTime: true),
        ),
      ],
    );
  }
}

class _HistoryDataRow extends StatelessWidget {
  final String label;
  final String value;

  const _HistoryDataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelectable;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isSelectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: isSelectable
              ? SelectableText(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                )
              : Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }
}

class _LoadingDetailRow extends StatelessWidget {
  final String label;

  const _LoadingDetailRow({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      ],
    );
  }
}
