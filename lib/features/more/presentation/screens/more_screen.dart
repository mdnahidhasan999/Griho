import 'dart:convert';
import 'dart:typed_data';

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
                      _ProfileAvatar(
                        name: profile.name,
                        photoUrl: profile.photoUrl,
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
                    ref,
                    profile.uid,
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
                      ref,
                      profile.uid,
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
      case 'electrician':
        return 'Electrician';
      default:
        return 'Not selected';
    }
  }

  String _routeForRole(String role) {
    switch (role) {
      case 'owner':
        return RouteNames.ownerHome;
      case 'tenant':
        return RouteNames.tenantHome;
      case 'manager':
        return RouteNames.managerHome;
      case 'caretaker':
        return RouteNames.caretakerHome;
      case 'electrician':
        return RouteNames.electricianHome;
      default:
        return RouteNames.roleSelection;
    }
  }

  Future<void> _showDefaultAccountDialog(
    BuildContext context,
    WidgetRef ref,
    String uid,
    List<String> availableRoles,
    String? currentRole,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Default Account'),
          content: RadioGroup<String>(
            groupValue: currentRole,
            onChanged: (value) {
              Navigator.of(dialogContext).pop();

              if (value != null && value != currentRole) {
                _changeRole(
                  context,
                  ref,
                  uid: uid,
                  role: value,
                  openDashboard: false,
                );
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: availableRoles.map((role) {
                return RadioListTile<String>(
                  value: role,
                  title: Text(_roleLabel(role)),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSwitchAccountDialog(
    BuildContext context,
    WidgetRef ref,
    String uid,
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
                    _changeRole(
                      context,
                      ref,
                      uid: uid,
                      role: role,
                      openDashboard: true,
                    );
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref, {
    required String uid,
    required String role,
    required bool openDashboard,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(userProfileRepositoryProvider)
          .updateDefaultDashboard(uid: uid, role: role);

      ref.invalidate(currentUserProfileProvider);

      if (!context.mounted) {
        return;
      }

      if (openDashboard) {
        context.go(_routeForRole(role));
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('Default account: ${_roleLabel(role)}')),
        );
      }
    } catch (error) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to change account.')),
      );
    }
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

/// Shows the saved profile photo (base64 data URL or network URL).
/// Falls back to the first letter of the name when there is no photo.
class _ProfileAvatar extends StatefulWidget {
  const _ProfileAvatar({required this.name, required this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  ImageProvider? _provider;

  @override
  void initState() {
    super.initState();
    _provider = _buildProvider(widget.photoUrl);
  }

  @override
  void didUpdateWidget(covariant _ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.photoUrl != widget.photoUrl) {
      _provider = _buildProvider(widget.photoUrl);
    }
  }

  ImageProvider? _buildProvider(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }

    if (url.startsWith('data:image')) {
      try {
        final Uint8List bytes = base64Decode(
          url.substring(url.indexOf(',') + 1),
        );

        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }

    if (url.startsWith('http')) {
      return NetworkImage(url);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;

    return CircleAvatar(
      radius: 28,
      backgroundImage: provider,
      child: provider == null
          ? Text(widget.name.isNotEmpty ? widget.name[0].toUpperCase() : 'G')
          : null,
    );
  }
}
