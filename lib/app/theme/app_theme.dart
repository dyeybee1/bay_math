import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Composes the app's [ThemeData], Material 3.
///
/// Version 1 scope: a single Light Theme only. Dark theme support is
/// deliberately not configured for this version.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build();

  static ThemeData _build() {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: AppTypography.textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}
