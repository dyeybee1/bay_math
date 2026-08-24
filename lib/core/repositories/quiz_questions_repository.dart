import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/quiz_question.dart';

/// Reads/writes `quiz_questions` rows — question membership and order
/// within one Internal Quiz. Write scope is entirely RLS-enforced
/// (`quiz_questions_teacher_write`, tightened in 0018 to also validate
/// the referenced question's ownership — see the schema comment there).
class QuizQuestionsRepository {
  const QuizQuestionsRepository(this._client);

  final SupabaseClient _client;

  Future<List<QuizQuestion>> fetchForQuiz(String quizId) async {
    try {
      final List<Map<String, dynamic>> data = await _client
          .from('quiz_questions')
          .select()
          .eq('quiz_id', quizId)
          .order('display_order');
      return data.map(QuizQuestion.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Question counts for a batch of quizzes in one round trip — the same
  /// `inFilter`-batching pattern used elsewhere in this codebase (e.g.
  /// `StudentsRepository.fetchByIds`), rather than issuing [fetchForQuiz]
  /// once per quiz (e.g. once per Quiz Results matrix column, which would
  /// turn a 10-column matrix into 10 separate queries). A quiz with no
  /// rows here — including every External Activity, since `quiz_questions`
  /// is Internal-Quiz-only per `enforce_internal_only` (0014) — is simply
  /// absent from the returned map rather than present with a `0`; callers
  /// should treat a missing key the same way they'd treat a `0` count.
  Future<Map<String, int>> fetchQuestionCountsForQuizzes(List<String> quizIds) async {
    if (quizIds.isEmpty) return const {};
    try {
      final List<Map<String, dynamic>> data =
          await _client.from('quiz_questions').select('quiz_id').inFilter('quiz_id', quizIds);
      final Map<String, int> counts = {};
      for (final Map<String, dynamic> row in data) {
        final String quizId = row['quiz_id'] as String;
        counts[quizId] = (counts[quizId] ?? 0) + 1;
      }
      return counts;
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Appends [questionId] at [displayOrder] (the caller passes the next
  /// free position — typically the current in-memory list's length + 1 —
  /// since a plain insert with a brand-new, higher order value can never
  /// collide with an existing row's `display_order`).
  Future<void> add({
    required String quizId,
    required String questionId,
    required int displayOrder,
  }) async {
    try {
      await _client.from('quiz_questions').insert({
        'quiz_id': quizId,
        'question_id': questionId,
        'display_order': displayOrder,
      });
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<void> remove(String quizQuestionId) async {
    try {
      await _client.from('quiz_questions').delete().eq('id', quizQuestionId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Rewrites the full display order for [quizId] to match
  /// [orderedQuestionIds] (position 0 becomes `display_order` 1, and so
  /// on).
  ///
  /// This runs as two batched upserts, not one — worth calling out
  /// explicitly, since a single multi-row statement isn't actually
  /// sufficient here. `quiz_questions_quiz_order_unique` (`unique
  /// (quiz_id, display_order)`, 0009) is a plain, non-deferrable unique
  /// constraint (unlike `enforce_at_least_one_correct` on
  /// `question_choices`, which *is* `deferrable initially deferred`).
  /// Postgres checks a non-deferrable unique index as each row is
  /// written, even within one multi-row `UPDATE`/`UPSERT` statement — so
  /// reassigning final positions 1..N directly in a single call can still
  /// transiently collide with another row in the same batch that hasn't
  /// been reassigned yet (the classic "swap two unique values" problem).
  /// Batching per row into one call avoids colliding with rows *outside*
  /// the batch, but not with rows inside it.
  ///
  /// The safe fix — still just two application-level statements, no new
  /// SQL — is a temporary-offset two-phase write: first move every row in
  /// the batch to a negative placeholder (`-(index + 1)`), which can never
  /// collide with any real (>= 1) `display_order`, then a second upsert
  /// assigns the real final values. Both phases target the
  /// `(quiz_id, question_id)` unique constraint for conflict resolution
  /// (not `(quiz_id, display_order)`), so each phase is itself one
  /// unambiguous batched upsert.
  Future<void> reorder({
    required String quizId,
    required List<String> orderedQuestionIds,
  }) async {
    try {
      await _client.from('quiz_questions').upsert(
        [
          for (int i = 0; i < orderedQuestionIds.length; i++)
            {
              'quiz_id': quizId,
              'question_id': orderedQuestionIds[i],
              'display_order': -(i + 1),
            },
        ],
        onConflict: 'quiz_id,question_id',
      );

      await _client.from('quiz_questions').upsert(
        [
          for (int i = 0; i < orderedQuestionIds.length; i++)
            {
              'quiz_id': quizId,
              'question_id': orderedQuestionIds[i],
              'display_order': i + 1,
            },
        ],
        onConflict: 'quiz_id,question_id',
      );
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
