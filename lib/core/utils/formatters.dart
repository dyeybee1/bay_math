/// Small, stateless, shared formatting helpers — see this folder's own
/// README for the rule of thumb on what belongs here.
library;

/// Formats a nullable percent value: whole numbers with no decimal, one
/// decimal place otherwise, an em dash when there's genuinely nothing to
/// show yet (never a bare "0%" standing in for "no data", which would
/// misrepresent e.g. a student who simply hasn't attempted anything).
///
/// Promoted here from what used to be two separate private copies —
/// `student_statistics_screen.dart`'s own `_formatPercent` (Phase 8) and
/// `teacher_dashboard_screen.dart`'s own `_formatPercent` (Phase 9 Part 3)
/// — now that the Phase 9 Part 4 roster drill-down needs the identical
/// logic a third time. Behavior is unchanged from both originals; this is
/// a pure move, not a rewrite.
String formatPercent(num? value) {
  if (value == null) return '—';
  if (value == value.roundToDouble()) return '${value.round()}%';
  return '${value.toStringAsFixed(1)}%';
}
