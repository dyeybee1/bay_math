import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_semantic_colors.dart';
import 'app_typography.dart';
import 'components/app_appbar_theme.dart';
import 'components/app_button_themes.dart';
import 'components/app_card_theme.dart';
import 'components/app_dialog_theme.dart';
import 'components/app_dropdown_menu_theme.dart';
import 'components/app_fab_theme.dart';
import 'components/app_input_theme.dart';
import 'components/app_list_tile_theme.dart';
import 'components/app_navigation_bar_theme.dart';
import 'components/app_progress_indicator_theme.dart';
import 'components/app_selection_control_themes.dart';
import 'components/app_snackbar_theme.dart';

/// Composes the app's [ThemeData], Material 3.
///
/// Version 1 scope: a single Light Theme only. Dark theme support is
/// deliberately not configured for this version, but every piece below
/// (colors, typography, component themes) is already modular, so adding
/// a dark variant later is additive, not a rewrite.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build();

  static ThemeData _build() {
    final ColorScheme colorScheme = AppColors.scheme;
    final TextTheme textTheme = AppTypography.textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      extensions: const <ThemeExtension<dynamic>>[
        AppSemanticColors.light,
      ],

      // --- Component themes ---
      filledButtonTheme: AppButtonThemes.filled(colorScheme),
      outlinedButtonTheme: AppButtonThemes.outlined(colorScheme),
      textButtonTheme: AppButtonThemes.text(colorScheme),
      cardTheme: AppCardTheme.card(colorScheme),
      inputDecorationTheme: AppInputTheme.inputDecoration(colorScheme),
      dialogTheme: AppDialogTheme.dialog(colorScheme, textTheme),
      snackBarTheme: AppSnackBarTheme.snackBar(colorScheme),
      appBarTheme: AppAppBarTheme.appBar(colorScheme, textTheme),
      navigationBarTheme: AppNavigationBarTheme.navigationBar(colorScheme, textTheme),
      floatingActionButtonTheme: AppFabTheme.fab(colorScheme),
      progressIndicatorTheme: AppProgressIndicatorTheme.progressIndicator(colorScheme),
      checkboxTheme: AppSelectionControlThemes.checkbox(colorScheme),
      radioTheme: AppSelectionControlThemes.radio(colorScheme),
      switchTheme: AppSelectionControlThemes.switchTheme(colorScheme),
      dropdownMenuTheme: AppDropdownMenuTheme.dropdownMenu(colorScheme),
      listTileTheme: AppListTileTheme.listTile(colorScheme),
    );
  }
}
