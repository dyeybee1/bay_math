import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/avatar_catalog.dart';

/// Renders a student's selected fixed-catalog avatar, with initials as the
/// deliberate fallback when no valid avatar id is available.
class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    super.key,
    required this.fullName,
    this.avatarId,
    this.size = 42,
    this.highlighted = false,
  });

  final String fullName;
  final String? avatarId;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final AvatarOption? avatar = AvatarCatalog.findById(avatarId);
    final Color background =
        avatar?.background ??
        (highlighted ? AppColors.primary : AppColors.primaryContainer);
    final Color foreground =
        avatar != null || highlighted ? Colors.white : AppColors.primary;

    return Semantics(
      label:
          avatar == null
              ? '$fullName initials avatar'
              : '$fullName ${avatar.label} avatar',
      image: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border:
              highlighted
                  ? Border.all(
                    color: Colors.white,
                    width: math.max(2, size * 0.05),
                  )
                  : null,
          boxShadow:
              highlighted
                  ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                  : null,
        ),
        child:
            avatar == null
                ? Text(
                  studentInitials(fullName),
                  style: TextStyle(
                    color: foreground,
                    fontSize: size * 0.3,
                    fontWeight: FontWeight.w700,
                  ),
                )
                : Icon(avatar.icon, color: foreground, size: size * 0.54),
      ),
    );
  }
}

String studentInitials(String name) {
  final List<String> parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first
        .substring(0, math.min(2, parts.first.length))
        .toUpperCase();
  }
  return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
}
