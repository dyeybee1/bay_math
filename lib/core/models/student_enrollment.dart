/// Mirrors `public.student_enrollments.status` (0002 enum `enrollment_status`,
/// extended by 0047 with `archived`). Previously `{active, closed}` here,
/// which did not match the real database enum at all (`closed` is not a
/// database value; `transferred`/`completed`/`archived` were missing) — any
/// enrollment row with one of those three statuses would have thrown from
/// `fromDb`'s `.byName` lookup. Fixed to the actual four values; no
/// `EnrollmentStatus` switch exists anywhere else in this codebase to
/// update alongside it (verified by search — the only other reference is
/// `StudentEnrollment.fromJson` below).
enum EnrollmentStatus {
  active,
  transferred,
  completed,
  archived;

  static EnrollmentStatus fromDb(String value) => EnrollmentStatus.values.byName(value);
}

/// A Dart-side mirror of one `public.student_enrollments` row — the
/// Student <-> Section join. `school_year_id` is deliberately not
/// duplicated here (0006): derive it via `section_id` -> `sections.school_year_id`
/// if ever needed.
class StudentEnrollment {
  const StudentEnrollment({
    required this.id,
    required this.studentId,
    required this.sectionId,
    required this.status,
    required this.enrolledAt,
    this.endedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String studentId;
  final String sectionId;
  final EnrollmentStatus status;
  final DateTime enrolledAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory StudentEnrollment.fromJson(Map<String, dynamic> json) {
    return StudentEnrollment(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      sectionId: json['section_id'] as String,
      status: EnrollmentStatus.fromDb(json['status'] as String),
      enrolledAt: DateTime.parse(json['enrolled_at'] as String),
      endedAt: json['ended_at'] == null ? null : DateTime.parse(json['ended_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
