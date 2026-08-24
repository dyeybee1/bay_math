import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/student_statistics.dart';

/// Phase 8 (Student Statistics) — Connection A only. Every method here is a
/// plain PostgREST read over one of the four `security_invoker` views added
/// in `0035_student_statistics_views.sql`, issued through the student's own
/// forwarded JWT (the client passed in, from `studentScopedClientProvider`).
/// No Edge Function / `service_role` call is involved anywhere in this
/// class — RLS on the underlying tables (`quiz_attempts`, `students`, etc.,
/// 0015 + 0035's Part 0 addition) already permits every read these views
/// need, exactly like `QuizAttemptsRepository`'s reads during quiz-taking.
///
/// Each view is guaranteed by its own definition to return either exactly
/// one row (`v_student_summary_tiles`, `v_student_overall_accuracy` — both
/// driven from the student's own `students` row via `LEFT JOIN LATERAL`) or
/// a list that may legitimately be empty (`v_student_lesson_quiz_scores`,
/// `v_student_topic_mastery` — e.g. a brand-new student with no linked-quiz
/// lessons or no completed quizzes yet). `.single()` is used only for the
/// former; the "always a row" guarantee is a property of the views
/// themselves, not re-derived here.
class StudentStatisticsRepository {
  const StudentStatisticsRepository(this._client);

  final SupabaseClient _client;

  /// The four summary tiles (rules #3/#4/#5) — one row.
  Future<StudentSummaryTiles> fetchSummaryTiles() async {
    try {
      final Map<String, dynamic> row =
          await _client.from('v_student_summary_tiles').select().single();
      return StudentSummaryTiles.fromJson(row);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// "Quiz Scores by Lesson" bar chart data (rule #6) — one row per
  /// lesson-with-a-linked-quiz; lessons without one never appear (already
  /// enforced by the view's own `WHERE`, not filtered again here). Already
  /// ordered by the view (`lessons.created_at`), so no `.order()` call is
  /// added on top of it.
  Future<List<LessonQuizScore>> fetchLessonQuizScores() async {
    try {
      final List<Map<String, dynamic>> rows =
          await _client.from('v_student_lesson_quiz_scores').select();
      return rows.map(LessonQuizScore.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// "Competency Mastery" per-topic bars (rules #8/#9) — regular quizzes
  /// only, one row per topic. The view has no `ORDER BY`; Part 3 decides
  /// presentation order.
  Future<List<TopicMastery>> fetchTopicMastery() async {
    try {
      final List<Map<String, dynamic>> rows =
          await _client.from('v_student_topic_mastery').select();
      return rows.map(TopicMastery.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// "Overall Accuracy" pie chart data (rule #7, revised) — one row.
  Future<OverallAccuracy> fetchOverallAccuracy() async {
    try {
      final Map<String, dynamic> row =
          await _client.from('v_student_overall_accuracy').select().single();
      return OverallAccuracy.fromJson(row);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Fetches all four views and composes them into one [StudentStatistics]
  /// — what the (Part 3) Statistics screen actually watches, via
  /// `studentStatisticsProvider`, so it deals with a single `AsyncValue`
  /// instead of four. The four requests are independent reads with no
  /// ordering dependency between them, so they're kicked off together and
  /// awaited afterward rather than sequentially.
  Future<StudentStatistics> fetchAll() async {
    try {
      final Future<StudentSummaryTiles> summaryFuture = fetchSummaryTiles();
      final Future<List<LessonQuizScore>> lessonQuizScoresFuture = fetchLessonQuizScores();
      final Future<List<TopicMastery>> topicMasteryFuture = fetchTopicMastery();
      final Future<OverallAccuracy> overallAccuracyFuture = fetchOverallAccuracy();

      return StudentStatistics(
        summary: await summaryFuture,
        lessonQuizScores: await lessonQuizScoresFuture,
        competencyMastery: await topicMasteryFuture,
        overallAccuracy: await overallAccuracyFuture,
      );
    } catch (error) {
      // Already an AppFailure if it came from one of the four methods
      // above (mapExceptionToFailure passes AppFailures through
      // unchanged) — this catch only matters if composing the record
      // itself somehow throws.
      throw mapExceptionToFailure(error);
    }
  }
}
