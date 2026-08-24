/// Mirrors `public.profiles.role`.
enum ProfileRole {
  admin,
  teacher;

  static ProfileRole fromDb(String value) => ProfileRole.values.byName(value);
}

/// Mirrors `public.profiles.status` (0002, extended by 0047 with `archived`).
enum ProfileStatus {
  pending,
  approved,
  rejected,
  suspended,
  archived;

  static ProfileStatus fromDb(String value) => ProfileStatus.values.byName(value);
}

/// A Teacher or Admin identity — the Dart-side mirror of one `profiles` row.
/// Students are never represented by this model; they have no `profiles`
/// row at all, by design.
class Profile {
  const Profile({
    required this.id,
    required this.role,
    required this.status,
    required this.fullName,
    required this.email,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final ProfileRole role;
  final ProfileStatus status;
  final String fullName;
  final String email;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      role: ProfileRole.fromDb(json['role'] as String),
      status: ProfileStatus.fromDb(json['status'] as String),
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] == null
          ? null
          : DateTime.parse(json['approved_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
