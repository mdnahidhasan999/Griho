// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';
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
        title: const Text('Owner Setup'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const GrihoLoadingView(message: 'Setting up...'),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GrihoStatusState(
                icon: Iconsax.warning_2,
                title: 'Unable to load account',
                subtitle: 'Please check your connection and try again.',
                actionLabel: 'Try Again',
                onAction: () => ref.invalidate(currentUserProfileProvider),
              ),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: GrihoStatusState(
                    icon: Iconsax.user_remove,
                    title: 'Profile not found',
                    subtitle: 'Your profile could not be loaded.',
                    actionLabel: 'Try Again',
                    onAction: () => ref.invalidate(currentUserProfileProvider),
                  ),
                ),
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
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [GrihoColors.deepTeal, Color(0xFF064C50)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GrihoLogo(size: 56),
                        const SizedBox(height: 20),
                        Text(
                          'Welcome, ${profile.name}!',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your Owner account is ready. Add your first property to start managing homes, units, tenants, and bills.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            color: GrihoColors.mintWhisper,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Get Started',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  propertiesAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: GrihoLoadingView(message: 'Loading properties...'),
                    ),
                    error: (_, _) => GrihoStatusState(
                      icon: Iconsax.warning_2,
                      title: 'Unable to load properties',
                      subtitle: 'Tap below to retry.',
                      actionLabel: 'Try Again',
                      onAction: () =>
                          ref.invalidate(currentOwnerPropertiesProvider),
                    ),
                    data: (properties) {
                      if (properties.isEmpty) {
                        return _SetupActionCard(
                          icon: Iconsax.building_4,
                          title: 'Add Your First Property',
                          description:
                              'Create your first property and start organizing floors and units.',
                          buttonLabel: 'Add Property',
                          onPressed: () async {
                            final result = await context.push(
                              RouteNames.addProperty,
                            );
                            if (!context.mounted) return;
                            ref.invalidate(currentOwnerPropertiesProvider);
                            if (result != null) {
                              context.go(RouteNames.ownerHome);
                            }
                          },
                        );
                      }

                      return Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Iconsax.buildings_2,
                                  size: 28,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Your properties are ready',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'You currently have ${properties.length} ${properties.length == 1 ? 'property' : 'properties'}. Manage them from your Owner Dashboard.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              height: 1.45,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SetupActionCard(
                            icon: Iconsax.element_3,
                            title: 'Open Owner Dashboard',
                            description:
                                'Manage your properties, tenants and bills from one place.',
                            buttonLabel: 'Open Dashboard',
                            onPressed: () => context.go(RouteNames.ownerHome),
                          ),
                          const SizedBox(height: 12),
                          _SetupActionCard(
                            icon: Iconsax.building_4,
                            title: 'Add Another Property',
                            description:
                                'Add another house or property to your account.',
                            buttonLabel: 'Add Property',
                            isSecondary: true,
                            onPressed: () async {
                              await context.push(RouteNames.addProperty);
                              if (!context.mounted) return;
                              ref.invalidate(currentOwnerPropertiesProvider);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'What you can manage with Griho',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _FeatureTile(
                    icon: Iconsax.buildings_2,
                    title: 'Properties and Units',
                    description:
                        'Organize properties, floors and individual units.',
                  ),
                  const _FeatureTile(
                    icon: Iconsax.people,
                    title: 'Tenants',
                    description:
                        'Manage tenant information and tenancy details.',
                  ),
                  const _FeatureTile(
                    icon: Iconsax.receipt_item,
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
      bottomNavigationBar: AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.home,
        onHomeTap: () => context.go(RouteNames.ownerHome),
        onMoreTap: () => context.push(RouteNames.more),
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
  final bool isSecondary;

  const _SetupActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 30, color: theme.colorScheme.primary),
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
              height: 1.45,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (isSecondary)
            GrihoSecondaryButton(label: buttonLabel, onPressed: onPressed)
          else
            GrihoPrimaryButton(label: buttonLabel, onPressed: onPressed),
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
          size: 20,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(description),
    );
  }
}
