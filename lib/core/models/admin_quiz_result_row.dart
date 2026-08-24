import 'quiz.dart';
import 'section.dart' show GradeLevel;

/// Mirrors the `status` column computed by `public.admin_quiz_results`
/// (0051) — `case when percentage >= 70 then 'passed' when percentage < 70
/// then 'needs_improvement' else null end`, applied to every row that view
/// already restricts to completed (`submitted_at is not null`), internal-
/// quiz, non-superseded attempts. Not a Postgres enum (it's a plain `text`
/// CASE expression in the view, same situation as [QuizResultStatus] for
/// 0045), modeled as one here for the same reason: so the UI switches on a
/// closed Dart type instead of comparing raw strings.
enum AdminQuizResultStatus {
  passed,
  needsImprovement;

  static AdminQuizResultStatus fromDb(String value) => switch (value) {
        'passed' => AdminQuizResultStatus.passed,
        'needs_improvement' => AdminQuizResultStatus.needsImprovement,
        _ => throw ArgumentError('Unknown status value: $value'),
      };

  String get label => switch (this) {
        AdminQuizResultStatus.passed => 'Passed',
        AdminQuizResultStatus.needsImprovement => 'Needs Improvement',
      };
}

/// The Admin Quiz Results screen's Assessment Type filter — the same
/// Pre-Test / Post-Test / Regular three-way mapping
/// `QuizResultsAssessmentFilter` (`teacher_quiz_results_providers.dart`)
/// already uses (`regular` = `quizzes.assessment_type IS NULL`, 0043),
/// PLUS a fourth [all] state this feature's filter row needs but the
/// Teacher screen's matrix selector never did (that screen has no
/// "All ___" catch-all — see its own doc comment; a matrix has no meaning
/// until both a section AND a specific assessment type are chosen). Kept
/// as its own type rather than reusing `QuizResultsAssessmentFilter`
/// directly, since widening that enum with an [all] case would change its
/// meaning for the screen that already relies on it having none.
///
/// [toRpcParam] is the single place this enum's mapping to
/// `admin_quiz_results`'s `p_assessment_type_filter` text parameter (0051)
/// lives, so the repository call site and this enum's own cases can't
/// silently drift apart.
enum AdminQuizResultsAssessmentTypeFilter {
  all,
  preTest,
  postTest,
  regular;

  String get label => switch (this) {
        AdminQuizResultsAssessmentTypeFilter.all => 'All Types',
        AdminQuizResultsAssessmentTypeFilter.preTest => 'Pre-Test',
        AdminQuizResultsAssessmentTypeFilter.postTest => 'Post-Test',
        AdminQuizResultsAssessmentTypeFilter.regular => 'Regular Quiz',
      };

  /// `null` for [all] — `admin_quiz_results`'s own convention (0051) for
  /// "no filter, every assessment type included" is a `null`
  /// `p_assessment_type_filter` argument, not a fourth enum value on the
  /// Postgres side (that enum only has two real values, `pre_test`/
  /// `post_test` — see 0051's own comment on why `regular` and "no
  /// filter" are both necessarily represented outside it).
  String? toRpcParam() => switch (this) {
        AdminQuizResultsAssessmentTypeFilter.all => null,
        AdminQuizResultsAssessmentTypeFilter.preTest => 'pre_test',
        AdminQuizResultsAssessmentTypeFilter.postTest => 'post_test',
        AdminQuizResultsAssessmentTypeFilter.regular => 'regular',
      };
}

