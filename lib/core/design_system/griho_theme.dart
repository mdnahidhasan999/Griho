// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      surface: GrihoColors.mintWhisper,
      onSurface: GrihoColors.textPrimary,
      onSurfaceVariant: GrihoColors.textSecondary,
      surfaceContainerLow: GrihoColors.surfaceCard,
      surfaceContainerHighest: GrihoColors.mintWhisper,
      outlineVariant: GrihoColors.softMint,
      error: GrihoColors.error,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: GrihoColors.mintWhisper,
      textTheme: _buildTextTheme(base.textTheme, GrihoColors.textPrimary),
      appBarTheme: const AppBarTheme(
        backgroundColor: GrihoColors.deepTeal,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      dividerTheme: DividerThemeData(
        color: GrihoColors.softMint.withValues(alpha: 0.75),
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        color: GrihoColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: GrihoColors.softMint),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: GrihoColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: GrihoColors.softMint),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: GrihoColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GrihoColors.emerald,
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
          backgroundColor: GrihoColors.mintWhisper.withValues(alpha: 0.5),
          side: const BorderSide(color: GrihoColors.emerald, width: 1.3),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : GrihoColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
              ? GrihoColors.emerald
              : GrihoColors.softMint.withValues(alpha: 0.5),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
              ? GrihoColors.emerald
              : Colors.transparent,
        ),
        side: const BorderSide(color: GrihoColors.emerald, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GrihoColors.mintWhisper.withValues(alpha: 0.45),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GrihoColors.softMint),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GrihoColors.softMint),
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
        backgroundColor: GrihoColors.darkCard,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      dividerTheme: const DividerThemeData(color: darkBorder, thickness: 1),
      cardTheme: CardThemeData(
        color: GrihoColors.darkCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: GrihoColors.darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: GrihoColors.darkCard,
        surfaceTintColor: Colors.transparent,
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
