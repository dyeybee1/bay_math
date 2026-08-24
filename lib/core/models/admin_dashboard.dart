/// Dart-side mirrors of the three `public.admin_dashboard_*` RPC wrapper row
/// shapes added in `0039_admin_dashboard.sql` — every field here maps 1:1
/// to a returned column, not to any underlying table directly. See that
/// migration for the exact business rules each function implements.
///
/// Two rules apply across all three models below, enforced entirely on the
/// SQL side (0039) and just reflected here in field nullability/shape:
///  - RETAKES: every score-based figure is built from each student's own
///    latest-SUBMITTED attempt per quiz (`app.v_admin_current_quiz_attempts`)
///    — never a pooled average across every submitted attempt, never the
///    highest score. [AdminSummaryTiles.totalQuizAttempts] is the one
///    exception: a raw completed-attempt count that intentionally includes
///    superseded retakes, because it answers "how many completed attempts
///    happened", not "how did students score".
///  - ARCHIVED SECTIONS: every score-based figure only counts a student who
///    currently holds an active enrollment in a current-school-year,
///    `status = 'active'` section (`app.v_admin_active_students`). A student
///    whose only enrollment is archived contributes to none of them, even
///    if they have completed attempts on record.
library;

import 'section.dart';

/// One row from `admin_dashboard_teachers_list` (0041) — the Total
/// Teachers tile's drill-down list. One row per approved teacher.
class AdminTeacherListEntry {
  const AdminTeacherListEntry({
    required this.teacherId,
    required this.fullName,
    required this.email,
    required this.sectionCount,
  });

  final String teacherId;
  final String fullName;
  final String email;

  /// Current-school-year, `status = 'active'` section assignments only.
  final int sectionCount;

  factory AdminTeacherListEntry.fromJson(Map<String, dynamic> json) {
    return AdminTeacherListEntry(
      teacherId: json['teacher_id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      sectionCount: json['section_count'] as int,
    );
  }
}

/// One row from `admin_dashboard_sections_list` (0041) — the Total
/// Sections tile's drill-down list. One row per current-school-year,
/// `status = 'active'` section — sections only, no per-student rows.
class AdminSectionListEntry {
  const AdminSectionListEntry({
    required this.sectionId,
    required this.sectionName,
    required this.gradeLevel,
    required this.primaryTeacherName,
    required this.studentCount,
  });

  final String sectionId;
  final String sectionName;
  final GradeLevel gradeLevel;

  /// 'Unassigned' when the section has no `is_primary = true`
  /// `teacher_sections` row yet.
  final String primaryTeacherName;
  final int studentCount;

  factory AdminSectionListEntry.fromJson(Map<String, dynamic> json) {
    return AdminSectionListEntry(
      sectionId: json['section_id'] as String,
      sectionName: json['section_name'] as String,
      gradeLevel: GradeLevel.fromDb(json['grade_level'] as String),
      primaryTeacherName: json['primary_teacher_name'] as String,
      studentCount: json['student_count'] as int,
    );
  }
}

/// One row from `admin_dashboard_quiz_attempts_by_grade` (0041) — level 1
/// of the Total Quiz Attempts tile's drill-down. Always one row per
/// [GradeLevel] value.
class GradeQuizAttempts {
  const GradeQuizAttempts({
    required this.gradeLevel,
    required this.totalQuizAttempts,
  });

  final GradeLevel gradeLevel;

  /// Every completed attempt (including superseded retakes) whose own
  /// frozen `section_id` (0010) falls in this grade — same population the
  /// Total Quiz Attempts tile itself counts.
  final int totalQuizAttempts;

  factory GradeQuizAttempts.fromJson(Map<String, dynamic> json) {
    return GradeQuizAttempts(
      gradeLevel: GradeLevel.fromDb(json['grade_level'] as String),
      totalQuizAttempts: json['total_quiz_attempts'] as int,
    );
  }
}

/// One row from `admin_dashboard_quiz_attempts_by_section` (0041) — level
/// 2 of the Total Quiz Attempts tile's drill-down, reached by tapping one
/// [GradeQuizAttempts] row. One row per current-school-year,
/// `status = 'active'` section in that grade, including sections with
/// zero attempts.
class SectionQuizAttempts {
  const SectionQuizAttempts({
    required this.sectionId,
    required this.sectionName,
    required this.totalQuizAttempts,
  });

  final String sectionId;
  final String sectionName;
  final int totalQuizAttempts;

