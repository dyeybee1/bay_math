import 'package:flutter/material.dart';

import '../../constants/app_radius.dart';
import '../../constants/app_spacing.dart';

/// Component theme for text fields / form inputs, and reused by
/// [DropdownMenu] (see `app_dropdown_menu_theme.dart`) so both share the
/// same visual language.
class AppInputTheme {
  const AppInputTheme._();

  static InputDecorationThemeData inputDecoration(ColorScheme colorScheme) {
    final OutlineInputBorder baseBorder = OutlineInputBorder(
      borderRadius: AppRadius.mediumAll,
      borderSide: BorderSide(color: colorScheme.outline),
    );

    return InputDecorationThemeData(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      errorStyle: TextStyle(color: colorScheme.error),
    );
  }
}
