/// Dart-side mirrors of the four `public.dashboard_*` RPC wrapper row
/// shapes added in `0037_teacher_dashboard.sql` (Phase 9, Part 1) — every
/// field here maps 1:1 to a returned column, not to any underlying table
/// directly. See that migration (and its `0038` co-teacher follow-up fix,
/// which changes internal computation only, not these shapes) for the
/// exact business rules each function implements.
library;

import 'section.dart';

/// One row from `dashboard_summary_tiles` — the four summary tiles (Total
/// Sections, Total Students, Average Quiz Score, Students Needing
/// Intervention). Always exactly one row for any grade/section filter
/// combination the calling teacher is authorized to query (zero-scope
/// filters still return one row of zeros/NULLs, never no row at all — see
/// the function's own comment in 0037).
class DashboardSummaryTiles {
  const DashboardSummaryTiles({
    required this.totalSections,
    required this.totalStudents,
    required this.studentsNeedingIntervention,
    this.averageQuizScorePercent,
  });

  final int totalSections;
  final int totalStudents;

  /// Unweighted pool of `v_student_current_quiz_attempts.score_percent`
  /// (0035) across every in-scope student, one vote per completed quiz —
  /// see 0037's function comment. Null when no in-scope student has a
  /// completed quiz yet.
  final num? averageQuizScorePercent;

  /// Count of distinct students matching 0037's intervention rule:
  /// `average_score_percent < 70` (only when they have >= 1 completed
  /// quiz) OR `>= 2` missed/unfinished expected internal quizzes.
  /// External Activities are excluded from the missed/unfinished count
  /// entirely (no score to judge them by).
  final int studentsNeedingIntervention;

  factory DashboardSummaryTiles.fromJson(Map<String, dynamic> json) {
    return DashboardSummaryTiles(
      totalSections: json['total_sections'] as int,
      totalStudents: json['total_students'] as int,
      averageQuizScorePercent: json['average_quiz_score_percent'] as num?,
      studentsNeedingIntervention: json['students_needing_intervention'] as int,
    );
  }
}

/// One row from `dashboard_avg_score_by_section` — one bar in the
/// "Average per Section" chart. One row per section in scope, even a
/// section with zero actively-enrolled students (student_count = 0,
/// averageQuizScorePercent null in that case).
class SectionAverageScore {
  const SectionAverageScore({
    required this.sectionId,
    required this.sectionName,
    required this.gradeLevel,
    required this.studentCount,
    this.averageQuizScorePercent,
  });

  final String sectionId;
  final String sectionName;
  final GradeLevel gradeLevel;

  /// Distinct actively-enrolled students in this section
  /// (`student_enrollments.status = 'active'`), independent of whether
  /// they've completed any quiz.
  final int studentCount;

  /// Same pooled, one-vote-per-completed-quiz semantics as
  /// [DashboardSummaryTiles.averageQuizScorePercent], scoped to this one
  /// section. Null when the section has no completed quizzes yet.
  final num? averageQuizScorePercent;

  factory SectionAverageScore.fromJson(Map<String, dynamic> json) {
    return SectionAverageScore(
      sectionId: json['section_id'] as String,
      sectionName: json['section_name'] as String,
      gradeLevel: GradeLevel.fromDb(json['grade_level'] as String),
      averageQuizScorePercent: json['average_quiz_score_percent'] as num?,
      studentCount: json['student_count'] as int,
    );
  }
}

/// One row from `dashboard_student_roster` — one row in the drill-down
/// table. One row per actively-enrolled student in scope.
class DashboardRosterEntry {
  const DashboardRosterEntry({
    required this.studentId,
    required this.fullName,
    required this.sectionId,
    required this.sectionName,
    required this.quizzesCompleted,
    required this.missedOrUnfinishedCount,
    required this.needsIntervention,
    this.averageQuizScorePercent,
  });

  final String studentId;
  final String fullName;
  final String sectionId;
  final String sectionName;

