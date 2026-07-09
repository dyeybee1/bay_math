import 'package:flutter/material.dart';

import '../../constants/app_elevation.dart';
import '../../constants/app_radius.dart';
import 'app_input_theme.dart';

/// Component theme for [DropdownMenu]. Reuses [AppInputTheme] so the
/// dropdown's field looks identical to a regular text input.
class AppDropdownMenuTheme {
  const AppDropdownMenuTheme._();

  static DropdownMenuThemeData dropdownMenu(ColorScheme colorScheme) {
    return DropdownMenuThemeData(
      inputDecorationTheme: AppInputTheme.inputDecoration(colorScheme),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(AppElevation.level2),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.mediumAll),
        ),
      ),
    );
  }
}
