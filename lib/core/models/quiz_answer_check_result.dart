/// One choice as returned by `check-quiz-answer` — unlike
/// `QuizAttemptChoice`, this DOES carry `is_correct`/`display_order`,
/// because by this point (after the student has submitted an answer) it's
/// the correct moment to reveal them. Used directly to build the
/// `quiz_attempt_answer_choice_snapshots` rows on the Connection-A insert,
/// without a third service_role round-trip.
class CheckedChoice {
  const CheckedChoice({
    required this.choiceId,
    required this.choiceText,
    required this.isCorrect,
    required this.displayOrder,
  });

  final String choiceId;
  final String choiceText;
  final bool isCorrect;
  final int displayOrder;

  factory CheckedChoice.fromJson(Map<String, dynamic> json) {
    return CheckedChoice(
      choiceId: json['choice_id'] as String,
      choiceText: json['choice_text'] as String,
      isCorrect: json['is_correct'] as bool,
      displayOrder: json['display_order'] as int,
    );
  }
}

/// The full `check-quiz-answer` response — the single source of truth for
/// whether a submitted choice was correct. Flutter never computes
/// `isCorrect` itself; it only relays this into the Connection-A insert
/// (`QuizAttemptsRepository.submitAnswer`).
class QuizAnswerCheckResult {
  const QuizAnswerCheckResult({
    required this.isCorrect,
    required this.explanationText,
    required this.choices,
  });

  final bool isCorrect;

  /// Null when the question has no explanation set — the UI skips that
  /// section gracefully rather than showing an empty box (Phase 6
  /// constraint 6).
  final String? explanationText;
  final List<CheckedChoice> choices;

  factory QuizAnswerCheckResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawChoices = json['choices'] as List<dynamic>;
    return QuizAnswerCheckResult(
      isCorrect: json['is_correct'] as bool,
      explanationText: json['explanation_text'] as String?,
      choices:
          rawChoices.map((choice) => CheckedChoice.fromJson(choice as Map<String, dynamic>)).toList(),
    );
  }
}
