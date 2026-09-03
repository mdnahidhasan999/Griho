import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../tenants/presentation/providers/tenant_dashboard_provider.dart';
import '../../../units/presentation/providers/unit_provider.dart';

class TenantHomeScreen extends ConsumerWidget {
  const TenantHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(currentTenantProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Griho'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () {
              _showLogoutDialog(context, ref);
            },
          ),
        ],
      ),
      body: tenantAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          onRetry: () {
            ref.invalidate(currentTenantProvider);
          },
        ),
        data: (tenant) {
          if (tenant == null) {
            return const _NoTenancyView();
          }

          final propertyAsync = ref.watch(
            propertyByIdProvider(tenant.propertyId),
          );

          final unitAsync = ref.watch(unitByIdProvider(tenant.unitId));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentTenantProvider);
              await ref.read(currentTenantProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _WelcomeCard(tenantName: tenant.name),

                const SizedBox(height: 16),

                _TenantAccountCard(
                  name: tenant.name,
                  phone: tenant.phone,
                  accountStatus: tenant.accountStatus.name,
                  tenantStatus: tenant.status.name,
                ),

                const SizedBox(height: 16),

                propertyAsync.when(
                  loading: () => const _LoadingCard(title: 'Property'),
                  error: (_, _) => const _DataErrorCard(title: 'Property'),
                  data: (property) {
                    if (property == null) {
                      return const _DataErrorCard(title: 'Property');
                    }

                    return _PropertyCard(
                      propertyName: property.name,
                      address: property.address,
                      propertyType: property.type.name,
                    );
                  },
                ),

                const SizedBox(height: 16),

                unitAsync.when(
                  loading: () => const _LoadingCard(title: 'Unit'),
                  error: (_, _) => const _DataErrorCard(title: 'Unit'),
                  data: (unit) {
                    if (unit == null) {
                      return const _DataErrorCard(title: 'Unit');
                    }

                    return _UnitCard(
                      unitNumber: unit.unitNumber,
                      unitName: unit.name,
                      floorNumber: unit.floorNumber,
                      monthlyRent: unit.monthlyRent,
                      status: unit.status.name,
                    );
                  },
                ),

                const SizedBox(height: 16),

                const _ComingSoonCard(
                  icon: Icons.payments_outlined,
                  title: 'Rent & Payments',
                  message: 'Rent and payment information will appear here.',
                ),

                const SizedBox(height: 12),

                const _ComingSoonCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Bills',
                  message: 'Utility and other bills will appear here.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// WELCOME CARD
// ============================================================================

class _WelcomeCard extends StatelessWidget {
  final String tenantName;

  const _WelcomeCard({required this.tenantName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Icon(
                Icons.person_outline,
                color: theme.colorScheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    tenantName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TENANT ACCOUNT CARD
// ============================================================================

class _TenantAccountCard extends StatelessWidget {
  final String name;
  final String phone;
  final String accountStatus;
  final String tenantStatus;

  const _TenantAccountCard({
    required this.name,
    required this.phone,
    required this.accountStatus,
    required this.tenantStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Account',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(icon: Icons.person_outline, label: 'Name', value: name),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: phone),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.verified_user_outlined,
              label: 'Account',
              value: _formatStatus(accountStatus),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'Tenant Status ',
              value: _formatStatus(tenantStatus),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PROPERTY CARD
// ============================================================================

class _PropertyCard extends StatelessWidget {
  final String propertyName;
  final String? address;
  final String propertyType;

  const _PropertyCard({
    required this.propertyName,
    required this.address,
    required this.propertyType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Property',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.home_work_outlined,
              label: 'Property',
              value: propertyName,
            ),
            if (address != null && address!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: address!,
              ),
            ],
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.category_outlined,
              label: 'Type',
              value: _formatStatus(propertyType),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// UNIT CARD
// ============================================================================

class _UnitCard extends StatelessWidget {
  final String unitNumber;
  final String? unitName;
  final int floorNumber;
  final double? monthlyRent;
  final String status;

  const _UnitCard({
    required this.unitNumber,
    required this.unitName,
    required this.floorNumber,
    required this.monthlyRent,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Unit',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.meeting_room_outlined,
              label: 'Unit',
              value: unitNumber,
            ),
            if (unitName != null && unitName!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.label_outline,
                label: 'Name',
                value: unitName!,
              ),
            ],
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.layers_outlined,
              label: 'Floor',
              value: floorNumber.toString(),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.home_outlined,
              label: 'Status',
              value: _formatStatus(status),
            ),
            if (monthlyRent != null) ...[
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.payments_outlined,
                label: 'Monthly Rent',
                value: '৳${monthlyRent!.toStringAsFixed(2)}',
              ),
            ],
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
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// LOADING CARD
// ============================================================================

class _LoadingCard extends StatelessWidget {
  final String title;

  const _LoadingCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text('Loading $title...'),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DATA ERROR CARD
// ============================================================================

class _DataErrorCard extends StatelessWidget {
  final String title;

  const _DataErrorCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text('$title unavailable'),
        subtitle: const Text('The requested information could not be loaded.'),
      ),
    );
  }
}

// ============================================================================
// NO TENANCY VIEW
// ============================================================================

class _NoTenancyView extends StatelessWidget {
  const _NoTenancyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.home_work_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to Griho',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your account is ready, but no active tenancy '
              'is connected to your account yet.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
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
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            Text(
              'Unable to load your account',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// COMING SOON CARD
// ============================================================================

class _ComingSoonCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _ComingSoonCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(message),
      ),
    );
  }
}

// ============================================================================
// HELPERS
// ============================================================================

String _formatStatus(String value) {
  if (value.isEmpty) {
    return value;
  }

  final formatted = value.replaceAllMapped(
    RegExp(r'([A-Z])'),
    (match) => ' ${match.group(1)}',
  );

  return formatted[0].toUpperCase() + formatted.substring(1);
}

Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
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
            child: const Text('Logout'),
          ),
        ],
      );
    },
  );

  if (shouldLogout != true) {
    return;
  }
  await ref

      .read(authControllerProvider.notifier)

      .signOut();
}