  /// Same pooled-per-student semantics as the other two views' average
  /// columns. Null when this student has zero completed quizzes.
  final num? averageQuizScorePercent;

  final int quizzesCompleted;

  /// Count of this student's own expected internal quizzes (built-in,
  /// grade-matched, UNION teacher-created ones assigned to their section —
  /// see 0037/0038) that are either missed (no attempt at all) or
  /// unfinished (an `active` attempt with `submitted_at IS NULL`).
  /// External Activities are never counted here.
  final int missedOrUnfinishedCount;

  /// The identical rule as [DashboardSummaryTiles.studentsNeedingIntervention],
  /// computed per-student rather than pooled: `averageQuizScorePercent`
  /// not null and `< 70`, OR `missedOrUnfinishedCount >= 2`.
  final bool needsIntervention;

  factory DashboardRosterEntry.fromJson(Map<String, dynamic> json) {
    return DashboardRosterEntry(
      studentId: json['student_id'] as String,
      fullName: json['full_name'] as String,
      sectionId: json['section_id'] as String,
      sectionName: json['section_name'] as String,
      averageQuizScorePercent: json['average_quiz_score_percent'] as num?,
      quizzesCompleted: json['quizzes_completed'] as int,
      missedOrUnfinishedCount: json['missed_or_unfinished_count'] as int,
      needsIntervention: json['needs_intervention'] as bool,
    );
  }
}

/// One row from `dashboard_competency_mastery` — one bar in the teacher-
/// scoped "Competency Mastery" chart. Same shape/semantics as the
/// student-scoped `TopicMastery` in `student_statistics.dart` (0035's
/// `v_student_topic_mastery`) — this is the identical concept, teacher-
/// scoped across their own sections' students instead of one student, so
/// the field naming deliberately matches that class rather than inventing
/// divergent names for the same idea. [topic] is `question_bank.topic`
/// used verbatim, regular quizzes only (Endless Quiz excluded — no
/// per-question table exists for it, same reasoning as 0035).
class TopicMasteryEntry {
  const TopicMasteryEntry({
    required this.topic,
    required this.questionsTotal,
    required this.questionsCorrect,
    required this.masteryPercent,
  });

  final String topic;
  final int questionsTotal;
  final int questionsCorrect;

  /// Never null in practice — the function only ever emits a row via
  /// `GROUP BY topic`, so `questionsTotal` (the `nullif` denominator) is
  /// always at least 1 for every row that exists. Kept as `num` (not
  /// `int`) since the function rounds to one decimal place.
  final num masteryPercent;

  factory TopicMasteryEntry.fromJson(Map<String, dynamic> json) {
    return TopicMasteryEntry(
      topic: json['topic'] as String,
      questionsTotal: json['questions_total'] as int,
      questionsCorrect: json['questions_correct'] as int,
      masteryPercent: json['mastery_percent'] as num,
    );
  }
}

/// One row from `dashboard_student_topic_mastery` (0046, Teacher Progress
/// Reports, Part 1) — one cell in the per-student x per-topic mastery
/// heatmap. One row per (student, topic) combination the student has at
/// least one answered question for — same "only rows that exist, `GROUP
/// BY`" shape as [TopicMasteryEntry], just widened by
/// `(student_id, full_name, section_id, section_name)`. Regular quizzes
/// only (Endless Quiz excluded — no per-question table, same reasoning as
/// [TopicMasteryEntry] and 0035's `v_student_topic_mastery`). Full roster,
/// not averaged or top/bottom-N — a student with zero answered questions
/// for a given topic simply has no row for that (student, topic) pair,
/// which the heatmap UI (Part 3) is expected to render as "no data" rather
/// than as a zero.
class StudentTopicMasteryEntry {
  const StudentTopicMasteryEntry({
    required this.studentId,
    required this.fullName,
    required this.sectionId,
    required this.sectionName,
    required this.topic,
    required this.questionsTotal,
    required this.questionsCorrect,
    required this.masteryPercent,
  });

