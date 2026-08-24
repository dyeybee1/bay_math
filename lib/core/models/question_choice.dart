/// A Dart-side mirror of one `public.question_choices` row — one answer
/// option for a `question_bank` question. The schema allows multiple
/// correct choices per question (0008), so [isCorrect] is not exclusive
/// across a question's choices.
class QuestionChoice {
  const QuestionChoice({
    required this.id,
    required this.questionId,
    required this.choiceText,
    required this.isCorrect,
    required this.displayOrder,
  });

  final String id;
  final String questionId;
  final String choiceText;
  final bool isCorrect;
  final int displayOrder;

  factory QuestionChoice.fromJson(Map<String, dynamic> json) {
    return QuestionChoice(
      id: json['id'] as String,
      questionId: json['question_id'] as String,
      choiceText: json['choice_text'] as String,
      isCorrect: json['is_correct'] as bool,
      displayOrder: json['display_order'] as int,
    );
  }
}
