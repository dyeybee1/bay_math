import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/lesson.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/widgets/widgets.dart';
import 'lesson_viewer_screen.dart';

/// Every lesson visible to the signed-in student — RLS
/// (`lessons_student_select`, 0015) resolves built-in + section-assigned
/// visibility automatically; this is the same query
/// `LessonsRepository.fetchVisibleToTeacher()` already runs for a Teacher,
/// just issued from the student-scoped client instead (see
/// `studentLessonsRepositoryProvider`'s doc comment for why that reuse is
/// safe).
final studentVisibleLessonsProvider = FutureProvider<List<Lesson>>((ref) {
  final repo = ref.watch(studentLessonsRepositoryProvider);
  if (repo == null) throw const SessionExpiredFailure();
  return repo.fetchVisibleToTeacher();
});

class StudentLessonsScreen extends ConsumerWidget {
  const StudentLessonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Lesson>> lessonsAsync = ref.watch(studentVisibleLessonsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lessons')),
      body: AppPageContainer(
        child: lessonsAsync.when(
          loading: () => const AppLoadingIndicator(),
          error: (error, _) => AppErrorState(
            message: error is AppFailure ? error.message : 'Could not load your lessons.',
            onRetry: () => ref.invalidate(studentVisibleLessonsProvider),
          ),
          data: (lessons) {
            if (lessons.isEmpty) {
              return const AppEmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No lessons yet',
                description: 'Check back once your teacher has assigned something.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(studentVisibleLessonsProvider),
              child: ListView.separated(
                itemCount: lessons.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final Lesson lesson = lessons[index];
                  return AppCard(
                    header: Text(lesson.title),
                    leading: const Icon(Icons.menu_book_outlined),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LessonViewerScreen(lesson: lesson),
                        ),
                      );
                    },
                    child: Text(
                      lesson.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
