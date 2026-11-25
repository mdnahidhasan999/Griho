// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/auth_destination_mapper.dart';
import '../../app/router/route_names.dart';
import '../../core/design_system/design_system.dart';
import '../../features/auth/presentation/controllers/auth_role_resolver.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/invitations/presentation/providers/work_invitations_providers.dart';
import '../../features/tenants/presentation/providers/recipient_invitations_provider.dart';

enum GrihoNavigationDestination { home, notices, invites, more }

class AppBottomNavigation extends ConsumerWidget {
  final GrihoNavigationDestination selectedDestination;
  final VoidCallback? onHomeTap;
  final VoidCallback? onNoticesTap;
  final VoidCallback? onInvitesTap;
  final VoidCallback? onMoreTap;

  const AppBottomNavigation({
    super.key,
    required this.selectedDestination,
    this.onHomeTap,
    this.onNoticesTap,
    this.onInvitesTap,
    this.onMoreTap,
  });

  String _resolveHomeRoute(WidgetRef ref) {
    final profile = ref.read(currentUserProfileProvider).value;
    if (profile == null) {
      return RouteNames.splash;
    }
    final destination = AuthRoleResolver.resolve(profile);
    return AuthDestinationMapper.routeFor(destination);
  }

  void _handleTap(
    BuildContext context,
    WidgetRef ref,
    GrihoNavigationDestination destination,
  ) {
    if (destination == selectedDestination) {
      return;
    }
    HapticFeedback.selectionClick();

    switch (destination) {
      case GrihoNavigationDestination.home:
        if (onHomeTap != null) {
          onHomeTap!();
        } else {
          context.go(_resolveHomeRoute(ref));
        }
      case GrihoNavigationDestination.notices:
        if (onNoticesTap != null) {
          onNoticesTap!();
        } else {
          context.go(RouteNames.notices);
        }
      case GrihoNavigationDestination.invites:
        if (onInvitesTap != null) {
          onInvitesTap!();
        } else {
          context.go(RouteNames.myInvitations);
        }
      case GrihoNavigationDestination.more:
        if (onMoreTap != null) {
          onMoreTap!();
        } else {
          context.go(RouteNames.more);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final pillBg = isDark ? const Color(0xFF1E222D) : Colors.white;
    final activeCapsuleBg = GrihoColors.emerald.withValues(
      alpha: isDark ? 0.18 : 0.12,
    );
    final activeFg = isDark ? const Color(0xFF34D399) : GrihoColors.emerald;
    final inactiveFg = isDark ? Colors.white60 : const Color(0xFF64748B);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.09),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _FloatingNavItem(
                    label: 'Home',
                    icon: Iconsax.home_2,
                    isSelected:
                        selectedDestination == GrihoNavigationDestination.home,
                    activeCapsuleBg: activeCapsuleBg,
                    activeFg: activeFg,
                    inactiveFg: inactiveFg,
                    onTap: () => _handleTap(
                      context,
                      ref,
                      GrihoNavigationDestination.home,
                    ),
                  ),
                  _FloatingNavItem(
                    label: 'Notices',
                    icon: Iconsax.notification,
                    isSelected:
                        selectedDestination ==
                        GrihoNavigationDestination.notices,
                    activeCapsuleBg: activeCapsuleBg,
                    activeFg: activeFg,
                    inactiveFg: inactiveFg,
                    onTap: () => _handleTap(
                      context,
                      ref,
                      GrihoNavigationDestination.notices,
                    ),
                  ),
                  // Only this item listens to invite count changes.
                  Consumer(
                    builder: (context, badgeRef, _) {
                      final leaseCount = badgeRef.watch(
                        recipientPendingInvitationsProvider.select(
                          (async) => async.value?.length ?? 0,
                        ),
                      );
                      final workCount = badgeRef.watch(
                        pendingWorkInvitationsProvider.select(
                          (async) => async.value?.length ?? 0,
                        ),
                      );
                      return _FloatingNavItem(
                        label: 'Invites',
                        icon: Iconsax.sms,
                        badgeCount: leaseCount + workCount,
                        isSelected:
                            selectedDestination ==
                            GrihoNavigationDestination.invites,
                        activeCapsuleBg: activeCapsuleBg,
                        activeFg: activeFg,
                        inactiveFg: inactiveFg,
                        onTap: () => _handleTap(
                          context,
                          ref,
                          GrihoNavigationDestination.invites,
                        ),
                      );
                    },
                  ),
                  _FloatingNavItem(
                    label: 'More',
                    icon: Iconsax.category,
                    isSelected:
                        selectedDestination == GrihoNavigationDestination.more,
                    activeCapsuleBg: activeCapsuleBg,
                    activeFg: activeFg,
                    inactiveFg: inactiveFg,
                    onTap: () => _handleTap(
                      context,
                      ref,
                      GrihoNavigationDestination.more,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingNavItem extends StatelessWidget {
  const _FloatingNavItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.activeCapsuleBg,
    required this.activeFg,
    required this.inactiveFg,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color activeCapsuleBg;
  final Color activeFg;
  final Color inactiveFg;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final fgColor = isSelected ? activeFg : inactiveFg;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: badgeCount > 0 ? '$label, $badgeCount pending' : label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? activeCapsuleBg : Colors.transparent,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Badge(
                    isLabelVisible: badgeCount > 0,
                    backgroundColor: GrihoColors.error,
                    textColor: Colors.white,
                    label: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Icon(icon, size: 21, color: fgColor),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: fgColor,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
