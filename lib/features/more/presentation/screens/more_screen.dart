import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/more_menu_item.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load account information.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  ref.invalidate(currentUserProfileProvider);
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('User profile not found.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        child: Text(
                          profile.name.isNotEmpty
                              ? profile.name[0].toUpperCase()
                              : 'G',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(profile.publicId),
                            const SizedBox(height: 4),
                            Text(
                              'Default: ${_roleLabel(profile.defaultDashboard)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Account', style: theme.textTheme.titleSmall),
              MoreMenuItem(
                icon: Icons.person_outline_rounded,
                title: 'Profile',
                subtitle: 'View and edit your profile',
                onTap: () {
                  context.push(RouteNames.editProfile, extra: profile);
                },
              ),
              MoreMenuItem(
                icon: Icons.home_outlined,
                title: 'Default Account',
                subtitle: 'Choose your default dashboard',
                onTap: () {
                  _showDefaultAccountDialog(
                    context,
                    profile.availableRoles,
                    profile.defaultDashboard,
                  );
                },
              ),
              if (profile.availableRoles.length > 1)
                MoreMenuItem(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Switch Account',
                  subtitle: 'Switch between authorized roles',
                  onTap: () {
                    _showSwitchAccountDialog(
                      context,
                      profile.availableRoles,
                      profile.defaultDashboard,
                    );
                  },
                ),
              const Divider(height: 32),
              Text('Activities', style: theme.textTheme.titleSmall),
              MoreMenuItem(
                icon: Icons.mail_outline_rounded,
                title: 'Invitations',
                subtitle: 'View your invitations',
                onTap: () {
                  context.push(RouteNames.tenantInvitations);
                },
              ),
              const Divider(height: 32),
              Text('Preferences', style: theme.textTheme.titleSmall),
              MoreMenuItem(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () {
                  _showComingSoon(context, 'Settings');
                },
              ),
              MoreMenuItem(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                onTap: () {
                  _showComingSoon(context, 'Help & Support');
                },
              ),
              const Divider(height: 32),
              MoreMenuItem(
                icon: Icons.logout_rounded,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                isDestructive: true,
                onTap: () {
                  _confirmLogout(context, ref);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'tenant':
        return 'Tenant';
      case 'manager':
        return 'Manager';
      case 'caretaker':
        return 'Caretaker';
      default:
        return 'Not selected';
    }
  }

  Future<void> _showDefaultAccountDialog(
    BuildContext context,
    List<String> availableRoles,
    String? currentRole,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Default Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableRoles.map((role) {
              return RadioListTile<String>(
                value: role,
                groupValue: currentRole,
                title: Text(_roleLabel(role)),
                onChanged: (value) {
                  Navigator.of(dialogContext).pop();

                  if (value != null && value != currentRole) {
                    _showComingSoon(context, 'Default Account');
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _showSwitchAccountDialog(
    BuildContext context,
    List<String> availableRoles,
    String? currentRole,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Switch Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableRoles.map((role) {
              return ListTile(
                leading: Icon(
                  role == currentRole
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(_roleLabel(role)),
                onTap: () {
                  Navigator.of(dialogContext).pop();

                  if (role != currentRole) {
                    _showComingSoon(context, 'Account Switching');
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to sign out of Griho?'),
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
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await ref.read(authControllerProvider.notifier).signOut();
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature integration is not connected yet.')),
    );
  }
}
