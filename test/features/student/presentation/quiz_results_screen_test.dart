import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/quiz.dart';
import 'package:instructional_math_app/core/models/quiz_attempt.dart';
import 'package:instructional_math_app/core/models/quiz_attempt_answer.dart';
import 'package:instructional_math_app/features/student/presentation/quiz_results_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('never shows a denominator below the recorded answer count', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(totalQuestions: 0));
    await tester.pumpAndSettle();

    expect(find.text('1 out of 1 correct'), findsOneWidget);
    expect(find.text('1 out of 0 correct'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a valid stored question total', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(totalQuestions: 3));
    await tester.pumpAndSettle();

    expect(find.text('1 out of 3 correct'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp({required int totalQuestions}) {
  return ProviderScope(
    overrides: [
      quizAttemptByIdProvider.overrideWith(
        (Ref ref, String attemptId) =>
            Future<QuizAttempt>.value(_attempt(totalQuestions: totalQuestions)),
      ),
      quizAttemptAnswersProvider.overrideWith(
        (Ref ref, String attemptId) =>
            Future<List<QuizAttemptAnswer>>.value(<QuizAttemptAnswer>[_answer]),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: QuizResultsScreen(quiz: _quiz, attemptId: 'attempt-1'),
    ),
  );
}

final DateTime _timestamp = DateTime.utc(2026, 1, 1);

final Quiz _quiz = Quiz(
  id: 'quiz-1',
  title: 'Eme lang',
  quizType: QuizType.internal,
  sourceType: ContentSourceType.teacher,
  createdBy: 'teacher-1',
  shuffleQuestions: false,
  shuffleChoices: false,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

QuizAttempt _attempt({required int totalQuestions}) => QuizAttempt(
  id: 'attempt-1',
  studentId: 'student-1',
  quizId: _quiz.id,
  sectionId: 'section-1',
  schoolYearId: 'school-year-1',
  attemptStatus: QuizAttemptStatus.active,
  totalQuestions: totalQuestions,
  score: 1,
  openedAt: _timestamp,
  submittedAt: _timestamp,
);

final QuizAttemptAnswer _answer = QuizAttemptAnswer(
  id: 'answer-1',
  quizAttemptId: 'attempt-1',
  questionId: 'question-1',
  questionTextSnapshot: 'What is 1 + 1?',
  selectedChoiceId: 'choice-2',
  isCorrect: true,
  answeredAt: _timestamp,
  choiceSnapshots: const [],
);
