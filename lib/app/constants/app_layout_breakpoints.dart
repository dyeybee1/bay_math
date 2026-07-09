import 'package:flutter/widgets.dart';

/// Layout tiers matching the app's two primary target experiences:
///
/// - [studentTabletLayout] — the Android tablet experience used by students.
/// - [teacherDesktopLayout] — the Desktop/Web experience used by teachers
///   and administrators.
///
/// [compactLayout] is kept only as a narrow-width safety fallback (e.g. a
/// phone-sized window); it is not one of the app's primary targets.
enum AppLayoutType {
  compactLayout,
  studentTabletLayout,
  teacherDesktopLayout,
}

/// Width thresholds that determine which [AppLayoutType] applies.
///
/// This is intentionally minimal for Phase 0 — a classifier only. Actual
/// responsive layout widgets built on top of this are a later-phase concern.
class AppLayoutBreakpoints {
  const AppLayoutBreakpoints._();

  /// Below this width: [AppLayoutType.compactLayout].
  static const double compactMax = 600;

  /// Below this width (and >= [compactMax]): [AppLayoutType.studentTabletLayout].
  static const double studentTabletMax = 1024;

  /// [studentTabletMax] and above: [AppLayoutType.teacherDesktopLayout].
  static AppLayoutType classify(double width) {
    if (width < compactMax) return AppLayoutType.compactLayout;
    if (width < studentTabletMax) return AppLayoutType.studentTabletLayout;
    return AppLayoutType.teacherDesktopLayout;
  }

  static AppLayoutType of(BuildContext context) {
    return classify(MediaQuery.sizeOf(context).width);
  }
}
