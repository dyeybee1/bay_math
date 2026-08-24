import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/endless_question.dart';
import '../models/endless_quiz_leaderboard.dart';

/// Phase 7 (Endless Quiz) — both connection types this feature needs, in
/// one class, off one client:
///
/// - `fetchQuestion`/`checkAnswer` are Connection B (Edge Function +
///   service_role), mirroring `QuizContentRepository`.
/// - `finalizeSession` is Connection A (a plain PostgREST insert under RLS
///   — `endless_quiz_sessions_student_insert`, 0015), mirroring the
///   simpler writes on `QuizAttemptsRepository`/`LessonProgressRepository`.
/// - `fetchLeaderboardTop`/`fetchMyRank` (0036) are also Connection A —
///   plain `.rpc()` calls against the `public.endless_quiz_leaderboard_top`
///   / `public.endless_quiz_leaderboard_my_rank` pass-through wrappers,
///   same student-scoped client and RLS-adjacent trust model as
///   `finalizeSession`, no Edge Function involved.
///
/// Kept as ONE class rather than splitting into a Connection-A/Connection-B
/// pair the way Phase 6 splits `QuizAttemptsRepository`/
/// `QuizContentRepository`: that split exists there for organizational
/// clarity across a much larger set of methods (attempt find-or-create,
/// answer submission, finalization, content fetch, answer check), not
/// because the two connection types need different clients — both of
/// those Phase 6 repositories are already instantiated from the exact same
/// `studentScopedClientProvider` client (see `supabase_providers.dart`),
/// which forwards the student's JWT both as a plain `Authorization` header
/// PostgREST verifies under RLS (Connection A) and as the header
/// `functions.invoke` sends along, which the Edge Function then
/// independently re-verifies itself (Connection B) — one client already
/// legitimately serves both roles. Originally three methods total, now
/// five with the addition of the two leaderboard reads below — still well
/// within the same reasoning: both new methods are Connection A against
/// that identical client, so splitting this into two near-empty classes
/// would still add a file for no organizational benefit. Not every method
/// on this class is Connection A/B split by feature, and that's fine —
/// the split Phase 6 uses is a convenience for a much larger surface area,
/// not a rule this class is obligated to mirror at five methods.
class EndlessQuizRepository {
  const EndlessQuizRepository(this._client);

  final SupabaseClient _client;

  /// One freshly-random practice question — a new call always returns an
  /// independently random question, never a stable/resumable one (there is
  /// no session/attempt row behind this to resume; see
  /// `endless-quiz-fetch-question`'s own comment on why no shuffle-
  /// persistence logic applies here).
  Future<EndlessQuestion> fetchQuestion() async {
    try {
      final FunctionResponse response =
          await _client.functions.invoke('endless-quiz-fetch-question');
      return EndlessQuestion.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// The authoritative correctness check for one Endless Quiz answer.
  /// Deliberately returns only the boolean — `endless-quiz-check-answer`'s
  /// response is `{ is_correct }` and nothing else (no explanation, no
  /// choices array); Endless Quiz is fast-paced practice, not an
  /// explanation-driven moment, and the underlying `svc_check_endless_answer`
  /// doesn't provide anything beyond the boolean regardless.
  Future<bool> checkAnswer({required String questionId, required String choiceId}) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'endless-quiz-check-answer',
        body: <String, dynamic>{'question_id': questionId, 'choice_id': choiceId},
      );
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      return data['is_correct'] as bool;
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Writes the one, session-ending `endless_quiz_sessions` row (0011) —
  /// Session Date/Questions Answered/Best Streak/Duration are derived from
  /// these four values, never written incrementally per-question. A plain
  /// insert, no TOCTOU-safe insert-on-conflict handling: double-submit
  /// protection for this is a client-side debounce in the Part 3 screen
  /// (disable the button after first tap), a deliberate, already-settled
  /// call — a rare double-tap producing a harmless duplicate near-zero-
  /// duration session row is an accepted tradeoff, not a gap to patch
  /// here. `students.best_endless_streak` is never written by this method
  /// or anywhere else in application code — `app.update_best_endless_streak`
  /// (0018) is a `SECURITY DEFINER` trigger that raises it automatically
  /// on this very insert whenever `bestStreakSession` exceeds the current
  /// all-time record.
  Future<void> finalizeSession({
    required String studentId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int questionsAnswered,
    required int bestStreakSession,
  }) async {
    try {
      await _client.from('endless_quiz_sessions').insert({
        'student_id': studentId,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
        'questions_answered': questionsAnswered,
        'best_streak_session': bestStreakSession,
      });
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// The top [limit] (default 50) active students in the caller's own
  /// grade, ranked by `best_endless_streak` desc — backs the main
  /// leaderboard list. Grade is auto-detected server-side from the
  /// caller's own active enrollment (`app.student_current_grade()`); there
  /// is no grade parameter to pass here, by design (see 0036's header).
  ///
  /// `.rpc()` against a `returns table (...)` function comes back as a
  /// `List<dynamic>` of row maps (the standard supabase-dart shape for a
  /// table-returning RPC) — there's no existing `returns table` `.rpc()`
  /// call elsewhere in this codebase to match against (`resolveSchoolYearId`
  /// in `quiz_attempts_repository.dart` is the only other `.rpc()` call on
  /// this client, and that one is a scalar `returns text`), so this is
  /// written against supabase-dart's documented shape rather than an
  /// in-repo precedent.
  Future<List<LeaderboardEntry>> fetchLeaderboardTop({int limit = 50}) async {
    try {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'endless_quiz_leaderboard_top',
        params: {'p_limit': limit},
      );
      return rows
          .map((row) => LeaderboardEntry.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// The caller's own rank within that same grade-scoped, full-population
  /// ranking — powers a "You're #N" card even when N falls outside
  /// [fetchLeaderboardTop]'s page. Always exactly one row per 0036's
  /// guarantee (one active enrollment per student,
  /// `student_enrollments_one_active_per_student`, 0006) — trusted the
  /// same way `StudentStatisticsRepository.fetchSummaryTiles` trusts
  /// `v_student_summary_tiles`'s own "always a row" guarantee, with no
  /// defensive empty-result branch added on top of it.
  Future<LeaderboardEntry> fetchMyRank() async {
    try {
      final List<dynamic> rows =
          await _client.rpc<List<dynamic>>('endless_quiz_leaderboard_my_rank');
      return LeaderboardEntry.fromJson(rows.single as Map<String, dynamic>);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
