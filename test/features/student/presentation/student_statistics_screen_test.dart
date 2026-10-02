import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:instructional_math_app/app/router/app_routes.dart';
import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/models/student_statistics.dart';
import 'package:instructional_math_app/features/student/data/student_statistics_providers.dart';
import 'package:instructional_math_app/features/student/presentation/student_statistics_screen.dart';

void main() {
  testWidgets('tablet layouts keep four summary cards and two panels', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final Size size in <Size>[
      const Size(1024, 768),
      const Size(1280, 800),
    ]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await tester.pumpWidget(_app(_populated));
      await tester.pumpAndSettle();

      final Offset lessons = tester.getTopLeft(
        find.byKey(const Key('statistics_lessons_card')),
      );
      for (final String key in <String>[
        'statistics_average_card',
        'statistics_best_card',
        'statistics_streak_card',
      ]) {
        final Offset next = tester.getTopLeft(find.byKey(Key(key)));
        expect(next.dy, closeTo(lessons.dy, 0.1));
        expect(next.dx, greaterThan(lessons.dx));
      }
      final Offset scores = tester.getTopLeft(
        find.byKey(const Key('statistics_scores_panel')),
      );
      final Offset accuracy = tester.getTopLeft(
        find.byKey(const Key('statistics_accuracy_panel')),
      );
      expect(scores.dy, closeTo(accuracy.dy, 0.1));
      expect(accuracy.dx, greaterThan(scores.dx));
      _expectLessonCount();
      expect(find.text('52.5%'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('statistics_best_card')),
          matching: find.text('90%'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('statistics_streak_card')),
          matching: find.textContaining('12', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(find.text('70%'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'viewport: $size');
    }
  });

  testWidgets('score and topic details retain supplied values and counts', (
    WidgetTester tester,
  ) async {
    await _setSize(tester, const Size(1024, 768));
    await tester.pumpWidget(_app(_populated));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('score_row_lesson-1')));
    await tester.pumpAndSettle();
    expect(find.text('0%'), findsWidgets);
    expect(find.text('Score: 0 of 10 questions'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final Finder topic = find.byKey(
      const Key('mastery_topic_A very long competency topic name that wraps'),
    );
    await tester.ensureVisible(topic);
    await tester.pumpAndSettle();
    await tester.tap(topic);
    await tester.pumpAndSettle();
    expect(find.text('73.3%'), findsWidgets);
    expect(find.text('11 correct out of 15 answers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty results keep lesson completion and show quiz route', (
    WidgetTester tester,
  ) async {
    await _setSize(tester, const Size(1024, 768));
    await tester.pumpWidget(_app(_empty));
    await tester.pumpAndSettle();

    _expectLessonCount();
    expect(find.text('No quiz results yet'), findsNWidgets(2));
    expect(find.text('Your first score starts here.'), findsOneWidget);
    expect(find.text('No accuracy data yet'), findsOneWidget);
    expect(find.text('No mastery data yet'), findsOneWidget);
    expect(find.text('Take a quiz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a genuine zero score stays distinct from absent topic data', (
    WidgetTester tester,
  ) async {
    await _setSize(tester, const Size(1280, 800));
    await tester.pumpWidget(_app(_zero));
    await tester.pumpAndSettle();

    final Finder average = find.byKey(const Key('statistics_average_card'));
    final Finder best = find.byKey(const Key('statistics_best_card'));
    final Finder accuracy = find.byKey(const Key('statistics_accuracy_panel'));
    expect(
      find.descendant(of: average, matching: find.text('0%')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: best, matching: find.text('0%')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: accuracy, matching: find.text('0%')),
      findsOneWidget,
    );
    expect(find.text('0 correct out of 10 answered.'), findsOneWidget);
    expect(find.text('No accuracy data yet'), findsNothing);
    expect(find.text('No data yet'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('mastery_topic_No answers topic')),
        matching: find.byType(TweenAnimationBuilder<double>),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps final values without fill animation', (
    WidgetTester tester,
  ) async {
    await _setSize(tester, const Size(1024, 768));
    await tester.pumpWidget(_app(_populated, reduceMotion: true));
    await tester.pumpAndSettle();
    final Iterable<TweenAnimationBuilder<double>> fills = tester.widgetList(
      find.byType(TweenAnimationBuilder<double>),
    );
    expect(fills, isNotEmpty);
    for (final TweenAnimationBuilder<double> fill in fills) {
      expect(fill.duration, Duration.zero);
    }
    expect(find.text('70%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('partial data does not invent accuracy or mastery scores', (
    WidgetTester tester,
  ) async {
    await _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app(_partial, reduceMotion: true));
    await tester.pumpAndSettle();
    expect(find.text('No accuracy data yet'), findsOneWidget);
    expect(find.text('No data yet'), findsOneWidget);
    _expectLessonCount();
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait layout keeps long lessons and topics readable', (
    WidgetTester tester,
  ) async {
    await _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app(_populated, reduceMotion: true));
    await tester.pumpAndSettle();
    final Finder topic = find.byKey(
      const Key('mastery_topic_A very long competency topic name that wraps'),
    );
    await tester.ensureVisible(topic);
    await tester.pumpAndSettle();
    expect(topic, findsOneWidget);
    expect(
      find.text('A very long competency topic name that wraps'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'direct back, take a quiz, and view lessons use existing routes',
    (WidgetTester tester) async {
      await _setSize(tester, const Size(1024, 768));
      final GoRouter router = GoRouter(
        initialLocation: AppRoutes.studentStatistics,
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.studentHome,
            builder: (_, _) => const Scaffold(body: Text('Student home route')),
          ),
          GoRoute(
            path: AppRoutes.studentStatistics,
            builder: (_, _) => const StudentStatisticsScreen(),
          ),
          GoRoute(
            path: AppRoutes.studentQuizzes,
            builder: (_, _) => const Scaffold(body: Text('Quizzes route')),
          ),
          GoRoute(
            path: AppRoutes.studentLessons,
            builder: (_, _) => const Scaffold(body: Text('Lessons route')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(_empty, router: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a quiz'));
      await tester.pumpAndSettle();
      expect(find.text('Quizzes route'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('View lessons'));
      await tester.pumpAndSettle();
      expect(find.text('Lessons route'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('statistics_back_button')));
      await tester.pumpAndSettle();
      expect(find.text('Student home route'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loading and error states remain available', (
    WidgetTester tester,
  ) async {
    await _setSize(tester, const Size(1024, 768));
    final Completer<StudentStatistics> pending = Completer<StudentStatistics>();
    await tester.pumpWidget(_app(null, loader: () => pending.future));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await tester.pumpWidget(
      _app(
        null,
        loader: () => Future<StudentStatistics>.error(Exception('offline')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load your statistics.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

void _expectLessonCount() {
  expect(
    find.descendant(
      of: find.byKey(const Key('statistics_lessons_card')),
      matching: find.textContaining('6  of 10', findRichText: true),
    ),
    findsOneWidget,
  );
}

Widget _app(
  StudentStatistics? statistics, {
  Future<StudentStatistics> Function()? loader,
  GoRouter? router,
  bool reduceMotion = false,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: <Override>[
      studentStatisticsProvider.overrideWith(
        (Ref ref) =>
            loader?.call() ?? Future<StudentStatistics>.value(statistics!),
      ),
      studentCompletedLessonsProvider.overrideWith(
        (Ref ref) => Future<List<StudentCompletedLesson>>.value(
          const <StudentCompletedLesson>[],
        ),
      ),
    ],
    child:
        router == null
            ? MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              builder:
                  (BuildContext context, Widget? child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: reduceMotion),
                    child: child!,
                  ),
              home: const StudentStatisticsScreen(),
            )
            : MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              routerConfig: router,
            ),
  );
}

const StudentStatistics _populated = StudentStatistics(
  summary: StudentSummaryTiles(
    studentId: 'student-1',
    bestEndlessStreak: 12,
    lessonsTotal: 10,
    lessonsCompleted: 6,
    quizzesCompleted: 2,
    averageScorePercent: 52.5,
    bestScorePercent: 90,
  ),
  lessonQuizScores: <LessonQuizScore>[
    LessonQuizScore(
      lessonId: 'lesson-1',
      lessonTitle: 'Addition and subtraction',
      quizId: 'quiz-1',
      quizAttemptId: 'attempt-1',
      score: 0,
      totalQuestions: 10,
      scorePercent: 0,
    ),
    LessonQuizScore(
      lessonId: 'lesson-2',
      lessonTitle: 'Comparing numbers',
      quizId: 'quiz-2',
      quizAttemptId: 'attempt-2',
      score: 9,
      totalQuestions: 10,
      scorePercent: 90,
    ),
    LessonQuizScore(
      lessonId: 'lesson-3',
      lessonTitle: 'Place value',
      quizId: 'quiz-3',
    ),
  ],
  competencyMastery: <TopicMastery>[
    TopicMastery(
      topic: 'A very long competency topic name that wraps',
      questionsTotal: 15,
      questionsCorrect: 11,
      masteryPercent: 73.3,
    ),
    TopicMastery(
      topic: 'Factors',
      questionsTotal: 10,
      questionsCorrect: 0,
      masteryPercent: 0,
    ),
  ],
  overallAccuracy: OverallAccuracy(
    studentId: 'student-1',
    correct: 7,
    incorrect: 3,
    accuracyPercent: 70,
  ),
);

const StudentStatistics _empty = StudentStatistics(
  summary: StudentSummaryTiles(
    studentId: 'student-1',
    bestEndlessStreak: 0,
    lessonsTotal: 10,
    lessonsCompleted: 6,
    quizzesCompleted: 0,
  ),
  lessonQuizScores: <LessonQuizScore>[
    LessonQuizScore(
      lessonId: 'lesson-1',
      lessonTitle: 'Addition and subtraction',
      quizId: 'quiz-1',
    ),
  ],
  competencyMastery: <TopicMastery>[],
  overallAccuracy: OverallAccuracy(
    studentId: 'student-1',
    correct: 0,
    incorrect: 0,
  ),
);

const StudentStatistics _zero = StudentStatistics(
  summary: StudentSummaryTiles(
    studentId: 'student-1',
    bestEndlessStreak: 0,
    lessonsTotal: 10,
    lessonsCompleted: 6,
    quizzesCompleted: 1,
    averageScorePercent: 0,
    bestScorePercent: 0,
  ),
  lessonQuizScores: <LessonQuizScore>[
    LessonQuizScore(
      lessonId: 'lesson-1',
      lessonTitle: 'Addition and subtraction',
      quizId: 'quiz-1',
      quizAttemptId: 'attempt-1',
      score: 0,
      totalQuestions: 10,
      scorePercent: 0,
    ),
  ],
  competencyMastery: <TopicMastery>[
    TopicMastery(
      topic: 'Addition and subtraction',
      questionsTotal: 10,
      questionsCorrect: 0,
      masteryPercent: 0,
    ),
    TopicMastery(
      topic: 'No answers topic',
      questionsTotal: 0,
      questionsCorrect: 0,
      masteryPercent: 0,
    ),
  ],
  overallAccuracy: OverallAccuracy(
    studentId: 'student-1',
    correct: 0,
    incorrect: 10,
    accuracyPercent: 0,
  ),
);

const StudentStatistics _partial = StudentStatistics(
  summary: StudentSummaryTiles(
    studentId: 'student-1',
    bestEndlessStreak: 2,
    lessonsTotal: 10,
    lessonsCompleted: 6,
    quizzesCompleted: 1,
    averageScorePercent: 75,
    bestScorePercent: 75,
  ),
  lessonQuizScores: <LessonQuizScore>[],
  competencyMastery: <TopicMastery>[
    TopicMastery(
      topic: 'No answers topic',
      questionsTotal: 0,
      questionsCorrect: 0,
      masteryPercent: 0,
    ),
  ],
  overallAccuracy: OverallAccuracy(
    studentId: 'student-1',
    correct: 0,
    incorrect: 0,
  ),
);
