// noinspection SpellCheckingInspection
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'profile_hub_screen.dart';

/// Cached effective roles provider — avoids querying Firestore on every MoreScreen rebuild.
final effectiveUserRolesProvider = FutureProvider<List<String>>((ref) async {
  final profile = await ref.watch(currentUserProfileProvider.future);
  if (profile == null) {
    return const [];
  }

  final roles = <String>{...profile.availableRoles};
  final db = FirebaseFirestore.instance;

  await Future.wait([
    if (!roles.contains('manager'))
      db
          .collection('managerAccess')
          .where('userId', isEqualTo: profile.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get()
          .then((snap) {
        if (snap.docs.isNotEmpty) {
          roles.add('manager');
        }
      })
          .catchError((_) {}),
    if (!roles.contains('caretaker') || !roles.contains('electrician'))
      db
          .collection('staffAccess')
          .where('userId', isEqualTo: profile.uid)
          .where('status', isEqualTo: 'active')
          .limit(10)
          .get()
          .then((snap) {
        for (final d in snap.docs) {
          final r = (d.data()['staffRole'] ?? '').toString();
          if (r == 'caretaker' || r == 'electrician') {
            roles.add(r);
          }
        }
      })
          .catchError((_) {}),
  ]);

  return roles.toList();
});

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(currentUserProfileProvider);
    ref.invalidate(effectiveUserRolesProvider);
    ref.invalidate(pendingWorkInvitationsProvider);
    await ref.read(currentUserProfileProvider.future);
  }

  void _openProfileHub(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProfileHubScreen()));
  }

  void _copyPublicId(BuildContext context, String publicId) {
    if (publicId.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: publicId));
    GrihoFeedback.showSuccess(context, 'Griho ID copied to clipboard.');
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

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'availableRoles': FieldValue.arrayUnion(['owner']),
        'defaultDashboard': 'owner',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(effectiveUserRolesProvider);

      if (!context.mounted) {
        return;
      }
      GrihoFeedback.showSuccess(
        context,
        'Owner Console activated! You can now add your property.',
      );

      context.go(RouteNames.ownerHome);
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      GrihoFeedback.showError(context, 'Unable to activate Owner role: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final effectiveRolesAsync = ref.watch(effectiveUserRolesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      backgroundColor: isDark
          ? GrihoColors.darkSurface
          : GrihoColors.mintWhisper,
      appBar: AppBar(
        backgroundColor: isDark ? GrihoColors.darkCard : GrihoColors.deepTeal,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text(
          'More',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
      body: profileAsync.when(
        loading: () => const GrihoLoadingView(message: 'Loading account...'),
        error: (_, _) => Center(
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: GrihoStatusState(
                  icon: Iconsax.user_remove,
                  title: 'User profile not found',
                  subtitle: 'Please sign in again.',
                ),
              ),
            );
          }

          final effectiveRoles =
              effectiveRolesAsync.value ?? profile.availableRoles;
          final isOwnerOrManager =
              profile.defaultDashboard == 'owner' ||
                  profile.defaultDashboard == 'manager' ||
                  effectiveRoles.contains('owner') ||
                  effectiveRoles.contains('manager');

          final profileSubtitle = switch (profile.defaultDashboard) {
            'owner' => 'Edit profile & manage house rules',
            'tenant' => 'Edit profile & view house rules',
            _ => 'Personal info & verified details',
          };

          return RefreshIndicator(
            color: GrihoColors.emerald,
            onRefresh: () => _refresh(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
              children: [
                // Profile Hero Card (Deep Teal + Emerald + Soft Mint)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [GrihoColors.deepTeal, Color(0xFF064C50)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: GrihoColors.deepTeal.withValues(alpha: 0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openProfileHub(context),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -24,
                            top: -24,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: GrihoColors.emerald.withValues(
                                  alpha: 0.22,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: GrihoColors.softMint,
                                  ),
                                  child: _ProfileAvatar(
                                    name: profile.name,
                                    photoUrl: profile.photoUrl,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            profile.publicId,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color:
                                              GrihoColors.mintWhisper,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            onTap: () => _copyPublicId(
                                              context,
                                              profile.publicId,
                                            ),
                                            child: const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Icon(
                                                Iconsax.copy,
                                                size: 14,
                                                color: GrihoColors.softMint,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: GrihoColors.emerald.withValues(
                                            alpha: 0.28,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: GrihoColors.softMint
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: Text(
                                          'Active Console: ${_roleLabel(profile.defaultDashboard)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: GrihoColors.mintWhisper,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Iconsax.arrow_right_3,
                                    size: 16,
                                    color: GrihoColors.softMint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Become Owner Banner (Soft Mint + Emerald + Deep Teal)
                if (!effectiveRoles.contains('owner'))
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Material(
                      color: isDark
                          ? GrihoColors.darkCard
                          : GrihoColors.softMint.withValues(alpha: 0.55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(
                          color: GrihoColors.emerald,
                          width: 1.2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: GrihoColors.deepTeal,
                          child: Icon(
                            Iconsax.home_hashtag,
                            color: GrihoColors.softMint,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Become a Property Owner',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : GrihoColors.deepTeal,
                          ),
                        ),
                        subtitle: Text(
                          'Register your own buildings & manage tenants',
                          style: TextStyle(
                            color: isDark
                                ? GrihoColors.mintWhisper
                                : GrihoColors.textSecondary,
                          ),
                        ),
                        trailing: const Icon(
                          Iconsax.arrow_right_3,
                          size: 18,
                          color: GrihoColors.emerald,
                        ),
                        onTap: () =>
                            _activateOwnerRole(context, ref, profile.uid),
                      ),
                    ),
                  ),

                const SizedBox(height: 18),

                // 1. Account Section
                GrihoSectionCard(
                  title: 'Account',
                  icon: Iconsax.user,
                  children: [
                    MoreMenuItem(
                      icon: Iconsax.user_edit,
                      title: 'Profile',
                      subtitle: profileSubtitle,
                      onTap: () => _openProfileHub(context),
                    ),
                    const Divider(height: 1),
                    MoreMenuItem(
                      icon: Iconsax.lock,
                      title: 'Change Password',
                      subtitle: 'Update your account password',
                      onTap: () => context.push(RouteNames.changePassword),
                    ),
                    const Divider(height: 1),
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
                    if (effectiveRoles.length > 1) ...[
                      const Divider(height: 1),
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
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // 2. Activities & Invitations Section
                GrihoSectionCard(
                  title: 'Activities & Invitations',
                  icon: Iconsax.document_text,
                  children: [
                    if (isOwnerOrManager) ...[
                      MoreMenuItem(
                        icon: Iconsax.document_text,
                        title: 'Activity & Audit Trail',
                        subtitle:
                        'Track manager actions, rent changes & billing logs',
                        onTap: () => context.push(RouteNames.activityLogs),
                      ),
                      const Divider(height: 1),
                    ],
                    if (effectiveRoles.contains('owner')) ...[
                      MoreMenuItem(
                        icon: Iconsax.people,
                        title: 'Team & Work Orders',
                        subtitle: 'Managers, caretakers, electricians & tasks',
                        onTap: () => context.push(RouteNames.ownerTeam),
                      ),
                      const Divider(height: 1),
                    ],
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
                    const Divider(height: 1),
                    MoreMenuItem(
                      icon: Iconsax.sms,
                      title: 'Tenancy Invitations',
                      subtitle: 'View your residential invitations',
                      onTap: () => context.push(RouteNames.tenantInvitations),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. Preferences Section
                GrihoSectionCard(
                  title: 'Preferences',
                  icon: Iconsax.setting_2,
                  children: [
                    MoreMenuItem(
                      icon: Iconsax.setting_2,
                      title: 'Settings',
                      subtitle: 'App preferences & notifications',
                      onTap: () => _showComingSoon(context, 'Settings'),
                    ),
                    const Divider(height: 1),
                    MoreMenuItem(
                      icon: Iconsax.message_question,
                      title: 'Help & Support',
                      subtitle: 'FAQs and customer support',
                      onTap: () => _showComingSoon(context, 'Help & Support'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 4. Logout Card
                Material(
                  color: isDark ? GrihoColors.darkCard : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: GrihoColors.error.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: MoreMenuItem(
                    icon: Iconsax.logout,
                    title: 'Logout',
                    subtitle: 'Sign out of your account',
                    isDestructive: true,
                    onTap: () => _confirmLogout(context, ref),
                  ),
                ),
              ],
            ),
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
              final isCurrent = role == currentRole;
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(
                  isCurrent
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isCurrent ? GrihoColors.emerald : null,
                ),
                title: Text(
                  _roleLabel(role),
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  if (!isCurrent) {
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
    } catch (_) {
      if (openDashboard && context.mounted) {
        context.go(_routeForRole(role));
        return;
      }
      if (!context.mounted) {
        return;
      }
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
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
      backgroundColor: GrihoColors.emerald.withValues(alpha: 0.25),
      backgroundImage: provider,
      child: provider == null
          ? Text(
        widget.name.trim().isNotEmpty
            ? widget.name.trim()[0].toUpperCase()
            : 'G',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: GrihoColors.mintWhisper,
        ),
      )
          : null,
    );
  }
}
