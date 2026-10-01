import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// One selectable avatar option.
///
/// Deliberately icon+color, not an image asset — no design art exists for
/// this yet, and this keeps the feature shippable without depending on new
/// assets or Supabase Storage (see 0053_student_avatar.sql's own comment on
/// why avatar_id is a catalog key, not an uploaded image). Swap [icon] for
/// `Image.asset(...)` later per entry if/when illustrated art is ready —
/// nothing outside this file needs to change, since every caller goes
/// through [AvatarCatalog.byId]/[AvatarCatalog.all].
class AvatarOption {
  const AvatarOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.background,
  });

  /// Must match one of the keys in `students_avatar_id_valid`
  /// (0053_student_avatar.sql) exactly — this is what gets sent to
  /// `set_student_avatar` and stored in `students.avatar_id`.
  final String id;

  /// Shown under the icon in the picker grid (e.g. "Fox").
  final String label;

  final IconData icon;
  final Color background;
}

/// The fixed avatar catalog. Keep this list and the database check
/// constraint (`students_avatar_id_valid`, 0053) in sync — an id here with
/// no matching database entry would be rejected on save; a database id
/// with no matching entry here would fail to render (falls back to
/// [AvatarCatalog.fallback]).
class AvatarCatalog {
  const AvatarCatalog._();

  static const List<AvatarOption> all = <AvatarOption>[
    AvatarOption(id: 'fox', label: 'Fox', icon: Icons.pets, background: AppColors.tertiary),
    AvatarOption(id: 'owl', label: 'Owl', icon: Icons.nightlight_round, background: AppColors.primary),
    AvatarOption(id: 'panda', label: 'Panda', icon: Icons.cruelty_free, background: Color(0xFF5B6270)),
    AvatarOption(id: 'robot', label: 'Robot', icon: Icons.smart_toy, background: AppColors.secondary),
    AvatarOption(id: 'star', label: 'Star', icon: Icons.star, background: Color(0xFFC98A2E)),
    AvatarOption(id: 'rocket', label: 'Rocket', icon: Icons.rocket_launch, background: AppColors.primary),
    AvatarOption(id: 'turtle', label: 'Turtle', icon: Icons.spa, background: AppColors.secondary),
    AvatarOption(id: 'whale', label: 'Whale', icon: Icons.waves, background: Color(0xFF2E5C8A)),
    AvatarOption(id: 'cat', label: 'Cat', icon: Icons.pets, background: AppColors.tertiary),
    AvatarOption(id: 'lion', label: 'Lion', icon: Icons.emoji_nature, background: Color(0xFFC98A2E)),
    AvatarOption(id: 'penguin', label: 'Penguin', icon: Icons.ac_unit, background: AppColors.primary),
    AvatarOption(id: 'dino', label: 'Dino', icon: Icons.forest, background: AppColors.secondary),
  ];

  /// Used whenever a student's stored `avatar_id` doesn't match any known
  /// option (e.g. catalog trimmed after they picked) — never null, so
  /// every call site can render unconditionally.
  static const AvatarOption fallback = AvatarOption(
    id: 'star',
    label: 'Star',
    icon: Icons.star,
    background: AppColors.primary,
  );

  /// Returns the exact catalog entry for [id], or `null` when the student
  /// has not selected an avatar (or an older value is no longer known).
  ///
  /// Use this when a UI has its own explicit fallback, such as initials.
  static AvatarOption? findById(String? id) {
    if (id == null) return null;
    for (final AvatarOption option in all) {
      if (option.id == id) return option;
    }
    return null;
  }

  static AvatarOption byId(String? id) {
    return findById(id) ?? fallback;
  }
}
