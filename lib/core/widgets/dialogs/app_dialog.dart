import 'package:flutter/material.dart';

import '../../../app/constants/app_dimensions.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_semantic_colors.dart';

/// Semantic type of an [AppDialog]. Drives the default icon and accent
/// color — all sourced from [Theme], never hardcoded.
enum AppDialogType { info, success, warning, error, confirmation }

/// The app's single reusable dialog.
///
/// Covers information/success/warning/error/confirmation messaging plus
/// fully custom content, with a responsive max width so it reads
/// comfortably on both the student tablet and teacher/admin desktop.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    this.type = AppDialogType.info,
    this.message,
    this.icon,
    this.content,
    this.actions,
    this.maxWidth = 420,
  });

  final String title;
  final AppDialogType type;
  final String? message;

  /// Overrides the type's default icon.
  final IconData? icon;

  /// Optional custom content shown below the message (e.g. a form).
  final Widget? content;

  /// Typically a row of [AppButton]s (Cancel / Confirm, etc.).
  final List<Widget>? actions;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AppSemanticColors? semantic =
        Theme.of(context).extension<AppSemanticColors>();
    final TextTheme textTheme = Theme.of(context).textTheme;

    final (Color accent, IconData defaultIcon) = switch (type) {
      AppDialogType.info => (colorScheme.primary, Icons.info_outline),
      AppDialogType.success => (
          semantic?.success ?? colorScheme.primary,
          Icons.check_circle_outline,
        ),
      AppDialogType.warning => (
          semantic?.warning ?? colorScheme.tertiary,
          Icons.warning_amber_outlined,
        ),
      AppDialogType.error => (colorScheme.error, Icons.error_outline),
      AppDialogType.confirmation => (colorScheme.primary, Icons.help_outline),
    };

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon ?? defaultIcon, color: accent, size: AppDimensions.iconExtraLarge),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: textTheme.titleLarge),
              if (message != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
              if (content != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                // Content can grow arbitrarily tall (e.g. a dynamic list of
                // form rows) — Flexible + scroll view lets it take up to
                // whatever room is left under the maxHeight cap above
                // instead of overflowing the dialog. A no-op when content
                // already fits: no visible scrollbar, no layout change.
                Flexible(child: SingleChildScrollView(child: content!)),
              ],
              if (actions != null && actions!.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    for (int i = 0; i < actions!.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      actions![i],
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Shows this dialog via [showDialog], avoiding boilerplate at call
  /// sites. Returns whatever [actions] pop via `Navigator.pop(context, value)`.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    AppDialogType type = AppDialogType.info,
    String? message,
    IconData? icon,
    Widget? content,
    List<Widget>? actions,
    double maxWidth = 420,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AppDialog(
        title: title,
        type: type,
        message: message,
        icon: icon,
        content: content,
        actions: actions,
        maxWidth: maxWidth,
      ),
    );
  }
}
