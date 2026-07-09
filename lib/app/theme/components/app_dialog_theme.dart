import 'package:flutter/material.dart';

import '../../constants/app_elevation.dart';
import '../../constants/app_radius.dart';

/// Component theme for [Dialog] / [AlertDialog].
class AppDialogTheme {
  const AppDialogTheme._();

  static DialogThemeData dialog(ColorScheme colorScheme, TextTheme textTheme) {
    return DialogThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: AppElevation.level3,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.largeAll),
      titleTextStyle: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
      contentTextStyle:
          textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
    );
  }
}
