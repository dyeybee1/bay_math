/// Mirrors `public.quiz_attempt_status` (0002).
enum QuizAttemptStatus {
  active,
  superseded;

  static QuizAttemptStatus fromDb(String value) => switch (value) {
        'active' => QuizAttemptStatus.active,
        'superseded' => QuizAttemptStatus.superseded,
        _ => throw ArgumentError('Unknown quiz_attempt_status value: $value'),
      };

  String toDb() => switch (this) {
        QuizAttemptStatus.active => 'active',
        QuizAttemptStatus.superseded => 'superseded',
      };
}

/// A Dart-side mirror of one `public.quiz_attempts` row (0010) — one
/// student's interaction with one Internal Quiz. `sectionId`/`schoolYearId`
/// are frozen historical context (immutable after insert, DB-trigger
/// enforced) and `totalQuestions` is auto-populated by a DB trigger (0018
/// item 6) — none of the three are ever set from application code.
class QuizAttempt {
  const QuizAttempt({
    required this.id,
    required this.studentId,
    required this.quizId,
    required this.sectionId,
    required this.schoolYearId,
    required this.attemptStatus,
    this.totalQuestions,
    this.score,
    required this.openedAt,
    this.submittedAt,
    this.resetBy,
    this.resetAt,
  });

  final String id;
  final String studentId;
  final String quizId;
  final String sectionId;
  final String schoolYearId;
  final QuizAttemptStatus attemptStatus;
  final int? totalQuestions;
  final num? score;
  final DateTime openedAt;
  final DateTime? submittedAt;
  final String? resetBy;
  final DateTime? resetAt;

  /// Read-only guard for the quiz-taking screen (Phase 6 constraint 8):
  /// once true, the screen must go read-only rather than allow further
  /// answer submission — the DB does not currently enforce this itself
  /// (see the `// TODO` in `quiz_attempts_repository.dart`).
  bool get isSubmitted => submittedAt != null;

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    return QuizAttempt(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      quizId: json['quiz_id'] as String,
      sectionId: json['section_id'] as String,
      schoolYearId: json['school_year_id'] as String,
      attemptStatus: QuizAttemptStatus.fromDb(json['attempt_status'] as String),
      totalQuestions: json['total_questions'] as int?,
      score: json['score'] as num?,
      openedAt: DateTime.parse(json['opened_at'] as String),
      submittedAt:
          json['submitted_at'] == null ? null : DateTime.parse(json['submitted_at'] as String),
      resetBy: json['reset_by'] as String?,
      resetAt: json['reset_at'] == null ? null : DateTime.parse(json['reset_at'] as String),
    );
  }
}
