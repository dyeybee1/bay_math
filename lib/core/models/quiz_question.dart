/// A Dart-side mirror of one `public.quiz_questions` row — a question's
/// membership (and order) within one Internal Quiz (0009). Never present
/// for External Activities (`enforce_internal_only` trigger, 0014).
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.quizId,
    required this.questionId,
    required this.displayOrder,
  });

  final String id;
  final String quizId;
  final String questionId;
  final int displayOrder;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String,
      quizId: json['quiz_id'] as String,
      questionId: json['question_id'] as String,
      displayOrder: json['display_order'] as int,
    );
  }
}
