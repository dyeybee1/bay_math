import 'package:flutter/material.dart';

import '../../constants/app_elevation.dart';

/// Component theme for [AppBar].
class AppAppBarTheme {
  const AppAppBarTheme._();

  static AppBarTheme appBar(ColorScheme colorScheme, TextTheme textTheme) {
    return AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: AppElevation.level0,
      scrolledUnderElevation: AppElevation.level1,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
    );
  }
}
