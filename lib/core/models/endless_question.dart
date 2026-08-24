import 'quiz_attempt_choice.dart';

/// A Dart-side mirror of the `endless-quiz-fetch-question` Edge Function's
/// response (Phase 7) — one sanitized (no `is_correct`) practice question
/// with its choices. Not a database row mirror (there's no
/// `endless_quiz_sessions` column this maps to — see that table's own
/// comment: no per-question data is ever persisted, only session-level
/// aggregates); this exists purely to give
/// `EndlessQuizRepository.fetchQuestion` a typed return value instead of an
/// untyped `Map`.
///
/// Deliberately its own top-level class rather than reusing
/// `QuizAttemptQuestion`, even though the two are currently
/// field-for-field identical (`questionId`/`promptText`/`choices`):
/// `QuizAttemptQuestion`'s own doc comment describes quiz-attempt-specific
/// semantics that do not hold here — deterministic per-attempt shuffle
/// ordering that stays stable across repeated fetches of the same attempt.
/// Endless Quiz has no attempt to be stable within; every fetch is an
/// independent, freshly-random question. Reusing that class would carry a
/// misleading doc comment along and imply a persistence/ordering guarantee
/// this feature deliberately does not make.
///
/// `choices`, however, DOES reuse [QuizAttemptChoice] rather than adding a
/// second, parallel model for an identical shape: `QuizAttemptChoice` is
/// already exactly `{choiceId, choiceText}`, sanitized (no `is_correct`),
/// which is precisely what `endless-quiz-fetch-question`'s `choices` array
/// is too — same two fields, same JSON key names, same sanitized intent.
/// There's no meaningful semantic difference at the single-choice level the
/// way there is at the question level above, so reuse here avoids pure
/// duplication.
class EndlessQuestion {
  const EndlessQuestion({
    required this.questionId,
    required this.promptText,
    required this.choices,
  });

  final String questionId;
  final String promptText;
  final List<QuizAttemptChoice> choices;

  factory EndlessQuestion.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawChoices = json['choices'] as List<dynamic>;
    return EndlessQuestion(
      questionId: json['question_id'] as String,
      promptText: json['prompt_text'] as String,
      choices: rawChoices
          .map((choice) => QuizAttemptChoice.fromJson(choice as Map<String, dynamic>))
          .toList(),
    );
  }
}
