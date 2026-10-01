import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/errors/app_failure.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/endless_question.dart';
import 'package:instructional_math_app/core/models/endless_quiz_leaderboard.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/lesson_page.dart';
import 'package:instructional_math_app/core/models/quiz.dart';
import 'package:instructional_math_app/core/models/quiz_answer_check_result.dart';
import 'package:instructional_math_app/core/models/quiz_attempt.dart';
import 'package:instructional_math_app/core/models/quiz_attempt_answer.dart';
import 'package:instructional_math_app/core/models/quiz_attempt_answer_choice_snapshot.dart';
import 'package:instructional_math_app/core/models/quiz_attempt_choice.dart';
import 'package:instructional_math_app/core/models/quiz_attempt_content.dart';
import 'package:instructional_math_app/core/models/quiz_attempt_question.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/models/student.dart';
import 'package:instructional_math_app/core/models/student_session.dart';
import 'package:instructional_math_app/core/models/student_statistics.dart';
import 'package:instructional_math_app/core/models/worked_example.dart';
import 'package:instructional_math_app/core/providers/student_profile_provider.dart';
import 'package:instructional_math_app/core/providers/student_session_provider.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/repositories/endless_quiz_repository.dart';
import 'package:instructional_math_app/core/repositories/quiz_attempts_repository.dart';
import 'package:instructional_math_app/core/repositories/quiz_content_repository.dart';
import 'package:instructional_math_app/features/splash/presentation/splash_screen.dart';
import 'package:instructional_math_app/features/student/data/endless_quiz_leaderboard_providers.dart';
import 'package:instructional_math_app/features/student/data/student_statistics_providers.dart';
import 'package:instructional_math_app/features/student/presentation/endless_quiz_full_leaderboard_screen.dart';
import 'package:instructional_math_app/features/student/presentation/endless_quiz_landing_screen.dart';
import 'package:instructional_math_app/features/student/presentation/endless_quiz_results_screen.dart';
import 'package:instructional_math_app/features/student/presentation/endless_quiz_screen.dart';
import 'package:instructional_math_app/features/student/presentation/lesson_viewer_screen.dart';
import 'package:instructional_math_app/features/student/presentation/quiz_results_screen.dart';
import 'package:instructional_math_app/features/student/presentation/quiz_taking_screen.dart';
import 'package:instructional_math_app/features/student/presentation/student_avatar_select_screen.dart';
import 'package:instructional_math_app/features/student/presentation/student_home_screen.dart';
import 'package:instructional_math_app/features/student/presentation/student_lessons_screen.dart';
import 'package:instructional_math_app/features/student/presentation/student_login_screen.dart';
import 'package:instructional_math_app/features/student/presentation/student_quizzes_screen.dart';
import 'package:instructional_math_app/features/student/presentation/student_statistics_screen.dart';
import 'package:instructional_math_app/features/student/presentation/worked_example_panel.dart';

