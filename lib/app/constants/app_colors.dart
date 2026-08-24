import 'package:flutter/material.dart';

/// BayMath shared colour palette (teacher UI design system).
///
/// Import this wherever a raw [Color] is needed instead of inline hex
/// literals, so the palette can evolve from one place.
abstract final class AppColors {
  // ── Primary ────────────────────────────────────────────────────────
  /// Deep navy — primary text, headings, active elements.
  static const Color navy = Color(0xFF16233F);

  /// Slightly lighter navy — hover state for navy buttons.
  static const Color navy2 = Color(0xFF1E2F52);

  /// Accent blue — primary actions, active nav, "My Content" indicators.
  static const Color accent = Color(0xFF2E5AE0);

  /// Soft accent — badge/glyph background that pairs with [accent].
  static const Color accentSoft = Color(0xFFEAF0FE);

  // ── Backgrounds ────────────────────────────────────────────────────
  /// Page background.
  static const Color bg = Color(0xFFF3F6FC);

  /// Card / row surface.
  static const Color card = Color(0xFFFFFFFF);

  // ── Borders & dividers ─────────────────────────────────────────────
  static const Color line = Color(0xFFE4E9F4);

  // ── Text ───────────────────────────────────────────────────────────
  /// Secondary / muted body text.
  static const Color textSoft = Color(0xFF5B6787);

  // ── Amber — "Built-in" badges (Lessons screen) ─────────────────────
  static const Color amber = Color(0xFFF2A93B);
  static const Color amberSoft = Color(0xFFFEF3E1);

  // ── Teal — secondary glyph accent ─────────────────────────────────
  static const Color teal = Color(0xFF12A594);
  static const Color tealSoft = Color(0xFFE4F7F4);

  // ── Neutral tag / badge (Question Bank) ───────────────────────────
  static const Color graySoft = Color(0xFFF1F3F8);
  static const Color grayText = Color(0xFF6B7590);

  // ── Danger — delete hover ──────────────────────────────────────────
  static const Color danger = Color(0xFFD14343);
  static const Color dangerSoft = Color(0xFFFCEBEB);
}
