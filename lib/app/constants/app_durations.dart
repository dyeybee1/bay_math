/// Centralized animation duration scale.
///
/// Use these for implicit/explicit animations instead of literal
/// `Duration(milliseconds: ...)` values, so motion feels consistent
/// across the app.
class AppDurations {
  const AppDurations._();

  /// Micro-interactions — e.g. button press feedback, icon toggles.
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transitions — e.g. page/route transitions, expand/collapse.
  static const Duration medium = Duration(milliseconds: 300);

  /// Deliberate, attention-drawing transitions — used sparingly.
  static const Duration slow = Duration(milliseconds: 500);
}