const List<Size> _supportedLandscapeSizes = <Size>[
  Size(1024, 600),
  Size(1280, 720),
  Size(1280, 800),
  Size(1920, 1200),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Student landscape responsiveness audit', () {
    testWidgets('startup, login, home, and avatar picker fit', (
      WidgetTester tester,
    ) async {
      for (final Size size in _supportedLandscapeSizes) {
        await _pumpAt(tester, size, const SplashScreen(), settle: false);
        _expectNoLayoutException(tester, 'Splash at $size');

        await _pumpAt(tester, size, const StudentLoginScreen());
        _expectNoLayoutException(tester, 'Student login at $size');

        await _pumpAt(
          tester,
          size,
          const StudentHomeScreen(),
          overrides: _homeOverrides,
        );
        _expectNoLayoutException(tester, 'Student home at $size');

        await tester.tap(find.byTooltip('Student account menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Log out'));
        await tester.pumpAndSettle();
        _expectNoLayoutException(tester, 'Student logout dialog at $size');
        await tester.tap(find.text('Stay here'));
        await tester.pumpAndSettle();

        await _pumpAt(tester, size, const StudentAvatarSelectScreen());
        expect(
          tester.getBottomLeft(find.text('Confirm')).dy,
          lessThanOrEqualTo(size.height),
          reason: 'Avatar confirmation should be visible at $size',
        );
        _expectNoLayoutException(tester, 'Student avatar picker at $size');
      }

      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await _pumpAt(tester, const Size(1024, 600), const StudentLoginScreen());
      await _scrollTo(tester, find.text('Log in'));
      _expectNoLayoutException(tester, 'Student login with keyboard');
      tester.view.resetViewInsets();
    });

    testWidgets('lesson viewer data, empty, loading, and error states fit', (
      WidgetTester tester,
    ) async {
      for (final Size size in _supportedLandscapeSizes) {
        await _pumpAt(
          tester,
          size,
          LessonViewerScreen(lesson: _lesson),
          overrides: <Override>[
            studentSessionProvider.overrideWith((Ref ref) => _session),
            lessonProgressRepositoryProvider.overrideWith((Ref ref) => null),
            lessonPagesProvider.overrideWith(
              (Ref ref, String lessonId) =>
                  Future<List<LessonPage>>.value(_lessonPages),
            ),
          ],
        );
        _expectNoLayoutException(tester, 'Lesson viewer at $size');
        await tester.tap(find.byTooltip('Lesson outline'));
        await tester.pump(const Duration(milliseconds: 500));
        _expectNoLayoutException(tester, 'Lesson outline drawer at $size');

        await _pumpAt(
          tester,
          size,
          LessonViewerScreen(lesson: _lesson),
          overrides: <Override>[
            lessonPagesProvider.overrideWith(
              (Ref ref, String lessonId) =>
                  Future<List<LessonPage>>.value(const <LessonPage>[]),
            ),
          ],
        );
        _expectNoLayoutException(tester, 'Empty lesson viewer at $size');

        await _pumpAt(
          tester,
          size,
          LessonViewerScreen(lesson: _lesson),
          overrides: <Override>[
            lessonPagesProvider.overrideWith(
              (Ref ref, String lessonId) =>
                  Completer<List<LessonPage>>().future,
            ),
          ],
          settle: false,
        );
        _expectNoLayoutException(tester, 'Loading lesson viewer at $size');

        await _pumpAt(
          tester,
          size,
          LessonViewerScreen(lesson: _lesson),
          overrides: <Override>[
            lessonPagesProvider.overrideWith(
              (Ref ref, String lessonId) =>
                  Future<List<LessonPage>>.error(Exception('audit error')),
            ),
          ],
        );
        _expectNoLayoutException(tester, 'Error lesson viewer at $size');

        await _pumpAt(
          tester,
          size,
          const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: WorkedExamplePanel(workedExample: _workedExample),
            ),
          ),
        );
        await tester.tap(find.text('Reveal this step'));
        await tester.pump(const Duration(milliseconds: 200));
        _expectNoLayoutException(tester, 'Worked example panel at $size');
      }
    });

    testWidgets('quiz taking workspace and async states fit', (
      WidgetTester tester,
    ) async {
      for (final Size size in _supportedLandscapeSizes) {
        await _pumpAt(
          tester,
          size,
          QuizTakingScreen(quiz: _quiz),
          overrides: _quizTakingOverrides(content: _quizContent),
        );
        _expectNoLayoutException(tester, 'Quiz workspace at $size');
        final Finder firstChoice = find.textContaining(
          'A complete explanation',
        );
        await _scrollTo(tester, firstChoice);
        _expectNoLayoutException(tester, 'Long quiz choices at $size');
        await tester.tap(firstChoice);
        await tester.pump();
        await tester.tap(find.text('Check Answer'));
        await tester.pump();
        _expectNoLayoutException(tester, 'Quiz feedback panel at $size');
        expect(
          find.byKey(const ValueKey<String>('quiz-feedback-panel')),
          findsOneWidget,
        );

        await _pumpAt(
          tester,
          size,
          QuizTakingScreen(quiz: _quiz),
          overrides: _quizTakingOverrides(
            content: const QuizAttemptContent(
              questions: <QuizAttemptQuestion>[],
              answeredQuestionIds: <String>[],
            ),
          ),
        );
        _expectNoLayoutException(tester, 'Empty quiz workspace at $size');

        await _pumpAt(
          tester,
          size,
          QuizTakingScreen(quiz: _quiz),
          overrides: <Override>[
            quizActiveAttemptProvider.overrideWith(
              (Ref ref, String quizId) => Completer<QuizAttempt>().future,
            ),
          ],
          settle: false,
        );
        _expectNoLayoutException(tester, 'Loading quiz workspace at $size');

        await _pumpAt(
          tester,
          size,
          QuizTakingScreen(quiz: _quiz),
          overrides: <Override>[
            quizActiveAttemptProvider.overrideWith(
              (Ref ref, String quizId) =>
                  Future<QuizAttempt>.error(Exception('audit error')),
            ),
          ],
        );
        _expectNoLayoutException(tester, 'Error quiz workspace at $size');
      }
    });

    testWidgets('quiz results and long review content fit', (
      WidgetTester tester,
    ) async {
      for (final Size size in _supportedLandscapeSizes) {
        await _pumpAt(
          tester,
          size,
          QuizResultsScreen(quiz: _quiz, attemptId: _attempt.id),
          overrides: <Override>[
            quizAttemptByIdProvider.overrideWith(
              (Ref ref, String id) => Future<QuizAttempt>.value(_attempt),
            ),
            quizAttemptAnswersProvider.overrideWith(
              (Ref ref, String id) =>
                  Future<List<QuizAttemptAnswer>>.value(_answers),
            ),
          ],
        );
        final Finder reviewButton = find.byKey(
          const ValueKey<String>('review_answers_button'),
        );
        await tester.ensureVisible(reviewButton);
        await tester.tap(reviewButton);
        await tester.pumpAndSettle();
        await _scrollTo(tester, find.text('Question 6'));
        _expectNoLayoutException(tester, 'Quiz review at $size');

        await _pumpAt(
          tester,
          size,
          QuizResultsScreen(quiz: _quiz, attemptId: _attempt.id),
          overrides: <Override>[
            quizAttemptByIdProvider.overrideWith(
              (Ref ref, String id) => Completer<QuizAttempt>().future,
            ),
          ],
          settle: false,
        );
        _expectNoLayoutException(tester, 'Loading quiz results at $size');

        await _pumpAt(
          tester,
          size,
          QuizResultsScreen(quiz: _quiz, attemptId: _attempt.id),
          overrides: <Override>[
            quizAttemptByIdProvider.overrideWith(
              (Ref ref, String id) =>
                  Future<QuizAttempt>.error(Exception('audit error')),
            ),
          ],
        );
        _expectNoLayoutException(tester, 'Error quiz results at $size');

        await _pumpAt(
          tester,
          size,
          QuizResultsScreen(quiz: _quiz, attemptId: _attempt.id),
          overrides: <Override>[
            quizAttemptByIdProvider.overrideWith(
              (Ref ref, String id) => Future<QuizAttempt>.value(_attempt),
            ),
            quizAttemptAnswersProvider.overrideWith(
              (Ref ref, String id) => Future<List<QuizAttemptAnswer>>.value(
                const <QuizAttemptAnswer>[],
              ),
            ),
          ],
        );
        _expectNoLayoutException(tester, 'Empty quiz results at $size');
      }
    });

    testWidgets('statistics data, empty, loading, and error states fit', (
      WidgetTester tester,
    ) async {
      for (final Size size in _supportedLandscapeSizes) {
        await _pumpAt(
          tester,
          size,
          const StudentStatisticsScreen(),
          overrides: <Override>[
            studentStatisticsProvider.overrideWith(
              (Ref ref) => Future<StudentStatistics>.value(_statistics),
            ),
          ],
        );
        await _scrollTo(tester, find.text('Competency Mastery'));
        _expectNoLayoutException(tester, 'Student statistics at $size');

        await _pumpAt(
          tester,
          size,
          const StudentStatisticsScreen(),
          overrides: <Override>[
            studentStatisticsProvider.overrideWith(
              (Ref ref) => Future<StudentStatistics>.value(_emptyStatistics),
            ),
          ],
        );
        _expectNoLayoutException(tester, 'Empty statistics at $size');

        await _pumpAt(
          tester,
          size,
          const StudentStatisticsScreen(),
          overrides: <Override>[
            studentStatisticsProvider.overrideWith(
              (Ref ref) => Completer<StudentStatistics>().future,
            ),
          ],
          settle: false,
        );
        _expectNoLayoutException(tester, 'Loading statistics at $size');

        await _pumpAt(
          tester,
          size,
          const StudentStatisticsScreen(),
          overrides: <Override>[
            studentStatisticsProvider.overrideWith(
              (Ref ref) =>
                  Future<StudentStatistics>.error(Exception('audit error')),
            ),
          ],
        );
        _expectNoLayoutException(tester, 'Error statistics at $size');
      }
    });

    testWidgets('endless landing, modal, leaderboard, and results fit', (
      WidgetTester tester,
    ) async {
      for (final Size size in _supportedLandscapeSizes) {
        await _pumpAt(
          tester,
          size,
          const EndlessQuizLandingScreen(),
          overrides: _endlessOverrides,
        );
        _expectNoLayoutException(tester, 'Endless landing at $size');
        await tester.tap(find.byTooltip('How Endless Quiz works'));
        await tester.pumpAndSettle();
        _expectNoLayoutException(tester, 'Endless help dialog at $size');
        await tester.tap(find.text('Ready to practice'));
        await tester.pumpAndSettle();

        await _pumpAt(
          tester,
          size,
          const EndlessQuizLandingScreen(),
          overrides: <Override>[
            endlessQuizLeaderboardProvider.overrideWith(
              (Ref ref) => Completer<EndlessQuizLeaderboardData>().future,
            ),
          ],
          settle: false,
        );
        _expectNoLayoutException(tester, 'Loading Endless landing at $size');

        await _pumpAt(
          tester,
          size,
          const EndlessQuizLandingScreen(),
          overrides: <Override>[
            endlessQuizLeaderboardProvider.overrideWith(
              (Ref ref) => Future<EndlessQuizLeaderboardData>.error(
                Exception('audit error'),
              ),
            ),
          ],
        );
        _expectNoLayoutException(tester, 'Error Endless landing at $size');

        await _pumpAt(
          tester,
          size,
          const EndlessQuizFullLeaderboardScreen(),
          overrides: _endlessOverrides,
        );
        _expectNoLayoutException(tester, 'Full leaderboard at $size');
        await _scrollTo(
          tester,
          find.text('Student With A Deliberately Long Name Number 20'),
        );
        _expectNoLayoutException(tester, 'Full leaderboard final row at $size');

        await _pumpAt(
          tester,
          size,
          const EndlessQuizFullLeaderboardScreen(),
          overrides: <Override>[
            endlessQuizLeaderboardProvider.overrideWith(
              (Ref ref) => Future<EndlessQuizLeaderboardData>.error(
                Exception('audit error'),
              ),
            ),
          ],
        );
        _expectNoLayoutException(tester, 'Error leaderboard at $size');

        await _pumpAt(
          tester,
          size,
          const EndlessQuizScreen(),
          overrides: <Override>[
            ownStudentGradeLevelProvider.overrideWith(
              (Ref ref) => Future<GradeLevel?>.value(GradeLevel.grade4),
            ),
            endlessQuizRepositoryProvider.overrideWith(
              (Ref ref) => _AuditEndlessQuizRepository(
                questionFuture: Future<EndlessQuestion>.value(_endlessQuestion),
              ),
            ),
          ],
        );
        _expectNoLayoutException(tester, 'Endless gameplay at $size');
        await _scrollTo(
          tester,
          find.text(_endlessQuestion.choices.first.choiceText),
        );
        await tester.tap(find.text(_endlessQuestion.choices.first.choiceText));
        await tester.pump();
        _expectNoLayoutException(tester, 'Endless feedback at $size');
        await tester.pump(const Duration(milliseconds: 1800));
        await tester.pump();

        await _pumpAt(
          tester,
          size,
          const EndlessQuizScreen(),
          overrides: <Override>[
            endlessQuizRepositoryProvider.overrideWith(
              (Ref ref) => _AuditEndlessQuizRepository(
                questionFuture: Completer<EndlessQuestion>().future,
              ),
            ),
          ],
          settle: false,
        );
        _expectNoLayoutException(tester, 'Loading Endless gameplay at $size');

        await _pumpAt(
          tester,
          size,
          const EndlessQuizScreen(),
          overrides: <Override>[
            endlessQuizRepositoryProvider.overrideWith(
              (Ref ref) => _AuditEndlessQuizRepository(
                questionFuture: Future<EndlessQuestion>.error(
                  const ValidationFailure(
                    'A deliberately long question-loading error remains readable.',
                  ),
                ),
              ),
            ),
          ],
        );
        _expectNoLayoutException(tester, 'Error Endless gameplay at $size');

        await _pumpAt(
          tester,
          size,
          const EndlessQuizResultsScreen(
            questionsAnswered: 128,
            bestStreakSession: 42,
          ),
        );
        _expectNoLayoutException(tester, 'Endless results at $size');
      }
    });
  });
}

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  Widget screen, {
  List<Override> overrides = const <Override>[],
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: screen,
      ),
    ),
  );
  if (settle) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  } else {
    await tester.pump();
  }
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) return;
  await tester.ensureVisible(finder.last);
  await tester.pumpAndSettle();
}

