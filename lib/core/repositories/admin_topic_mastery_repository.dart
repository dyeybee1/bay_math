import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/admin_topic_mastery.dart';
import '../models/section.dart' show GradeLevel;

/// Admin -> Performance Reports / Topic Mastery — Part 2's Dart data layer
/// for the `public.admin_competency_mastery(...)` RPC that Part 1 (0052)
/// already added to the live schema. That RPC is itself a thin
/// `security invoker` pass-through wrapping a `security definer`
/// `app.admin_competency_mastery` function which gates on `app.is_admin()`
/// — same reasoning [AdminQuizResultsRepository]'s own doc comment gives
/// for 0051, restated briefly here rather than duplicated in full. Every
/// method below is therefore a plain `.rpc()` call, no Edge Function /
/// `service_role` call anywhere in this class.
///
/// The RPC's underlying function name (`admin_competency_mastery`) is kept
/// as-is here since it already exists in the live schema and Part 1
/// explicitly said not to recreate it — only this Dart-side class and its
/// model ([AdminTopicMasteryRow]) use "Topic" naming, per the confirmed
/// project decision that `question_bank.topic` holds real lesson-title
/// strings, not short competency-bucket labels.
///
/// Expects [supabaseClientProvider] (the calling Admin's own Supabase Auth
/// session), NOT `studentScopedClientProvider` — identical reasoning to
/// [AdminQuizResultsRepository]. The 42501 (`insufficient_privilege`) a
/// non-admin session gets back is mapped to `NotAuthorizedFailure` by
/// [mapExceptionToFailure] the same way any other RLS/guard denial is.
///
/// There is no `fetchSchoolYears` method on this class — per Part 1's own
/// migration note, the School Year filter dropdown reuses the existing
/// `admin_quiz_results_school_years` RPC (0051) via
/// [AdminQuizResultsRepository.fetchSchoolYears] /
/// `adminQuizResultsSchoolYearsProvider` directly; adding a second,
/// functionally-identical method here would duplicate that RPC call for no
/// reason.
class AdminTopicMasteryRepository {
  const AdminTopicMasteryRepository(this._client);

  final SupabaseClient _client;

  /// Every `admin_competency_mastery` (0052) row — one per distinct
  /// `question_bank.topic` — matching the given grade/section/school-year
  /// filters, all three applied server-side via RPC parameters, same
  /// "never fetch-all-then-filter-client-side" convention 0051's
  /// [AdminQuizResultsRepository.fetchResults] follows for the dimensions
  /// the RPC actually supports:
  ///  - [gradeLevel] null -> every grade.
  ///  - [sectionId] null -> every section.
  ///  - [schoolYearId] null -> "All Time" (0052's own default scope,
  ///    matching 0051's convention exactly).
  ///
  /// There is deliberately no `topic` parameter here — `admin_competency_
  /// mastery` (0052) has no `p_topic` argument; it always returns every
  /// distinct topic matching the other three filters. A single-topic
  /// selection (the screen's Topic filter dropdown, Part 3) is applied
  /// client-side, on the list this method returns — see
  /// `performance_reports_providers.dart`'s own comment on
  /// [adminPerformanceReportsProvider] for why that is a deliberate,
  /// flagged choice rather than an oversight.
  Future<List<AdminTopicMasteryRow>> fetchTopicMastery({
    GradeLevel? gradeLevel,
    String? sectionId,
    String? schoolYearId,
  }) async {
    try {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'admin_competency_mastery',
        params: <String, dynamic>{
          'p_school_year_id': schoolYearId,
          'p_grade_level': gradeLevel?.toDb(),
          'p_section_id': sectionId,
        },
      );
      return rows
          .map((row) => AdminTopicMasteryRow.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
