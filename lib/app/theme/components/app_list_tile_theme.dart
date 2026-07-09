import 'package:flutter/material.dart';

import '../../constants/app_radius.dart';
import '../../constants/app_spacing.dart';

/// Component theme for [ListTile].
class AppListTileTheme {
  const AppListTileTheme._();

  static ListTileThemeData listTile(ColorScheme colorScheme) {
    return ListTileThemeData(
      iconColor: colorScheme.onSurfaceVariant,
      textColor: colorScheme.onSurface,
      selectedColor: colorScheme.primary,
      selectedTileColor: colorScheme.primaryContainer,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mediumAll),
      minVerticalPadding: AppSpacing.sm,
    );
  }
}
