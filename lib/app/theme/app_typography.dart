import 'package:flutter/material.dart';

/// App-wide typography scale, built on Flutter's default (system) font so
/// no additional font/Google Fonts package is required — Material's type
/// scale alone gives a clear five-tier hierarchy:
///
/// - **Display** — hero/splash-level text only, used sparingly.
/// - **Headline** — screen and section headers.
/// - **Title** — card headers, dialog titles, list section titles.
/// - **Body** — the bulk of readable content (instructions, explanations).
/// - **Label** — buttons, chips, captions, form field labels.
///
/// Grades 4-6 students and adult teachers/admins share this scale for now;
/// per-audience type-scale tuning (e.g. larger student-facing text) is a
/// later-phase concern once real screens exist — see the README's Future
/// Reusability Notes.
class AppTypography {
  const AppTypography._();

  static const TextTheme textTheme = TextTheme(
    // --- Display ---
    displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400),
    displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
    displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),

    // --- Headline ---
    headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),

    // --- Title ---
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),

    // --- Body ---
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),

    // --- Label ---
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
  );
}
