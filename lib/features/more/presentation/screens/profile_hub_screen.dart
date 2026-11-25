// noinspection SpellCheckingInspection
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/more_menu_item.dart';
import 'house_rules_screen.dart';

class ProfileHubScreen extends ConsumerWidget {
  const ProfileHubScreen({super.key});

  ImageProvider? _buildAvatarProvider(String? url) {
    if (url == null || url.isEmpty) return null;
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
    if (url.startsWith('http')) return NetworkImage(url);
    return null;
  }

  String _roleLabel(String? role) => switch (role) {
    'owner' => 'Owner Console',
    'tenant' => 'Resident Console',
    'manager' => 'Manager Console',
    'caretaker' => 'Caretaker Console',
    'electrician' => 'Electrician Console',
    _ => 'Griho Account',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const GrihoLoadingView(message: 'Loading profile...'),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load profile',
              subtitle: 'Please try again.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(currentUserProfileProvider),
            ),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: GrihoStatusState(
                icon: Iconsax.user_remove,
                title: 'Profile not found',
                subtitle: 'Please sign in again.',
              ),
            );
          }

          final avatarProvider = _buildAvatarProvider(profile.photoUrl);
          final activeRole = profile.defaultDashboard;
          final isOwnerConsole = activeRole == 'owner';
          final isTenantConsole = activeRole == 'tenant';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              // Profile Summary Header
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: avatarProvider,
                      child: avatarProvider == null
                          ? Text(
                        profile.name.trim().isNotEmpty
                            ? profile.name.trim()[0].toUpperCase()
                            : 'G',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${profile.publicId}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (profile.phoneNumber?.isNotEmpty == true) ...[
                            const SizedBox(height: 2),
                            Text(
                              profile.phoneNumber!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: GrihoColors.emerald.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _roleLabel(activeRole),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: GrihoColors.emerald,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Menu Options
              GrihoSectionCard(
                title: isOwnerConsole || isTenantConsole
                    ? 'Profile & Rules'
                    : 'Profile',
                icon: Iconsax.user,
                children: [
                  MoreMenuItem(
                    icon: Iconsax.user_edit,
                    title: 'Edit Profile',
                    subtitle: 'Personal info, NID photos & verified details',
                    onTap: () =>
                        context.push(RouteNames.editProfile, extra: profile),
                  ),
                  if (isOwnerConsole) ...[
                    const Divider(height: 1),
                    MoreMenuItem(
                      icon: Iconsax.document_text_1,
                      title: 'House Rules & Policies',
                      subtitle: 'Set or edit rules for your tenants',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const OwnerHouseRulesScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                  if (isTenantConsole) ...[
                    const Divider(height: 1),
                    MoreMenuItem(
                      icon: Iconsax.shield_tick,
                      title: 'My House Rules',
                      subtitle: 'View rules set by your landlord',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TenantHouseRulesScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
