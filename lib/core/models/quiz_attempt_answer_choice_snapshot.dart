/// A Dart-side mirror of one `public.quiz_attempt_answer_choice_snapshots`
/// row (0010) — frozen historical choice data for one answered question.
/// `quiz_results_screen.dart` reads these instead of live
/// `question_choices` rows, since a question's choices can be edited by a
/// Teacher/Admin after the fact (Phase 2 schema §7.6/§9 Recommendation 4).
class QuizAttemptAnswerChoiceSnapshot {
  const QuizAttemptAnswerChoiceSnapshot({
    required this.id,
    required this.quizAttemptAnswerId,
    required this.choiceTextSnapshot,
    required this.wasCorrect,
    required this.wasSelected,
    required this.displayOrder,
  });

  final String id;
  final String quizAttemptAnswerId;
  final String choiceTextSnapshot;
  final bool wasCorrect;
  final bool wasSelected;
  final int displayOrder;

  factory QuizAttemptAnswerChoiceSnapshot.fromJson(Map<String, dynamic> json) {
    return QuizAttemptAnswerChoiceSnapshot(
      id: json['id'] as String,
      quizAttemptAnswerId: json['quiz_attempt_answer_id'] as String,
      choiceTextSnapshot: json['choice_text_snapshot'] as String,
      wasCorrect: json['was_correct'] as bool,
      wasSelected: json['was_selected'] as bool,
      displayOrder: json['display_order'] as int,
    );
  }
}