  factory SectionQuizAttempts.fromJson(Map<String, dynamic> json) {
    return SectionQuizAttempts(
      sectionId: json['section_id'] as String,
      sectionName: json['section_name'] as String,
      totalQuizAttempts: json['total_quiz_attempts'] as int,
    );
  }
}

/// One row from `admin_dashboard_score_by_section` (0041) — level 2 of the
/// Average Mathematics Score tile's drill-down, reached by tapping one
/// [GradeLevelAverageScore] row (level 1 is the existing
/// `admin_dashboard_score_by_grade`, unchanged). One row per
/// current-school-year, `status = 'active'` section in that grade,
/// including sections with zero qualifying students.
class AdminSectionAverageScore {
  const AdminSectionAverageScore({
    required this.sectionId,
    required this.sectionName,
    required this.studentCount,
    this.averageScorePercent,
  });

  final String sectionId;
  final String sectionName;

  /// Average of each qualifying student's own average score, one vote per
  /// student. Null when no student in this section currently qualifies.
  final num? averageScorePercent;
  final int studentCount;

  factory AdminSectionAverageScore.fromJson(Map<String, dynamic> json) {
    return AdminSectionAverageScore(
      sectionId: json['section_id'] as String,
      sectionName: json['section_name'] as String,
      averageScorePercent: json['average_score_percent'] as num?,
      studentCount: json['student_count'] as int,
    );
  }
}

/// One row from `admin_dashboard_intervention_students` (0041) — the
/// Students Requiring Intervention tile's drill-down list. One row per
/// currently-active student matching the identical rule
/// [AdminSummaryTiles.studentsRequiringIntervention] counts, so this
/// list's length always equals that tile's number.
class AdminInterventionStudent {
  const AdminInterventionStudent({
    required this.studentId,
    required this.fullName,
    required this.gradeLevel,
    required this.sectionName,
    required this.missedOrUnfinishedCount,
    this.averageScorePercent,
  });

  final String studentId;
  final String fullName;

  /// Added 0042 — the student's current grade level, so the client can
  /// group this flat list as Grade Level -> Section -> Student instead of
  /// surfacing names directly.
  final GradeLevel gradeLevel;
  final String sectionName;

  /// Null when the student has zero completed attempts yet — they are
  /// still included here if [missedOrUnfinishedCount] alone is >= 2.
  final num? averageScorePercent;
  final int missedOrUnfinishedCount;

  factory AdminInterventionStudent.fromJson(Map<String, dynamic> json) {
    return AdminInterventionStudent(
      studentId: json['student_id'] as String,
      fullName: json['full_name'] as String,
      gradeLevel: GradeLevel.fromDb(json['grade_level'] as String),
      sectionName: json['section_name'] as String,
      averageScorePercent: json['average_score_percent'] as num?,
      missedOrUnfinishedCount: json['missed_or_unfinished_count'] as int,
    );
  }
}

/// One row from `admin_dashboard_summary_tiles` — the 6 stat cards (Total
/// Students, Total Teachers, Total Sections, Total Quiz Attempts, Average
/// Mathematics Score, Students Requiring Intervention). Always exactly one
/// row.
class AdminSummaryTiles {
  const AdminSummaryTiles({
    required this.totalStudents,
    required this.totalTeachers,
    required this.totalSections,
    required this.totalQuizAttempts,
    required this.studentsRequiringIntervention,
    this.averageScore,
  });

  /// Count of `app.v_admin_active_students` — students with a currently
  /// active enrollment in a current-school-year, `status = 'active'`
  /// section. A student whose only enrollment is archived does not count.
  final int totalStudents;

  /// Approved teachers (`profiles.role = 'teacher'`, `status = 'approved'`),
  /// deliberately NOT scoped to the current school year — see 0039.
  final int totalTeachers;

  /// Current-school-year sections with `status = 'active'` only.
  final int totalSections;

  /// Raw count of completed (`submitted_at is not null`) regular-quiz
  /// attempts in the current school year(s) — includes superseded retake
  /// attempts by design. NOT filtered by [totalStudents]'s active-student
  /// scope; a completed attempt still counts even if that student's
  /// enrollment has since changed. The one metric in this class that is an
  /// activity count rather than a per-student-average aggregate.
  final int totalQuizAttempts;

  /// Average, across every currently-active student with >= 1 completed
  /// attempt, of that student's own average `score_percent` across their
  /// own current (deduped, retake-resolved) attempts — one vote per
  /// student, never a pooled per-attempt average. Null when no currently
  /// active student has a completed attempt yet.
  final num? averageScore;

  /// Count of currently-active students (app.v_admin_active_students) with
  /// EITHER their own average score below 70 OR >= 2 missed/unfinished
  /// expected internal quizzes (0040) — matches the Teacher Dashboard's
  /// (0037) intervention rule on both criteria.
  final int studentsRequiringIntervention;

