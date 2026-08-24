import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// BayMath shared typography helpers.
///
/// - Headings / titles → **Lexend** (weights 600–700)
/// - Body / labels / UI text → **Inter** (weights 400–600)
abstract final class AppTextStyles {
  // ── Lexend (headings / titles) ──────────────────────────────────────
  static TextStyle lexend({
    double size = 16,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.navy,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.lexend(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // ── Inter (body / labels / UI) ──────────────────────────────────────
  static TextStyle inter({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.navy,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
}
