import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../properties/presentation/providers/property_provider.dart';
import '../../../rents/domain/entities/rent_rate.dart';
import '../../../rents/presentation/providers/rent_rate_provider.dart';
import '../../../tenants/presentation/providers/tenant_dashboard_provider.dart';
import '../../../tenants/presentation/screens/tenant_tenancy_history_screen.dart';
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
          // ==========================================================
          // TENANCY HISTORY
          // ==========================================================
          IconButton(
            tooltip: 'Tenancy History',
            icon: const Icon(Icons.history_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TenantTenancyHistoryScreen(),
                ),
              );
            },
          ),

          // ==========================================================
          // LOGOUT
          // ==========================================================
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

          AsyncValue<RentRate?>? currentRentRateAsync;

          propertyAsync.whenData((property) {
            if (property != null) {
              currentRentRateAsync = ref.watch(
                currentRentRateProvider((
                  unitId: tenant.unitId,
                  ownerId: property.ownerId,
                )),
              );
            }
          });

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentTenantProvider);

              await ref.read(currentTenantProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // ==========================================================
                // WELCOME
                // ==========================================================
                _WelcomeCard(tenantName: tenant.name),

                const SizedBox(height: 16),

                // ==========================================================
                // TENANT PROFILE
                // ==========================================================
                _TenantAccountCard(
                  name: tenant.name,
                  phone: tenant.phone,
                  accountStatus: tenant.accountStatus.name,
                  tenantStatus: tenant.status.name,
                ),

                const SizedBox(height: 16),

                // ==========================================================
                // CURRENT PROPERTY
                // ==========================================================
                propertyAsync.when(
                  loading: () => const _LoadingCard(title: 'Property'),
                  error: (_, _) => const _DataErrorCard(title: 'Property'),
                  data: (property) {
                    if (property == null) {
                      return const _DataErrorCard(title: 'Property');
                    }

                    return _PropertyCard(
                      propertyName: property.name,
                      propertyCode: property.propertyCode,
                      address: property.address,
                      propertyType: property.type.name,
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ==========================================================
                // CURRENT UNIT
                // ==========================================================
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
                      rentRateAsync: currentRentRateAsync,
                      status: unit.status.name,
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ==========================================================
                // RENT SUMMARY
                // ==========================================================
                const _RentSummaryCard(),

                const SizedBox(height: 16),

                // ==========================================================
                // QUICK ACTIONS
                // ==========================================================
                propertyAsync.when(
                  loading: () =>
                      const _QuickActionsCard(propertyAvailable: false),
                  error: (_, _) =>
                      const _QuickActionsCard(propertyAvailable: false),
                  data: (property) {
                    return _QuickActionsCard(
                      propertyAvailable: property != null,
                      propertyName: property?.name,
                      propertyCode: property?.propertyCode,
                      address: property?.address,
                      propertyType: property?.type.name,
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ==========================================================
                // TENANCY HISTORY
                // ==========================================================
                _TenancyHistoryCard(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TenantTenancyHistoryScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ==========================================================
                // RECENT ACTIVITY
                // ==========================================================
                const _RecentActivityCard(),

                const SizedBox(height: 24),
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
              'Tenant Profile',
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
              label: 'Tenant Status',
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
  final String propertyCode;
  final String? address;
  final String propertyType;

  const _PropertyCard({
    required this.propertyName,
    required this.propertyCode,
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
              'Current Property',
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

            const SizedBox(height: 12),

            _InfoRow(
              icon: Icons.tag_outlined,
              label: 'Code',
              value: propertyCode,
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
  final AsyncValue<RentRate?>? rentRateAsync;
  final String status;

  const _UnitCard({
    required this.unitNumber,
    required this.unitName,
    required this.floorNumber,
    required this.rentRateAsync,
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
              'Current Unit',
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

            const SizedBox(height: 12),

            _CurrentRentRow(rentRateAsync: rentRateAsync),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CURRENT RENT ROW
// ============================================================================

class _CurrentRentRow extends StatelessWidget {
  final AsyncValue<RentRate?>? rentRateAsync;

  const _CurrentRentRow({required this.rentRateAsync});

  @override
  Widget build(BuildContext context) {
    if (rentRateAsync == null) {
      return const _InfoRow(
        icon: Icons.payments_outlined,
        label: 'Monthly Rent',
        value: 'Unavailable',
      );
    }

    return rentRateAsync!.when(
      loading: () {
        return const Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.payments_outlined, size: 20),
            SizedBox(width: 12),
            SizedBox(width: 95, child: Text('Monthly Rent')),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        );
      },
      error: (_, _) {
        return const _InfoRow(
          icon: Icons.payments_outlined,
          label: 'Monthly Rent',
          value: 'Unavailable',
        );
      },
      data: (rentRate) {
        if (rentRate == null) {
          return const _InfoRow(
            icon: Icons.payments_outlined,
            label: 'Monthly Rent',
            value: 'Not set',
          );
        }

        return _InfoRow(
          icon: Icons.payments_outlined,
          label: 'Monthly Rent',
          value: _formatCurrency(rentRate.amount),
        );
      },
    );
  }
}

// ============================================================================
// RENT SUMMARY CARD
// ============================================================================

class _RentSummaryCard extends StatelessWidget {
  const _RentSummaryCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 28,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rent Summary',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rent, payment and due information will appear here once the billing system is available.',
                    style: theme.textTheme.bodyMedium,
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
// QUICK ACTIONS CARD
// ============================================================================

class _QuickActionsCard extends StatelessWidget {
  final bool propertyAvailable;
  final String? propertyName;
  final String? propertyCode;
  final String? address;
  final String? propertyType;

  const _QuickActionsCard({
    required this.propertyAvailable,
    this.propertyName,
    this.propertyCode,
    this.address,
    this.propertyType,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.payments_outlined,
                    label: 'Rent',
                    enabled: false,
                    onPressed: null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.receipt_long_outlined,
                    label: 'Bills',
                    enabled: false,
                    onPressed: null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.history_outlined,
                    label: 'Payments',
                    enabled: false,
                    onPressed: null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.home_work_outlined,
                    label: 'Property',
                    enabled: propertyAvailable,
                    onPressed: propertyAvailable
                        ? () {
                            _showPropertyDetails(
                              context,
                              propertyName: propertyName!,
                              propertyCode: propertyCode!,
                              address: address,
                              propertyType: propertyType!,
                            );
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TENANCY HISTORY CARD
// ============================================================================

class _TenancyHistoryCard extends StatelessWidget {
  final VoidCallback onPressed;

  const _TenancyHistoryCard({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                child: Icon(
                  Icons.history_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tenancy History',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View your previous tenancies and rental history.',
                      style: theme.textTheme.bodyMedium,
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
}

// ============================================================================
// QUICK ACTION BUTTON
// ============================================================================

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    );
  }
}

// ============================================================================
// PROPERTY DETAILS DIALOG
// ============================================================================

Future<void> _showPropertyDetails(
  BuildContext context, {
  required String propertyName,
  required String propertyCode,
  required String? address,
  required String propertyType,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Property Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogInfoRow(
                icon: Icons.home_work_outlined,
                label: 'Property',
                value: propertyName,
              ),
              const SizedBox(height: 16),
              _DialogInfoRow(
                icon: Icons.tag_outlined,
                label: 'Code',
                value: propertyCode,
              ),
              if (address != null && address.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                _DialogInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Address',
                  value: address,
                ),
              ],
              const SizedBox(height: 16),
              _DialogInfoRow(
                icon: Icons.category_outlined,
                label: 'Type',
                value: _formatStatus(propertyType),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

// ============================================================================
// DIALOG INFO ROW
// ============================================================================

class _DialogInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DialogInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// RECENT ACTIVITY CARD
// ============================================================================

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.history_outlined,
              size: 28,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Activity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recent rent, bill and payment activity will appear here once those systems are available.',
                    style: theme.textTheme.bodyMedium,
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
          width: 95,
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
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.home_work_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),

            const SizedBox(height: 24),

            Text(
              'No Active Tenancy',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            Text(
              'Your account is active, but you currently do not have '
              'an active tenancy connected to your account.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            Text(
              'When a property owner sends you a new invitation, '
              'you can review and accept it to connect a tenancy '
              'to your account.',
              style: theme.textTheme.bodyMedium,
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

String _formatCurrency(double amount) {
  return '৳${amount.toStringAsFixed(2)}';
}

// ============================================================================
// LOGOUT
// ============================================================================

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

  await ref.read(authControllerProvider.notifier).signOut();
}