  factory AdminSummaryTiles.fromJson(Map<String, dynamic> json) {
    return AdminSummaryTiles(
      totalStudents: json['total_students'] as int,
      totalTeachers: json['total_teachers'] as int,
      totalSections: json['total_sections'] as int,
      totalQuizAttempts: json['total_quiz_attempts'] as int,
      averageScore: json['average_mathematics_score'] as num?,
      studentsRequiringIntervention:
          json['students_requiring_intervention'] as int,
    );
  }
}

/// One row from `admin_dashboard_score_by_grade` — one bar in the "Average
/// Score by Grade Level" chart. Always one row per [GradeLevel] value
/// (grade_4/grade_5/grade_6), even a grade with zero qualifying students
/// (in which case [studentCount] is 0 and [averageScore] is null) — the
/// function never omits a grade.
class GradeLevelAverageScore {
  const GradeLevelAverageScore({
    required this.gradeLevel,
    required this.studentCount,
    this.averageScore,
  });

  final GradeLevel gradeLevel;

  /// Average of each qualifying student's own average score, one vote per
  /// student. A qualifying student is currently-active
  /// (`app.v_admin_active_students`) AND currently enrolled in a section
  /// of this [gradeLevel] AND has >= 1 completed attempt. Null when no
  /// student qualifies for this grade.
  final num? averageScore;

  /// Distinct qualifying-student count backing [averageScore] — not an
  /// attempt count.
  final int studentCount;

  factory GradeLevelAverageScore.fromJson(Map<String, dynamic> json) {
    return GradeLevelAverageScore(
      gradeLevel: GradeLevel.fromDb(json['grade_level'] as String),
      averageScore: json['average_score_percent'] as num?,
      studentCount: json['student_count'] as int,
    );
  }
}

/// Mirrors the four bucket labels `admin_dashboard_proficiency_distribution`
/// (0039) returns verbatim in its `bucket` column — the db string IS the
/// display label already, so [toDb] and [label] intentionally return the
/// same text (unlike [GradeLevel], which maps a snake_case db value to a
/// separately-worded display label).
enum ProficiencyBucket {
  advanced,
  proficient,
  approachingProficiency,
  belowBasic;

  static ProficiencyBucket fromDb(String value) => switch (value) {
        'Advanced' => ProficiencyBucket.advanced,
        'Proficient' => ProficiencyBucket.proficient,
        'Approaching Proficiency' => ProficiencyBucket.approachingProficiency,
        'Below Basic' => ProficiencyBucket.belowBasic,
        _ => throw ArgumentError('Unknown proficiency bucket value: $value'),
      };

  String toDb() => switch (this) {
        ProficiencyBucket.advanced => 'Advanced',
        ProficiencyBucket.proficient => 'Proficient',
        ProficiencyBucket.approachingProficiency => 'Approaching Proficiency',
        ProficiencyBucket.belowBasic => 'Below Basic',
      };

  /// User-facing label for the pie chart legend/slices — identical text to
  /// [toDb] since the SQL bucket labels are already display-ready.
  String get label => toDb();
}

/// One row from `admin_dashboard_proficiency_distribution` — one slice of
/// the "Proficiency Distribution" pie chart. Unlike
/// [GradeLevelAverageScore], a bucket with zero students has NO row at
/// all (per 0039's function comment) — a missing slice, not an empty one.
class ProficiencyDistribution {
  const ProficiencyDistribution({
    required this.bucket,
    required this.studentCount,
    required this.percent,
  });

  final ProficiencyBucket bucket;

  /// Count of currently-active students (`app.v_admin_active_students`)
  /// with >= 1 completed attempt whose own average score falls in this
  /// bucket: Advanced 90-100, Proficient 75-89, Approaching Proficiency
  /// 60-74, Below Basic <60.
  final int studentCount;

  /// [studentCount] as a percentage of the total currently-active,
  /// >= 1-completed-attempt student count (i.e. the sum of every bucket's
  /// [studentCount] across all rows this call returns) — NOT a percentage
  /// of [AdminSummaryTiles.totalStudents]. A student with zero completed
  /// attempts, or who is not currently active, is excluded from both the
  /// numerator and the denominator, so this never appears as a row with a
  /// null percent.
  final num percent;

  factory ProficiencyDistribution.fromJson(Map<String, dynamic> json) {
    return ProficiencyDistribution(
      bucket: ProficiencyBucket.fromDb(json['bucket'] as String),
      studentCount: json['student_count'] as int,
      percent: json['percent'] as num,
    );
  }
}
