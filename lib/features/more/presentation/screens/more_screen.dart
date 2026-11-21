// noinspection SpellCheckingInspection
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';
import '../../../../core/services/fcm_notification_service.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../invitations/presentation/providers/work_invitations_providers.dart';
import '../widgets/more_menu_item.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  Future<List<String>> _resolveEffectiveRoles(
    String uid,
    List<String> storedRoles,
  ) async {
    final roles = <String>{...storedRoles};

    try {
      final activeManagerAccess = await FirebaseFirestore.instance
          .collection('managerAccess')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (activeManagerAccess.docs.isNotEmpty) {
        roles.add('manager');
      }
    } catch (_) {}

    try {
      final staff = await FirebaseFirestore.instance
          .collection('staffAccess')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .get();
      for (final d in staff.docs) {
        final r = (d.data()['staffRole'] ?? '').toString();
        if (r == 'caretaker' || r == 'electrician') roles.add(r);
      }
    } catch (_) {}

    return roles.toList();
  }

  Future<void> _activateOwnerRole(
    BuildContext context,
    WidgetRef ref,
    String uid,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Become a Property Owner?'),
        content: const Text(
          'Unlock the Owner Console to register your own buildings, manage units, and invite tenants or managers.\n\n'
          'You will still keep your existing Resident or Manager access and can switch between consoles anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Iconsax.home_hashtag, size: 18),
            label: const Text('Activate Owner Console'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'availableRoles': FieldValue.arrayUnion(['owner']),
        'defaultDashboard': 'owner',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ref.invalidate(currentUserProfileProvider);

      if (!context.mounted) return;
      GrihoFeedback.showSuccess(
        context,
        'Owner Console activated! You can now add your property.',
      );

      context.go(RouteNames.ownerHome);
    } catch (e) {
      if (!context.mounted) return;
      GrihoFeedback.showError(context, 'Unable to activate Owner role: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('More')),
      body: profileAsync.when(
        loading: () => const GrihoLoadingView(message: 'Loading account...'),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
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
            return const Center(child: Text('User profile not found.'));
          }

          return FutureBuilder<List<String>>(
            future: _resolveEffectiveRoles(profile.uid, profile.availableRoles),
            builder: (context, rolesSnapshot) {
              final effectiveRoles =
                  rolesSnapshot.data ?? profile.availableRoles;
              final isOwnerOrManager =
                  profile.defaultDashboard == 'owner' ||
                  profile.defaultDashboard == 'manager' ||
                  effectiveRoles.contains('owner') ||
                  effectiveRoles.contains('manager');

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
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
                                  'Active Console: ${_roleLabel(profile.defaultDashboard)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!effectiveRoles.contains('owner'))
                    Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 2),
                      child: Material(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.45,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary,
                            child: Icon(
                              Iconsax.home_hashtag,
                              color: theme.colorScheme.onPrimary,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Become a Property Owner',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: const Text(
                            'Register your own buildings & manage tenants',
                          ),
                          trailing: const Icon(Iconsax.arrow_right_3),
                          onTap: () =>
                              _activateOwnerRole(context, ref, profile.uid),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text('Account', style: theme.textTheme.titleSmall),
                  MoreMenuItem(
                    icon: Iconsax.user,
                    title: 'Profile',
                    subtitle: 'View and edit your profile',
                    onTap: () {
                      context.push(RouteNames.editProfile, extra: profile);
                    },
                  ),
                  MoreMenuItem(
                    icon: Iconsax.lock,
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    onTap: () {
                      context.push(RouteNames.changePassword);
                    },
                  ),
                  MoreMenuItem(
                    icon: Iconsax.home_2,
                    title: 'Default Account',
                    subtitle: 'Choose your default dashboard',
                    onTap: () {
                      _showDefaultAccountDialog(
                        context,
                        ref,
                        profile.uid,
                        effectiveRoles,
                        profile.defaultDashboard,
                      );
                    },
                  ),
                  if (effectiveRoles.length > 1)
                    MoreMenuItem(
                      icon: Iconsax.arrange_square,
                      title: 'Switch Account Console',
                      subtitle:
                          'Switch between your Owner, Manager, Staff & Resident views',
                      onTap: () {
                        _showSwitchAccountDialog(
                          context,
                          ref,
                          profile.uid,
                          effectiveRoles,
                          profile.defaultDashboard,
                        );
                      },
                    ),
                  const Divider(height: 32),
                  Text('Activities & Audit', style: theme.textTheme.titleSmall),
                  if (isOwnerOrManager)
                    MoreMenuItem(
                      icon: Iconsax.document_text,
                      title: 'Activity & Audit Trail',
                      subtitle:
                          'Track manager actions, rent changes & billing logs',
                      onTap: () {
                        context.push(RouteNames.activityLogs);
                      },
                    ),
                  if (effectiveRoles.contains('owner'))
                    MoreMenuItem(
                      icon: Iconsax.people,
                      title: 'Team & Work Orders',
                      subtitle: 'Managers, caretakers, electricians & tasks',
                      onTap: () {
                        context.push(RouteNames.ownerTeam);
                      },
                    ),
                  Consumer(
                    builder: (context, ref, _) {
                      final count =
                          ref
                              .watch(pendingWorkInvitationsProvider)
                              .value
                              ?.length ??
                          0;
                      return MoreMenuItem(
                        icon: Iconsax.briefcase,
                        title: count > 0
                            ? 'Work Invitations ($count new)'
                            : 'Work Invitations',
                        subtitle:
                            'Manager, caretaker & electrician offers from owners',
                        onTap: () async {
                          await context.push(RouteNames.myInvitations);
                          ref.invalidate(pendingWorkInvitationsProvider);
                        },
                      );
                    },
                  ),
                  MoreMenuItem(
                    icon: Iconsax.sms,
                    title: 'Tenancy Invitations',
                    subtitle: 'View your residential invitations',
                    onTap: () {
                      context.push(RouteNames.tenantInvitations);
                    },
                  ),
                  const Divider(height: 32),
                  Text('Preferences', style: theme.textTheme.titleSmall),
                  MoreMenuItem(
                    icon: Iconsax.setting_2,
                    title: 'Settings',
                    onTap: () {
                      _showComingSoon(context, 'Settings');
                    },
                  ),
                  MoreMenuItem(
                    icon: Iconsax.message_question,
                    title: 'Help & Support',
                    onTap: () {
                      _showComingSoon(context, 'Help & Support');
                    },
                  ),
                  const Divider(height: 32),
                  MoreMenuItem(
                    icon: Iconsax.logout,
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
          );
        },
      ),
      bottomNavigationBar: const AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.more,
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
          title: const Text('Switch Account Console'),
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
        GrihoFeedback.showSuccess(
          context,
          'Default account: ${_roleLabel(role)}',
        );
      }
    } catch (error) {
      if (openDashboard && context.mounted) {
        context.go(_routeForRole(role));
        return;
      }
      if (!context.mounted) return;
      GrihoFeedback.showError(context, 'Unable to change account.');
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

    await FcmNotificationService.instance.removeTokenOnLogout();
    await ref.read(authControllerProvider.notifier).signOut();
  }

  void _showComingSoon(BuildContext context, String feature) {
    GrihoFeedback.showInfo(
      context,
      '$feature integration is not connected yet.',
    );
  }
}

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
