import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_failure.dart';
import '../errors/failure_mapper.dart';
import '../models/quiz_answer_check_result.dart';
import '../models/quiz_attempt.dart';
import '../models/quiz_attempt_answer.dart';
import '../models/quiz_attempt_answer_choice_snapshot.dart';

/// Phase 6 (Quiz-Taking) Connection A — every call here goes over the
/// student's own forwarded JWT via the client passed in
/// (`studentScopedClientProvider`), relying entirely on RLS
/// (`quiz_attempts_*`, `quiz_attempt_answers_student_insert`,
/// `quiz_attempt_answer_choice_snapshots_student_insert`, 0015). No Edge
/// Function is involved in any method here — that's `QuizContentRepository`
/// (Connection B), a deliberately separate class.
class QuizAttemptsRepository {
  const QuizAttemptsRepository(this._client);

  final SupabaseClient _client;

  /// Resolves [sectionId]'s school year — needed to build the
  /// `findOrCreateActiveAttempt` insert payload. Students cannot read the
  /// `sections` table directly at all ("Student: indirect only", 0015), so
  /// this goes through `public.student_section_school_year` (0023), a
  /// narrow pass-through RPC added specifically for this lookup — not a
  /// general-purpose sections read.
  Future<String> resolveSchoolYearId(String sectionId) async {
    try {
      final Object? result = await _client.rpc(
        'student_section_school_year',
        params: {'p_section_id': sectionId},
      );
      if (result is! String) {
        throw const ServerFailure('Could not determine your current school year.');
      }
      return result;
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// TOCTOU-safe find-or-create against
  /// `quiz_attempts_one_active_per_student_quiz` (0010) — the unique index
  /// that IS the "one active attempt" enforcement. Attempts the insert;
  /// if it loses a race to a concurrent identical insert (or the student
  /// already has an active attempt for this quiz from an earlier session),
  /// reads back the row that won instead of erroring or retrying the
  /// insert itself.
  ///
  /// `sectionId`/`schoolYearId` must be the student's own current
  /// enrollment's section and that section's school year —
  /// `quiz_attempts_student_insert`'s WITH CHECK (0015, fixed for students
  /// in 0023) independently re-verifies both against real enrollment data,
  /// never trusting these values on their own.
  Future<QuizAttempt> findOrCreateActiveAttempt({
    required String studentId,
    required String quizId,
    required String sectionId,
    required String schoolYearId,
  }) async {
    try {
      try {
        final Map<String, dynamic> row = await _client
            .from('quiz_attempts')
            .insert({
              'student_id': studentId,
              'quiz_id': quizId,
              'section_id': sectionId,
              'school_year_id': schoolYearId,
            })
            .select()
            .single();
        return QuizAttempt.fromJson(row);
      } on PostgrestException catch (error) {
        if (error.code == '23505') {
          final Map<String, dynamic> existing = await _client
              .from('quiz_attempts')
              .select()
              .eq('student_id', studentId)
              .eq('quiz_id', quizId)
              .eq('attempt_status', 'active')
              .single();
          return QuizAttempt.fromJson(existing);
        }
        rethrow;
      }
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// The student's most recent attempt (by `opened_at`) for [quizId], if
  /// any — active, submitted, or superseded — used by the quiz list screen
  /// to decide between Start / Resume / Review. RLS
  /// (`quiz_attempts_select`, 0015) already scopes this to the caller's
  /// own rows; `studentId` is passed explicitly anyway to keep the query
  /// shape obvious and match every other method's signature on this class.
  Future<QuizAttempt?> fetchLatestForQuiz({required String studentId, required String quizId}) async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('quiz_attempts')
          .select()
          .eq('student_id', studentId)
          .eq('quiz_id', quizId)
          .order('opened_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null ? null : QuizAttempt.fromJson(row);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<QuizAttempt> fetchAttempt(String attemptId) async {
    try {
      final Map<String, dynamic> row =
          await _client.from('quiz_attempts').select().eq('id', attemptId).single();
      return QuizAttempt.fromJson(row);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Records one answered question. `isCorrect` and `choiceSnapshots` must
  /// come from `QuizContentRepository.checkAnswer`'s response (Connection
  /// B) — never recomputed client-side (Phase 6 constraint 3/6).
  ///
  /// TOCTOU-safe against
  /// `quiz_attempt_answers_attempt_question_unique` (0010): on a
  /// conflicting concurrent submit (or a duplicate spam-tap that slipped
  /// past the client-side debounce), this is a no-op — the winning
  /// insert's row and its snapshots are already the complete, correct
  /// record for this question, so there's nothing further to write.
  ///
  /// KNOWN GAP (flagged, not fixed here — see the same note on
  /// `check-quiz-answer/index.ts`): this RLS policy does not check
  /// `quiz_attempts.submitted_at`, so nothing here stops a call against an
  /// already-submitted attempt at the DB layer. Mitigated by the
  /// screen-level read-only guard once `attempt.isSubmitted` is true.
  /// // TODO(phase-6-followup): add `submitted_at is null` to
  /// // `quiz_attempt_answers_student_insert`'s WITH CHECK in a future
  /// // migration.
  Future<void> submitAnswer({
    required String attemptId,
    required String questionId,
    required String questionTextSnapshot,
    required String choiceId,
    required bool isCorrect,
    required List<CheckedChoice> choiceSnapshots,
  }) async {
    try {
      String answerId;
      try {
        final Map<String, dynamic> row = await _client
            .from('quiz_attempt_answers')
            .insert({
              'quiz_attempt_id': attemptId,
              'question_id': questionId,
              'question_text_snapshot': questionTextSnapshot,
              'selected_choice_id': choiceId,
              'is_correct': isCorrect,
            })
            .select('id')
            .single();
        answerId = row['id'] as String;
      } on PostgrestException catch (error) {
        if (error.code == '23505') {
          // Already recorded by the winning insert — nothing further to
          // write (see method doc above).
          return;
        }
        rethrow;
      }

      if (choiceSnapshots.isNotEmpty) {
        await _client.from('quiz_attempt_answer_choice_snapshots').insert([
          for (final CheckedChoice choice in choiceSnapshots)
            <String, dynamic>{
              'quiz_attempt_answer_id': answerId,
              'choice_text_snapshot': choice.choiceText,
              'was_correct': choice.isCorrect,
              'was_selected': choice.choiceId == choiceId,
              'display_order': choice.displayOrder,
            },
        ]);
      }
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Every answered question for [attemptId], with its choice snapshots
  /// attached — for the read-only results screen. Snapshot data (frozen at
  /// answer time) is what's rendered, never live `question_choices` rows.
  Future<List<QuizAttemptAnswer>> fetchAnswers(String attemptId) async {
    try {
      final List<Map<String, dynamic>> answerRows = await _client
          .from('quiz_attempt_answers')
          .select()
          .eq('quiz_attempt_id', attemptId)
          .order('answered_at');

      if (answerRows.isEmpty) return const [];

      final List<String> answerIds = [for (final Map<String, dynamic> row in answerRows) row['id'] as String];
      final List<Map<String, dynamic>> snapshotRows = await _client
          .from('quiz_attempt_answer_choice_snapshots')
          .select()
          .inFilter('quiz_attempt_answer_id', answerIds)
          .order('display_order');

      final Map<String, List<QuizAttemptAnswerChoiceSnapshot>> snapshotsByAnswerId = {};
      for (final Map<String, dynamic> row in snapshotRows) {
        final QuizAttemptAnswerChoiceSnapshot snapshot = QuizAttemptAnswerChoiceSnapshot.fromJson(row);
        snapshotsByAnswerId.putIfAbsent(snapshot.quizAttemptAnswerId, () => []).add(snapshot);
      }

      return [
        for (final Map<String, dynamic> row in answerRows)
          QuizAttemptAnswer.fromJson(
            row,
            choiceSnapshots: snapshotsByAnswerId[row['id'] as String] ?? const [],
          ),
      ];
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Marks [attemptId] submitted and computes its final score from the
  /// already-answered rows — no service_role call needed, since
  /// `is_correct` on each row is already authoritative (set from
  /// Connection B's `check-quiz-answer` at answer time, never recomputed
  /// here).
  ///
  /// Idempotent per Phase 6 constraint 7: calling this again on an
  /// already-submitted attempt returns the existing result unchanged,
  /// rather than erroring or re-scoring.
  ///
  /// Score is the raw count of correct answers (not a percentage) — the
  /// architecture doc didn't specify a format, and `total_questions` is
  /// already available separately for any "X out of Y" display; this was
  /// the most conservative reading of `quiz_attempts_score_non_negative`
  /// (which has no upper-bound companion constraint the way a 0–100
  /// percentage would). Flagging this choice — straightforward to change
  /// to a percentage later if that's not what's wanted.
  Future<QuizAttempt> finalize(String attemptId) async {
    try {
      final Map<String, dynamic> currentRow =
          await _client.from('quiz_attempts').select().eq('id', attemptId).single();
      final QuizAttempt current = QuizAttempt.fromJson(currentRow);
      if (current.isSubmitted) return current;

      final List<Map<String, dynamic>> answerRows = await _client
          .from('quiz_attempt_answers')
          .select('is_correct')
          .eq('quiz_attempt_id', attemptId);

      final int correctCount = answerRows.where((row) => row['is_correct'] as bool).length;

      final Map<String, dynamic> updatedRow = await _client
          .from('quiz_attempts')
          .update({
            'submitted_at': DateTime.now().toUtc().toIso8601String(),
            'score': correctCount,
          })
          .eq('id', attemptId)
          .select()
          .single();
      return QuizAttempt.fromJson(updatedRow);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
