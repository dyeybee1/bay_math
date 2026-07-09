import 'package:flutter/material.dart';

/// Central color palette for the app.
///
/// A single seed color drives the Material 3 `ColorScheme` (see
/// `app_theme.dart`); the extra named colors below are for accents that
/// don't map cleanly to Material 3 roles (e.g. subject-agnostic success/
/// warning states used later for quiz feedback, kept here only as palette
/// constants — no widgets or business logic reference them yet).
class AppColors {
  const AppColors._();

  /// Primary brand seed — a calm, focus-friendly blue suited to a
  /// classroom learning tool.
  static const Color seed = Color(0xFF2F6FED);

  static const Color success = Color(0xFF2E9E5B);
  static const Color warning = Color(0xFFE0A319);
  static const Color error = Color(0xFFD64545);

  static const Color neutralLight = Color(0xFFF5F7FA);
  static const Color neutralDark = Color(0xFF1B1F27);
}
