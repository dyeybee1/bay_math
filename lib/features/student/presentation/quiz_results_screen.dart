import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/quiz.dart';
import '../../../core/models/quiz_attempt.dart';
import '../../../core/models/quiz_attempt_answer.dart';
import '../../../core/models/quiz_attempt_answer_choice_snapshot.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/quiz_attempts_repository.dart';
import '../../../core/widgets/widgets.dart';

final quizAttemptByIdProvider = FutureProvider.family<QuizAttempt, String>((ref, attemptId) {
  final QuizAttemptsRepository? repo = ref.watch(quizAttemptsRepositoryProvider);
  if (repo == null) throw const SessionExpiredFailure();
  return repo.fetchAttempt(attemptId);
});

final quizAttemptAnswersProvider = FutureProvider.family<List<QuizAttemptAnswer>, String>((ref, attemptId) {
  final QuizAttemptsRepository? repo = ref.watch(quizAttemptsRepositoryProvider);
  if (repo == null) throw const SessionExpiredFailure();
  return repo.fetchAnswers(attemptId);
});

/// Read-only — score and every answered question's frozen historical
/// snapshot data, never live `question_choices` rows (Phase 6 constraint:
/// "results screen ... plus the stored choice snapshots (frozen historical
/// data, never live question_choices)").
class QuizResultsScreen extends ConsumerWidget {
  const QuizResultsScreen({super.key, required this.quiz, required this.attemptId});

  final Quiz quiz;
  final String attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<QuizAttempt> attemptAsync = ref.watch(quizAttemptByIdProvider(attemptId));
    final AsyncValue<List<QuizAttemptAnswer>> answersAsync = ref.watch(quizAttemptAnswersProvider(attemptId));

    return Scaffold(
      appBar: AppBar(title: Text('${quiz.title} — Results')),
      body: AppPageContainer(
        scrollable: true,
        child: attemptAsync.when(
          loading: () => const AppLoadingIndicator(),
          error: (error, _) => AppErrorState(
            message: error is AppFailure ? error.message : 'Could not load these results.',
            onRetry: () => ref.invalidate(quizAttemptByIdProvider(attemptId)),
          ),
          data: (attempt) => answersAsync.when(
            loading: () => const AppLoadingIndicator(),
            error: (error, _) => AppErrorState(
              message: error is AppFailure ? error.message : 'Could not load these results.',
              onRetry: () => ref.invalidate(quizAttemptAnswersProvider(attemptId)),
            ),
            data: (answers) {
              final int correctCount = answers.where((a) => a.isCorrect).length;
              final int totalQuestions = attempt.totalQuestions ?? answers.length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppCard(
                    header: const Text('Score'),
                    child: Text(
                      '$correctCount out of $totalQuestions correct',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (answers.isEmpty)
                    const AppEmptyState(
                      icon: Icons.assignment_late_outlined,
                      title: 'No answers were recorded for this attempt',
                    )
                  else
                    for (int i = 0; i < answers.length; i++) ...<Widget>[
                      _AnswerResultCard(index: i, answer: answers[i]),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AnswerResultCard extends StatelessWidget {
  const _AnswerResultCard({required this.index, required this.answer});

  final int index;
  final QuizAttemptAnswer answer;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final List<QuizAttemptAnswerChoiceSnapshot> choices = [...answer.choiceSnapshots]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return AppCard(
      header: Text('Question ${index + 1}'),
      trailing: AppBadge(
        label: answer.isCorrect ? 'Correct' : 'Incorrect',
        variant: answer.isCorrect ? AppBadgeVariant.success : AppBadgeVariant.error,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(answer.questionTextSnapshot),
          const SizedBox(height: AppSpacing.sm),
          for (final choice in choices)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  Icon(
                    choice.wasCorrect ? Icons.check_circle : Icons.circle_outlined,
                    size: 18,
                    color: choice.wasCorrect
                        ? colorScheme.primary
                        : (choice.wasSelected ? colorScheme.error : colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      choice.choiceTextSnapshot,
                      style: choice.wasSelected ? const TextStyle(fontWeight: FontWeight.bold) : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
