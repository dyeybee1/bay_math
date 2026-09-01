import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/quiz.dart';
import 'package:instructional_math_app/core/models/quiz_attempt.dart';
import 'package:instructional_math_app/features/student/presentation/quiz_results_screen.dart';
import 'package:instructional_math_app/features/student/presentation/quiz_taking_screen.dart';
import 'package:instructional_math_app/features/student/presentation/student_quizzes_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Student Quizzes & Activities landscape catalog', () {
    testWidgets('fits supported landscape viewports in two columns', (
      WidgetTester tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final Size size in <Size>[
        const Size(1024, 600),
        const Size(1280, 720),
        const Size(1280, 800),
        const Size(1920, 1200),
      ]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;

        await tester.pumpWidget(_testApp());
        await tester.pumpAndSettle();

        final Finder firstCard = find.byKey(
          const Key('assessment_card_pre-start'),
        );
        final Finder secondCard = find.byKey(
          const Key('assessment_card_post-review'),
        );
        expect(firstCard, findsOneWidget);
        expect(secondCard, findsOneWidget);

        final Offset firstPosition = tester.getTopLeft(firstCard);
        final Offset secondPosition = tester.getTopLeft(secondCard);
        expect(secondPosition.dy, closeTo(firstPosition.dy, 0.1));
        expect(secondPosition.dx, greaterThan(firstPosition.dx));
        expect(tester.getSize(firstCard).width, lessThanOrEqualTo(700));
        expect(find.text(_quizzes.first.title), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'viewport: $size');
      }
    });

    testWidgets('uses assessment order, explicit types, and action labels', (
      WidgetTester tester,
    ) async {
      await _setLandscapeSize(tester, const Size(1280, 800));
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      final Offset firstPosition = tester.getTopLeft(
        find.byKey(const Key('assessment_card_pre-start')),
      );
      final Offset secondPosition = tester.getTopLeft(
        find.byKey(const Key('assessment_card_post-review')),
      );
      final Offset thirdPosition = tester.getTopLeft(
        find.byKey(const Key('assessment_card_regular-start')),
      );

      expect(secondPosition.dy, closeTo(firstPosition.dy, 0.1));
      expect(secondPosition.dx, greaterThan(firstPosition.dx));
      expect(thirdPosition.dy, greaterThan(firstPosition.dy));
      expect(find.text('QUIZ'), findsNWidgets(4));
      expect(find.text('PRE-TEST'), findsOneWidget);
      expect(find.text('POST-TEST'), findsOneWidget);
      expect(find.text('EXTERNAL ACTIVITY'), findsOneWidget);
      expect(_buttonLabel(tester, 'regular-start'), 'Start');
      expect(_buttonLabel(tester, 'pre-start'), 'Start');
      expect(_buttonLabel(tester, 'post-review'), 'Review');
      expect(_buttonLabel(tester, 'regular-review'), 'Review');
      expect(_buttonLabel(tester, 'regular-resume'), 'Resume');
      expect(_buttonLabel(tester, 'superseded-start'), 'Start');
      expect(tester.takeException(), isNull);
    });

    testWidgets('every Start and Resume opens its original quiz', (
      WidgetTester tester,
    ) async {
      await _setLandscapeSize(tester, const Size(1280, 800));
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      for (final String quizId in <String>[
        'regular-start',
        'pre-start',
        'regular-resume',
        'superseded-start',
      ]) {
        final Finder action = find.byKey(Key('assessment_action_$quizId'));
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final QuizTakingScreen screen = tester.widget<QuizTakingScreen>(
          find.byType(QuizTakingScreen),
        );
        expect(identical(screen.quiz, _quizById(quizId)), isTrue);

        Navigator.of(tester.element(find.byType(QuizTakingScreen))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('every Review opens the matching result and attempt', (
      WidgetTester tester,
    ) async {
      await _setLandscapeSize(tester, const Size(1280, 800));
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      for (final String quizId in <String>['post-review', 'regular-review']) {
        final Finder action = find.byKey(Key('assessment_action_$quizId'));
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final QuizResultsScreen screen = tester.widget<QuizResultsScreen>(
          find.byType(QuizResultsScreen),
        );
        expect(identical(screen.quiz, _quizById(quizId)), isTrue);
        expect(screen.attemptId, _attempts[quizId]!.id);

        Navigator.of(tester.element(find.byType(QuizResultsScreen))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps catalog and per-card async states readable', (
      WidgetTester tester,
    ) async {
      await _setLandscapeSize(tester, const Size(1024, 600));
      final Completer<List<Quiz>> pendingQuizzes = Completer<List<Quiz>>();

      await tester.pumpWidget(
        _testApp(quizLoader: () => pendingQuizzes.future),
      );
      await tester.pump();
      expect(find.text('Gathering your activities…'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_testApp(quizzes: const <Quiz>[]));
      await tester.pumpAndSettle();
      expect(find.text('No quizzes yet'), findsOneWidget);
      expect(
        find.text('Check back once your teacher has assigned something.'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _testApp(
          quizLoader: () => Future<List<Quiz>>.error(Exception('offline')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not load your quizzes.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.pumpWidget(_testApp(attemptErrorQuizId: 'regular-start'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('assessment_retry_regular-start')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

String _buttonLabel(WidgetTester tester, String quizId) {
  return tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(Key('assessment_action_$quizId')),
          matching: find.byType(Text),
        ),
      )
      .data!;
}

Future<void> _setLandscapeSize(WidgetTester tester, Size size) async {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

Widget _testApp({
  List<Quiz>? quizzes,
  Future<List<Quiz>> Function()? quizLoader,
  String? attemptErrorQuizId,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      studentVisibleQuizzesProvider.overrideWith(
        (Ref ref) =>
            quizLoader?.call() ?? Future<List<Quiz>>.value(quizzes ?? _quizzes),
      ),
      studentLatestAttemptForQuizProvider.overrideWith((Ref ref, String id) {
        if (id == attemptErrorQuizId) {
          return Future<QuizAttempt?>.error(Exception('attempt offline'));
        }
        return Future<QuizAttempt?>.value(_attempts[id]);
      }),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const StudentQuizzesScreen(),
    ),
  );
}

Quiz _quizById(String id) => _quizzes.singleWhere((Quiz quiz) => quiz.id == id);

final List<Quiz> _quizzes = <Quiz>[
  _quiz(
    id: 'regular-start',
    title: 'Quiz 1: Addition and Subtraction of Numbers up to 1,000,000',
  ),
  _quiz(
    id: 'pre-start',
    title: 'Grade 4 Pre-Test',
    assessmentType: AssessmentType.preTest,
  ),
  _quiz(
    id: 'post-review',
    title: 'Grade 4 Post-Test',
    assessmentType: AssessmentType.postTest,
  ),
  _quiz(id: 'regular-review', title: 'Comparing Whole Numbers Review'),
  _quiz(id: 'regular-resume', title: 'Fractions Skills Check'),
  _quiz(id: 'superseded-start', title: 'Multi-Step Problem Solving'),
  _quiz(
    id: 'external',
    title: 'Explore Fractions with GeoGebra',
    quizType: QuizType.externalActivity,
    externalUrl: 'https://www.geogebra.org/',
    externalPlatformHint: ExternalPlatformHint.geogebra,
  ),
];

final Map<String, QuizAttempt?> _attempts = <String, QuizAttempt?>{
  'regular-start': null,
  'pre-start': null,
  'post-review': _attempt('post-review', submitted: true),
  'regular-review': _attempt('regular-review', submitted: true),
  'regular-resume': _attempt('regular-resume'),
  'superseded-start': _attempt(
    'superseded-start',
    status: QuizAttemptStatus.superseded,
  ),
};

Quiz _quiz({
  required String id,
  required String title,
  QuizType quizType = QuizType.internal,
  AssessmentType? assessmentType,
  String? externalUrl,
  ExternalPlatformHint? externalPlatformHint,
}) {
  final DateTime timestamp = DateTime.utc(2026, 1, 1);
  return Quiz(
    id: id,
    title: title,
    quizType: quizType,
    sourceType: ContentSourceType.builtIn,
    externalUrl: externalUrl,
    externalPlatformHint: externalPlatformHint,
    assessmentType: assessmentType,
    shuffleQuestions: false,
    shuffleChoices: false,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

QuizAttempt _attempt(
  String quizId, {
  bool submitted = false,
  QuizAttemptStatus status = QuizAttemptStatus.active,
}) {
  return QuizAttempt(
    id: 'attempt-$quizId',
    studentId: 'student-1',
    quizId: quizId,
    sectionId: 'section-1',
    schoolYearId: 'school-year-1',
    attemptStatus: status,
    openedAt: DateTime.utc(2026, 1, 1),
    submittedAt: submitted ? DateTime.utc(2026, 1, 2) : null,
  );
}
