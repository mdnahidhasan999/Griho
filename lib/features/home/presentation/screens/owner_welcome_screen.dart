import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';

class OwnerWelcomeScreen extends ConsumerWidget {
  const OwnerWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Owner Setup',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () =>
          const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stackTrace) =>
              _ErrorState(
                message: 'Unable to load your account information.',
                onRetry: () => ref.invalidate(currentUserProfileProvider),
              ),
          data: (profile) {
            if (profile == null) {
              return _ErrorState(
                message: 'Your profile could not be found.',
                onRetry: () => ref.invalidate(currentUserProfileProvider),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(currentUserProfileProvider);
                ref.invalidate(currentOwnerPropertiesProvider);

                await Future.wait([
                  ref.read(currentUserProfileProvider.future),
                  ref.read(currentOwnerPropertiesProvider.future),
                ]);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primaryContainer,
                          theme.colorScheme.surfaceContainerHighest,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.home_work_rounded,
                            size: 34,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Welcome, ${profile.name}!',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Your Owner account is ready to get started. '
                              'Add your first property to begin managing '
                              'your homes, units, tenants and bills.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Get Started',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  propertiesAsync.when(
                    loading: () =>
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, stackTrace) =>
                        _ErrorState(
                          message: 'Unable to load your properties.',
                          onRetry: () {
                            ref.invalidate(currentOwnerPropertiesProvider);
                          },
                        ),
                    data: (properties) {
                      if (properties.isEmpty) {
                        return _SetupActionCard(
                          icon: Icons.add_home_work_rounded,
                          title: 'Add Your First Property',
                          description:
                          'Create your first property and start '
                              'organizing floors and units.',
                          buttonLabel: 'Add Property',
                          onPressed: () async {
                            final result = await context.push(
                              RouteNames.addProperty,
                            );

                            if (!context.mounted) {
                              return;
                            }

                            ref.invalidate(currentOwnerPropertiesProvider);

                            if (result != null) {
                              context.go(RouteNames.ownerHome);
                            }
                          },
                        );
                      }

                      return Column(
                        children: [
                          _InfoCard(
                            icon: Icons.apartment_rounded,
                            title: 'Your properties are ready',
                            description:
                            'You currently have ${properties.length} '
                                '${properties.length == 1
                                ? 'property'
                                : 'properties'}. '
                                'You can manage them from your Owner Dashboard.',
                          ),
                          const SizedBox(height: 12),
                          _SetupActionCard(
                            icon: Icons.dashboard_customize_rounded,
                            title: 'Open Owner Dashboard',
                            description:
                            'Manage your properties, tenants and bills '
                                'from one place.',
                            buttonLabel: 'Open Dashboard',
                            onPressed: () {
                              context.go(RouteNames.ownerHome);
                            },
                          ),
                          const SizedBox(height: 12),
                          _SetupActionCard(
                            icon: Icons.add_home_work_outlined,
                            title: 'Add Another Property',
                            description:
                            'Add another house or property to your account.',
                            buttonLabel: 'Add Property',
                            onPressed: () async {
                              await context.push(RouteNames.addProperty);

                              if (!context.mounted) {
                                return;
                              }

                              ref.invalidate(currentOwnerPropertiesProvider);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'What you can manage with Griho',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _FeatureTile(
                    icon: Icons.apartment_outlined,
                    title: 'Properties and Units',
                    description:
                    'Organize properties, floors and individual units.',
                  ),
                  const _FeatureTile(
                    icon: Icons.people_outline_rounded,
                    title: 'Tenants',
                    description:
                    'Manage tenant information and tenancy details.',
                  ),
                  const _FeatureTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'Monthly Billing',
                    description:
                    'Manage rent and other property-related charges.',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SetupActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _SetupActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 32,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 30,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Icon(
          icon,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(description),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
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
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}