import 'package:flutter/material.dart';

abstract final class GrihoColors {
  // Brand Core Palette (4 Core Colors)
  static const Color deepTeal = Color(0xFF023337); // AppBar / Dark Hero / Headings
  static const Color emerald = Color(0xFF4EA674); // Accent / Primary Button
  static const Color softMint = Color(0xFFC0E6B9); // Borders / Containers / Badges
  static const Color mintWhisper = Color(0xFFE9F8E7); // Page Background / Soft Tint

  // Supporting Neutrals & Semantic Colors
  static const Color background = mintWhisper;
  static const Color surfaceCard = Colors.white;
  static const Color darkSurface = Color(0xFF0D1B1E);
  static const Color darkCard = Color(0xFF13262A);

  static const Color textPrimary = deepTeal;
  static const Color textSecondary = Color(0xFF4A6365);
  static const Color borderLight = softMint;

  static const Color success = Color(0xFF2E8B57);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0284C7);
}
