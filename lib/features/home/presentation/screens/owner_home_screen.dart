import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/utils/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class OwnerHomeScreen extends ConsumerWidget {
  const OwnerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Griho'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _showSignOutDialog(context, ref),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stackTrace) {
          return _ErrorView(
            message: 'Unable to load your profile.',
            onRetry: () {
              ref.invalidate(currentUserProfileProvider);
            },
          );
        },
        data: (profile) {
          if (profile == null) {
            return _ErrorView(
              message: 'User profile not found.',
              onRetry: () {
                ref.invalidate(currentUserProfileProvider);
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentUserProfileProvider);

              await ref.read(currentUserProfileProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _WelcomeCard(name: profile.name, publicId: profile.publicId),

                const SizedBox(height: 24),

                Text('Overview', style: Theme.of(context).textTheme.titleLarge),

                const SizedBox(height: 12),

                const Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.home_work_outlined,
                        title: 'Properties',
                        value: '0',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.people_outline,
                        title: 'Tenants',
                        value: '0',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                const Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.receipt_long_outlined,
                        title: 'Pending Bills',
                        value: '0',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.payments_outlined,
                        title: 'This Month',
                        value: '৳0',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),

                const SizedBox(height: 12),

                _ActionCard(
                  icon: Icons.add_home_work_outlined,
                  title: 'Add Property',
                  description: 'Add and manage your property.',
                  onTap: () {
                    AppSnackbar.info(
                      context,
                      'Property management will be available in the next step.',
                    );
                  },
                ),

                const SizedBox(height: 12),

                _ActionCard(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'Add Tenant',
                  description: 'Invite a tenant to your property.',
                  onTap: () {
                    AppSnackbar.info(
                      context,
                      'Tenant management will be available in the next step.',
                    );
                  },
                ),

                const SizedBox(height: 12),

                _ActionCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Manage Bills',
                  description: 'View and manage property bills.',
                  onTap: () {
                    AppSnackbar.info(
                      context,
                      'Billing will be available in the next step.',
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSignOutDialog(BuildContext context, WidgetRef ref) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'Are you sure you want to sign out of your Griho account?',
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
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true || !context.mounted) {
      return;
    }

    await ref.read(authControllerProvider.notifier).signOut();
  }
}

class _WelcomeCard extends StatelessWidget {
  final String name;
  final String publicId;

  const _WelcomeCard({required this.name, required this.publicId});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back,',
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 4),

            Text(name, style: Theme.of(context).textTheme.headlineSmall),

            if (publicId.isNotEmpty) ...[
              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Griho ID: $publicId',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),

            const Text(
              'Manage your properties, tenants and bills from one place.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),

            const SizedBox(height: 16),

            Text(value, style: Theme.of(context).textTheme.headlineSmall),

            const SizedBox(height: 4),

            Text(title, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 30),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),

                    const SizedBox(height: 4),

                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              const Icon(Icons.chevron_right),
            ],
          ),
        ),
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
