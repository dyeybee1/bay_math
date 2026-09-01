import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/quiz.dart';
import 'package:instructional_math_app/features/student/presentation/student_curriculum_order.dart';

void main() {
  group('Student curriculum ordering', () {
    test(
      'orders every grade lesson sequence and keeps custom lessons stable',
      () {
        for (final List<String> curriculum in <List<String>>[
          _grade4Lessons,
          _grade5Lessons,
          _grade6Lessons,
        ]) {
          final List<Lesson> shuffled = <Lesson>[
            _lesson('custom-a', 'Teacher enrichment A'),
            ...curriculum.reversed.indexed.map(
              ((int, String) entry) => _lesson('lesson-${entry.$1}', entry.$2),
            ),
            _lesson('custom-b', 'Teacher enrichment B'),
          ];

          final List<Lesson> ordered = orderStudentLessons(shuffled);

          expect(ordered.map((Lesson lesson) => lesson.title), <String>[
            ...curriculum,
            'Teacher enrichment A',
            'Teacher enrichment B',
          ]);
          expect(shuffled.first.title, 'Teacher enrichment A');
        }
      },
    );

    test(
      'orders pre-test, post-test, regular quiz numbers, custom quizzes, and activities',
      () {
        final List<Quiz> source = <Quiz>[
          _quiz('custom-a', 'Skills Check'),
          _quiz(
            'external',
            'Practice in GeoGebra',
            quizType: QuizType.externalActivity,
          ),
          _quiz('quiz-10', 'Quiz 10: Final Topic'),
          _quiz(
            'post',
            'Grade 4 Post-Test',
            assessmentType: AssessmentType.postTest,
          ),
          _quiz('quiz-2', 'Quiz 2: Second Topic'),
          _quiz(
            'pre',
            'Grade 4 Pre-Test',
            assessmentType: AssessmentType.preTest,
          ),
          _quiz('quiz-1', 'Quiz 1: First Topic'),
          _quiz('custom-b', 'Teacher Challenge'),
        ];

        final List<Quiz> ordered = orderStudentQuizzes(source);

        expect(ordered.map((Quiz quiz) => quiz.id), <String>[
          'pre',
          'post',
          'quiz-1',
          'quiz-2',
          'quiz-10',
          'custom-a',
          'custom-b',
          'external',
        ]);
        expect(source.first.id, 'custom-a');
      },
    );

    test(
      'collapses duplicate built-in lessons and quizzes to the oldest row',
      () {
        final Lesson newerLesson = _lesson(
          'lesson-newer',
          'Types of Fractions',
          createdAt: DateTime.utc(2026, 2, 1),
        );
        final Lesson canonicalLesson = _lesson(
          'lesson-canonical',
          'Types of Fractions',
          createdAt: DateTime.utc(2026, 1, 1),
        );
        final Lesson teacherCopy = _lesson(
          'lesson-teacher',
          'Types of Fractions',
          sourceType: ContentSourceType.teacher,
        );

        final List<Lesson> lessons = orderStudentLessons(<Lesson>[
          newerLesson,
          teacherCopy,
          canonicalLesson,
        ]);

        expect(lessons.map((Lesson lesson) => lesson.id), <String>[
          'lesson-canonical',
          'lesson-teacher',
        ]);

        final Quiz newerQuiz = _quiz(
          'quiz-newer',
          'Quiz 5: Types of Fractions',
          createdAt: DateTime.utc(2026, 2, 1),
        );
        final Quiz canonicalQuiz = _quiz(
          'quiz-canonical',
          'Quiz 5: Types of Fractions',
          createdAt: DateTime.utc(2026, 1, 1),
        );
        final Quiz teacherCopyQuiz = _quiz(
          'quiz-teacher',
          'Quiz 5: Types of Fractions',
          sourceType: ContentSourceType.teacher,
        );

        final List<Quiz> quizzes = orderStudentQuizzes(<Quiz>[
          newerQuiz,
          teacherCopyQuiz,
          canonicalQuiz,
        ]);

        expect(quizzes.map((Quiz quiz) => quiz.id), <String>[
          'quiz-canonical',
          'quiz-teacher',
        ]);
      },
    );
  });
}

final List<String> _grade4Lessons = <String>[
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

final List<String> _grade5Lessons = <String>[
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

final List<String> _grade6Lessons = <String>[
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

Lesson _lesson(
  String id,
  String title, {
  ContentSourceType sourceType = ContentSourceType.builtIn,
  DateTime? createdAt,
}) {
  final DateTime timestamp = createdAt ?? DateTime.utc(2026, 1, 1);
  return Lesson(
    id: id,
    title: title,
    body: 'Body',
    sourceType: sourceType,
    createdBy: sourceType == ContentSourceType.teacher ? 'teacher-1' : null,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

Quiz _quiz(
  String id,
  String title, {
  QuizType quizType = QuizType.internal,
  AssessmentType? assessmentType,
  ContentSourceType sourceType = ContentSourceType.builtIn,
  DateTime? createdAt,
}) {
  final DateTime timestamp = createdAt ?? DateTime.utc(2026, 1, 1);
  return Quiz(
    id: id,
    title: title,
    quizType: quizType,
    sourceType: sourceType,
    createdBy: sourceType == ContentSourceType.teacher ? 'teacher-1' : null,
    externalUrl:
        quizType == QuizType.externalActivity ? 'https://example.com' : null,
    assessmentType: assessmentType,
    shuffleQuestions: false,
    shuffleChoices: false,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
