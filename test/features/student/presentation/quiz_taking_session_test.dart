import 'package:flutter_test/flutter_test.dart';
import 'package:instructional_math_app/core/models/quiz_answer_check_result.dart';
import 'package:instructional_math_app/features/student/presentation/quiz_taking_session.dart';

void main() {
  const QuizAnswerCheckResult correctResult = QuizAnswerCheckResult(
    isCorrect: true,
    explanationText: 'The digit is in the hundreds place.',
    choices: <CheckedChoice>[],
  );

  group('QuizTakingSession', () {
    test('selection stays neutral and can change before checking', () {
      final QuizTakingSession session = QuizTakingSession();

      expect(session.selectedChoiceFor('question-1'), isNull);
      expect(session.checkedResultFor('question-1'), isNull);
      expect(session.beginCheck('question-1'), isFalse);

      expect(
        session.selectChoice(questionId: 'question-1', choiceId: 'choice-a'),
        isTrue,
      );
      expect(
        session.selectChoice(questionId: 'question-1', choiceId: 'choice-b'),
        isTrue,
      );

      expect(session.selectedChoiceFor('question-1'), 'choice-b');
      expect(session.checkedResultFor('question-1'), isNull);
    });

    test('one check locks the answer and rejects duplicate checks', () {
      final QuizTakingSession session = QuizTakingSession();
      session.selectChoice(questionId: 'question-1', choiceId: 'choice-b');

      expect(session.beginCheck('question-1'), isTrue);
      expect(session.beginCheck('question-1'), isFalse);
      expect(session.isChecking('question-1'), isTrue);
      expect(
        session.selectChoice(questionId: 'question-1', choiceId: 'choice-c'),
        isFalse,
      );

      session.completeCheck(questionId: 'question-1', result: correctResult);

      expect(session.isChecking('question-1'), isFalse);
      expect(session.checkedResultFor('question-1'), same(correctResult));
      expect(session.beginCheck('question-1'), isFalse);
      expect(
        session.selectChoice(questionId: 'question-1', choiceId: 'choice-c'),
        isFalse,
      );
    });

    test('failed check preserves selection and allows a retry', () {
      final QuizTakingSession session = QuizTakingSession();
      session.selectChoice(questionId: 'question-1', choiceId: 'choice-a');
      expect(session.beginCheck('question-1'), isTrue);

      session.failCheck('question-1');

      expect(session.selectedChoiceFor('question-1'), 'choice-a');
      expect(session.checkedResultFor('question-1'), isNull);
      expect(session.beginCheck('question-1'), isTrue);
    });

    test('keeps independent selected and checked state for revisits', () {
      final QuizTakingSession session = QuizTakingSession();
      session.selectChoice(questionId: 'question-1', choiceId: 'choice-a');
      session.beginCheck('question-1');
      session.completeCheck(questionId: 'question-1', result: correctResult);
      session.selectChoice(questionId: 'question-2', choiceId: 'choice-d');

      expect(session.selectedChoiceFor('question-1'), 'choice-a');
      expect(session.checkedResultFor('question-1'), same(correctResult));
      expect(session.selectedChoiceFor('question-2'), 'choice-d');
      expect(session.checkedResultFor('question-2'), isNull);
    });

    test('allows only one final submission at a time', () {
      final QuizTakingSession session = QuizTakingSession();

      expect(session.beginQuizSubmission(), isTrue);
      expect(session.isSubmittingQuiz, isTrue);
      expect(session.beginQuizSubmission(), isFalse);

      session.endQuizSubmission();

      expect(session.isSubmittingQuiz, isFalse);
      expect(session.beginQuizSubmission(), isTrue);
    });
  });

  group('quizPrimaryActionFor', () {
    test('requires checking before an unanswered question can advance', () {
      expect(
        quizPrimaryActionFor(
          isLastQuestion: false,
          hasFeedback: false,
          isResumeLocked: false,
          isReadOnly: false,
        ),
        QuizPrimaryAction.checkAnswer,
      );
      expect(
        quizPrimaryActionFor(
          isLastQuestion: false,
          hasFeedback: true,
          isResumeLocked: false,
          isReadOnly: false,
        ),
        QuizPrimaryAction.nextQuestion,
      );
    });

    test('reveals final feedback before finish and results actions', () {
      expect(
        quizPrimaryActionFor(
          isLastQuestion: true,
          hasFeedback: false,
          isResumeLocked: false,
          isReadOnly: false,
        ),
        QuizPrimaryAction.checkAnswer,
      );
      expect(
        quizPrimaryActionFor(
          isLastQuestion: true,
          hasFeedback: true,
          isResumeLocked: false,
          isReadOnly: false,
        ),
        QuizPrimaryAction.finishQuiz,
      );
      expect(
        quizPrimaryActionFor(
          isLastQuestion: true,
          hasFeedback: false,
          isResumeLocked: true,
          isReadOnly: false,
        ),
        QuizPrimaryAction.finishQuiz,
      );
      expect(
        quizPrimaryActionFor(
          isLastQuestion: true,
          hasFeedback: false,
          isResumeLocked: true,
          isReadOnly: true,
        ),
        QuizPrimaryAction.viewResults,
      );
    });
  });
}
