import 'package:flutter/material.dart';

import '../../../app/constants/app_spacing.dart';
import '../app_component_size.dart';

/// Visual intent of an [AppButton]. Maps to Material 3 button types and
/// [ThemeData] roles — no color is ever hardcoded here.
enum AppButtonVariant {
  /// High-emphasis action. Uses `colorScheme.primary`.
  primary,

  /// Medium-emphasis action. Uses Material 3's tonal button
  /// (`colorScheme.secondaryContainer`).
  secondary,

  /// Medium-emphasis action with a visible border, no fill.
  outlined,

  /// Low-emphasis action, no fill or border.
  text,

  /// Destructive action (e.g. delete). Uses `colorScheme.error`.
  danger,
}

/// The app's single reusable button.
///
/// Wraps Flutter/Material 3's [FilledButton]/[OutlinedButton]/[TextButton]
/// so every button in the app — regardless of module — shares the same
/// API, sizing, and disabled/loading behavior. All colors come from the
/// current [Theme]; nothing is hardcoded here.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppComponentSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticLabel,
  });

  final String label;

  /// Null disables the button (combined with [isLoading], either one
  /// disables interaction).
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppComponentSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  /// Shows a spinner in place of the label/icons and disables interaction.
  final bool isLoading;

  final bool isFullWidth;

  /// Overrides the label as the accessibility announcement, useful when
  /// [label] is abbreviated but the action needs a fuller description.
  final String? semanticLabel;

  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final Widget child = isLoading
        ? SizedBox(
            width: size.iconSize,
            height: size.iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _loadingColor(colorScheme),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (leadingIcon != null) ...<Widget>[
                Icon(leadingIcon, size: size.iconSize),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              if (trailingIcon != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Icon(trailingIcon, size: size.iconSize),
              ],
            ],
          );

    final VoidCallback? effectiveOnPressed = _isDisabled ? null : onPressed;

    final Widget button = switch (variant) {
      AppButtonVariant.primary =>
        FilledButton(onPressed: effectiveOnPressed, child: child),
      AppButtonVariant.secondary =>
        FilledButton.tonal(onPressed: effectiveOnPressed, child: child),
      AppButtonVariant.outlined =>
        OutlinedButton(onPressed: effectiveOnPressed, child: child),
      AppButtonVariant.text =>
        TextButton(onPressed: effectiveOnPressed, child: child),
      AppButtonVariant.danger => FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          child: child,
        ),
    };

    return Semantics(
      button: true,
      enabled: !_isDisabled,
      label: semanticLabel ?? label,
      child: SizedBox(
        height: size.controlHeight,
        width: isFullWidth ? double.infinity : null,
        child: button,
      ),
    );
  }

  Color _loadingColor(ColorScheme colorScheme) => switch (variant) {
        AppButtonVariant.primary => colorScheme.onPrimary,
        AppButtonVariant.danger => colorScheme.onError,
        AppButtonVariant.secondary => colorScheme.onSecondaryContainer,
        AppButtonVariant.outlined || AppButtonVariant.text => colorScheme.primary,
      };
}
