import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:instructional_math_app/app/router/app_routes.dart';
import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/features/student/data/student_lessons_providers.dart';
import 'package:instructional_math_app/features/student/presentation/lesson_viewer_screen.dart';
import 'package:instructional_math_app/features/student/presentation/student_curriculum_order.dart';
import 'package:instructional_math_app/features/student/presentation/student_lesson_illustration.dart';
import 'package:instructional_math_app/features/student/presentation/student_lessons_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('maps built-in math topics to their offline illustration families', () {
    expect(
      StudentLessonVisual.forLesson(
        _lesson('place', 'Place Value of Whole Numbers', ''),
      ).kind,
      StudentLessonArtKind.placeValue,
    );
    expect(
      StudentLessonVisual.forLesson(
        _lesson('fraction', 'Types of Fractions', ''),
      ).kind,
      StudentLessonArtKind.fractionCircle,
    );
    expect(
      StudentLessonVisual.forLesson(
        _lesson('decimal', 'Decimals and Their Relationship to Fractions', ''),
      ).accent,
      StudentLessonVisual.purple.accent,
    );
    expect(
      StudentLessonVisual.forLesson(
        _lesson('teacher', 'Custom Fractions', '', ContentSourceType.teacher),
      ).kind,
      StudentLessonArtKind.generic,
    );
  });

  testWidgets(
    'shows real ordered lessons in two tablet columns with a dynamic count',
    (WidgetTester tester) async {
      await _setSize(tester, const Size(1024, 600));
      await tester.pumpWidget(_testApp(lessons: _lessons));
      await tester.pumpAndSettle();

      final List<Lesson> ordered = orderStudentLessons(_lessons);
      final Finder first = find.byKey(
        ValueKey<String>('lesson_card_${ordered[0].id}'),
      );
      final Finder second = find.byKey(
        ValueKey<String>('lesson_card_${ordered[1].id}'),
      );
      expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
      expect(
        tester.getTopLeft(second).dx,
        greaterThan(tester.getTopLeft(first).dx),
      );
      expect(find.text('${_lessons.length} lessons'), findsOneWidget);
      expect(find.text('Choose your next math lesson.'), findsNothing);
      expect(find.text(ordered.first.title), findsOneWidget);
      expect(find.text(ordered.first.body), findsNothing);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('uses one column in portrait and preserves long lesson titles', (
    WidgetTester tester,
  ) async {
    await _setSize(tester, const Size(600, 900));
    await tester.pumpWidget(_testApp(lessons: _lessons));
    await tester.pumpAndSettle();

    final List<Lesson> ordered = orderStudentLessons(_lessons);
    final Finder first = find.byKey(
      ValueKey<String>('lesson_card_${ordered[0].id}'),
    );
    final Finder second = find.byKey(
      ValueKey<String>('lesson_card_${ordered[1].id}'),
    );
    expect(
      tester.getTopLeft(second).dy,
      greaterThan(tester.getBottomLeft(first).dy),
    );
    expect(tester.getTopLeft(second).dx, tester.getTopLeft(first).dx);
    expect(find.text(ordered[0].title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits supported tablet sizes and enlarged mobile text', (
    WidgetTester tester,
  ) async {
    for (final Size size in <Size>[
      const Size(1024, 768),
      const Size(1280, 800),
      const Size(360, 740),
    ]) {
      await _setSize(tester, size);
      await tester.pumpWidget(
        _testApp(lessons: _lessons, textScale: size.width < 600 ? 1.5 : 1),
      );
      await tester.pumpAndSettle();
      expect(find.text('5 lessons'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'viewport: $size');
    }
  });

  testWidgets(
    'renders persisted completed, in progress and not started statuses',
    (WidgetTester tester) async {
      await _setSize(tester, const Size(1280, 800));
      await tester.pumpWidget(
        _testApp(
          lessons: _lessons,
          statuses: const <String, String>{
            'lesson-1': 'completed',
            'lesson-2': 'in_progress',
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Not started'), findsNWidgets(_lessons.length - 2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opens the actual selected lesson in the existing viewer', (
    WidgetTester tester,
  ) async {
    await _setSize(tester, const Size(1280, 800));
    await tester.pumpWidget(_testApp(lessons: _lessons));
    await tester.pumpAndSettle();

    final Lesson selected = orderStudentLessons(_lessons)[1];
    final InkWell card = tester.widget<InkWell>(
      find.byKey(ValueKey<String>('lesson_tap_${selected.id}')),
    );
    card.onTap!();
    card.onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final LessonViewerScreen viewer = tester.widget<LessonViewerScreen>(
      find.byType(LessonViewerScreen),
    );
    expect(identical(viewer.lesson, selected), isTrue);
    expect(
      find.byType(LessonViewerScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'returns from lessons to student home through the existing route',
    (WidgetTester tester) async {
      await _setSize(tester, const Size(1024, 768));
      final GoRouter router = GoRouter(
        initialLocation: AppRoutes.studentHome,
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.studentHome,
            builder:
                (BuildContext context, GoRouterState state) => Scaffold(
                  body: TextButton(
                    onPressed: () => context.push(AppRoutes.studentLessons),
                    child: const Text('Student home'),
                  ),
                ),
          ),
          GoRoute(
            path: AppRoutes.studentLessons,
            builder:
                (BuildContext context, GoRouterState state) =>
                    const StudentLessonsScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentVisibleLessonsProvider.overrideWith(
              (Ref ref) => Future<List<Lesson>>.value(_lessons),
            ),
            studentLessonStatusesProvider.overrideWith(
              (Ref ref) =>
                  Future<Map<String, String>>.value(<String, String>{}),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            builder:
                (BuildContext context, Widget? child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: child!,
                ),
          ),
        ),
      );
      await tester.tap(find.text('Student home'));
      await tester.pumpAndSettle();
      expect(find.text('Lessons'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('lessons_back_button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Student home'), findsOneWidget);
      expect(find.text('Lessons'), findsNothing);
    },
  );

  testWidgets(
    'keeps teacher-authored extras and counts beyond the built-in set',
    (WidgetTester tester) async {
      await _setSize(tester, const Size(1280, 800));
      final List<Lesson> lessons = <Lesson>[
        ..._lessons,
        ...List<Lesson>.generate(
          12,
          (int i) => _lesson(
            'extra-$i',
            'Teacher lesson ${i + 1}',
            'Extra lesson body',
            ContentSourceType.teacher,
          ),
        ),
      ];
      await tester.pumpWidget(_testApp(lessons: lessons));
      await tester.pumpAndSettle();

      expect(find.text('17 lessons'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('lesson_card_extra-11')),
        350,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Teacher lesson 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows loading, empty, and retryable lesson errors', (
    WidgetTester tester,
  ) async {
    await _setSize(tester, const Size(1024, 600));
    final Completer<List<Lesson>> pending = Completer<List<Lesson>>();
    await tester.pumpWidget(_testApp(lessonLoader: () => pending.future));
    await tester.pump();
    expect(find.text('Gathering your lessons…'), findsOneWidget);

    await tester.pumpWidget(_testApp(lessons: const <Lesson>[]));
    await tester.pumpAndSettle();
    expect(find.text('No lessons yet'), findsOneWidget);

    await tester.pumpWidget(
      _testApp(
        lessonLoader: () => Future<List<Lesson>>.error(Exception('offline')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load your lessons.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not label progress when the status request fails', (
    WidgetTester tester,
  ) async {
    await _setSize(tester, const Size(1024, 600));
    await tester.pumpWidget(_testApp(lessons: _lessons, statusError: true));
    await tester.pumpAndSettle();
    expect(find.text('Could not load lesson progress.'), findsOneWidget);
    expect(find.text('Not started'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('runs decorative motion and honors reduced motion', (
    WidgetTester tester,
  ) async {
    await _setSize(tester, const Size(1024, 768));
    await tester.pumpWidget(
      _testApp(lessons: _lessons, animateBackground: true),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpWidget(_testApp(lessons: _lessons));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

Widget _testApp({
  List<Lesson>? lessons,
  Future<List<Lesson>> Function()? lessonLoader,
  Map<String, String> statuses = const <String, String>{},
  bool statusError = false,
  double textScale = 1,
  bool animateBackground = false,
}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    studentVisibleLessonsProvider.overrideWith(
      (Ref ref) => lessonLoader?.call() ?? Future<List<Lesson>>.value(lessons),
    ),
    studentLessonStatusesProvider.overrideWith(
      (Ref ref) =>
          statusError
              ? Future<Map<String, String>>.error(Exception('offline'))
              : Future<Map<String, String>>.value(statuses),
    ),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    builder:
        (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: !animateBackground,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
    home: const StudentLessonsScreen(),
  ),
);

final List<Lesson> _lessons = <Lesson>[
  _lesson(
    'lesson-1',
    'Addition and Subtraction of Numbers up to 1,000,000',
    'Add and subtract.',
  ),
  _lesson('lesson-2', 'Comparing Numbers up to 1,000,000', 'Compare numbers.'),
  _lesson(
    'lesson-3',
    'Comparing, Adding, and Subtracting Fractions',
    'Use fractions.',
  ),
  _lesson('lesson-4', 'Converting and Plotting Fractions', 'Plot fractions.'),
  _lesson(
    'lesson-5',
    'A Deliberately Long Mathematics Lesson Title That Must Wrap Cleanly Across Multiple Lines',
    'A long title.',
  ),
];

Lesson _lesson(
  String id,
  String title,
  String body, [
  ContentSourceType sourceType = ContentSourceType.builtIn,
]) {
  final DateTime timestamp = DateTime.utc(2026, 1, 1);
  return Lesson(
    id: id,
    title: title,
    body: body,
    sourceType: sourceType,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
