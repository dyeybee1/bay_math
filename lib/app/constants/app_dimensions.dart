import 'app_spacing.dart';

/// Centralized, reusable UI dimensions that don't belong in the spacing
/// or radius scales but should still never be hardcoded inline.
class AppDimensions {
  const AppDimensions._();

  // --- Icon sizes ---
  static const double iconSmall = 16;
  static const double iconMedium = 24;
  static const double iconLarge = 32;
  static const double iconExtraLarge = 48;

  // --- Avatar sizes ---
  static const double avatarSmall = 24;
  static const double avatarMedium = 40;
  static const double avatarLarge = 64;

  // --- Layout limits ---
  /// Caps content width on wide Desktop viewports (Teacher/Administrator)
  /// so text and forms don't stretch to uncomfortable reading widths.
  static const double maxContentWidth = 1200;

  /// Material's recommended minimum interactive touch target. Applied to
  /// every tappable component theme — especially important on the
  /// Android tablet, where the primary users are Grade 4–6 students.
  static const double minTouchTarget = 48;

  // --- Defaults ---
  /// Default content padding, expressed via the spacing scale rather
  /// than a new magic number.
  static const double defaultPadding = AppSpacing.md;

  /// Default spacing between sibling components, expressed via the
  /// spacing scale rather than a new magic number.
  static const double defaultMargin = AppSpacing.md;
}
