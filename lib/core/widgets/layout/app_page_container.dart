import 'package:flutter/material.dart';

import '../../../app/constants/app_dimensions.dart';
import '../../../app/constants/app_layout_breakpoints.dart';
import '../../../app/constants/app_spacing.dart';

/// The app's single reusable page wrapper — intended to wrap almost every
/// screen's body in later phases.
///
/// Automatically applies:
/// - A maximum content width ([AppDimensions.maxContentWidth]), so text
///   and forms stay readable on wide Desktop/Web windows.
/// - Responsive padding, denser on tablet, roomier on desktop, via
///   [AppLayoutBreakpoints].
/// - [SafeArea], so content never sits under a device notch/status bar.
/// - Center alignment for the constrained content within the full width.
class AppPageContainer extends StatelessWidget {
  const AppPageContainer({
    super.key,
    required this.child,
    this.scrollable = false,
    this.applySafeArea = true,
  });

  final Widget child;

  /// Wraps content in a [SingleChildScrollView] when true.
  final bool scrollable;

  final bool applySafeArea;

  EdgeInsets _responsivePadding(BuildContext context) {
    final AppLayoutType layout = AppLayoutBreakpoints.of(context);
    return switch (layout) {
      AppLayoutType.compactLayout => const EdgeInsets.all(AppSpacing.md),
      AppLayoutType.studentTabletLayout => const EdgeInsets.all(AppSpacing.lg),
      AppLayoutType.desktopLayout =>
        const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
    };
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
        child: Padding(
          padding: _responsivePadding(context),
          child: child,
        ),
      ),
    );

    if (scrollable) {
      content = SingleChildScrollView(child: content);
    }

    if (applySafeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }
}
