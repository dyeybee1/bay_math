import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/admin_dashboard.dart';
import '../models/section.dart' show GradeLevel;

/// Admin Dashboard (0039) — Part 1's SQL exposed three zero-argument
/// `public.admin_dashboard_*` functions (`admin_dashboard_summary_tiles`,
/// `admin_dashboard_score_by_grade`, `admin_dashboard_proficiency_distribution`),
/// each a thin `security invoker` pass-through to a `security definer`
/// `app.admin_dashboard_*` function that itself gates on `app.is_admin()` —
/// see 0039's header for why plain `security invoker` reads weren't used
/// instead. Every method below is therefore a plain `.rpc()` call, the same
/// shape `TeacherDashboardRepository`, `EndlessQuizRepository.fetchLeaderboardTop`/
/// `fetchMyRank` (0036), and `QuizAttemptsRepository.resolveSchoolYearId`
/// (0023) already use — no Edge Function / `service_role` call anywhere in
/// this class.
///
/// Expects [supabaseClientProvider] (the calling Admin's own Supabase Auth
/// session), NOT `studentScopedClientProvider` — same reasoning as
/// `teacherDashboardRepositoryProvider`: an Admin session, like a Teacher
/// session, carries a normal Supabase Auth JWT, so `app.is_admin()` inside
/// each `app.admin_dashboard_*` function reads it directly. The 42501
/// (`insufficient_privilege`) a non-admin session gets back from
/// `app.is_admin()`'s guard is mapped to [NotAuthorizedFailure] by
/// [mapExceptionToFailure] the same way any other RLS/guard denial is —
/// no bespoke handling needed here.
///
/// No `p_*` parameters on any of the three calls below, unlike
/// `TeacherDashboardRepository`'s `p_grade_level`/`p_section_id` filters —
/// the Admin Dashboard is unscoped/system-wide by design (0039's own
/// header: "whose whole premise is system-wide, unscoped totals"), so
/// there is nothing to narrow.
///
/// Deliberately three separate methods, not one combined call — mirrors
/// why `TeacherDashboardRepository` stays four separate methods instead of
/// one `fetchAll()`: the summary tiles and the two charts are backed by
/// three independent SQL functions (0039 Functions 1-3), each its own
/// `.rpc()` round-trip, so each gets its own method (and, in Phase 4, its
/// own provider) with its own independent loading/error/refresh state,
/// rather than forcing all three panels to share one `Future` and fail or
/// reload together when only one of them actually needs to.
class AdminDashboardRepository {
  const AdminDashboardRepository(this._client);

  final SupabaseClient _client;

  /// The 6 stat cards (0039 Function 1) — always exactly one row; the SQL
  /// function's `return query select (...)...` shape guarantees a row
  /// even when every underlying count/average is zero/null, so this
  /// trusts `rows.single` the same way
  /// `EndlessQuizRepository.fetchMyRank` trusts its own single-row
  /// guarantee, with no defensive empty-result branch added on top.
  Future<AdminSummaryTiles> fetchSummaryTiles() async {
    try {
      final List<dynamic> rows =
          await _client.rpc<List<dynamic>>('admin_dashboard_summary_tiles');
      return AdminSummaryTiles.fromJson(rows.single as Map<String, dynamic>);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// "Average Score by Grade Level" bar chart data (0039 Function 2) —
  /// always exactly 3 rows, one per [GradeLevel] value
  /// (grade_4/grade_5/grade_6), even a grade with zero qualifying
  /// students (see that function's own comment in 0039) — so the caller
  /// never has to handle a missing bar, only a null
  /// [GradeLevelAverageScore.averageScore] on one it already has.
  Future<List<GradeLevelAverageScore>> fetchScoreByGrade() async {
    try {
      final List<dynamic> rows =
          await _client.rpc<List<dynamic>>('admin_dashboard_score_by_grade');
      return rows
          .map((row) => GradeLevelAverageScore.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// "Proficiency Distribution" pie chart data (0039 Function 3) — 0 to 4
  /// rows: unlike [fetchScoreByGrade], a bucket with zero currently-active
  /// qualifying students has NO row at all (per that function's own
  /// comment in 0039), so an empty list here is a valid, renderable
  /// "nobody has a completed attempt yet" result, not an error state.
  Future<List<ProficiencyDistribution>> fetchProficiencyDistribution() async {
    try {
      final List<dynamic> rows = await _client
          .rpc<List<dynamic>>('admin_dashboard_proficiency_distribution');
      return rows
          .map((row) => ProficiencyDistribution.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  // -------------------------------------------------------------------
  // Tile drill-downs (0041) — one method per `public.admin_dashboard_*`
  // RPC added in 0041. Same `.rpc()` + `mapExceptionToFailure` shape as
  // the three methods above; no Edge Function / `service_role` call.
  // -------------------------------------------------------------------

  /// Total Teachers tile drill-down (0041).
  Future<List<AdminTeacherListEntry>> fetchTeachersList() async {
    try {
      final List<dynamic> rows =
          await _client.rpc<List<dynamic>>('admin_dashboard_teachers_list');
      return rows
          .map((row) => AdminTeacherListEntry.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Total Sections tile drill-down (0041).
  Future<List<AdminSectionListEntry>> fetchSectionsList() async {
    try {
      final List<dynamic> rows =
          await _client.rpc<List<dynamic>>('admin_dashboard_sections_list');
      return rows
          .map((row) => AdminSectionListEntry.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Total Quiz Attempts tile drill-down, level 1 (0041): one row per
  /// grade level.
  Future<List<GradeQuizAttempts>> fetchQuizAttemptsByGrade() async {
    try {
      final List<dynamic> rows =
          await _client.rpc<List<dynamic>>('admin_dashboard_quiz_attempts_by_grade');
      return rows
          .map((row) => GradeQuizAttempts.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Total Quiz Attempts tile drill-down, level 2 (0041): one row per
  /// section within [gradeLevel].
  Future<List<SectionQuizAttempts>> fetchQuizAttemptsBySection(GradeLevel gradeLevel) async {
    try {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'admin_dashboard_quiz_attempts_by_section',
        params: <String, dynamic>{'p_grade_level': gradeLevel.toDb()},
      );
      return rows
          .map((row) => SectionQuizAttempts.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Average Mathematics Score tile drill-down, level 2 (0041): one row
  /// per section within [gradeLevel]. Level 1 is [fetchScoreByGrade]
  /// above (unchanged, already one row per grade).
  Future<List<AdminSectionAverageScore>> fetchScoreBySection(GradeLevel gradeLevel) async {
    try {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'admin_dashboard_score_by_section',
        params: <String, dynamic>{'p_grade_level': gradeLevel.toDb()},
      );
      return rows
          .map((row) => AdminSectionAverageScore.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Students Requiring Intervention tile drill-down (0041).
  Future<List<AdminInterventionStudent>> fetchInterventionStudents() async {
    try {
      final List<dynamic> rows =
          await _client.rpc<List<dynamic>>('admin_dashboard_intervention_students');
      return rows
          .map((row) => AdminInterventionStudent.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
