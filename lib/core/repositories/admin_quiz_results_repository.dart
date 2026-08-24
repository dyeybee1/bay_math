import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/admin_quiz_result_row.dart';
import '../models/section.dart' show GradeLevel;

/// Admin -> Quiz Results (0051) — Part 1's SQL exposed two thin
/// `security invoker` `public.admin_quiz_results*` pass-throughs, each
/// wrapping a `security definer` `app.admin_quiz_results*` function that
/// itself gates on `app.is_admin()` — see 0051's header for why plain
/// `security invoker` reads weren't used instead (same reasoning
/// `AdminDashboardRepository`'s own doc comment gives for 0039). Every
/// method below is therefore a plain `.rpc()` call, the same shape
/// `AdminDashboardRepository` and `TeacherDashboardRepository` already
/// use — no Edge Function / `service_role` call anywhere in this class.
///
/// Expects [supabaseClientProvider] (the calling Admin's own Supabase Auth
/// session), NOT `studentScopedClientProvider` — identical reasoning to
/// `AdminDashboardRepository`: an Admin session carries a normal Supabase
/// Auth JWT, so `app.is_admin()` inside each `app.admin_quiz_results*`
/// function reads it directly. The 42501 (`insufficient_privilege`) a
/// non-admin session gets back is mapped to [NotAuthorizedFailure] by
/// [mapExceptionToFailure] the same way any other RLS/guard denial is — no
/// bespoke handling needed here.
///
/// Unlike `TeacherQuizResultsRepository` (0045), which applies zero
/// `p_*` filters and leaves all narrowing to the UI layer (RLS alone
/// determines its result set), [fetchResults] below DOES pass every
/// filter through as an RPC parameter — per the locked spec:
/// "Filtering: Server-side, via RPC parameters — never fetch-all-then-
/// filter-client-side." `admin_quiz_results`'s whole premise is
/// school-wide, unscoped-by-RLS-alone results (0051's own header, mirrors
/// 0039's `AdminDashboardRepository` reasoning), so the server-side
/// `p_grade_level`/`p_section_id`/`p_assessment_type_filter`/
/// `p_school_year_id` arguments are the only narrowing that happens at
/// all.
class AdminQuizResultsRepository {
  const AdminQuizResultsRepository(this._client);

  final SupabaseClient _client;

  /// Every `admin_quiz_results` (0051) row matching the given filters, all
  /// four applied server-side. Every parameter is optional/nullable,
  /// matching the RPC's own "unset = no filter on this dimension"
  /// convention exactly:
  ///  - [gradeLevel] null -> every grade.
  ///  - [sectionId] null -> every section.
  ///  - [assessmentTypeFilter] defaults to
  ///    [AdminQuizResultsAssessmentTypeFilter.all] -> every assessment
  ///    type (`toRpcParam()` sends `null` for that case — see that enum's
  ///    own doc comment for why "regular" and "no filter" both need
  ///    representing outside the real 2-value `assessment_type` Postgres
  ///    enum).
  ///  - [schoolYearId] null -> "All Time" (0051's own default scope for
  ///    this whole feature — deliberately NOT the current-school-year-only
  ///    scoping `AdminDashboardRepository`'s methods use).
  Future<List<AdminQuizResultRow>> fetchResults({
    GradeLevel? gradeLevel,
    String? sectionId,
    AdminQuizResultsAssessmentTypeFilter assessmentTypeFilter =
        AdminQuizResultsAssessmentTypeFilter.all,
    String? schoolYearId,
  }) async {
    try {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'admin_quiz_results',
        params: <String, dynamic>{
          'p_grade_level': gradeLevel?.toDb(),
          'p_section_id': sectionId,
          'p_assessment_type_filter': assessmentTypeFilter.toRpcParam(),
          'p_school_year_id': schoolYearId,
        },
      );
      return rows
          .map((row) => AdminQuizResultRow.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Every `public.school_years` row (0051's `admin_quiz_results_school_
  /// years`), for the School Year filter dropdown. No parameters — the
  /// dropdown's own "All Time" catch-all is a UI-only sentinel (see
  /// [AdminSchoolYearOption]'s own doc comment), never a value this method
  /// requests from the server.
  Future<List<AdminSchoolYearOption>> fetchSchoolYears() async {
    try {
      final List<dynamic> rows =
          await _client.rpc<List<dynamic>>('admin_quiz_results_school_years');
      return rows
          .map((row) => AdminSchoolYearOption.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
