import 'package:flutter/material.dart';

import '../../constants/app_elevation.dart';
import '../../constants/app_radius.dart';

/// Component theme for [SnackBar].
class AppSnackBarTheme {
  const AppSnackBarTheme._();

  static SnackBarThemeData snackBar(ColorScheme colorScheme) {
    return SnackBarThemeData(
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      actionTextColor: colorScheme.inversePrimary,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mediumAll),
      elevation: AppElevation.level2,
    );
  }
}
