// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Follows the device system appearance automatically (Day -> Light, Night -> Dark).
final grihoThemeModeProvider = Provider<ThemeMode>((ref) {
  return ThemeMode.system;
});
