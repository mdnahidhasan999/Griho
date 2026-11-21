import 'package:flutter/material.dart';

abstract final class GrihoColors {
  // Brand Core Palette
  static const Color deepTeal = Color(
    0xFF023337,
  ); // Primary / Dark Hero[span_6](start_span)[span_6](end_span)
  static const Color emerald = Color(
    0xFF4EA674,
  ); // Accent / Primary Button[span_7](start_span)[span_7](end_span)
  static const Color softMint = Color(
    0xFFC0E6B9,
  ); // Container / Highlight[span_8](start_span)[span_8](end_span)
  static const Color mintWhisper = Color(
    0xFFE9F8E7,
  ); // Light Surface / Tint[span_9](start_span)[span_9](end_span)

  // Supporting Neutrals & Semantic Colors
  static const Color background = Color(0xFFF6FBF5);
  static const Color surfaceCard = Colors.white;
  static const Color darkSurface = Color(0xFF0D1B1E);
  static const Color darkCard = Color(0xFF13262A);

  static const Color textPrimary = Color(0xFF023337);
  static const Color textSecondary = Color(0xFF4A6365);
  static const Color borderLight = Color(0xFFD5EAD2);

  static const Color success = Color(0xFF2E8B57);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0284C7);
}
