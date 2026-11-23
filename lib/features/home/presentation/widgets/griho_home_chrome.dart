// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Unified AppBar shared across all 5 role home screens.
class GrihoHomeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const GrihoHomeAppBar({
    super.key,
    required this.consoleLabel,
    this.extraActions = const <Widget>[],
    this.bottom,
  });

  final String consoleLabel;
  final List<Widget> extraActions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  String _roleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Property Owner';
      case 'manager':
        return 'Building Manager';
      case 'tenant':
        return 'Resident';
      case 'caretaker':
        return 'Caretaker';
      case 'electrician':
        return 'Electrician';
      default:
        return role;
    }
  }

  String _routeForRole(String role) {
    switch (role) {
      case 'owner':
        return RouteNames.ownerHome;
      case 'manager':
        return RouteNames.managerHome;
      case 'tenant':
        return RouteNames.tenantHome;
      case 'caretaker':
        return RouteNames.caretakerHome;
      case 'electrician':
        return RouteNames.electricianHome;
      default:
        return RouteNames.roleSelection;
    }
  }

  Future<void> _showQuickRoleSwitcher(
    BuildContext context,
    WidgetRef ref,
    AppUser profile,
  ) async {
    final roles = profile.availableRoles;
    if (roles.length <= 1) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Switch Console'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: roles.map((role) {
              final isCurrent = role == profile.defaultDashboard;
              return ListTile(
                leading: Icon(
                  isCurrent
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(
                  _roleLabel(role),
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                onTap: () async {
                  Navigator.of(dialogContext).pop();
                  if (isCurrent) {
                    return;
                  }

                  try {
                    await ref
                        .read(userProfileRepositoryProvider)
                        .updateDefaultDashboard(uid: profile.uid, role: role);
                    ref.invalidate(currentUserProfileProvider);
                  } catch (_) {}

                  if (context.mounted) {
                    context.go(_routeForRole(role));
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final hasMultipleRoles = (profile?.availableRoles.length ?? 0) > 1;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      centerTitle: false,
      title: GrihoLogo(size: 38, showWordmark: true, subtitle: consoleLabel),
      actions: [
        if (hasMultipleRoles && profile != null)
          IconButton(
            tooltip: 'Switch role',
            icon: const Icon(Iconsax.arrange_square),
            onPressed: () => _showQuickRoleSwitcher(context, ref, profile),
          ),
        ...extraActions,
      ],
      bottom: bottom,
    );
  }
}

/// Unified Top Header (Greeting + Full Name + Copiable Griho ID) shared across all roles.
class GrihoHomeTopHeader extends StatelessWidget {
  const GrihoHomeTopHeader({
    super.key,
    required this.name,
    required this.publicId,
  });

  final String name;
  final String publicId;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) {
      return 'Good morning';
    }
    if (h < 17) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        if (publicId.isNotEmpty)
          ActionChip(
            avatar: Icon(
              Iconsax.copy,
              size: 15,
              color: theme.colorScheme.primary,
            ),
            label: Text(
              publicId,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: publicId));
              GrihoFeedback.showSuccess(context, 'Griho ID copied.');
            },
          ),
      ],
    );
  }
}
