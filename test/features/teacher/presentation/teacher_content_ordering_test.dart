import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/quiz.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/features/teacher/presentation/lessons_screen.dart';
import 'package:instructional_math_app/features/teacher/presentation/quizzes_screen.dart';
import 'package:instructional_math_app/features/teacher/presentation/teacher_content_ordering.dart';

void main() {
  group('Teacher lesson ordering', () {
    test(
      'uses the Grade 4-6 curriculum order and numbers custom lessons 11+',
      () {
        final List<Lesson> lessons = <Lesson>[
          ..._builtInLessons(GradeLevel.grade6, _grade6Lessons.reversed),
          _teacherLesson(
            id: 'custom-2',
            title: 'Second custom lesson',
            createdAt: _timestamp.add(const Duration(days: 2)),
          ),
          ..._builtInLessons(GradeLevel.grade4, _grade4Lessons.reversed),
          _teacherLesson(
            id: 'custom-1',
            title: 'First custom lesson',
            createdAt: _timestamp.add(const Duration(days: 1)),
          ),
          ..._builtInLessons(GradeLevel.grade5, _grade5Lessons.reversed),
        ];

        final List<TeacherContentListEntry<Lesson>> ordered =
            orderTeacherLessons(lessons);

        expect(
          ordered.map(
            (TeacherContentListEntry<Lesson> entry) => entry.content.title,
          ),
          <String>[
            ..._grade4Lessons,
            ..._grade5Lessons,
            ..._grade6Lessons,
            'First custom lesson',
            'Second custom lesson',
          ],
        );
        expect(
          ordered.map(
            (TeacherContentListEntry<Lesson> entry) => entry.sequenceNumber,
          ),
          <int?>[..._oneToTen, ..._oneToTen, ..._oneToTen, 11, 12],
        );
      },
    );
  });

  group('Teacher quiz ordering', () {
    test('orders Quiz 1-10 numerically and numbers custom quizzes 11+', () {
      final List<Quiz> quizzes = <Quiz>[
        _teacherQuiz(
          id: 'custom-2',
          title: 'Second custom quiz',
          createdAt: _timestamp.add(const Duration(days: 2)),
        ),
        ..._builtInQuizzes(GradeLevel.grade4, _grade4Lessons.reversed),
        _teacherQuiz(
          id: 'custom-1',
          title: 'First custom quiz',
          createdAt: _timestamp.add(const Duration(days: 1)),
        ),
      ];

      final List<TeacherContentListEntry<Quiz>> ordered = orderTeacherQuizzes(
        quizzes,
      );

      expect(
        ordered.map(
          (TeacherContentListEntry<Quiz> entry) => entry.content.title,
        ),
        <String>[
          for (int index = 0; index < _grade4Lessons.length; index++)
            'Quiz ${index + 1}: ${_grade4Lessons[index]}',
          'First custom quiz',
          'Second custom quiz',
        ],
      );
      expect(
        ordered.map(
          (TeacherContentListEntry<Quiz> entry) => entry.sequenceNumber,
        ),
        <int?>[..._oneToTen, 11, 12],
      );
    });

    test('keeps pre-tests and post-tests outside regular quiz numbering', () {
      final List<Quiz> quizzes = <Quiz>[
        _builtInQuiz(
          id: 'post-test',
          title: 'Grade 4 Post-Test',
          gradeLevel: GradeLevel.grade4,
          assessmentType: AssessmentType.postTest,
        ),
        _builtInQuiz(
          id: 'quiz-10',
          title: 'Quiz 10: Final topic',
          gradeLevel: GradeLevel.grade4,
        ),
        _builtInQuiz(
          id: 'pre-test',
          title: 'Grade 4 Pre-Test',
          gradeLevel: GradeLevel.grade4,
          assessmentType: AssessmentType.preTest,
        ),
        _builtInQuiz(
          id: 'quiz-1',
          title: 'Quiz 1: First topic',
          gradeLevel: GradeLevel.grade4,
        ),
      ];

      final List<TeacherContentListEntry<Quiz>> ordered = orderTeacherQuizzes(
        quizzes,
      );

      expect(
        ordered.map((TeacherContentListEntry<Quiz> entry) => entry.content.id),
        <String>['pre-test', 'quiz-1', 'quiz-10', 'post-test'],
      );
      expect(
        ordered.map(
          (TeacherContentListEntry<Quiz> entry) => entry.sequenceNumber,
        ),
        <int?>[null, 1, 10, null],
      );
    });
  });

  group('Teacher content screen numbering', () {
    testWidgets(
      'Lessons screen preserves curriculum numbers and starts mine at 11',
      (WidgetTester tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1100, 800);
        addTearDown(tester.view.reset);
        final List<Lesson> lessons = <Lesson>[
          _teacherLesson(
            id: 'custom-lesson',
            title: 'My remediation lesson',
            createdAt: _timestamp.add(const Duration(days: 1)),
          ),
          ..._builtInLessons(GradeLevel.grade4, <String>[
            _grade4Lessons[9],
            _grade4Lessons[0],
          ]),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [lessonsProvider.overrideWith((Ref ref) => lessons)],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const LessonsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byKey(
              const ValueKey<String>('lesson-sequence-grade4-lesson-1'),
            ),
            matching: find.text('1'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(
              const ValueKey<String>('lesson-sequence-grade4-lesson-0'),
            ),
            matching: find.text('10'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(
              const ValueKey<String>('lesson-sequence-custom-lesson'),
            ),
            matching: find.text('11'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Quizzes screen shows a teacher-created quiz as Quiz 11', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1100, 800);
      addTearDown(tester.view.reset);
      final List<Quiz> quizzes = <Quiz>[
        _builtInQuiz(
          id: 'quiz-10',
          title: 'Quiz 10: ${_grade4Lessons[9]}',
          gradeLevel: GradeLevel.grade4,
        ),
        _teacherQuiz(
          id: 'custom-quiz',
          title: 'My remediation quiz',
          createdAt: _timestamp.add(const Duration(days: 1)),
        ),
        _builtInQuiz(
          id: 'quiz-1',
          title: 'Quiz 1: ${_grade4Lessons[0]}',
          gradeLevel: GradeLevel.grade4,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quizzesProvider.overrideWith((Ref ref) => quizzes),
            quizQuestionCountsProvider.overrideWith(
              (Ref ref) => <String, int>{
                for (final Quiz quiz in quizzes) quiz.id: 10,
              },
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const QuizzesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder firstQuiz = find.text('Quiz 1: ${_grade4Lessons[0]}');
      final Finder tenthQuiz = find.text('Quiz 10: ${_grade4Lessons[9]}');
      expect(firstQuiz, findsOneWidget);
      expect(tenthQuiz, findsOneWidget);
      expect(find.text('Quiz 11: My remediation quiz'), findsOneWidget);
      expect(
        tester.getTopLeft(firstQuiz).dy,
        lessThan(tester.getTopLeft(tenthQuiz).dy),
      );
      expect(tester.takeException(), isNull);
    });
  });
}

Iterable<Lesson> _builtInLessons(
  GradeLevel gradeLevel,
  Iterable<String> titles,
) sync* {
  int index = 0;
  for (final String title in titles) {
    yield Lesson(
      id: '${gradeLevel.name}-lesson-${index++}',
      title: title,
      body: '',
      sourceType: ContentSourceType.builtIn,
      gradeLevel: gradeLevel,
      createdAt: _timestamp,
      updatedAt: _timestamp,
    );
  }
}

Lesson _teacherLesson({
  required String id,
  required String title,
  required DateTime createdAt,
}) {
  return Lesson(
    id: id,
    title: title,
    body: '',
    sourceType: ContentSourceType.teacher,
    createdBy: 'teacher-1',
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

Iterable<Quiz> _builtInQuizzes(
  GradeLevel gradeLevel,
  Iterable<String> lessonTitles,
) sync* {
  final List<String> titles = lessonTitles.toList();
  for (int index = 0; index < titles.length; index++) {
    final int number = 10 - index;
    yield _builtInQuiz(
      id: '${gradeLevel.name}-quiz-$number',
      title: 'Quiz $number: ${titles[index]}',
      gradeLevel: gradeLevel,
    );
  }
}

Quiz _builtInQuiz({
  required String id,
  required String title,
  required GradeLevel gradeLevel,
  AssessmentType? assessmentType,
}) {
  return Quiz(
    id: id,
    title: title,
    quizType: QuizType.internal,
    sourceType: ContentSourceType.builtIn,
    gradeLevel: gradeLevel,
    assessmentType: assessmentType,
    shuffleQuestions: true,
    shuffleChoices: true,
    createdAt: _timestamp,
    updatedAt: _timestamp,
  );
}

Quiz _teacherQuiz({
  required String id,
  required String title,
  required DateTime createdAt,
}) {
  return Quiz(
    id: id,
    title: title,
    quizType: QuizType.internal,
    sourceType: ContentSourceType.teacher,
    createdBy: 'teacher-1',
    shuffleQuestions: true,
    shuffleChoices: true,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

final DateTime _timestamp = DateTime.utc(2026, 9, 13);

const List<int> _oneToTen = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

const List<String> _grade4Lessons = <String>[
  'Addition and Subtraction of Numbers up to 1,000,000',
  'Comparing Numbers up to 1,000,000',
  'Place Value of Whole Numbers',
  'Multiplication, Division, and MDAS',
  'Types of Fractions',
  'Converting and Plotting Fractions',
  'Comparing, Adding, and Subtracting Fractions',
  'Factors of Numbers up to 100',
  'Decimals and Their Relationship to Fractions',
  'Place Value and Value of Decimal Digits',
];

const List<String> _grade5Lessons = <String>[
  'Understanding 12-Hour and 24-Hour Time',
  'Solving Operations Using GMDAS',
  'Multiplying and Dividing Fractions',
  'Finding the Area of Plane Figures',
  'Adding, Subtracting, and Multiplying Decimals',
  'Using Divisibility Rules',
  'Prime and Composite Numbers',
  'Understanding and Solving Probability',
  'GMDAS with Fractions and Decimals',
  'Finding the Surface Area of Solid Figures',
];

const List<String> _grade6Lessons = <String>[
  'Operations with Fractions, Whole Numbers, and Mixed Numbers',
  'Operations with Decimals',
  'Understanding Ratio and Proportion',
  'Exponents and GEMDAS',
  'Volume of Cubes and Rectangular Prisms',
  'Perimeter and Area of Plane and Composite Figures',
  'Parts and Circumference of a Circle',
  'Area of a Circle',
  'Common Factors and Greatest Common Factor (GCF)',
  'Common Multiples and Least Common Multiple (LCM)',
];
