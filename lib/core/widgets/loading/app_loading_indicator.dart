import 'package:flutter/material.dart';

import '../../../app/constants/app_spacing.dart';
import '../app_component_size.dart';

enum AppLoadingVariant { circular, linear }

/// The app's single reusable loading indicator.
///
/// Wraps [CircularProgressIndicator]/[LinearProgressIndicator] (already
/// themed in Phase 0.5) with consistent sizing and an optional message,
/// plus a fullscreen overlay mode for blocking async operations.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = AppComponentSize.medium,
    this.variant = AppLoadingVariant.circular,
    this.fullscreen = false,
    this.message,
  });

  final AppComponentSize size;
  final AppLoadingVariant variant;

  /// When true, fills the available space with a semi-transparent
  /// surface-colored scrim behind the indicator — for blocking overlays.
  final bool fullscreen;

  final String? message;

  @override
  Widget build(BuildContext context) {
    final Widget indicator = variant == AppLoadingVariant.linear
        ? SizedBox(
            width: fullscreen ? 200 : size.iconSize * 3,
            child: const LinearProgressIndicator(),
          )
        : SizedBox(
            width: size.iconSize,
            height: size.iconSize,
            child: const CircularProgressIndicator(strokeWidth: 3),
          );

    final Widget content = Semantics(
      liveRegion: true,
      label: message ?? 'Loading',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          indicator,
          if (message != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );

    if (!fullscreen) return Center(child: content);

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      child: Center(child: content),
    );
  }
}
