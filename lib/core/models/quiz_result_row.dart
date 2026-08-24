import 'quiz.dart';
import 'quiz_attempt.dart';

/// Mirrors the `status` column computed by `public.v_teacher_quiz_results`
/// (0045) — `case when submitted_at is null then 'in_progress' else
/// 'completed' end`. Not a Postgres enum (there's no DB type behind this
/// column, it's a plain `text` CASE expression in the view), but modeled
/// as one here for the same reason every DB-derived string on this class
/// is: so the UI switches on a closed Dart type instead of comparing raw
/// strings.
enum QuizResultStatus {
  inProgress,
  completed;

  static QuizResultStatus fromDb(String value) => switch (value) {
        'in_progress' => QuizResultStatus.inProgress,
        'completed' => QuizResultStatus.completed,
        _ => throw ArgumentError('Unknown status value: $value'),
      };

  String get label => switch (this) {
        QuizResultStatus.inProgress => 'In Progress',
        QuizResultStatus.completed => 'Completed',
      };
}

/// A Dart-side mirror of one `public.v_teacher_quiz_results` row (0045) —
/// one flat, teacher-facing quiz result: a student's attempt at an
/// assessment, joined against section/quiz context. Read-only by
/// construction (there is no corresponding insert/update path — the view
/// is a read-only projection over `quiz_attempts`, and writes to that
/// table go through `QuizAttempt`/`QuizAttemptsRepository` instead, never
/// through this model).
///
/// Field nullability mirrors the view's own column nullability (0045):
/// `assessmentType`, `score`, `totalQuestions`, and `percentage` can all be
/// null (an ordinary non-assessment quiz has no `assessment_type`; an
/// attempt that hasn't been scored yet has no `score`/`total_questions`,
/// and `percentage` is `NULL` whenever the view's own
/// `nullif(total_questions, 0)` guard divides by nothing). `dateTaken` is
/// null for an attempt still in progress (`submitted_at is null`), which
/// is exactly the case `status` also reports as `QuizResultStatus.inProgress`.
class QuizResultRow {
  const QuizResultRow({
    required this.quizAttemptId,
    required this.studentName,
    required this.sectionId,
    required this.sectionName,
    required this.quizId,
    required this.assessmentName,
    this.assessmentType,
    this.score,
    this.totalQuestions,
    this.percentage,
    this.dateTaken,
    required this.status,
    required this.attemptStatus,
  });

  final String quizAttemptId;
  final String studentName;
  final String sectionId;
  final String sectionName;
  final String quizId;
  final String assessmentName;

  /// Null for ordinary (non Pre-Test/Post-Test) quizzes — mirrors
  /// `quizzes.assessment_type` (0043) exactly.
  final AssessmentType? assessmentType;

  final num? score;
  final int? totalQuestions;

  /// `round(100.0 * score / nullif(total_questions, 0), 1)` in the view —
  /// null whenever `totalQuestions` is null or zero, never a division
  /// error.
  final double? percentage;

  /// `quiz_attempts.submitted_at` — null while the attempt is still in
  /// progress.
  final DateTime? dateTaken;

  final QuizResultStatus status;

  /// Included for completeness even though the view itself already
  /// excludes `'superseded'` rows (0045) — every row reaching this model
  /// will always be `QuizAttemptStatus.active`, but the column is still
  /// selected on the view, so it's mirrored here (reusing the existing
  /// `QuizAttemptStatus` enum from `quiz_attempt.dart`) rather than
  /// silently dropped.
  final QuizAttemptStatus attemptStatus;

  factory QuizResultRow.fromJson(Map<String, dynamic> json) {
    return QuizResultRow(
      quizAttemptId: json['quiz_attempt_id'] as String,
      studentName: json['student_name'] as String,
      sectionId: json['section_id'] as String,
      sectionName: json['section_name'] as String,
      quizId: json['quiz_id'] as String,
      assessmentName: json['assessment_name'] as String,
      assessmentType: json['assessment_type'] == null
          ? null
          : AssessmentType.fromDb(json['assessment_type'] as String),
      score: json['score'] as num?,
      totalQuestions: json['total_questions'] as int?,
      percentage: (json['percentage'] as num?)?.toDouble(),
      dateTaken: json['date_taken'] == null ? null : DateTime.parse(json['date_taken'] as String),
      status: QuizResultStatus.fromDb(json['status'] as String),
      attemptStatus: QuizAttemptStatus.fromDb(json['attempt_status'] as String),
    );
  }
}
