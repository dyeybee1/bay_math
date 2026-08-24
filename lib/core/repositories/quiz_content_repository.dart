import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/quiz_answer_check_result.dart';
import '../models/quiz_attempt_content.dart';

/// Phase 6 (Quiz-Taking) Connection B — the only two things that go
/// through an Edge Function + service_role: fetching sanitized quiz
/// content, and checking a submitted choice. Deliberately separate from
/// `QuizAttemptsRepository` (Connection A) — mirrors that split exactly as
/// specified in the architecture: attempt find-or-create, answer
/// insertion, and finalization never go through an Edge Function.
class QuizContentRepository {
  const QuizContentRepository(this._client);

  final SupabaseClient _client;

  /// Sanitized (no `is_correct`) question/choice content for an active
  /// attempt, shuffled per the quiz's settings, plus already-answered
  /// question IDs for resume support.
  Future<QuizAttemptContent> fetchContent(String attemptId) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'quiz-content-for-attempt',
        body: <String, dynamic>{'attempt_id': attemptId},
      );
      return QuizAttemptContent.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// The single authoritative correctness check for one submitted choice —
  /// also returns the explanation (this is the correct moment to reveal
  /// it) and every choice's `is_correct`/`display_order`, so the caller can
  /// build `quiz_attempt_answer_choice_snapshots` without a third
  /// service_role round-trip of its own.
  Future<QuizAnswerCheckResult> checkAnswer({
    required String attemptId,
    required String questionId,
    required String choiceId,
  }) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'check-quiz-answer',
        body: <String, dynamic>{
          'attempt_id': attemptId,
          'question_id': questionId,
          'choice_id': choiceId,
        },
      );
      return QuizAnswerCheckResult.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
