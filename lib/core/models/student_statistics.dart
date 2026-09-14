/// Dart-side mirrors of the four read-only views added in
/// `0035_student_statistics_views.sql` (Phase 8, Part 1) — every field here
/// maps 1:1 to a view column, not to any underlying table directly. See
/// that migration for the exact business rules (rule numbers referenced
/// below) each view implements.
library;

/// One row from `v_student_summary_tiles` — the four summary tiles
/// (Lessons Completed, Average Quiz Score, Best Score, Endless Quiz High;
/// rules #3/#4/#5). Always exactly one row for the signed-in student (the
/// view is driven from their own `students` row via `LEFT JOIN LATERAL`,
/// so a student with zero completed quizzes/lessons still gets zeros/NULLs
/// here rather than no row at all — see the view's comment).
class StudentSummaryTiles {
  const StudentSummaryTiles({
    required this.studentId,
    required this.bestEndlessStreak,
    required this.lessonsTotal,
    required this.lessonsCompleted,
    required this.quizzesCompleted,
    this.averageScorePercent,
    this.bestScorePercent,
  });

  final String studentId;

  /// `students.best_endless_streak`, read directly (rule #5) — already
  /// trigger-maintained, no client-side computation involved.
  final int bestEndlessStreak;

  /// Count of the RLS-filtered lessons returned by the same provider as the
  /// Student Lessons screen — the denominator for "Lessons Completed".
  final int lessonsTotal;

  /// Subset of [lessonsTotal] whose IDs occur in this student's completed
  /// progress set.
  final int lessonsCompleted;

  /// Count of distinct quizzes with a "current" attempt (rule #2) — the
  /// sample size behind [averageScorePercent]/[bestScorePercent].
  final int quizzesCompleted;

  /// Unweighted average of each completed quiz's own `score_percent`, one
  /// vote per quiz regardless of question count (rule #3, see the
  /// migration header's "FLAGGED ASSUMPTION"). Null when
  /// [quizzesCompleted] is 0.
  final num? averageScorePercent;

  /// Highest `score_percent` across the student's "current" attempts (rule
  /// #3). Null when [quizzesCompleted] is 0.
  final num? bestScorePercent;

  factory StudentSummaryTiles.fromJson(Map<String, dynamic> json) {
    return StudentSummaryTiles(
      studentId: json['student_id'] as String,
      bestEndlessStreak: json['best_endless_streak'] as int,
      lessonsTotal: json['lessons_total'] as int,
      lessonsCompleted: json['lessons_completed'] as int,
      quizzesCompleted: json['quizzes_completed'] as int,
      averageScorePercent: json['average_score_percent'] as num?,
      bestScorePercent: json['best_score_percent'] as num?,
    );
  }

  StudentSummaryTiles withLessonCounts({
    required int total,
    required int completed,
  }) {
    return StudentSummaryTiles(
      studentId: studentId,
      bestEndlessStreak: bestEndlessStreak,
      lessonsTotal: total,
      lessonsCompleted: completed,
      quizzesCompleted: quizzesCompleted,
      averageScorePercent: averageScorePercent,
      bestScorePercent: bestScorePercent,
    );
  }
}

/// One row from `v_student_lesson_quiz_scores` — one entry in the "Quiz
/// Scores by Lesson" bar chart (rule #6). The view's `WHERE
/// l.linked_quiz_id IS NOT NULL` already guarantees every row here has a
/// linked quiz; lessons with no linked quiz never produce a row at all
/// (rule #6's "omit entirely" — there is no separate filtering step to do
/// on the Flutter side).
class LessonQuizScore {
  const LessonQuizScore({
    required this.lessonId,
    required this.lessonTitle,
    required this.quizId,
    this.quizAttemptId,
    this.score,
    this.totalQuestions,
    this.scorePercent,
    this.submittedAt,
  });

  final String lessonId;
  final String lessonTitle;

  /// Always non-null — the view's `WHERE` clause guarantees it (rule #6).
  final String quizId;

  /// Null when the student hasn't completed this lesson's linked quiz yet.
  final String? quizAttemptId;

  final num? score;
  final int? totalQuestions;