void _expectNoLayoutException(WidgetTester tester, String reason) {
  expect(tester.takeException(), isNull, reason: reason);
}

final DateTime _timestamp = DateTime.utc(2026, 1, 1);

final StudentSession _session = StudentSession(
  accessToken: 'audit-token',
  expiresAt: DateTime.utc(2027),
  studentId: 'student-1',
);

final Student _student = Student(
  id: 'student-1',
  username: 'alexandria.student',
  fullName: 'Alexandria Montgomery-Rutherford',
  createdBy: 'teacher-1',
  status: StudentStatus.active,
  avatarId: 'rocket',
  bestEndlessStreak: 42,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final Lesson _lesson = Lesson(
  id: 'lesson-1',
  title: 'Understanding Multi-Step Problems With Fractions and Decimals',
  body: 'Lesson body',
  sourceType: ContentSourceType.builtIn,
  gradeLevel: GradeLevel.grade4,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final List<LessonPage> _lessonPages = <LessonPage>[
  LessonPage(
    id: 'page-1',
    lessonId: _lesson.id,
    displayOrder: 1,
    sectionType: 'explanation',
    title: 'A Long Guided Lesson Page Title That Must Wrap Without Colliding',
    body: List<String>.filled(
      8,
      'Fractions and decimals can represent the same quantity. Compare the place values carefully and explain each step in your reasoning.',
    ).join('\n\n'),
    createdAt: _timestamp,
    updatedAt: _timestamp,
  ),
  LessonPage(
    id: 'page-2',
    lessonId: _lesson.id,
    displayOrder: 2,
    sectionType: 'summary',
    title: 'Review and reflect',
    body: 'Use equivalent forms and verify the result.',
    createdAt: _timestamp,
    updatedAt: _timestamp,
  ),
];

final Quiz _quiz = Quiz(
  id: 'quiz-1',
  title:
      'A Very Long Quiz Title About Fractions, Decimals, and Multi-Step Reasoning',
  quizType: QuizType.internal,
  sourceType: ContentSourceType.builtIn,
  gradeLevel: GradeLevel.grade4,
  shuffleQuestions: false,
  shuffleChoices: false,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final QuizAttempt _attempt = QuizAttempt(
  id: 'attempt-1',
  studentId: _student.id,
  quizId: _quiz.id,
  sectionId: 'section-1',
  schoolYearId: 'school-year-1',
  attemptStatus: QuizAttemptStatus.active,
  totalQuestions: 6,
  openedAt: _timestamp,
);

const List<QuizAttemptChoice> _longChoices = <QuizAttemptChoice>[
  QuizAttemptChoice(
    choiceId: 'choice-a',
    choiceText:
        'A complete explanation involving equivalent fractions and careful place-value reasoning',
  ),
  QuizAttemptChoice(
    choiceId: 'choice-b',
    choiceText:
        'A different multi-step answer with several mathematical terms that must wrap cleanly',
  ),
  QuizAttemptChoice(
    choiceId: 'choice-c',
    choiceText:
        'Another plausible response designed to stress the available width of the answer card',
  ),
  QuizAttemptChoice(
    choiceId: 'choice-d',
    choiceText:
        'The final detailed option that remains readable and keeps its touch target intact',
  ),
];

const QuizAttemptContent _quizContent = QuizAttemptContent(
  questions: <QuizAttemptQuestion>[
    QuizAttemptQuestion(
      questionId: 'question-1',
      promptText:
          'A class completed three fifths of a project on Monday and another 0.25 of the whole project on Tuesday. Explain which operation finds the unfinished part and choose the best answer.',
      choices: _longChoices,
    ),
  ],
  answeredQuestionIds: <String>[],
);

const WorkedExample _workedExample = WorkedExample(
  operandA: '654321',
  operandB: '123456',
  operation: WorkedExampleOperation.subtraction,
  result: '530865',
  steps: <WorkedExampleStep>[
    WorkedExampleStep(
      columnLabel: 'Ones',
      digitA: 1,
      digitB: 6,
      borrowOut: 1,
      computationText: '11 − 6 = 5',
      resultDigit: 5,
      actionText:
          'Regroup one ten as ten ones, then write five in the ones place.',
    ),
    WorkedExampleStep(
      columnLabel: 'Tens',
      digitA: 2,
      digitB: 5,
      borrowIn: 1,
      borrowOut: 1,
      computationText: '11 − 5 = 6',
      resultDigit: 6,
      actionText: 'Regroup from the hundreds place and write six.',
    ),
    WorkedExampleStep(
      columnLabel: 'Hundreds',
      digitA: 3,
      digitB: 4,
      borrowIn: 1,
      borrowOut: 1,
      computationText: '12 − 4 = 8',
      resultDigit: 8,
      actionText: 'Regroup and write eight in the hundreds place.',
    ),
    WorkedExampleStep(
      columnLabel: 'Thousands',
      digitA: 4,
      digitB: 3,
      borrowIn: 1,
      computationText: '3 − 3 = 0',
      resultDigit: 0,
      actionText: 'Write zero in the thousands place.',
    ),
    WorkedExampleStep(
      columnLabel: 'Ten Thousands',
      digitA: 5,
      digitB: 2,
      computationText: '5 − 2 = 3',
      resultDigit: 3,
      actionText: 'Write three in the ten-thousands place.',
    ),
    WorkedExampleStep(
      columnLabel: 'Hundred Thousands',
      digitA: 6,
      digitB: 1,
      computationText: '6 − 1 = 5',
      resultDigit: 5,
      actionText: 'Write five in the hundred-thousands place.',
    ),
  ],
);

List<Override> _quizTakingOverrides({required QuizAttemptContent content}) {
  return <Override>[
    studentSessionProvider.overrideWith((Ref ref) => _session),
    quizContentRepositoryProvider.overrideWith(
      (Ref ref) => _AuditQuizContentRepository(),
    ),
    quizAttemptsRepositoryProvider.overrideWith(
      (Ref ref) => _AuditQuizAttemptsRepository(),
    ),
    quizActiveAttemptProvider.overrideWith(
      (Ref ref, String quizId) => Future<QuizAttempt>.value(_attempt),
    ),
    quizContentProvider.overrideWith(
      (Ref ref, String attemptId) => Future<QuizAttemptContent>.value(content),
    ),
  ];
}

final List<QuizAttemptAnswer> _answers = List<QuizAttemptAnswer>.generate(
  6,
  (int index) => QuizAttemptAnswer(
    id: 'answer-$index',
    quizAttemptId: _attempt.id,
    questionId: 'question-$index',
    questionTextSnapshot:
        'Question ${index + 1}: Explain why the selected operation is appropriate for this multi-step fractions and decimals problem.',
    selectedChoiceId: 'choice-a',
    isCorrect: index.isEven,
    answeredAt: _timestamp,
    choiceSnapshots: <QuizAttemptAnswerChoiceSnapshot>[
      QuizAttemptAnswerChoiceSnapshot(
        id: 'snapshot-$index-a',
        quizAttemptAnswerId: 'answer-$index',
        choiceTextSnapshot: _longChoices[0].choiceText,
        wasCorrect: index.isEven,
        wasSelected: true,
        displayOrder: 1,
      ),
      QuizAttemptAnswerChoiceSnapshot(
        id: 'snapshot-$index-b',
        quizAttemptAnswerId: 'answer-$index',
        choiceTextSnapshot: _longChoices[1].choiceText,
        wasCorrect: !index.isEven,
        wasSelected: false,
        displayOrder: 2,
      ),
    ],
  ),
);

final List<Override> _homeOverrides = <Override>[
  studentSessionProvider.overrideWith((Ref ref) => _session),
  ownStudentProfileProvider.overrideWith(
    (Ref ref) => Future<Student?>.value(_student),
  ),
  ownStudentGradeLevelProvider.overrideWith(
    (Ref ref) => Future<GradeLevel?>.value(GradeLevel.grade4),
  ),
  studentVisibleLessonsProvider.overrideWith(
    (Ref ref) => Future<List<Lesson>>.value(<Lesson>[_lesson]),
  ),
  studentVisibleQuizzesProvider.overrideWith(
    (Ref ref) => Future<List<Quiz>>.value(<Quiz>[_quiz]),
  ),
];

final List<LeaderboardEntry> _leaderboardEntries = <LeaderboardEntry>[
  for (int index = 1; index <= 20; index += 1)
    LeaderboardEntry(
      rank: index,
      fullName:
          index == 12
              ? _student.fullName
              : 'Student With A Deliberately Long Name Number $index',
      bestEndlessStreak: 60 - index,
    ),
];

final EndlessQuizLeaderboardData _leaderboardData = (
  topEntries: _leaderboardEntries,
  myRank: _leaderboardEntries[11],
);

final List<Override> _endlessOverrides = <Override>[
  ownStudentProfileProvider.overrideWith(
    (Ref ref) => Future<Student?>.value(_student),
  ),
  ownStudentGradeLevelProvider.overrideWith(
    (Ref ref) => Future<GradeLevel?>.value(GradeLevel.grade4),
  ),
  endlessQuizLeaderboardProvider.overrideWith(
    (Ref ref) => Future<EndlessQuizLeaderboardData>.value(_leaderboardData),
  ),
];

const EndlessQuestion _endlessQuestion = EndlessQuestion(
  questionId: 'endless-question-1',
  promptText:
      'Which detailed explanation correctly compares three fifths with sixty-two hundredths?',
  choices: _longChoices,
);

class _AuditQuizContentRepository implements QuizContentRepository {
  @override
  Future<QuizAnswerCheckResult> checkAnswer({
    required String attemptId,
    required String questionId,
    required String choiceId,
  }) async {
    return QuizAnswerCheckResult(
      isCorrect: true,
      explanationText: List<String>.filled(
        3,
        'Three fifths is sixty hundredths, so comparing the place values shows which decimal is greater.',
      ).join(' '),
      choices: const <CheckedChoice>[],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuditQuizAttemptsRepository implements QuizAttemptsRepository {
  @override
  Future<void> submitAnswer({
    required String attemptId,
    required String questionId,
    required String questionTextSnapshot,
    required String choiceId,
    required bool isCorrect,
    required List<CheckedChoice> choiceSnapshots,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuditEndlessQuizRepository implements EndlessQuizRepository {
  _AuditEndlessQuizRepository({required this.questionFuture});

  final Future<EndlessQuestion> questionFuture;

  @override
  Future<EndlessQuestion> fetchQuestion() => questionFuture;

  @override
  Future<bool> checkAnswer({
    required String questionId,
    required String choiceId,
  }) async => true;

  @override
  Future<void> finalizeSession({
    required String studentId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int questionsAnswered,
    required int bestStreakSession,
  }) async {}

  @override
  Future<List<LeaderboardEntry>> fetchLeaderboardTop({int limit = 50}) async =>
      _leaderboardEntries;

  @override
  Future<LeaderboardEntry> fetchMyRank() async => _leaderboardData.myRank;
}

const StudentStatistics _statistics = StudentStatistics(
  summary: StudentSummaryTiles(
    studentId: 'student-1',
    bestEndlessStreak: 42,
    lessonsTotal: 12,
    lessonsCompleted: 9,
    quizzesCompleted: 8,
    averageScorePercent: 86.5,
    bestScorePercent: 100,
  ),
  lessonQuizScores: <LessonQuizScore>[
    LessonQuizScore(
      lessonId: 'lesson-1',
      lessonTitle:
          'Understanding Equivalent Fractions and Decimal Relationships',
      quizId: 'quiz-1',
      score: 8,
      totalQuestions: 10,
      scorePercent: 80,
    ),
    LessonQuizScore(
      lessonId: 'lesson-2',
      lessonTitle: 'Solving Multi-Step Problems With Mixed Operations',
      quizId: 'quiz-2',
      score: 9,
      totalQuestions: 10,
      scorePercent: 90,
    ),
  ],
  competencyMastery: <TopicMastery>[
    TopicMastery(
      topic: 'Understanding Equivalent Fractions and Decimal Relationships',
      questionsTotal: 12,
      questionsCorrect: 10,
      masteryPercent: 83.3,
    ),
    TopicMastery(
      topic: 'Solving Multi-Step Problems With Mixed Operations',
      questionsTotal: 10,
      questionsCorrect: 9,
      masteryPercent: 90,
    ),
  ],
  overallAccuracy: OverallAccuracy(
    studentId: 'student-1',
    correct: 38,
    incorrect: 7,
    accuracyPercent: 84.4,
  ),
);

const StudentStatistics _emptyStatistics = StudentStatistics(
  summary: StudentSummaryTiles(
    studentId: 'student-1',
    bestEndlessStreak: 0,
    lessonsTotal: 0,
    lessonsCompleted: 0,
    quizzesCompleted: 0,
  ),
  lessonQuizScores: <LessonQuizScore>[],
  competencyMastery: <TopicMastery>[],
  overallAccuracy: OverallAccuracy(
    studentId: 'student-1',
    correct: 0,
    incorrect: 0,
  ),
);
