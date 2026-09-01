import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/features/student/presentation/lesson_viewer_screen.dart';
import 'package:instructional_math_app/features/student/presentation/student_curriculum_order.dart';
import 'package:instructional_math_app/features/student/presentation/student_lessons_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Student Lessons landscape catalog', () {
    testWidgets('fits supported landscape tablet viewports in two columns', (
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

        await tester.pumpWidget(_testApp(lessons: _lessons));
        await tester.pumpAndSettle();

        final Finder firstCard = find.byKey(const Key('lesson_card_0'));
        final Finder secondCard = find.byKey(const Key('lesson_card_1'));
        expect(firstCard, findsOneWidget);
        expect(secondCard, findsOneWidget);

        final Offset firstPosition = tester.getTopLeft(firstCard);
        final Offset secondPosition = tester.getTopLeft(secondCard);
        expect(secondPosition.dy, closeTo(firstPosition.dy, 0.1));
        expect(secondPosition.dx, greaterThan(firstPosition.dx));
        expect(tester.getSize(firstCard).width, lessThanOrEqualTo(700));
        expect(find.text(_lessons.first.title), findsOneWidget);
        expect(find.text(_lessons.first.body), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'viewport: $size');
      }
    });

    testWidgets('uses curriculum order and opens every selected lesson', (
      WidgetTester tester,
    ) async {
      await _setLandscapeSize(tester, const Size(1280, 800));
      await tester.pumpWidget(_testApp(lessons: _lessons));
      await tester.pumpAndSettle();
      final List<Lesson> orderedLessons = orderStudentLessons(_lessons);

      final Offset firstPosition = tester.getTopLeft(
        find.byKey(const Key('lesson_card_0')),
      );
      final Offset secondPosition = tester.getTopLeft(
        find.byKey(const Key('lesson_card_1')),
      );
      final Offset thirdPosition = tester.getTopLeft(
        find.byKey(const Key('lesson_card_2')),
      );

      expect(secondPosition.dy, closeTo(firstPosition.dy, 0.1));
      expect(secondPosition.dx, greaterThan(firstPosition.dx));
      expect(thirdPosition.dy, greaterThan(firstPosition.dy));
      expect(find.text('LESSON 01'), findsOneWidget);
      expect(find.text('LESSON 02'), findsOneWidget);
      expect(find.text('LESSON 03'), findsOneWidget);

      for (int index = 0; index < orderedLessons.length; index += 1) {
        final Finder card = find.byKey(Key('lesson_card_$index'));
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final LessonViewerScreen viewer = tester.widget<LessonViewerScreen>(
          find.byType(LessonViewerScreen),
        );
        expect(identical(viewer.lesson, orderedLessons[index]), isTrue);

        Navigator.of(tester.element(find.byType(LessonViewerScreen))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps loading, empty, and error states readable', (
      WidgetTester tester,
    ) async {
      await _setLandscapeSize(tester, const Size(1024, 600));
      final Completer<List<Lesson>> pendingLessons = Completer<List<Lesson>>();

      await tester.pumpWidget(
        _testApp(lessonLoader: () => pendingLessons.future),
      );
      await tester.pump();
      expect(find.text('Gathering your lessons…'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_testApp(lessons: const <Lesson>[]));
      await tester.pumpAndSettle();
      expect(find.text('No lessons yet'), findsOneWidget);
      expect(
        find.text('Check back once your teacher has assigned something.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

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
  });
}

Future<void> _setLandscapeSize(WidgetTester tester, Size size) async {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

Widget _testApp({
  List<Lesson>? lessons,
  Future<List<Lesson>> Function()? lessonLoader,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      studentVisibleLessonsProvider.overrideWith(
        (Ref ref) =>
            lessonLoader?.call() ?? Future<List<Lesson>>.value(lessons),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const StudentLessonsScreen(),
    ),
  );
}

final List<Lesson> _lessons = <Lesson>[
  _lesson(
    'lesson-1',
    'Addition and Subtraction of Numbers up to 1,000,000',
    'Learn to add and subtract whole numbers up to 1,000,000, with a place-value review and step-by-step worked examples for both operations.',
  ),
  _lesson(
    'lesson-2',
    'Comparing Numbers up to 1,000,000',
    'Learn to compare whole numbers using symbols and worked examples with numbers of different digit counts.',
  ),
  _lesson(
    'lesson-3',
    'Comparing, Adding, and Subtracting Fractions',
    'Learn how to compare fractions with the same denominator and how to add and subtract them clearly.',
  ),
  _lesson(
    'lesson-4',
    'Converting and Plotting Fractions',
    'Change mixed numbers into improper fractions and find and name fractions on a number line.',
  ),
  _lesson(
    'lesson-5',
    'A Deliberately Long Mathematics Lesson Title That Must Wrap Cleanly Across Multiple Lines',
    'This longer supporting description verifies that the catalog remains readable without overflowing at shorter landscape tablet sizes.',
  ),
];

Lesson _lesson(String id, String title, String body) {
  final DateTime timestamp = DateTime.utc(2026, 1, 1);
  return Lesson(
    id: id,
    title: title,
    body: body,
    sourceType: ContentSourceType.builtIn,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
