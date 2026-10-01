import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/student_statistics.dart';
import 'package:instructional_math_app/features/student/data/student_statistics_providers.dart';
import 'package:instructional_math_app/features/student/presentation/student_statistics_screen.dart';

void main() {
  testWidgets('completed lessons tile opens the lesson detail drilldown', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final List<StudentCompletedLesson> completedLessons =
        <StudentCompletedLesson>[
          StudentCompletedLesson(lessonNumber: 1, lesson: _lessonOne),
          StudentCompletedLesson(lessonNumber: 2, lesson: _lessonTwo),
        ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentStatisticsProvider.overrideWith(
            (Ref ref) => Future<StudentStatistics>.value(_statistics),
          ),
          studentCompletedLessonsProvider.overrideWith(
            (Ref ref) =>
                Future<List<StudentCompletedLesson>>.value(completedLessons),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const StudentStatisticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('lessons_completed_tile')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Completed lessons'), findsOneWidget);
    expect(find.text('2 of 10 lessons completed'), findsOneWidget);
    expect(find.text('LESSON 01'), findsOneWidget);
    expect(find.text('LESSON 02'), findsOneWidget);
    expect(find.text(_lessonOne.title), findsOneWidget);
    expect(find.text(_lessonTwo.title), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('completed_lesson_lesson-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

final DateTime _timestamp = DateTime.utc(2026, 1, 1);

final Lesson _lessonOne = Lesson(
  id: 'lesson-1',
  title: 'Addition and Subtraction of Numbers up to 1,000,000',
  body: 'Lesson body',
  sourceType: ContentSourceType.builtIn,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final Lesson _lessonTwo = Lesson(
  id: 'lesson-2',
  title: 'Comparing Numbers up to 1,000,000',
  body: 'Lesson body',
  sourceType: ContentSourceType.builtIn,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

const StudentStatistics _statistics = StudentStatistics(
  summary: StudentSummaryTiles(
    studentId: 'student-1',
    bestEndlessStreak: 0,
    lessonsTotal: 10,
    lessonsCompleted: 2,
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
