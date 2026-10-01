import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/student_statistics.dart';
import '../../../core/providers/supabase_providers.dart';
import '../presentation/student_curriculum_order.dart';
import 'student_lessons_providers.dart';

/// Phase 8 (Student Statistics) — Part 2 deliverable.
///
/// This lives under `lib/features/student/data/` alongside the shared lesson
/// catalog provider. Repository providers remain in `core/providers/`, while
/// these one-shot feature fetch/composition providers stay with the student
/// feature that consumes them.
///
/// The full statistics payload for the signed-in student — the single
/// provider the Statistics screen watches. The quiz/statistics fields come
/// from [StudentStatisticsRepository.fetchAll]. Lesson counts are reconciled
/// against [studentVisibleLessonsProvider], the Student Lessons screen's own
/// source, and the student's completed progress IDs.
///
/// Throws [SessionExpiredFailure] if watched with no student signed in,
/// matching [studentVisibleLessonsProvider]'s / every other student-scoped
/// provider's existing convention in this codebase — screens under
/// `/student-*` are only ever reached after login, so this is a
/// "should not happen" guard, not a normal empty state.
final FutureProvider<StudentStatistics> studentStatisticsProvider =
    FutureProvider<StudentStatistics>((Ref ref) async {
      final statisticsRepository = ref.watch(
        studentStatisticsRepositoryProvider,
      );
      if (statisticsRepository == null) {
        throw const SessionExpiredFailure();
      }

      final Future<StudentStatistics> statisticsFuture =
          statisticsRepository.fetchAll();
      final Future<List<Lesson>> lessonsFuture = ref.watch(
        studentVisibleLessonsProvider.future,
      );
      final Future<Set<String>> completedIdsFuture = ref.watch(
        studentCompletedLessonIdsProvider.future,
      );

      return reconcileStudentLessonCounts(
        statistics: await statisticsFuture,
        availableLessons: await lessonsFuture,
        completedLessonIds: await completedIdsFuture,
      );
    });

/// One completed lesson together with its number in the visible curriculum.
/// The number is retained here because filtering first would incorrectly label
/// completed Lessons 3 and 4 as Lessons 1 and 2 in the drilldown.
class StudentCompletedLesson {
  const StudentCompletedLesson({
    required this.lessonNumber,
    required this.lesson,
  });

  final int lessonNumber;
  final Lesson lesson;
}

/// Ordered lesson details for the Statistics completion drilldown.
///
/// This composes the same visible catalog and completed-ID providers used by
/// the lesson landing page, so the detail rows cannot disagree with its badges
/// or with the reconciled summary count above.
final FutureProvider<List<StudentCompletedLesson>>
studentCompletedLessonsProvider = FutureProvider<List<StudentCompletedLesson>>((
  Ref ref,
) async {
  final List<Lesson> lessons = orderStudentLessons(
    await ref.watch(studentVisibleLessonsProvider.future),
  );
  final Set<String> completedIds = await ref.watch(
    studentCompletedLessonIdsProvider.future,
  );

  return <StudentCompletedLesson>[
    for (final (int index, Lesson lesson) in lessons.indexed)
      if (completedIds.contains(lesson.id))
        StudentCompletedLesson(lessonNumber: index + 1, lesson: lesson),
  ];
});

/// The single cache-coherency boundary for data changed by a successfully
/// completed Student quiz.
///
/// [studentStatisticsProvider] is intentionally retained rather than globally
/// auto-disposed, so it must be invalidated when its underlying quiz-attempt
/// rows change. If Statistics is mounted, Riverpod refetches it immediately;
/// otherwise the next visit starts a fresh fetch. Authentication and unrelated
/// Student providers are deliberately untouched.
final Provider<StudentStatisticsSynchronizer>
studentStatisticsSynchronizerProvider = Provider<StudentStatisticsSynchronizer>(
  (Ref ref) {
    return StudentStatisticsSynchronizer(
      onQuizCompleted: () => ref.invalidate(studentStatisticsProvider),
    );
  },
);

class StudentStatisticsSynchronizer {
  const StudentStatisticsSynchronizer({required this.onQuizCompleted});

  final void Function() onQuizCompleted;

  void quizCompleted() => onQuizCompleted();
}

/// Replaces the summary view's independent lesson counts with counts derived
/// from the same lesson collection displayed by the Student Lessons screen.
/// The set intersection excludes stale progress for unavailable lessons and
/// prevents duplicate completion rows from inflating the numerator.
StudentStatistics reconcileStudentLessonCounts({
  required StudentStatistics statistics,
  required Iterable<Lesson> availableLessons,
  required Iterable<String> completedLessonIds,
}) {
  final List<Lesson> catalogLessons = orderStudentLessons(
    availableLessons.toList(growable: false),
  );
  final Set<String> availableIds =
      catalogLessons.map((Lesson lesson) => lesson.id).toSet();
  final int completed =
      completedLessonIds.toSet().intersection(availableIds).length;

  return StudentStatistics(
    summary: statistics.summary.withLessonCounts(
      total: availableIds.length,
      completed: completed,
    ),
    lessonQuizScores: statistics.lessonQuizScores,
    competencyMastery: statistics.competencyMastery,
    overallAccuracy: statistics.overallAccuracy,
  );
}