  final String studentId;
  final String fullName;
  final String sectionId;
  final String sectionName;
  final String topic;
  final int questionsTotal;
  final int questionsCorrect;

  /// Never null in practice — same reasoning as
  /// [TopicMasteryEntry.masteryPercent]: the function only ever emits a
  /// row via `GROUP BY student_id, full_name, section_id, section_name,
  /// topic`, so `questionsTotal` (the `nullif` denominator) is always at
  /// least 1 for every row that exists. Kept as `num` (not `int`) since
  /// the function rounds to one decimal place.
  final num masteryPercent;

  factory StudentTopicMasteryEntry.fromJson(Map<String, dynamic> json) {
    return StudentTopicMasteryEntry(
      studentId: json['student_id'] as String,
      fullName: json['full_name'] as String,
      sectionId: json['section_id'] as String,
      sectionName: json['section_name'] as String,
      topic: json['topic'] as String,
      questionsTotal: json['questions_total'] as int,
      questionsCorrect: json['questions_correct'] as int,
      masteryPercent: json['mastery_percent'] as num,
    );
  }
}

/// One row from `dashboard_intervention_students` (0047) — the drill-down
/// feed shared by the Teacher Dashboard's "Students Needing Help" tile
/// (0037) and the Teacher Progress Reports' "Students Requiring
/// Intervention" tile (0046), so a teacher sees the same Grade Level ->
/// Section -> Student grouping from either entry point. Only students
/// matching the intervention rule are included (no full-roster mode,
/// unlike [DashboardRosterEntry]); [gradeLevel] lets the client group by
/// grade without a second fetch or query shape.
class TeacherInterventionStudent {
  const TeacherInterventionStudent({
    required this.studentId,
    required this.fullName,
    required this.gradeLevel,
    required this.sectionId,
    required this.sectionName,
    required this.missedOrUnfinishedCount,
    this.averageQuizScorePercent,
  });

  final String studentId;
  final String fullName;
  final GradeLevel gradeLevel;
  final String sectionId;
  final String sectionName;

  /// Null when the student has zero completed quizzes yet — they are
  /// still included here if [missedOrUnfinishedCount] alone is >= 2.
  final num? averageQuizScorePercent;
  final int missedOrUnfinishedCount;

  factory TeacherInterventionStudent.fromJson(Map<String, dynamic> json) {
    return TeacherInterventionStudent(
      studentId: json['student_id'] as String,
      fullName: json['full_name'] as String,
      gradeLevel: GradeLevel.fromDb(json['grade_level'] as String),
      sectionId: json['section_id'] as String,
      sectionName: json['section_name'] as String,
      averageQuizScorePercent: json['average_quiz_score_percent'] as num?,
      missedOrUnfinishedCount: json['missed_or_unfinished_count'] as int,
    );
  }
}

/// Client-side classification of a `masteryPercent` value into the three
/// bands the Progress Reports feature displays (heatmap cell color,
/// legend, "Most Difficult"/"Highest Mastered" cards). Deliberately not a
/// database concept — Part 1's RPC returns raw `mastery_percent` only, no
/// band/label column (locked product decision) — so classification lives
/// entirely here as a pure function of the already-fetched number. There
/// is no `MasteryBand` case for "no data" on purpose: a `null`
/// `masteryPercent` (or the total absence of a row for a given
/// student/topic pair) is a distinct state from any band and must be
/// handled explicitly by the caller (see `masteryBandFor` in
/// `progress_report_providers.dart`, which returns `null` rather than
/// inventing a fourth enum case for it).
enum MasteryBand {
  needsSupport,
  proficient,
  mastered;

  /// User-facing label for legends, chips, and the heatmap cell tooltip.
  String get displayLabel => switch (this) {
        MasteryBand.needsSupport => 'Needs Support',
        MasteryBand.proficient => 'Proficient',
        MasteryBand.mastered => 'Mastered',
      };
}