/// A Dart-side mirror of one `public.admin_quiz_results(...)` row (0051) —
/// one flat, admin-facing quiz result: a student's completed Internal Quiz
/// attempt, joined against section/assessment context, school-wide (not
/// scoped to a single teacher's sections the way `QuizResultRow`/0045 is).
/// Read-only by construction — there is no insert/update path through this
/// model, the same reasoning `QuizResultRow`'s own doc comment gives for
/// itself.
///
/// Field nullability mirrors `app.v_admin_quiz_results_rows`' own column
/// nullability (0051), NOT `QuizResultRow`'s (0045) — the two views differ
/// in what they can return:
///  - [dateTaken] is required (non-null) here, unlike
///    `QuizResultRow.dateTaken` — `admin_quiz_results` only ever returns
///    completed attempts (`submitted_at is not null` is baked into view 1
///    of 0051), so there is no "in progress" row shape to represent at
///    all, unlike 0045's view which includes both.
///  - [assessmentType], [score], [totalQuestions], and [percentage] can
///    all be null for the same reasons `QuizResultRow`'s equivalents can:
///    an ordinary (non Pre-Test/Post-Test) quiz has no `assessment_type`,
///    and `percentage` is null whenever the view's own
///    `nullif(total_questions, 0)` guard divides by nothing.
///  - [status] can be null too — 0051's own view comment flags this as an
///    edge case (only possible if [percentage] itself is null on an
///    otherwise-qualifying row, not expected in practice for a completed
///    Internal Quiz attempt, but guarded rather than assumed on the SQL
///    side, and mirrored here rather than force-unwrapped).
///
/// There is no `attemptStatus` field the way `QuizResultRow` carries one
/// (0045) — `admin_quiz_results` never selects that column at all (0051
/// filters `attempt_status <> 'superseded'` internally, in view 1, and
/// does not expose the surviving value), so there is nothing to mirror.
class AdminQuizResultRow {
  const AdminQuizResultRow({
    required this.quizAttemptId,
    required this.studentName,
    required this.sectionId,
    required this.sectionName,
    required this.gradeLevel,
    required this.quizId,
    required this.assessmentName,
    this.assessmentType,
    this.score,
    this.totalQuestions,
    this.percentage,
    required this.dateTaken,
    this.status,
  });

  final String quizAttemptId;
  final String studentName;
  final String sectionId;
  final String sectionName;

  /// The HISTORICAL section's grade level (`sections.grade_level` via the
  /// frozen `quiz_attempts.section_id`, 0010) — the section the student
  /// was actually in when they took the quiz, not their current
  /// enrollment. Same source 0045's `v_teacher_quiz_results` uses.
  final GradeLevel gradeLevel;

  final String quizId;
  final String assessmentName;

  /// Null for ordinary (non Pre-Test/Post-Test) quizzes — mirrors
  /// `quizzes.assessment_type` (0043) exactly.
  final AssessmentType? assessmentType;

  final num? score;
  final int? totalQuestions;

  /// `round(100.0 * score / nullif(total_questions, 0), 1)` in the view —
  /// null whenever [totalQuestions] is null or zero, never a division
  /// error.
  final double? percentage;

  /// `quiz_attempts.submitted_at` — always present here, unlike
  /// `QuizResultRow.dateTaken` (0045), because `admin_quiz_results` only
  /// ever returns completed attempts (`submitted_at is not null` is
  /// enforced upstream in 0051's view 1).
  final DateTime dateTaken;

  /// 'Passed' (>= 70%) / 'Needs Improvement' (< 70%) — null only in the
  /// edge case [percentage] itself is null (see this class's own doc
  /// comment).
  final AdminQuizResultStatus? status;

  factory AdminQuizResultRow.fromJson(Map<String, dynamic> json) {
    return AdminQuizResultRow(
      quizAttemptId: json['quiz_attempt_id'] as String,
      studentName: json['student_name'] as String,
      sectionId: json['section_id'] as String,
      sectionName: json['section_name'] as String,
      gradeLevel: GradeLevel.fromDb(json['grade_level'] as String),
      quizId: json['quiz_id'] as String,
      assessmentName: json['assessment_name'] as String,
      assessmentType: json['assessment_type'] == null
          ? null
          : AssessmentType.fromDb(json['assessment_type'] as String),
      score: json['score'] as num?,
      totalQuestions: json['total_questions'] as int?,
      percentage: (json['percentage'] as num?)?.toDouble(),
      dateTaken: DateTime.parse(json['date_taken'] as String),
      status: json['status'] == null
          ? null
          : AdminQuizResultStatus.fromDb(json['status'] as String),
    );
  }
}

/// One row from `admin_quiz_results_school_years` (0051) — an entry for
/// the Quiz Results screen's School Year filter dropdown. The dropdown's
/// own "All Time" option is a UI-only sentinel (a `null` `schoolYearId` in
/// the filter selection, matching 0051's own `p_school_year_id` NULL =
/// "All Time" convention) and is never represented by an instance of this
/// class — every [AdminSchoolYearOption] is a real `school_years` row.
class AdminSchoolYearOption {
  const AdminSchoolYearOption({
    required this.schoolYearId,
    required this.label,
    required this.isCurrent,
  });

  final String schoolYearId;
  final String label;
  final bool isCurrent;

  factory AdminSchoolYearOption.fromJson(Map<String, dynamic> json) {
    return AdminSchoolYearOption(
      schoolYearId: json['school_year_id'] as String,
      label: json['label'] as String,
      isCurrent: json['is_current'] as bool,
    );
  }
}
