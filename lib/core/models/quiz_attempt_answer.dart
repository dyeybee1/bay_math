import 'quiz_attempt_answer_choice_snapshot.dart';

/// A Dart-side mirror of one `public.quiz_attempt_answers` row (0010), with
/// its `quiz_attempt_answer_choice_snapshots` rows attached — everything
/// `quiz_results_screen.dart` needs to render one question's historical
/// result without a second round-trip per question.
///
/// `questionTextSnapshot` and `choiceSnapshots` are frozen at answer time
/// and remain authoritative regardless of later edits to the live
/// `question_bank`/`question_choices` rows (Phase 2 schema §7.6).
class QuizAttemptAnswer {
  const QuizAttemptAnswer({
    required this.id,
    required this.quizAttemptId,
    required this.questionId,
    required this.questionTextSnapshot,
    required this.selectedChoiceId,
    required this.isCorrect,
    required this.answeredAt,
    required this.choiceSnapshots,
  });

  final String id;
  final String quizAttemptId;
  final String questionId;
  final String questionTextSnapshot;

  /// Live-row backlink only, for traceability (0010 comment) — the
  /// snapshots below are what's actually rendered.
  final String? selectedChoiceId;
  final bool isCorrect;
  final DateTime answeredAt;
  final List<QuizAttemptAnswerChoiceSnapshot> choiceSnapshots;

  factory QuizAttemptAnswer.fromJson(
    Map<String, dynamic> json, {
    required List<QuizAttemptAnswerChoiceSnapshot> choiceSnapshots,
  }) {
    return QuizAttemptAnswer(
      id: json['id'] as String,
      quizAttemptId: json['quiz_attempt_id'] as String,
      questionId: json['question_id'] as String,
      questionTextSnapshot: json['question_text_snapshot'] as String,
      selectedChoiceId: json['selected_choice_id'] as String?,
      isCorrect: json['is_correct'] as bool,
      answeredAt: DateTime.parse(json['answered_at'] as String),
      choiceSnapshots: choiceSnapshots,
    );
  }
}
