import 'package:flutter/material.dart';

/// Component theme for [LinearProgressIndicator] / [CircularProgressIndicator].
class AppProgressIndicatorTheme {
  const AppProgressIndicatorTheme._();

  static ProgressIndicatorThemeData progressIndicator(ColorScheme colorScheme) {
    return ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: colorScheme.surfaceContainerHighest,
      circularTrackColor: colorScheme.surfaceContainerHighest,
    );
  }
}
