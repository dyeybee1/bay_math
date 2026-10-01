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

  static ProfileStatus fromDb(String value) =>
      ProfileStatus.values.byName(value);
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
    this.approvedByName,
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
  final String? approvedByName;
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
      approvedBy: _nullableString(json['approved_by']),
      approvedByName: _embeddedFullName(json['approved_by_profile']),
      approvedAt: _nullableTimestamp(json['approved_at']),
      createdAt: _requiredTimestamp(json['created_at'], 'created_at'),
      updatedAt: _requiredTimestamp(json['updated_at'], 'updated_at'),
    );
  }

  static String? _nullableString(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static String? _embeddedFullName(Object? value) {
    final Object? row =
        value is List<Object?> && value.isNotEmpty ? value.first : value;
    if (row is! Map<Object?, Object?>) return null;
    return _nullableString(row['full_name']);
  }

  static DateTime? _nullableTimestamp(Object? value) {
    if (value is DateTime) return value;
    return value is String ? DateTime.tryParse(value) : null;
  }

  static DateTime _requiredTimestamp(Object? value, String fieldName) {
    final DateTime? parsed = _nullableTimestamp(value);
    if (parsed != null) return parsed;
    throw FormatException('Invalid or missing $fieldName timestamp.');
  }
}
