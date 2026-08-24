import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/quiz_result_row.dart';

/// Teacher-facing quiz results — Connection A, over the calling teacher's
/// own Supabase Auth session (the client passed in, from
/// `supabaseClientProvider`, NOT `studentScopedClientProvider` — see
/// `teacherQuizResultsRepositoryProvider` in `supabase_providers.dart`).
///
/// Deliberately a separate class from `QuizAttemptsRepository` rather than
/// a method added there, even though both read `quiz_attempts` under the
/// hood: `QuizAttemptsRepository`'s own doc comment states it is Phase 6
/// Connection A *for the student* — every method on it goes out over
/// `studentScopedClientProvider`, the student's own forwarded JWT (see
/// `resolveSchoolYearId`, `findOrCreateActiveAttempt`, etc.). This class's
/// one method needs the opposite session — the *teacher's* own Auth
/// session — the same split the codebase already draws elsewhere (compare
/// `TeacherDashboardRepository`, explicitly built from
/// `supabaseClientProvider`, against every student-scoped repository built
/// from `studentScopedClientProvider`). Folding a teacher-scoped method
/// into a student-scoped class would blur exactly the distinction those
/// two provider names exist to keep visible at every call site.
///
/// Every method here reads `public.v_teacher_quiz_results` (0045), a
/// `security_invoker` view that already rides entirely on
/// `quiz_attempts_select` (0015) — `app.teacher_has_section(section_id)` —
/// plus ordinary teacher read access on `students`/`sections`/`quizzes`.
/// No additional filtering is applied here beyond what that RLS already
/// enforces; section/date/assessment-type filters are a UI-layer concern
/// (applied client-side against the full result set this returns), not a
/// query-parameter on this repository.
class TeacherQuizResultsRepository {
  const TeacherQuizResultsRepository(this._client);

  final SupabaseClient _client;

  /// Every quiz result row visible to the calling teacher — i.e. every
  /// non-superseded `quiz_attempts` row (0045 already excludes
  /// `attempt_status = 'superseded'`) for a student in one of the
  /// teacher's own sections. No section/date/assessment-type parameters:
  /// RLS alone determines the result set, and any further narrowing
  /// happens client-side in the UI layer, not here.
  Future<List<QuizResultRow>> fetchResultsForTeacher() async {
    try {
      final List<Map<String, dynamic>> rows =
          await _client.from('v_teacher_quiz_results').select();
      return [for (final Map<String, dynamic> row in rows) QuizResultRow.fromJson(row)];
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
