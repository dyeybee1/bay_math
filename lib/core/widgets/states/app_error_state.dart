import 'package:flutter/material.dart';

import '../../../app/constants/app_dimensions.dart';
import '../../../app/constants/app_spacing.dart';
import '../buttons/app_button.dart';

/// The app's single reusable error state.
///
/// Used whenever a screen/section fails to load — kept generic and
/// content-free here; feature modules supply the message and retry
/// behavior.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.icon = Icons.error_outline,
    this.message = 'Something went wrong.',
    this.onRetry,
    this.retryLabel = 'Try again',
    this.customAction,
  });

  final IconData icon;
  final String message;

  /// If provided (and [customAction] is not), a default retry button
  /// is rendered.
  final VoidCallback? onRetry;
  final String retryLabel;

  /// Overrides the default retry button entirely with any widget
  /// (e.g. a link, a different action).
  final Widget? customAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: AppDimensions.iconExtraLarge, color: colorScheme.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (customAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              customAction!,
            ] else if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: retryLabel,
                onPressed: onRetry,
                variant: AppButtonVariant.primary,
                leadingIcon: Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
