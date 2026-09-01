import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/quiz.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/models/student.dart';
import 'package:instructional_math_app/core/models/student_session.dart';
import 'package:instructional_math_app/core/providers/student_profile_provider.dart';
import 'package:instructional_math_app/core/providers/student_session_provider.dart';
import 'package:instructional_math_app/features/student/presentation/student_home_screen.dart';
import 'package:instructional_math_app/features/student/presentation/student_lessons_screen.dart';
import 'package:instructional_math_app/features/student/presentation/student_quizzes_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home counts match deduplicated lesson and assessment catalogs', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentSessionProvider.overrideWith(
            (Ref ref) => StudentSession(
              accessToken: 'test-token',
              expiresAt: DateTime.utc(2027),
              studentId: 'student-1',
            ),
          ),
          ownStudentProfileProvider.overrideWith(
            (Ref ref) => Future<Student?>.value(_student),
          ),
          ownStudentGradeLevelProvider.overrideWith(
            (Ref ref) => Future<GradeLevel?>.value(GradeLevel.grade4),
          ),
          studentVisibleLessonsProvider.overrideWith(
            (Ref ref) => Future<List<Lesson>>.value(_lessonsWithDuplicate),
          ),
          studentVisibleQuizzesProvider.overrideWith(
            (Ref ref) => Future<List<Quiz>>.value(_quizzesWithDuplicate),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const StudentHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10 lessons'), findsOneWidget);
    expect(find.text('13 assessments'), findsOneWidget);
    expect(find.text('11 lessons'), findsNothing);
    expect(find.text('14 assessments'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

final DateTime _timestamp = DateTime.utc(2026, 1, 1);

final Student _student = Student(
  id: 'student-1',
  username: 'jean',
  fullName: 'Jean Cyril Soriano',
  createdBy: 'teacher-1',
  status: StudentStatus.active,
  bestEndlessStreak: 0,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final List<Lesson> _lessonsWithDuplicate = <Lesson>[
  for (int index = 1; index <= 10; index += 1)
    _lesson('lesson-$index', 'Lesson $index'),
  _lesson('lesson-duplicate', 'Lesson 5'),
];

final List<Quiz> _quizzesWithDuplicate = <Quiz>[
  _quiz('pre-test', 'Grade 4 Pre-Test', assessmentType: AssessmentType.preTest),
  _quiz(
    'post-test',
    'Grade 4 Post-Test',
    assessmentType: AssessmentType.postTest,
  ),
  for (int index = 1; index <= 11; index += 1)
    _quiz('quiz-$index', 'Quiz $index: Topic $index'),
  _quiz('quiz-duplicate', 'Quiz 5: Topic 5'),
];

Lesson _lesson(String id, String title) => Lesson(
  id: id,
  title: title,
  body: 'Body',
  sourceType: ContentSourceType.builtIn,
  gradeLevel: GradeLevel.grade4,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

Quiz _quiz(String id, String title, {AssessmentType? assessmentType}) => Quiz(
  id: id,
  title: title,
  quizType: QuizType.internal,
  sourceType: ContentSourceType.builtIn,
  gradeLevel: GradeLevel.grade4,
  assessmentType: assessmentType,
  shuffleQuestions: false,
  shuffleChoices: false,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);
