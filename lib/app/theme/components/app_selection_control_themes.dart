import 'package:flutter/material.dart';

import '../../constants/app_radius.dart';

/// Component themes for the selection-control trio: [Checkbox], [Radio],
/// and [Switch]. Grouped together since they share the same selected/
/// unselected color logic.
class AppSelectionControlThemes {
  const AppSelectionControlThemes._();

  static CheckboxThemeData checkbox(ColorScheme colorScheme) {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
      side: BorderSide(color: colorScheme.outline, width: 1.5),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.smallAll),
    );
  }

  static RadioThemeData radio(ColorScheme colorScheme) {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.primary;
        return colorScheme.outline;
      }),
    );
  }

  static SwitchThemeData switchTheme(ColorScheme colorScheme) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.primary;
        return colorScheme.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colorScheme.primaryContainer;
        return colorScheme.surfaceContainerHighest;
      }),
      trackOutlineColor: WidgetStateProperty.all(colorScheme.outline),
    );
  }
}
