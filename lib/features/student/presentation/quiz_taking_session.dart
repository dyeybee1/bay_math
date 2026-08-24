import '../../../core/models/quiz_answer_check_result.dart';

enum QuizPrimaryAction { checkAnswer, nextQuestion, finishQuiz, viewResults }

QuizPrimaryAction quizPrimaryActionFor({
  required bool isLastQuestion,
  required bool hasFeedback,
  required bool isResumeLocked,
  required bool isReadOnly,
}) {
  final bool canAdvance = hasFeedback || isResumeLocked || isReadOnly;
  if (isReadOnly && isLastQuestion) return QuizPrimaryAction.viewResults;
  if (canAdvance && isLastQuestion) return QuizPrimaryAction.finishQuiz;
  if (canAdvance) return QuizPrimaryAction.nextQuestion;
  return QuizPrimaryAction.checkAnswer;
}

/// Transient, presentation-only state for one quiz-taking screen visit.
///
/// The backend remains authoritative for correctness and persistence. This
/// class only remembers the student's current selections and the checked
/// responses already returned by the backend so moving between questions
/// does not discard visible state.
class QuizTakingSession {
  final Map<String, String> _selectedChoiceIds = <String, String>{};
  final Map<String, QuizAnswerCheckResult> _checkedResults =
      <String, QuizAnswerCheckResult>{};
  final Set<String> _checkingQuestionIds = <String>{};
  bool _isSubmittingQuiz = false;

  bool get isSubmittingQuiz => _isSubmittingQuiz;

  String? selectedChoiceFor(String questionId) {
    return _selectedChoiceIds[questionId];
  }

  QuizAnswerCheckResult? checkedResultFor(String questionId) {
    return _checkedResults[questionId];
  }

  bool isChecking(String questionId) {
    return _checkingQuestionIds.contains(questionId);
  }

  bool isChecked(String questionId) {
    return _checkedResults.containsKey(questionId);
  }

  /// Updates a neutral, not-yet-checked selection.
  ///
  /// Returns false once checking has started or feedback has been received,
  /// which keeps answer choices locked through slow or duplicate taps.
  bool selectChoice({required String questionId, required String choiceId}) {
    if (isChecking(questionId) || isChecked(questionId)) return false;
    _selectedChoiceIds[questionId] = choiceId;
    return true;
  }

  /// Claims the single in-flight check for [questionId].
  ///
  /// A false result means there is no selection, the question is already
  /// checked, or another check is in progress. The caller must not issue a
  /// backend request in those cases.
  bool beginCheck(String questionId) {
    if (selectedChoiceFor(questionId) == null ||
        isChecking(questionId) ||
        isChecked(questionId)) {
      return false;
    }
    _checkingQuestionIds.add(questionId);
    return true;
  }

  /// Stores an authoritative result after both checking and answer recording
  /// succeed. Same-session revisits can then restore the exact feedback.
  void completeCheck({
    required String questionId,
    required QuizAnswerCheckResult result,
  }) {
    if (!_checkingQuestionIds.remove(questionId)) return;
    _checkedResults[questionId] = result;
  }

  /// Releases an in-flight check while retaining the student's selection so
  /// they can retry without having to choose the answer again.
  void failCheck(String questionId) {
    _checkingQuestionIds.remove(questionId);
  }

  /// Claims the single in-flight final submission for this screen visit.
  bool beginQuizSubmission() {
    if (_isSubmittingQuiz) return false;
    _isSubmittingQuiz = true;
    return true;
  }

  void endQuizSubmission() {
    _isSubmittingQuiz = false;
  }
}
