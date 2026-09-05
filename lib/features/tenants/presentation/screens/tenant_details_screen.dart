import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/unit_provider.dart';
import '../../domain/entities/tenant.dart';
import '../controllers/tenant_controller.dart';
import '../providers/property_tenants_provider.dart';
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

    if (tenant == null) {
      return;
    }

    if (tenant.status != TenantStatus.active) {
      return;
    }

    final shouldEndTenancy = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('End Tenancy?'),
          content: Text(
            'Are you sure you want to end the tenancy of '
                '"${tenant.name}"?\n\n'
                'The tenant will become inactive and the unit '
                'will become available.',
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
            state.error?.toString() ??
                'Unable to end tenancy.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _tenant = endedTenant;
    });

    ref.invalidate(
      propertyTenantsProvider(tenant.propertyId),
    );

    ref.invalidate(
      propertyByIdProvider(tenant.propertyId),
    );

    ref.invalidate(
      unitByIdProvider(tenant.unitId),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tenancy ended successfully.',
        ),
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
        builder: (_) =>
            StartNewTenancyScreen(
              tenant: tenant,
            ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result != true) {
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
          title: const Text('Delete Tenant?'),
          content: Text(
            'Are you sure you want to delete '
                '"${tenant.name}"?\n\n'
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
            state.error?.toString() ??
                'Unable to delete tenant.',
          ),
        ),
      );

      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tenant Details'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tenant Details'),
        ),
        body: _ErrorView(
          message: _errorMessage!,
          onRetry: _loadTenant,
        ),
      );
    }

    final tenant = _tenant;

    if (tenant == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tenant Details'),
        ),
        body: const Center(
          child: Text('Tenant not found.'),
        ),
      );
    }

    final tenantState = ref.watch(
      tenantControllerProvider,
    );

    final propertyAsync = ref.watch(
      propertyByIdProvider(tenant.propertyId),
    );

    final unitAsync = ref.watch(
      unitByIdProvider(tenant.unitId),
    );

    final isActive = tenant.status == TenantStatus.active;

    final canStartNewTenancy =
        tenant.status == TenantStatus.inactive &&
            tenant.accountStatus == TenantAccountStatus.registered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Details'),
        actions: [
          IconButton(
            tooltip: 'Edit Tenant',
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

              if (!context.mounted) {
                return;
              }

              if (result != null) {
                setState(() {
                  _tenant = result;
                });

                ref.invalidate(
                  propertyTenantsProvider(
                    result.propertyId,
                  ),
                );

                ref.invalidate(
                  propertyByIdProvider(
                    result.propertyId,
                  ),
                );

                ref.invalidate(
                  unitByIdProvider(
                    result.unitId,
                  ),
                );
              }
            },
            icon: const Icon(
              Icons.edit_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Delete Tenant',
            onPressed: tenantState.isLoading
                ? null
                : _deleteTenant,
            icon: const Icon(
              Icons.delete_outline,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTenant,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 36,
                      child: Icon(
                        Icons.person_outline,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tenant.name,
                      textAlign: TextAlign.center,
                      style: Theme
                          .of(context)
                          .textTheme
                          .headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    _TenantStatusChip(
                      status: tenant.status,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ========================================================
            // ACTIVE TENANCY
            // ========================================================

            if (isActive) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tenancy',
                        style: Theme
                            .of(context)
                            .textTheme
                            .titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'End the current tenancy to make '
                            'the unit available for another tenant.',
                        style: Theme
                            .of(context)
                            .textTheme
                            .bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: tenantState.isLoading
                              ? null
                              : _endTenancy,
                          icon: const Icon(
                            Icons.assignment_return_outlined,
                          ),
                          label: const Text(
                            'End Tenancy',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ========================================================
            // START NEW TENANCY
            // ========================================================

            if (canStartNewTenancy) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Tenancy',
                        style: Theme
                            .of(context)
                            .textTheme
                            .titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Start a new tenancy for this registered '
                            'tenant in an available unit.',
                        style: Theme
                            .of(context)
                            .textTheme
                            .bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: tenantState.isLoading
                              ? null
                              : _startNewTenancy,
                          icon: const Icon(
                            Icons.add_home_work_outlined,
                          ),
                          label: const Text(
                            'Start New Tenancy',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ========================================================
            // TENANT INFORMATION
            // ========================================================

            _InfoCard(
              title: 'Tenant Information',
              children: [
                _InfoRow(
                  label: 'Phone',
                  value: tenant.phone,
                ),
                _InfoRow(
                  label: 'Email',
                  value: tenant.email
                      ?.trim()
                      .isNotEmpty == true
                      ? tenant.email!
                      : 'Not provided',
                ),
                _InfoRow(
                  label: 'NID Number',
                  value:
                  tenant.nidNumber
                      ?.trim()
                      .isNotEmpty == true
                      ? tenant.nidNumber!
                      : 'Not provided',
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ========================================================
            // PROPERTY INFORMATION
            // ========================================================

            _InfoCard(
              title: 'Property Information',
              children: [
                propertyAsync.when(
                  loading: () =>
                  const _LoadingInfoRow(
                    label: 'Property',
                  ),
                  error: (_, _) =>
                  const _InfoRow(
                    label: 'Property',
                    value: 'Unable to load',
                  ),
                  data: (Property? property) {
                    return _InfoRow(
                      label: 'Property',
                      value:
                      property?.name ??
                          'Property not found',
                    );
                  },
                ),
                unitAsync.when(
                  loading: () =>
                  const _LoadingInfoRow(
                    label: 'Unit',
                  ),
                  error: (_, _) =>
                  const _InfoRow(
                    label: 'Unit',
                    value: 'Unable to load',
                  ),
                  data: (Unit? unit) {
                    return _InfoRow(
                      label: 'Unit',
                      value: _unitDisplayName(unit),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ========================================================
            // ACCOUNT INFORMATION
            // ========================================================

            _InfoCard(
              title: 'Account Information',
              children: [
                _InfoRow(
                  label: 'Account Status',
                  value:
                  tenant.accountStatus ==
                      TenantAccountStatus.registered
                      ? 'Registered'
                      : 'Not registered',
                ),
                _InfoRow(
                  label: 'Confirmation',
                  value:
                  tenant.confirmationStatus ==
                      TenantConfirmationStatus.confirmed
                      ? 'Confirmed'
                      : tenant.confirmationStatus.name.replaceFirst(
                    tenant.confirmationStatus.name[0],
                    tenant.confirmationStatus.name[0]
                        .toUpperCase(),
                  ),
                ),
                _InfoRow(
                  label: 'Created',
                  value: _formatDate(
                    tenant.createdAt,
                  ),
                ),
                _InfoRow(
                  label: 'Last Updated',
                  value: _formatDate(
                    tenant.updatedAt,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _unitDisplayName(Unit? unit) {
    if (unit == null) {
      return 'Unit not found';
    }

    final name = unit.name?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    return unit.unitNumber;
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme
                .of(context)
                .textTheme
                .labelMedium,
          ),
          const SizedBox(height: 8),
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
// STATUS
// ============================================================================

class _TenantStatusChip extends StatelessWidget {
  final TenantStatus status;

  const _TenantStatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme
            .of(context)
            .colorScheme
            .surfaceContainerHighest,
      ),
      child: Text(
        status == TenantStatus.active
            ? 'Active'
            : 'Inactive',
        style: Theme
            .of(context)
            .textTheme
            .labelMedium,
      ),
    );
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
              style: Theme
                  .of(context)
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
// INFO ROW
// ============================================================================

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme
                .of(context)
                .textTheme
                .labelMedium,
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: Theme
                .of(context)
                .textTheme
                .bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR
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