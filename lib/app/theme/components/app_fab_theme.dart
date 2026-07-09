import 'package:flutter/material.dart';

import '../../constants/app_elevation.dart';
import '../../constants/app_radius.dart';

/// Component theme for [FloatingActionButton].
///
/// Uses the tertiary (Orange accent) role so the FAB reads as the app's
/// single highest-priority action, distinct from primary Blue buttons.
class AppFabTheme {
  const AppFabTheme._();

  static FloatingActionButtonThemeData fab(ColorScheme colorScheme) {
    return FloatingActionButtonThemeData(
      backgroundColor: colorScheme.tertiary,
      foregroundColor: colorScheme.onTertiary,
      elevation: AppElevation.level3,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.largeAll),
    );
  }
}
