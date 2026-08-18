import 'package:flutter/material.dart';

abstract final class AppSnackbar {
  static void success(BuildContext context, String message) {
    _show(context, message: message, icon: Icons.check_circle_outline);
  }

  static void error(BuildContext context, String message) {
    _show(context, message: message, icon: Icons.error_outline);
  }

  static void warning(BuildContext context, String message) {
    _show(context, message: message, icon: Icons.warning_amber_rounded);
  }

  static void info(BuildContext context, String message) {
    _show(context, message: message, icon: Icons.info_outline);
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
