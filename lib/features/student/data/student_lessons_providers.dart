import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/lesson.dart';
import '../../../core/providers/supabase_providers.dart';

/// Every lesson currently available to the signed-in student. The Student
/// Lessons catalog and every lesson-count consumer must share this provider so
/// they use the same RLS-filtered result rather than independently estimating
/// visibility.
final FutureProvider<List<Lesson>> studentVisibleLessonsProvider =
    FutureProvider<List<Lesson>>((Ref ref) {
      final repo = ref.watch(studentLessonsRepositoryProvider);
      if (repo == null) throw const SessionExpiredFailure();
      return repo.fetchVisibleToTeacher();
    });

/// Completed lesson IDs for the signed-in student.
///
/// Kept beside [studentVisibleLessonsProvider] so every student lesson surface
/// uses the same completion source. The lesson viewer invalidates this after a
/// successful completion write, refreshing both the catalog badges and the
/// Statistics drilldown without changing the persistence flow.
final FutureProvider<Set<String>> studentCompletedLessonIdsProvider =
    FutureProvider<Set<String>>((Ref ref) {
      final progressRepository = ref.watch(lessonProgressRepositoryProvider);
      if (progressRepository == null) throw const SessionExpiredFailure();
      return progressRepository.fetchCompletedLessonIds();
    });

/// Full persisted lesson statuses for the catalog badges. Completion-only
/// consumers keep their existing provider and count semantics.
final FutureProvider<Map<String, String>> studentLessonStatusesProvider =
    FutureProvider<Map<String, String>>((Ref ref) {
      final progressRepository = ref.watch(lessonProgressRepositoryProvider);
      if (progressRepository == null) throw const SessionExpiredFailure();
      return progressRepository.fetchLessonStatuses();
    });
