import 'package:flutter/material.dart';

import '../../constants/app_dimensions.dart';
import '../../constants/app_elevation.dart';

/// Component theme for [NavigationBar] (Material 3's bottom/tablet nav).
class AppNavigationBarTheme {
  const AppNavigationBarTheme._();

  static NavigationBarThemeData navigationBar(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
      elevation: AppElevation.level2,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final bool selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium?.copyWith(
          color: selected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final bool selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
          size: AppDimensions.iconMedium,
        );
      }),
    );
  }
}
