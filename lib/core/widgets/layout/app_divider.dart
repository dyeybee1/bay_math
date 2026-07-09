import 'package:flutter/material.dart';

import '../../../app/constants/app_spacing.dart';

/// The app's single reusable divider — wraps [Divider]/[VerticalDivider]
/// with a consistent spacing API instead of ad-hoc [SizedBox]s scattered
/// through feature code.
class AppDivider extends StatelessWidget {
  const AppDivider({
    super.key,
    this.axis = Axis.horizontal,
    this.spacing = AppSpacing.md,
  });

  final Axis axis;

  /// Space on either side of the divider line (vertical margin for
  /// horizontal dividers, horizontal margin for vertical ones).
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (axis == Axis.vertical) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing),
        child: const VerticalDivider(width: 1),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing),
      child: const Divider(height: 1),
    );
  }
}
