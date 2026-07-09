import 'package:flutter/widgets.dart';

/// Layout tiers matching the app's target experiences:
///
/// - [studentTabletLayout] — the Android tablet experience used by students.
/// - [desktopLayout] — the Desktop/Web experience, shared by both the
///   Teacher and the Administrator audiences. Both use the same physical
///   form factor and viewport widths; if their layouts ever need to
///   diverge, that's a role-based navigation decision for a later phase
///   (once auth/roles exist), not a width-based breakpoint.
///
/// [compactLayout] is kept only as a narrow-width safety fallback (e.g. a
/// phone-sized window); it is not one of the app's primary targets.
enum AppLayoutType {
  compactLayout,
  studentTabletLayout,
  desktopLayout,
}

/// Width thresholds that determine which [AppLayoutType] applies.
///
/// This is intentionally minimal — a classifier only. Actual responsive
/// layout widgets built on top of this are a later-phase concern.
class AppLayoutBreakpoints {
  const AppLayoutBreakpoints._();

  /// Below this width: [AppLayoutType.compactLayout].
  static const double compactMax = 600;

  /// Below this width (and >= [compactMax]): [AppLayoutType.studentTabletLayout].
  static const double studentTabletMax = 1024;

  /// [studentTabletMax] and above: [AppLayoutType.desktopLayout]
  /// (Teacher and Administrator).
  static AppLayoutType classify(double width) {
    if (width < compactMax) return AppLayoutType.compactLayout;
    if (width < studentTabletMax) return AppLayoutType.studentTabletLayout;
    return AppLayoutType.desktopLayout;
  }

  static AppLayoutType of(BuildContext context) {
    return classify(MediaQuery.sizeOf(context).width);
  }
}
