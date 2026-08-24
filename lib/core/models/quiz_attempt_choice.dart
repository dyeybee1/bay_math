/// One answer option as returned by the `quiz-content-for-attempt` Edge
/// Function, while the student is still taking the quiz — deliberately
/// sanitized, with no `is_correct` field. Kept separate from the
/// teacher-side `QuestionChoice` model (which does carry `is_correct` and
/// authoring fields that don't belong in this shape).
class QuizAttemptChoice {
  const QuizAttemptChoice({required this.choiceId, required this.choiceText});

  final String choiceId;
  final String choiceText;

  factory QuizAttemptChoice.fromJson(Map<String, dynamic> json) {
    return QuizAttemptChoice(
      choiceId: json['choice_id'] as String,
      choiceText: json['choice_text'] as String,
    );
  }
}
