import 'package:flutter/material.dart';

import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../app_component_size.dart';

/// The app's single reusable card.
///
/// Wraps [Card] (already themed in Phase 0.5) and adds a consistent
/// header/footer/leading/trailing layout plus optional tap handling —
/// so every card-based UI (lesson tiles, summary panels, list rows)
/// shares the same structure instead of each feature reinventing it.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.header,
    this.subtitle,
    this.leading,
    this.trailing,
    this.footer,
    this.padding,
    this.margin,
    this.onTap,
    this.size = AppComponentSize.medium,
    this.elevation,
    this.semanticLabel,
  });

  /// Primary content of the card.
  final Widget child;

  /// Optional header title, shown above [child] alongside [leading]/[trailing].
  final Widget? header;

  /// Optional secondary line shown under [header].
  final Widget? subtitle;

  final Widget? leading;
  final Widget? trailing;

  /// Optional content shown below [child], separated by spacing.
  final Widget? footer;

  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// When set, the entire card becomes tappable with a Material ripple.
  final VoidCallback? onTap;

  final AppComponentSize size;

  /// Overrides the themed default elevation for this instance.
  final double? elevation;

  final String? semanticLabel;

  EdgeInsetsGeometry get _defaultPadding => switch (size) {
        AppComponentSize.small => const EdgeInsets.all(AppSpacing.sm),
        AppComponentSize.medium => const EdgeInsets.all(AppSpacing.md),
        AppComponentSize.large => const EdgeInsets.all(AppSpacing.lg),
      };

  bool get _hasHeaderRow => header != null || leading != null || trailing != null;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: padding ?? _defaultPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_hasHeaderRow)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  if (leading != null) ...<Widget>[
                    leading!,
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (header != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          DefaultTextStyle(
                            style: Theme.of(context).textTheme.titleMedium!,
                            child: header!,
                          ),
                          if (subtitle != null)
                            DefaultTextStyle(
                              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                              child: subtitle!,
                            ),
                        ],
                      ),
                    ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          child,
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: footer,
            ),
        ],
      ),
    );

    final Widget card = Card(
      margin: margin,
      elevation: elevation,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: AppRadius.largeAll,
              child: content,
            )
          : content,
    );

    if (semanticLabel == null) return card;
    return Semantics(label: semanticLabel, child: card);
  }
}
