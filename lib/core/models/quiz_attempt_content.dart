import 'quiz_attempt_question.dart';

/// The full `quiz-content-for-attempt` response — sanitized question/choice
/// content plus which question IDs are already answered (resume support).
/// Not a database row mirror (there's no single table this maps to); this
/// exists purely to give `QuizContentRepository.fetchContent` and its
/// `FutureProvider.family` a single typed return value instead of an
/// untyped `Map`.
class QuizAttemptContent {
  const QuizAttemptContent({required this.questions, required this.answeredQuestionIds});

  final List<QuizAttemptQuestion> questions;
  final List<String> answeredQuestionIds;

  factory QuizAttemptContent.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawQuestions = json['questions'] as List<dynamic>;
    final List<dynamic> rawAnswered = json['answered_question_ids'] as List<dynamic>;
    return QuizAttemptContent(
      questions: rawQuestions
          .map((question) => QuizAttemptQuestion.fromJson(question as Map<String, dynamic>))
          .toList(),
      answeredQuestionIds: rawAnswered.cast<String>(),
    );
  }
}
