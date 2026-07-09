import 'package:flutter/material.dart';

import '../../constants/app_elevation.dart';
import '../../constants/app_radius.dart';
import '../../constants/app_spacing.dart';

/// Component theme for [Card].
class AppCardTheme {
  const AppCardTheme._();

  static CardThemeData card(ColorScheme colorScheme) {
    return CardThemeData(
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: AppElevation.level1,
      margin: const EdgeInsets.all(AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeAll,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    );
  }
}
