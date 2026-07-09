import 'package:flutter/material.dart';

/// Central color palette for the app.
///
/// Deliberately muted / moderate-saturation tones rather than bright,
/// playful primaries — the brief calls for "modern, clean, professional,
/// not childish, not overly playful," which for Grades 4–6 means calm and
/// readable over vibrant. Text uses dark gray, never pure black, to
/// reduce contrast fatigue during extended reading/practice.
///
/// [scheme] is the single Material 3 [ColorScheme] the rest of the theme
/// is built from — nothing outside this file and `app_semantic_colors.dart`
/// should reference a raw [Color] literal.
class AppColors {
  const AppColors._();

  // --- Primary (Blue) ---
  static const Color primary = Color(0xFF2E5C8A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFD6E4F5);
  static const Color onPrimaryContainer = Color(0xFF15304A);

  // --- Secondary (Green) ---
  static const Color secondary = Color(0xFF3F7D5C);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFD9EBE0);
  static const Color onSecondaryContainer = Color(0xFF1B3F2C);

  // --- Accent / Tertiary (Orange) ---
  static const Color tertiary = Color(0xFFC97A3D);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFF6E1CD);
  static const Color onTertiaryContainer = Color(0xFF5C3512);

  // --- Error (Red) ---
  static const Color error = Color(0xFFB3423A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFF6D8D5);
  static const Color onErrorContainer = Color(0xFF4A1613);

  // --- Neutral surfaces ---
  /// Very light gray app background (behind cards/surfaces).
  static const Color background = Color(0xFFF7F8FA);

  /// White — cards, sheets, dialogs, and other elevated surfaces.
  static const Color surface = Color(0xFFFFFFFF);

  /// A step darker than [surface] — used for subtle containers like
  /// filled input fields and track backgrounds.
  static const Color surfaceContainerHighest = Color(0xFFEDEFF2);

  // --- Text / outline ---
  /// Primary text color — dark gray, not pure black.
  static const Color textPrimary = Color(0xFF2A2E35);

  /// Secondary/supporting text color (labels, hints, captions).
  static const Color textSecondary = Color(0xFF5B6270);

  static const Color outline = Color(0xFFC4C9D0);
  static const Color outlineVariant = Color(0xFFDEE1E6);

  /// The single Material 3 [ColorScheme] for the app.
  ///
  /// Built via [ColorScheme.fromSeed] (guarantees every required M3 role
  /// is populated with a harmonious value), then overridden with the
  /// specific brand roles above so primary/secondary/tertiary map
  /// exactly to Blue/Green/Orange as specified, rather than all being
  /// algorithmically derived from a single seed hue.
  static final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: textPrimary,
    surfaceContainerHighest: surfaceContainerHighest,
    onSurfaceVariant: textSecondary,
    outline: outline,
    outlineVariant: outlineVariant,
  );
}
