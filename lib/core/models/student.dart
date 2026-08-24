/// Mirrors `public.students.status` (added by 0047 — students had no status
/// column at all before that migration). Same shape/pattern as
/// `ProfileStatus`/`ProfileRole` in `profile.dart`.
enum StudentStatus {
  active,
  archived;

  static StudentStatus fromDb(String value) => StudentStatus.values.byName(value);
}

/// A Dart-side mirror of one `public.students` row.
///
/// Deliberately does NOT include `password_encrypted` — that column is
/// excluded from every client-facing select (see `StudentsRepository`,
/// which explicitly lists columns rather than using `select('*')`) and is
/// never meant to reach the Flutter client at all (0016_grants.sql: the
/// column-level grant excludes it entirely). Reading/writing a student's
/// password goes exclusively through the `create-student` /
/// `set-student-password` / `view-student-password` Edge Functions.
class Student {
  const Student({
    required this.id,
    this.studentNumber,
    required this.username,
    required this.fullName,
    required this.createdBy,
    required this.status,
    required this.bestEndlessStreak,
    this.avatarId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? studentNumber;
  final String username;
  final String fullName;
  final String createdBy;
  final StudentStatus status;
  final int bestEndlessStreak;

  /// Catalog key (see `avatar_catalog.dart`), not an image — null means the
  /// student hasn't picked one yet (0053_student_avatar.sql). Nullable in
  /// [_publicColumns]-style selects that don't request it, too, so this
  /// field tolerates a missing map key the same way it tolerates an
  /// explicit `null` value from the database.
  final String? avatarId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      studentNumber: json['student_number'] as String?,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      createdBy: json['created_by'] as String,
      status: StudentStatus.fromDb(json['status'] as String),
      bestEndlessStreak: json['best_endless_streak'] as int,
      avatarId: json['avatar_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
