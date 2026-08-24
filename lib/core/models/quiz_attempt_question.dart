import 'quiz_attempt_choice.dart';

/// One question as returned by the `quiz-content-for-attempt` Edge
/// Function — sanitized (no `is_correct` anywhere) content for an active
/// quiz attempt. Question/choice order reflects the quiz's shuffle
/// settings, deterministically seeded per attempt server-side — re-fetching
/// within the same attempt returns the same order every time. Still, do
/// not treat list *position* as a stable identity for a question; key off
/// `questionId` instead (see `_QuizTakingScreenState`).
///
/// No `displayOrder` field here on purpose — unlike the teacher-side
/// `QuizQuestion` model, this shape's list order from the Edge Function
/// response IS the order to render, whether or not it was shuffled.
class QuizAttemptQuestion {
  const QuizAttemptQuestion({
    required this.questionId,
    required this.promptText,
    required this.choices,
  });

  final String questionId;
  final String promptText;
  final List<QuizAttemptChoice> choices;

  factory QuizAttemptQuestion.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawChoices = json['choices'] as List<dynamic>;
    return QuizAttemptQuestion(
      questionId: json['question_id'] as String,
      promptText: json['prompt_text'] as String,
      choices:
          rawChoices
              .map(
                (choice) =>
                    QuizAttemptChoice.fromJson(choice as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}
