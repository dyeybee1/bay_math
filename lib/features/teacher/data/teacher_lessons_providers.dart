import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/lesson.dart';
import '../../../core/models/lesson_page.dart';
import '../../../core/providers/supabase_providers.dart';

/// Built-in lessons plus the calling Teacher's own. The repository deliberately
/// applies no client-side visibility filter; Supabase RLS remains authoritative.
final FutureProvider<List<Lesson>> lessonsProvider =
    FutureProvider<List<Lesson>>((Ref ref) {
      return ref.watch(lessonsRepositoryProvider).fetchVisibleToTeacher();
    });

/// Resolves a route lesson only from the same RLS-scoped collection shown in
/// the Teacher lesson catalog. Inaccessible and missing ids look identical.
final teacherVisibleLessonProvider = FutureProvider.family<Lesson?, String>((
  Ref ref,
  String lessonId,
) async {
  final List<Lesson> lessons = await ref.watch(lessonsProvider.future);
  for (final Lesson lesson in lessons) {
    if (lesson.id == lessonId) return lesson;
  }
  return null;
});

/// Ordered lesson content. Parent-lesson visibility is enforced again by the
/// existing `lesson_pages` RLS policy in the repository query.
final teacherLessonPagesProvider =
    FutureProvider.family<List<LessonPage>, String>((Ref ref, String lessonId) {
      return ref.watch(lessonsRepositoryProvider).fetchPages(lessonId);
    });
