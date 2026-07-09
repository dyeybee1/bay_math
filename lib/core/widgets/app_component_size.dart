import 'package:flutter/material.dart';

import '../../app/constants/app_dimensions.dart';

/// Shared size tier used by every reusable widget in this library.
///
/// Rather than each widget inventing its own small/medium/large mapping,
/// the mapping lives once here (via [AppComponentSizeX]) and every widget
/// reuses it — this is the single source of truth for "how big is small,
/// medium, large" across buttons, inputs, cards, avatars, loading
/// indicators, etc.
///
/// As a rule of thumb: the Android tablet (Student) UI should default to
/// [large] for generous touch targets; the Desktop (Teacher/Admin) UI
/// should default to [medium] for denser, mouse-driven layouts.
enum AppComponentSize { small, medium, large }

extension AppComponentSizeX on AppComponentSize {
  /// Height for tappable controls (buttons, inputs). All tiers stay at
  /// or above [AppDimensions.minTouchTarget] for accessibility, except
  /// [small], which is only intended for dense, non-primary desktop UI.
  double get controlHeight => switch (this) {
        AppComponentSize.small => 36,
        AppComponentSize.medium => 44,
        AppComponentSize.large => AppDimensions.minTouchTarget,
      };

  /// Icon size to pair with this component size.
  double get iconSize => switch (this) {
        AppComponentSize.small => AppDimensions.iconSmall,
        AppComponentSize.medium => AppDimensions.iconMedium,
        AppComponentSize.large => AppDimensions.iconLarge,
      };

  /// Avatar diameter for this component size.
  double get avatarDiameter => switch (this) {
        AppComponentSize.small => AppDimensions.avatarSmall,
        AppComponentSize.medium => AppDimensions.avatarMedium,
        AppComponentSize.large => AppDimensions.avatarLarge,
      };

  /// Text style to pair with this component size, pulled from the
  /// current [TextTheme] rather than hardcoded font sizes.
  TextStyle? textStyle(TextTheme textTheme) => switch (this) {
        AppComponentSize.small => textTheme.bodySmall,
        AppComponentSize.medium => textTheme.bodyLarge,
        AppComponentSize.large => textTheme.titleMedium,
      };
}
