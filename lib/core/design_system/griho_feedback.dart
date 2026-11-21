// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'griho_colors.dart';

enum GrihoMessageType { success, error, warning, info }

abstract final class GrihoFeedback {
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(
      context,
      message: message,
      type: GrihoMessageType.success,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: message,
      type: GrihoMessageType.error,
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(
      context,
      message: message,
      type: GrihoMessageType.warning,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(
      context,
      message: message,
      type: GrihoMessageType.info,
      duration: duration,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required GrihoMessageType type,
    required Duration duration,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final Color bg;
    final Color accent;
    final IconData icon;

    switch (type) {
      case GrihoMessageType.success:
        bg = GrihoColors.deepTeal;
        accent = GrihoColors.softMint;
        icon = Iconsax.tick_circle;
      case GrihoMessageType.error:
        bg = const Color(0xFF7F1D1D);
        accent = const Color(0xFFFECACA);
        icon = Iconsax.close_circle;
      case GrihoMessageType.warning:
        bg = const Color(0xFF78350F);
        accent = const Color(0xFFFDE68A);
        icon = Iconsax.warning_2;
      case GrihoMessageType.info:
        bg = GrihoColors.deepTeal;
        accent = GrihoColors.emerald;
        icon = Iconsax.info_circle;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          backgroundColor: bg,
          elevation: 6,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: accent.withValues(alpha: 0.35)),
          ),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => messenger.hideCurrentSnackBar(),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
