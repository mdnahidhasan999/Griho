// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'griho_colors.dart';

abstract final class GrihoTheme {
  static TextTheme _buildTextTheme(TextTheme base, Color textColor) {
    final jakarta = GoogleFonts.plusJakartaSansTextTheme(base);
    final banglaFallback = GoogleFonts.hindSiliguri().fontFamily;

    return jakarta
        .apply(
          bodyColor: textColor,
          displayColor: textColor,
          fontFamilyFallback: [?banglaFallback],
        )
        .copyWith(
          headlineSmall: jakarta.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          titleLarge: jakarta.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          titleMedium: jakarta.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          bodyMedium: jakarta.bodyMedium?.copyWith(height: 1.4),
        );
  }

  // ==========================================================================
  // DAY MODE (LIGHT THEME)
  // ==========================================================================
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      brightness: Brightness.light,
      seedColor: GrihoColors.emerald,
      primary: GrihoColors.deepTeal,
      onPrimary: Colors.white,
      primaryContainer: GrihoColors.softMint,
      onPrimaryContainer: GrihoColors.deepTeal,
      secondary: GrihoColors.emerald,
      onSecondary: Colors.white,
      secondaryContainer: GrihoColors.mintWhisper,
      onSecondaryContainer: GrihoColors.deepTeal,
      tertiary: GrihoColors.emerald,
      surface: GrihoColors.background,
      onSurface: GrihoColors.textPrimary,
      onSurfaceVariant: GrihoColors.textSecondary,
      surfaceContainerLow: GrihoColors.surfaceCard,
      surfaceContainerHighest: GrihoColors.mintWhisper,
      outlineVariant: GrihoColors.borderLight,
      error: GrihoColors.error,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: GrihoColors.background,
      textTheme: _buildTextTheme(base.textTheme, GrihoColors.textPrimary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: GrihoColors.deepTeal,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: GrihoColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: GrihoColors.borderLight),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: GrihoColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: GrihoColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GrihoColors.deepTeal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GrihoColors.deepTeal,
          side: const BorderSide(color: GrihoColors.deepTeal, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GrihoColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GrihoColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GrihoColors.emerald, width: 1.8),
        ),
      ),
    );
  }

  // ==========================================================================
  // NIGHT MODE (DARK THEME)
  // ==========================================================================
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    const darkBorder = Color(0xFF213C40);
    const darkMutedText = Color(0xFF9CB8BA);

    final colorScheme = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: GrihoColors.emerald,
      primary: GrihoColors.emerald,
      onPrimary: GrihoColors.deepTeal,
      primaryContainer: const Color(0xFF0A4348),
      onPrimaryContainer: GrihoColors.mintWhisper,
      secondary: GrihoColors.softMint,
      onSecondary: GrihoColors.deepTeal,
      secondaryContainer: const Color(0xFF173337),
      onSecondaryContainer: GrihoColors.softMint,
      tertiary: GrihoColors.emerald,
      surface: GrihoColors.darkSurface,
      onSurface: Colors.white,
      onSurfaceVariant: darkMutedText,
      surfaceContainerLow: GrihoColors.darkCard,
      surfaceContainerHighest: const Color(0xFF1B3539),
      outlineVariant: darkBorder,
      error: const Color(0xFFF87171),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: GrihoColors.darkSurface,
      textTheme: _buildTextTheme(base.textTheme, Colors.white),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: GrihoColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: GrihoColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: GrihoColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GrihoColors.emerald,
          foregroundColor: GrihoColors.deepTeal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GrihoColors.softMint,
          side: const BorderSide(color: GrihoColors.emerald, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GrihoColors.darkCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GrihoColors.emerald, width: 1.8),
        ),
      ),
    );
  }
}
