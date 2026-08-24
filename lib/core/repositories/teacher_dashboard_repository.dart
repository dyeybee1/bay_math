import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/section.dart';
import '../models/teacher_dashboard.dart';

/// Phase 9 (Teacher Dashboard) — Connection A only. Every method here is a
/// plain `.rpc()` call against one of the four `public.dashboard_*`
/// pass-through wrappers added in `0037_teacher_dashboard.sql`, issued
/// through the calling teacher's own Supabase Auth session (the client
/// passed in, from `supabaseClientProvider` — see
/// `teacherDashboardRepositoryProvider` in `supabase_providers.dart`). No
/// Edge Function / `service_role` call is involved anywhere in this class,
/// exactly like `EndlessQuizRepository.fetchLeaderboardTop`/`fetchMyRank`
/// (0036) and `QuizAttemptsRepository.resolveSchoolYearId` (0023) — the
/// only two existing `.rpc()` precedents in this codebase, both followed
/// below. `0038`'s `app.section_expected_internal_quiz_ids` helper is not
/// referenced anywhere in this file — it has no `public.*` wrapper and is
/// only ever called from inside the four `0037` functions' own SQL
/// bodies, never from Flutter.
///
/// Deliberately NO `fetchAll()` composing method here, unlike
/// `StudentStatisticsRepository.fetchAll()`. That composition made sense
/// there because every tile/chart on the Student Statistics screen loads
/// together as one unit. This dashboard is different by design (Part 3/4):
/// the summary tiles load first and independently, the "Average per
/// Section" chart is a separate panel that can load (and fail, and be
/// refreshed) on its own, and the roster/competency-mastery drill-downs
/// are only fetched on demand when a section/card is tapped — bundling all
/// four into one `Future` would force every panel to share one loading/
/// error state even though they're genuinely independent fetches with
/// independent triggers. Four separate methods (mirrored by four separate
/// providers in `teacher_dashboard_providers.dart`) is the deliberate
/// choice here, not an oversight.
///
/// Nullable RPC parameter handling: there is no existing precedent in this
/// codebase for a `.rpc()` call with an optional `p_*` parameter — both
/// `fetchLeaderboardTop` (0036) and `resolveSchoolYearId` (0023) always
/// pass their one parameter. Since every `p_grade_level`/`p_section_id`
/// parameter on the `0037` SQL side is `default null`, either omitting the
/// key or passing an explicit `null` reaches the same SQL default — this
/// class always includes both keys explicitly (`null` when unset) rather
/// than conditionally omitting them, so every call site has the same
/// predictable param-map shape regardless of which filters are active,
/// making the four methods below trivially diffable against each other.
class TeacherDashboardRepository {
  const TeacherDashboardRepository(this._client);

  final SupabaseClient _client;

  /// The four summary tiles (0037 Function 1) — one row.
  Future<DashboardSummaryTiles> fetchSummaryTiles({
    GradeLevel? gradeLevel,
    String? sectionId,
  }) async {
    try {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'dashboard_summary_tiles',
        params: <String, dynamic>{
          'p_grade_level': gradeLevel?.toDb(),
          'p_section_id': sectionId,
        },
      );
      return DashboardSummaryTiles.fromJson(rows.single as Map<String, dynamic>);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// "Average per Section" bar chart data (0037 Function 2) — one row per
  /// section in scope. No `sectionId` filter param — narrowing to one
  /// section would defeat this function's own purpose (see 0037's
  /// comment on `dashboard_avg_score_by_section`).
  Future<List<SectionAverageScore>> fetchAverageScoreBySection({
    GradeLevel? gradeLevel,
  }) async {
    try {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'dashboard_avg_score_by_section',
        params: <String, dynamic>{'p_grade_level': gradeLevel?.toDb()},
      );
      return rows
          .map((row) => SectionAverageScore.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// The drill-down roster (0037 Function 3) — one row per actively-
  /// enrolled student in scope.
  Future<List<DashboardRosterEntry>> fetchRoster({
    GradeLevel? gradeLevel,
    String? sectionId,
  }) async {
    try {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'dashboard_student_roster',
        params: <String, dynamic>{
          'p_grade_level': gradeLevel?.toDb(),
          'p_section_id': sectionId,
        },
      );
      return rows
          .map((row) => DashboardRosterEntry.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// "Competency Mastery" per-topic bars (0037 Function 4, regular
  /// quizzes only) — one row per topic in scope.
  Future<List<TopicMasteryEntry>> fetchCompetencyMastery({
    GradeLevel? gradeLevel,
    String? sectionId,
  }) async {
    try {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'dashboard_competency_mastery',
        params: <String, dynamic>{
          'p_grade_level': gradeLevel?.toDb(),
          'p_section_id': sectionId,
        },
      );
      return rows
          .map((row) => TopicMasteryEntry.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Teacher Progress Reports per-student x per-topic mastery heatmap feed
  /// (0046 Part 1, `app.dashboard_student_topic_mastery` /
  /// `public.dashboard_student_topic_mastery`) — one row per (student,
  /// topic) for every actively-enrolled student in scope, full roster.
  /// Same nullable-param-handling and error-mapping convention as the
  /// four `0037` methods above (always passes both keys explicitly, maps
  /// exceptions through [mapExceptionToFailure]) — added here as a fifth,
  /// independent method rather than folded into [fetchCompetencyMastery],
  /// since Progress Reports (0046) is a separate screen/feature from the
  /// Teacher Dashboard (0037) even though both ultimately read
  /// `question_bank.topic` mastery data.
  Future<List<StudentTopicMasteryEntry>> fetchStudentTopicMastery({
    GradeLevel? gradeLevel,
    String? sectionId,
  }) async {
    try {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'dashboard_student_topic_mastery',
        params: <String, dynamic>{
          'p_grade_level': gradeLevel?.toDb(),
          'p_section_id': sectionId,
        },
      );
      return rows
          .map((row) => StudentTopicMasteryEntry.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Intervention drill-down feed (0047, `app.dashboard_intervention_students`)
  /// — one row per flagged student across every section the calling
  /// teacher teaches, with `grade_level` included. No `gradeLevel`/
  /// `sectionId` params, unlike the methods above — this always returns
  /// the teacher's full flagged list; [TeacherInterventionStudentsScreen]
  /// and the Progress Reports drill-down both group the one result
  /// client-side rather than re-fetching per grade/section.
  Future<List<TeacherInterventionStudent>> fetchInterventionStudents() async {
    try {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'dashboard_intervention_students',
      );
      return rows
          .map((row) => TeacherInterventionStudent.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
