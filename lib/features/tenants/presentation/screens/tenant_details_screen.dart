import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../domain/entities/tenant.dart';
import '../controllers/tenant_controller.dart';
import '../providers/property_tenants_provider.dart';

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
          content: Text(state.error?.toString() ?? 'Unable to delete tenant.'),
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
        appBar: AppBar(title: const Text('Tenant Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tenant Details')),
        body: _ErrorView(message: _errorMessage!, onRetry: _loadTenant),
      );
    }

    final tenant = _tenant;

    if (tenant == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tenant Details')),
        body: const Center(child: Text('Tenant not found.')),
      );
    }

    final tenantState = ref.watch(tenantControllerProvider);

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
                        propertyTenantsProvider(result.propertyId),
                      );
                    }
                  },
            icon: const Icon(Icons.edit_outlined),
          ),

          IconButton(
            tooltip: 'Delete Tenant',
            onPressed: tenantState.isLoading ? null : _deleteTenant,
            icon: const Icon(Icons.delete_outline),
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
                      child: Icon(Icons.person_outline, size: 36),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      tenant.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),

                    const SizedBox(height: 8),

                    _TenantStatusChip(status: tenant.status),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            _InfoCard(
              title: 'Tenant Information',
              children: [
                _InfoRow(label: 'Phone', value: tenant.phone),

                _InfoRow(
                  label: 'Email',
                  value: tenant.email?.trim().isNotEmpty == true
                      ? tenant.email!
                      : 'Not provided',
                ),

                _InfoRow(
                  label: 'NID Number',
                  value: tenant.nidNumber?.trim().isNotEmpty == true
                      ? tenant.nidNumber!
                      : 'Not provided',
                ),
              ],
            ),

            const SizedBox(height: 20),

            _InfoCard(
              title: 'Property Information',
              children: [
                _InfoRow(label: 'Property ID', value: tenant.propertyId),

                _InfoRow(label: 'Unit ID', value: tenant.unitId),
              ],
            ),

            const SizedBox(height: 20),

            _InfoCard(
              title: 'Account Information',
              children: [
                _InfoRow(label: 'Tenant ID', value: tenant.id),

                _InfoRow(
                  label: 'User ID',
                  value: tenant.userId?.trim().isNotEmpty == true
                      ? tenant.userId!
                      : 'Not linked',
                ),

                _InfoRow(
                  label: 'Created',
                  value: _formatDate(tenant.createdAt),
                ),

                _InfoRow(
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

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _TenantStatusChip extends StatelessWidget {
  final TenantStatus status;

  const _TenantStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        _statusLabel(status),
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }

  String _statusLabel(TenantStatus status) {
    switch (status) {
      case TenantStatus.active:
        return 'Active';

      case TenantStatus.inactive:
        return 'Inactive';
    }
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),

            const SizedBox(height: 16),

            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),

          const SizedBox(height: 4),

          SelectableText(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),

            const SizedBox(height: 16),

            Text(message, textAlign: TextAlign.center),

            const SizedBox(height: 16),

            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
