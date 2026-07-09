import 'package:flutter/material.dart';

import '../app_component_size.dart';

/// The app's single reusable avatar.
///
/// Placed under `navigation/` rather than `feedback/` since its primary
/// use is identifying the current user in navigation surfaces (app bar,
/// nav rail, profile menu) — not status feedback.
///
/// Resolution order: [imageUrl] first, falling back to [initials], then
/// to a generic person [icon] if neither is provided.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.icon = Icons.person_outline,
    this.size = AppComponentSize.medium,
    this.semanticLabel,
  });

  final String? imageUrl;
  final String? initials;
  final IconData icon;
  final AppComponentSize size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final double diameter = size.avatarDiameter;

    Widget content;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      content = ClipOval(
        child: Image.network(
          imageUrl!,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _fallback(colorScheme, diameter),
        ),
      );
    } else {
      content = _fallback(colorScheme, diameter);
    }

    return Semantics(
      label: semanticLabel ?? (initials != null ? 'Avatar: $initials' : 'Avatar'),
      image: imageUrl != null,
      child: SizedBox(width: diameter, height: diameter, child: content),
    );
  }

  Widget _fallback(ColorScheme colorScheme, double diameter) {
    return CircleAvatar(
      radius: diameter / 2,
      backgroundColor: colorScheme.primaryContainer,
      child: initials != null && initials!.isNotEmpty
          ? Text(
              initials!.length > 2 ? initials!.substring(0, 2) : initials!,
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: diameter * 0.4,
              ),
            )
          : Icon(icon, color: colorScheme.onPrimaryContainer, size: diameter * 0.6),
    );
  }
}
