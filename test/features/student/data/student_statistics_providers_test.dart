import 'package:flutter_test/flutter_test.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/student_statistics.dart';
import 'package:instructional_math_app/features/student/data/student_statistics_providers.dart';

void main() {
  test(
    'lesson counts use unique available lessons and completed intersection',
    () {
      final StudentStatistics result = reconcileStudentLessonCounts(
        statistics: _statistics,
        availableLessons: <Lesson>[
          ...List<Lesson>.generate(
            10,
            (int index) =>
                _lesson('lesson-${index + 1}', title: 'Lesson ${index + 1}'),
          ),
          _lesson(
            'types-of-fractions-canonical',
            title: 'Types of Fractions',
            createdAt: DateTime.utc(2025),
          ),
          _lesson(
            'types-of-fractions-duplicate',
            title: 'Types of Fractions',
            createdAt: DateTime.utc(2026),
          ),
        ],
        completedLessonIds: <String>[
          ...List<String>.generate(7, (int index) => 'lesson-${index + 1}'),
          'types-of-fractions-canonical',
          'types-of-fractions-duplicate',
          'unavailable-lesson',
        ],
      );

      expect(result.summary.lessonsCompleted, 8);
      expect(result.summary.lessonsTotal, 11);
      expect(result.summary.averageScorePercent, 75);
    },
  );
}

Lesson _lesson(String id, {required String title, DateTime? createdAt}) {
  return Lesson(
    id: id,
    title: title,
    body: 'Body',
    sourceType: ContentSourceType.builtIn,
    createdAt: createdAt ?? DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

const StudentStatistics _statistics = StudentStatistics(
  summary: StudentSummaryTiles(
    studentId: 'student-1',
    bestEndlessStreak: 4,
    lessonsTotal: 12,
    lessonsCompleted: 8,
    quizzesCompleted: 2,
    averageScorePercent: 75,
    bestScorePercent: 90,
  ),
  lessonQuizScores: <LessonQuizScore>[],
  competencyMastery: <TopicMastery>[],
  overallAccuracy: OverallAccuracy(
    studentId: 'student-1',
    correct: 3,
    incorrect: 1,
    accuracyPercent: 75,
  ),
);