  /// Null means "not yet attempted" (distinct from a real 0%) — render as
  /// no-bar for this lesson, not a zero-height bar (matches the mockup's
  /// L3–L10 columns, and the view's own comment).
  final num? scorePercent;

  final DateTime? submittedAt;

  factory LessonQuizScore.fromJson(Map<String, dynamic> json) {
    return LessonQuizScore(
      lessonId: json['lesson_id'] as String,
      lessonTitle: json['lesson_title'] as String,
      quizId: json['quiz_id'] as String,
      quizAttemptId: json['quiz_attempt_id'] as String?,
      score: json['score'] as num?,
      totalQuestions: json['total_questions'] as int?,
      scorePercent: json['score_percent'] as num?,
      submittedAt:
          json['submitted_at'] == null
              ? null
              : DateTime.parse(json['submitted_at'] as String),
    );
  }
}

/// One row from `v_student_topic_mastery` — one bar in "Competency
/// Mastery" (rule #8, regular quizzes only). [topic] is
/// `question_bank.topic` used verbatim (rule #9) — even though seeded
/// values are full lesson titles rather than short labels, this is
/// deliberate; do not shorten/remap it anywhere in the UI either.
class TopicMastery {
  const TopicMastery({
    required this.topic,
    required this.questionsTotal,
    required this.questionsCorrect,
    required this.masteryPercent,
  });

  final String topic;
  final int questionsTotal;
  final int questionsCorrect;

  /// Never null in practice — the view only ever emits a row via `GROUP BY
  /// qb.topic`, so `questionsTotal` (the `nullif` denominator) is always
  /// at least 1 for every row that exists. Kept as `num` (not `int`) since
  /// the view rounds to one decimal place.
  final num masteryPercent;

  factory TopicMastery.fromJson(Map<String, dynamic> json) {
    return TopicMastery(
      topic: json['topic'] as String,
      questionsTotal: json['questions_total'] as int,
      questionsCorrect: json['questions_correct'] as int,
      masteryPercent: json['mastery_percent'] as num,
    );
  }
}

/// The single row from `v_student_overall_accuracy` — the "Overall
/// Accuracy" pie chart (rule #7, revised: regular quizzes only, Endless
/// Quiz excluded — see the migration header for why). Always exactly one
/// row for the signed-in student, same "always a row" shape as
/// [StudentSummaryTiles].
class OverallAccuracy {
  const OverallAccuracy({
    required this.studentId,
    required this.correct,
    required this.incorrect,
    this.accuracyPercent,
  });

  final String studentId;
  final int correct;
  final int incorrect;

  /// Null only when [correct] + [incorrect] == 0 (no regular-quiz answers
  /// yet) — the view's own `nullif` guard. Provided for convenience;
  /// re-derivable client-side from [correct]/[incorrect] if ever needed.
  final num? accuracyPercent;

  factory OverallAccuracy.fromJson(Map<String, dynamic> json) {
    return OverallAccuracy(
      studentId: json['student_id'] as String,
      correct: json['correct'] as int,
      incorrect: json['incorrect'] as int,
      accuracyPercent: json['accuracy_percent'] as num?,
    );
  }
}

/// The full statistics payload for one student — the four views' results
/// composed into a single object so the (Part 3) Statistics screen can
/// watch one provider instead of four. See
/// `StudentStatisticsRepository.fetchAll` / `studentStatisticsProvider`.
class StudentStatistics {
  const StudentStatistics({
    required this.summary,
    required this.lessonQuizScores,
    required this.competencyMastery,
    required this.overallAccuracy,
  });

  final StudentSummaryTiles summary;

  /// "Quiz Scores by Lesson" bar chart data, in the view's own order
  /// (`lessons.created_at` — see the migration's "FLAGGED ASSUMPTION" on
  /// lesson ordering; Part 3 may re-sort client-side).
  final List<LessonQuizScore> lessonQuizScores;

  /// "Competency Mastery" bars, one per topic (rule #8/#9). The view has
  /// no explicit `ORDER BY`, so Part 3 should apply whatever presentation
  /// order it wants (e.g. alphabetical, or descending by mastery).
  final List<TopicMastery> competencyMastery;

  final OverallAccuracy overallAccuracy;
}
