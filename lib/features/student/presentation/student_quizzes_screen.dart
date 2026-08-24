import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/quiz.dart';
import '../../../core/models/quiz_attempt.dart';
import '../../../core/models/student_session.dart';
import '../../../core/providers/student_session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/quiz_attempts_repository.dart';
import '../../../core/repositories/quizzes_repository.dart';
import '../../../core/widgets/widgets.dart';
import 'quiz_results_screen.dart';
import 'quiz_taking_screen.dart';

/// Every quiz visible to the signed-in student — RLS
/// (`quizzes_student_select`, 0015) resolves built-in + section-assigned
/// visibility automatically; this is the same query
/// `QuizzesRepository.fetchVisibleToTeacher()` already runs for a Teacher,
/// just issued from the student-scoped client instead.
final studentVisibleQuizzesProvider = FutureProvider<List<Quiz>>((ref) {
  final QuizzesRepository? repo = ref.watch(studentQuizzesRepositoryProvider);
  if (repo == null) throw const SessionExpiredFailure();
  return repo.fetchVisibleToTeacher();
});

/// The student's most recent attempt for one Internal Quiz, if any — drives
/// the Start/Resume/Review label per row. Not requested for External
/// Activities (they're not attempt-tracked, per Phase 6 scope).
final studentLatestAttemptForQuizProvider = FutureProvider.family<QuizAttempt?, String>((ref, quizId) {
  final StudentSession? session = ref.watch(studentSessionProvider);
  final QuizAttemptsRepository? repo = ref.watch(quizAttemptsRepositoryProvider);
  if (session == null || repo == null) throw const SessionExpiredFailure();
  return repo.fetchLatestForQuiz(studentId: session.studentId, quizId: quizId);
});

class StudentQuizzesScreen extends ConsumerWidget {
  const StudentQuizzesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Quiz>> quizzesAsync = ref.watch(studentVisibleQuizzesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quizzes & Activities')),
      body: AppPageContainer(
        child: quizzesAsync.when(
          loading: () => const AppLoadingIndicator(),
          error: (error, _) => AppErrorState(
            message: error is AppFailure ? error.message : 'Could not load your quizzes.',
            onRetry: () => ref.invalidate(studentVisibleQuizzesProvider),
          ),
          data: (quizzes) {
            if (quizzes.isEmpty) {
              return const AppEmptyState(
                icon: Icons.quiz_outlined,
                title: 'No quizzes yet',
                description: 'Check back once your teacher has assigned something.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(studentVisibleQuizzesProvider),
              child: ListView.separated(
                itemCount: quizzes.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final Quiz quiz = quizzes[index];
                  return quiz.quizType == QuizType.internal
                      ? _InternalQuizTile(quiz: quiz)
                      : _ExternalActivityTile(quiz: quiz);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InternalQuizTile extends ConsumerWidget {
  const _InternalQuizTile({required this.quiz});

  final Quiz quiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<QuizAttempt?> attemptAsync = ref.watch(studentLatestAttemptForQuizProvider(quiz.id));

    return AppCard(
      header: Text(quiz.title),
      leading: const Icon(Icons.quiz_outlined),
      child: attemptAsync.when(
        loading: () => const SizedBox(
          height: 36,
          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
        error: (_, _) => AppButton(
          label: 'Retry',
          variant: AppButtonVariant.outlined,
          onPressed: () => ref.invalidate(studentLatestAttemptForQuizProvider(quiz.id)),
        ),
        data: (attempt) {
          final bool isSubmitted = attempt?.isSubmitted ?? false;
          final bool isActiveUnsubmitted =
              attempt != null && !isSubmitted && attempt.attemptStatus == QuizAttemptStatus.active;

          final String label = attempt == null
              ? 'Start'
              : isSubmitted
                  ? 'Review'
                  : isActiveUnsubmitted
                      ? 'Resume'
                      : 'Start';

          return Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: label,
              variant: isSubmitted ? AppButtonVariant.outlined : AppButtonVariant.primary,
              onPressed: () {
                if (isSubmitted) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => QuizResultsScreen(quiz: quiz, attemptId: attempt!.id),
                    ),
                  );
                } else {
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => QuizTakingScreen(quiz: quiz)))
                      .then((_) => ref.invalidate(studentLatestAttemptForQuizProvider(quiz.id)));
                }
              },
            ),
          );
        },
      ),
    );
  }
}

/// Plain link-out row — not attempt-tracked (Phase 6 scope note).
class _ExternalActivityTile extends StatelessWidget {
  const _ExternalActivityTile({required this.quiz});

  final Quiz quiz;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      header: Text(quiz.title),
      leading: const Icon(Icons.open_in_new),
      subtitle: Text(quiz.externalPlatformHint?.label ?? 'External Activity'),
      onTap: quiz.externalUrl == null
          ? null
          : () async {
              final Uri uri = Uri.parse(quiz.externalUrl!);
              final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!launched && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open this activity.')),
                );
              }
            },
      child: const Text('Tap to open'),
    );
  }
}
