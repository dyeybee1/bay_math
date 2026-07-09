import 'package:flutter/material.dart';

import '../../../app/constants/app_dimensions.dart';
import '../../../app/constants/app_radius.dart';

/// The app's single reusable selectable chip — used for filters, tags,
/// and multi/single-select option lists.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final bool selected;

  /// Null makes the chip non-interactive regardless of [enabled].
  final ValueChanged<bool>? onSelected;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool interactive = enabled && onSelected != null;

    return FilterChip(
      label: Text(label),
      avatar: icon != null ? Icon(icon, size: AppDimensions.iconSmall) : null,
      selected: selected,
      onSelected: interactive ? onSelected : null,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mediumAll,
        side: BorderSide(color: selected ? colorScheme.primary : colorScheme.outline),
      ),
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primaryContainer,
      disabledColor: colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: !interactive
            ? colorScheme.onSurfaceVariant
            : selected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurface,
      ),
    );
  }
}
