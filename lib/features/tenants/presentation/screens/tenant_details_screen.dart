import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/unit_provider.dart';
import '../../domain/entities/tenancy_history.dart';
import '../../domain/entities/tenant.dart';
import '../controllers/tenant_controller.dart';
import '../providers/property_tenants_provider.dart';
import '../providers/tenancy_history_provider.dart';
import 'start_new_tenancy_screen.dart';

class TenantDetailsScreen extends ConsumerStatefulWidget {
  final String tenantId;

  const TenantDetailsScreen({
    super.key,
    required this.tenantId,
  });

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

  // ========================================================================
  // END TENANCY
  // ========================================================================

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
            'Are you sure you want to end the active tenancy of "${tenant
                .name}"?\n\n'
                'The resident will be marked as inactive and the assigned unit will immediately become vacant and available.',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.error?.toString() ?? 'Unable to end tenancy agreement.',
          ),
          backgroundColor: Theme
              .of(context)
              .colorScheme
              .error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _tenant = endedTenant;
    });

    ref.invalidate(propertyTenantsProvider(tenant.propertyId));
    ref.invalidate(propertyByIdProvider(tenant.propertyId));
    ref.invalidate(unitByIdProvider(tenant.unitId));
    ref.invalidate(
      tenantHistoryProvider((
      tenantId: tenant.id,
      ownerId: tenant.ownerId,
      )),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tenancy agreement ended successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ========================================================================
  // START NEW TENANCY
  // ========================================================================

  Future<void> _startNewTenancy() async {
    final tenant = _tenant;
    if (tenant == null) {
      return;
    }

    if (tenant.status != TenantStatus.inactive) {
      return;
    }

    if (tenant.accountStatus != TenantAccountStatus.registered) {
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StartNewTenancyScreen(tenant: tenant),
      ),
    );

    if (!mounted || result != true) {
      return;
    }

    await _loadTenant();
  }

  // ========================================================================
  // DELETE TENANT
  // ========================================================================

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

    final success = await ref
        .read(tenantControllerProvider.notifier)
        .deleteTenant(tenant.id);

    if (!mounted) {
      return;
    }

    if (!success) {
      final state = ref.read(tenantControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.error?.toString() ?? 'Unable to delete resident record.',
          ),
          backgroundColor: Theme
              .of(context)
              .colorScheme
              .error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resident Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resident Details')),
        body: _ErrorView(
          message: _errorMessage!,
          onRetry: _loadTenant,
        ),
      );
    }

    final tenant = _tenant;
    if (tenant == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resident Details')),
        body: const Center(child: Text('Resident information not found.')),
      );
    }

    final tenantState = ref.watch(tenantControllerProvider);
    final propertyAsync = ref.watch(propertyByIdProvider(tenant.propertyId));
    final unitAsync = ref.watch(unitByIdProvider(tenant.unitId));
    final historyAsync = ref.watch(
      tenantHistoryProvider((
      tenantId: tenant.id,
      ownerId: tenant.ownerId,
      )),
    );

    final isActive = tenant.status == TenantStatus.active;
    final canStartNewTenancy = tenant.status == TenantStatus.inactive &&
        tenant.accountStatus == TenantAccountStatus.registered;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Resident Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
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

              setState(() {
                _tenant = result;
              });

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
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete Resident',
            onPressed: tenantState.isLoading ? null : _deleteTenant,
            icon: const Icon(Icons.delete_outline_rounded),
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
            // 1. Profile Hero Header
            _TenantHeroCard(tenant: tenant),

            const SizedBox(height: 18),

            // 2. Tenancy Status Action Card
            if (isActive) ...[
              _ActiveTenancyActionCard(
                isLoading: tenantState.isLoading,
                onEndTenancy: _endTenancy,
              ),
              const SizedBox(height: 18),
            ] else
              if (canStartNewTenancy) ...[
                _NewTenancyActionCard(
                  isLoading: tenantState.isLoading,
                  onStartNewTenancy: _startNewTenancy,
                ),
                const SizedBox(height: 18),
              ],

            // 3. Property & Space Allocation
            _buildSectionCard(
              title: 'Current Allocation',
              subtitle: 'Assigned property and residential space',
              icon: Icons.apartment_rounded,
              children: [
                propertyAsync.when(
                  loading: () => const _LoadingDetailRow(label: 'Property'),
                  error: (_, _) =>
                  const _DetailRow(
                    label: 'Property',
                    value: 'Property information unavailable',
                  ),
                  data: (property) =>
                      _DetailRow(
                        label: 'Property',
                        value: property != null
                            ? '${property.name} (${property.propertyCode})'
                            : 'Property record not found',
                      ),
                ),
                const SizedBox(height: 10),
                unitAsync.when(
                  loading: () => const _LoadingDetailRow(label: 'Unit / Floor'),
                  error: (_, _) =>
                  const _DetailRow(
                    label: 'Unit / Floor',
                    value: 'Unit information unavailable',
                  ),
                  data: (unit) =>
                      _DetailRow(
                        label: 'Unit / Floor',
                        value: _unitDisplayName(unit),
                      ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 4. Contact & Identification Credentials
            _buildSectionCard(
              title: 'Contact & Identification',
              subtitle: 'Phone, email, and verified identity records',
              icon: Icons.contact_page_outlined,
              children: [
                _DetailRow(
                  label: 'Phone Number',
                  value: tenant.phone,
                  isSelectable: true,
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Email Address',
                  value: tenant.email
                      ?.trim()
                      .isNotEmpty == true
                      ? tenant.email!.trim()
                      : 'Email not linked to this resident record',
                  isSelectable: true,
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'National ID (NID)',
                  value: tenant.nidNumber
                      ?.trim()
                      .isNotEmpty == true
                      ? tenant.nidNumber!
                      : 'Not provided',
                  isSelectable: true,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 5. Tenancy History Stream
            historyAsync.when(
              loading: () =>
                  _buildSectionCard(
                    title: 'Tenancy History',
                    subtitle: 'Past agreements and occupancy snapshots',
                    icon: Icons.history_rounded,
                    children: const [
                      LinearProgressIndicator(),
                    ],
                  ),
              error: (_, _) =>
                  _buildSectionCard(
                    title: 'Tenancy History',
                    subtitle: 'Past agreements and occupancy snapshots',
                    icon: Icons.history_rounded,
                    children: const [
                      Text('Unable to load tenancy history records.'),
                    ],
                  ),
              data: (histories) {
                if (histories.isEmpty) {
                  return _buildSectionCard(
                    title: 'Tenancy History',
                    subtitle: 'Past agreements and occupancy snapshots',
                    icon: Icons.history_rounded,
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

                return _TenancyHistorySection(
                  histories: histories,
                  formatDate: _formatDate,
                );
              },
            ),

            const SizedBox(height: 18),

            // 6. Griho Account Metadata
            _buildSectionCard(
              title: 'Account Information',
              subtitle: 'System registration and account lifecycle status',
              icon: Icons.badge_outlined,
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
                  value: _formatDate(tenant.createdAt),
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  label: 'Last Updated',
                  value: _formatDate(tenant.updatedAt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
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

  String _unitDisplayName(Unit? unit) {
    if (unit == null) {
      return 'Unit not found';
    }
    final name = unit.name?.trim();
    if (name != null && name.isNotEmpty) {
      return '$name (Unit ${unit.unitNumber} • Floor ${unit.floorNumber})';
    }
    return 'Unit ${unit.unitNumber} • Floor ${unit.floorNumber}';
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} at $hour:$minute';
  }
}

// ============================================================================
// PROFILE HERO CARD
// ============================================================================

class _TenantHeroCard extends StatelessWidget {
  final Tenant tenant;

  const _TenantHeroCard({required this.tenant});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = tenant.status == TenantStatus.active;
    final isRegistered =
        tenant.accountStatus == TenantAccountStatus.registered;

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
                  _initials(tenant.name),
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
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? Icons.check_circle_rounded : Icons
                          .pause_circle_rounded,
                      size: 14,
                      color: isActive ? Colors.green.shade800 : Colors.orange
                          .shade800,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isActive ? 'Active Lease' : 'Inactive / Vacated',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.green.shade800 : Colors.orange
                            .shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isRegistered
                      ? Colors.teal.withValues(alpha: 0.12)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRegistered ? Icons.verified_user_rounded : Icons
                          .person_outline,
                      size: 14,
                      color: isRegistered ? Colors.teal.shade800 : theme
                          .colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isRegistered ? 'Registered User' : 'Unregistered',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isRegistered ? Colors.teal.shade800 : theme
                            .colorScheme.onSurfaceVariant,
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

  static String _initials(String name) {
    final value = name.trim();
    if (value.isEmpty) {
      return 'T';
    }
    final parts =
    value.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ============================================================================
// CONTEXTUAL ACTIONS
// ============================================================================

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
                Icon(
                  Icons.assignment_return_outlined,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'End Active Lease',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Concluding this tenancy will finalize occupancy records and mark the assigned unit available for new tenants.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                ),
                onPressed: isLoading ? null : onEndTenancy,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'End Tenancy Agreement',
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

class _NewTenancyActionCard extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onStartNewTenancy;

  const _NewTenancyActionCard({
    required this.isLoading,
    required this.onStartNewTenancy,
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
                Icon(
                  Icons.add_home_work_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Initiate New Tenancy',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'This resident is currently inactive. You can assign them to a vacant apartment and establish recurring rent terms.',
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
                onPressed: isLoading ? null : onStartNewTenancy,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Assign Unit & Start Tenancy',
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
// TENANCY HISTORY SECTION
// ============================================================================

class _TenancyHistorySection extends StatelessWidget {
  final List<TenancyHistory> histories;
  final String Function(DateTime) formatDate;

  const _TenancyHistorySection({
    required this.histories,
    required this.formatDate,
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
                Icon(Icons.history_rounded, size: 20,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Tenancy History (${histories.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Past lease terms and occupancy records',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < histories.length; index++) ...[
              _TenancyHistoryItem(
                history: histories[index],
                formatDate: formatDate,
              ),
              if (index != histories.length - 1) const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _TenancyHistoryItem extends StatelessWidget {
  final TenancyHistory history;
  final String Function(DateTime) formatDate;

  const _TenancyHistoryItem({
    required this.history,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitDisplay = history.unitName
        ?.trim()
        .isNotEmpty == true
        ? '${history.unitName!} (Unit ${history.unitNumber})'
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
        _HistoryDataRow(label: 'Unit / Floor',
            value: '$unitDisplay • Floor ${history.floorNumber}'),
        _HistoryDataRow(
          label: 'Monthly Rent',
          value: history.monthlyRent != null
              ? '৳ ${_formatRent(history.monthlyRent!)}'
              : 'Not recorded',
        ),
        _HistoryDataRow(
            label: 'Commenced', value: formatDate(history.startedAt)),
        _HistoryDataRow(label: 'Vacated', value: formatDate(history.endedAt)),
      ],
    );
  }

  String _formatRent(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
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

// ============================================================================
// DETAIL ROW
// ============================================================================

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
