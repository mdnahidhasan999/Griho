// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

class MoreMenuItem extends StatelessWidget {
  const MoreMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final foregroundColor = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    final iconColor = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return ListTile(
      leading: Icon(icon, size: 21, color: iconColor),
      title: Text(
        title,
        style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(
        Iconsax.arrow_right_3,
        size: 16,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
