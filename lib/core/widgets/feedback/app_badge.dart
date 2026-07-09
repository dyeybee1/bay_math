import 'package:flutter/material.dart';

import '../../../app/constants/app_dimensions.dart';
import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_semantic_colors.dart';

/// Semantic intent of an [AppBadge]. Colors are always resolved from the
/// current [Theme] / [AppSemanticColors] — never hardcoded.
enum AppBadgeVariant { success, warning, error, info, neutral }

/// The app's single reusable status badge — a small, filled label used
/// for compact status indicators (e.g. "Completed", "Overdue", "Draft").
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.icon,
  });

  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AppSemanticColors? semantic = Theme.of(context).extension<AppSemanticColors>();

    final (Color background, Color foreground) = switch (variant) {
      AppBadgeVariant.success => (
          semantic?.successContainer ?? colorScheme.secondaryContainer,
          semantic?.onSuccessContainer ?? colorScheme.onSecondaryContainer,
        ),
      AppBadgeVariant.warning => (
          semantic?.warningContainer ?? colorScheme.tertiaryContainer,
          semantic?.onWarningContainer ?? colorScheme.onTertiaryContainer,
        ),
      AppBadgeVariant.error => (colorScheme.errorContainer, colorScheme.onErrorContainer),
      AppBadgeVariant.info => (
          semantic?.infoContainer ?? colorScheme.primaryContainer,
          semantic?.onInfoContainer ?? colorScheme.onPrimaryContainer,
        ),
      AppBadgeVariant.neutral => (colorScheme.surfaceContainerHighest, colorScheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.smallAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: AppDimensions.iconSmall, color: foreground),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
