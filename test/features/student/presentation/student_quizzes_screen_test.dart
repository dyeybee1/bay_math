import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/app/router/app_routes.dart';
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
      expect(find.text('QUIZ 1'), findsOneWidget);
      expect(find.text('QUIZ'), findsNWidgets(3));
      expect(find.text('PRE-TEST'), findsOneWidget);
      expect(find.text('POST-TEST'), findsOneWidget);
      expect(find.text('EXTERNAL ACTIVITY'), findsOneWidget);
      expect(_buttonLabel(tester, 'regular-start'), 'Start');
      expect(_buttonLabel(tester, 'pre-start'), 'Start');
      expect(_buttonLabel(tester, 'post-review'), 'Review');
      expect(_buttonLabel(tester, 'regular-review'), 'Review');
      expect(_buttonLabel(tester, 'regular-resume'), 'Continue');
      expect(_buttonLabel(tester, 'superseded-start'), 'Start');
      expect(tester.takeException(), isNull);
    });

    testWidgets('card actions use the approved scoped tablet styling', (
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
        final GlobalKey captureKey = GlobalKey();
        await tester.pumpWidget(_testApp(captureKey: captureKey));
        await tester.pumpAndSettle();

        for (final String id in <String>['pre-start', 'post-review']) {
          _expectActionStyle(
            tester,
            id,
            background: const Color(0xFF2859DB),
            foreground: Colors.white,
            hasShadow: true,
          );
        }
        for (final String id in <String>['regular-start', 'regular-review']) {
          _expectActionStyle(
            tester,
            id,
            background: const Color(0xFFEEF3FF),
            foreground: const Color(0xFF3F65B9),
            hasShadow: false,
          );
        }

        if (const bool.fromEnvironment('CAPTURE_QUIZZES_BUTTONS')) {
          final RenderRepaintBoundary boundary = tester.renderObject(
            find.byKey(captureKey),
          );
          await tester.runAsync(() async {
            final ui.Image image = await boundary.toImage(pixelRatio: 1);
            final ByteData? bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final Directory directory = Directory(
              'build/quizzes_button_review',
            );
            await directory.create(recursive: true);
            await File(
              '${directory.path}/${size.width.toInt()}x${size.height.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
      'filters use real attempt states and update the visible count',
      (WidgetTester tester) async {
        await _setLandscapeSize(tester, const Size(1024, 768));
        await tester.pumpWidget(_testApp());
        await tester.pumpAndSettle();

        expect(find.text('7 activities'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('assessment_card_pre-start')),
            matching: find.text('Not started'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('assessment_card_post-review')),
            matching: find.text('Completed'),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('assessment_filter_quizzes')));
        await tester.pumpAndSettle();
        expect(find.text('4 activities'), findsOneWidget);
        expect(
          find.byKey(const Key('assessment_card_pre-start')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('assessment_card_regular-resume')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('assessment_card_regular-resume')),
            matching: find.text('In progress'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('assessment_card_superseded-start')),
            matching: find.text('Not started'),
          ),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const Key('assessment_filter_assessments')),
        );
        await tester.pumpAndSettle();
        expect(find.text('2 activities'), findsOneWidget);
        expect(
          find.byKey(const Key('assessment_card_pre-start')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('assessment_card_post-review')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('assessment_filter_completed')));
        await tester.pumpAndSettle();
        expect(find.text('2 activities'), findsOneWidget);
        expect(
          find.byKey(const Key('assessment_card_post-review')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('assessment_card_regular-review')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('assessment_card_pre-start')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('shows all records beyond prototype and keeps portrait usable', (
      WidgetTester tester,
    ) async {
      await _setLandscapeSize(tester, const Size(390, 844));
      final List<Quiz> many = <Quiz>[
        ..._quizzes,
        for (int index = 1; index <= 6; index++)
          _quiz(
            id: 'more-$index',
            title:
                'Extended learning activity $index with a very long descriptive title',
          ),
      ];
      await tester.pumpWidget(_testApp(quizzes: many, reduceMotion: true));
      await tester.pumpAndSettle();
      expect(find.text('13 activities'), findsOneWidget);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('assessment_card_more-6')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(
        find.textContaining('Extended learning activity 6'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('back button returns home from a direct catalog route', (
      WidgetTester tester,
    ) async {
      await _setLandscapeSize(tester, const Size(1024, 768));
      final GoRouter router = GoRouter(
        initialLocation: AppRoutes.studentQuizzes,
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.studentHome,
            builder: (_, _) => const Scaffold(body: Text('Student home')),
          ),
          GoRoute(
            path: AppRoutes.studentQuizzes,
            builder: (_, _) => const StudentQuizzesScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            studentVisibleQuizzesProvider.overrideWith(
              (Ref ref) => Future<List<Quiz>>.value(_quizzes),
            ),
            studentLatestAttemptForQuizProvider.overrideWith(
              (Ref ref, String id) => Future<QuizAttempt?>.value(_attempts[id]),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quizzes_back_button')));
      await tester.pumpAndSettle();
      expect(find.text('Student home'), findsOneWidget);
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

void _expectActionStyle(
  WidgetTester tester,
  String quizId, {
  required Color background,
  required Color foreground,
  required bool hasShadow,
}) {
  final Finder action = find.byKey(Key('assessment_action_$quizId'));
  final Finder buttonFinder = find.descendant(
    of: action,
    matching: find.byType(FilledButton),
  );
  final FilledButton button = tester.widget<FilledButton>(buttonFinder);
  final ButtonStyle style = button.style!;
  expect(style.backgroundColor!.resolve(<WidgetState>{}), background);
  expect(style.foregroundColor!.resolve(<WidgetState>{}), foreground);
  expect(style.minimumSize!.resolve(<WidgetState>{})!.height, 48);
  expect(
    style.padding!.resolve(<WidgetState>{}),
    const EdgeInsets.symmetric(horizontal: 14),
  );
  expect(style.textStyle!.resolve(<WidgetState>{})!.fontSize, 12);
  expect(
    style.textStyle!.resolve(<WidgetState>{})!.fontWeight,
    FontWeight.w800,
  );
  final RoundedRectangleBorder shape =
      style.shape!.resolve(<WidgetState>{})! as RoundedRectangleBorder;
  expect(shape.borderRadius, BorderRadius.circular(12));
  expect(tester.getSize(buttonFinder).height, greaterThanOrEqualTo(48));

  final Icon icon = tester.widget<Icon>(
    find.descendant(of: action, matching: find.byType(Icon)),
  );
  expect(icon.size, 18);
  final DecoratedBox decoration = tester.widget<DecoratedBox>(
    find.descendant(of: action, matching: find.byType(DecoratedBox)).first,
  );
  final BoxDecoration box = decoration.decoration as BoxDecoration;
  expect(box.boxShadow?.isNotEmpty ?? false, hasShadow);
  if (hasShadow) {
    expect(box.boxShadow!.single.color, const Color(0xFF1E46B5));
    expect(box.boxShadow!.single.offset, const Offset(0, 3));
  }
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
  bool reduceMotion = false,
  GlobalKey? captureKey,
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
      builder:
          (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
      home:
          captureKey == null
              ? const StudentQuizzesScreen()
              : RepaintBoundary(
                key: captureKey,
                child: const StudentQuizzesScreen(),
              ),
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
