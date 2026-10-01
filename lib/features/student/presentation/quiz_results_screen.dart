import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/quiz.dart';
import '../../../core/models/quiz_attempt.dart';
import '../../../core/models/quiz_attempt_answer.dart';
import '../../../core/models/quiz_attempt_answer_choice_snapshot.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/quiz_attempts_repository.dart';
import 'endless_quiz_design.dart';

final quizAttemptByIdProvider = FutureProvider.family<QuizAttempt, String>((
  ref,
  attemptId,
) {
  final QuizAttemptsRepository? repo = ref.watch(
    quizAttemptsRepositoryProvider,
  );
  if (repo == null) throw const SessionExpiredFailure();
  return repo.fetchAttempt(attemptId);
});

final quizAttemptAnswersProvider =
    FutureProvider.family<List<QuizAttemptAnswer>, String>((ref, attemptId) {
      final QuizAttemptsRepository? repo = ref.watch(
        quizAttemptsRepositoryProvider,
      );
      if (repo == null) throw const SessionExpiredFailure();
      return repo.fetchAnswers(attemptId);
    });

/// A focused completion experience. Frozen per-question snapshots live on the
/// separate [QuizReviewScreen], while score computation remains unchanged.
class QuizResultsScreen extends ConsumerWidget {
  const QuizResultsScreen({
    super.key,
    required this.quiz,
    required this.attemptId,
  });

  final Quiz quiz;
  final String attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<QuizAttempt> attemptAsync = ref.watch(
      quizAttemptByIdProvider(attemptId),
    );
    final AsyncValue<List<QuizAttemptAnswer>> answersAsync = ref.watch(
      quizAttemptAnswersProvider(attemptId),
    );

    return _QuizPageFrame(
      title: 'Quiz complete',
      subtitle: quiz.title,
      onBack: () => Navigator.maybePop(context),
      child: attemptAsync.when(
        loading:
            () => const EndlessStatePanel(
              title: 'Preparing your results',
              message: 'Your score summary will be ready in a moment.',
              icon: Icons.auto_graph_rounded,
              loading: true,
            ),
        error:
            (Object error, StackTrace _) => EndlessStatePanel(
              title: 'Could not load your results',
              message: _errorMessage(error),
              icon: Icons.cloud_off_outlined,
              actionLabel: 'Try again',
              onAction:
                  () => ref.invalidate(quizAttemptByIdProvider(attemptId)),
            ),
        data:
            (QuizAttempt attempt) => answersAsync.when(
              loading:
                  () => const EndlessStatePanel(
                    title: 'Gathering your answers',
                    message: 'We are building your result summary.',
                    icon: Icons.fact_check_outlined,
                    loading: true,
                  ),
              error:
                  (Object error, StackTrace _) => EndlessStatePanel(
                    title: 'Could not load your answers',
                    message: _errorMessage(error),
                    icon: Icons.cloud_off_outlined,
                    actionLabel: 'Try again',
                    onAction:
                        () => ref.invalidate(
                          quizAttemptAnswersProvider(attemptId),
                        ),
                  ),
              data: (List<QuizAttemptAnswer> answers) {
                final int correctCount =
                    answers
                        .where((QuizAttemptAnswer answer) => answer.isCorrect)
                        .length;
                // Keep the established legacy fallback: an old stored total
                // must never be lower than the frozen answers being shown.
                final int storedTotalQuestions = attempt.totalQuestions ?? 0;
                final int totalQuestions =
                    storedTotalQuestions < answers.length
                        ? answers.length
                        : storedTotalQuestions;

                return _QuizCompletionContent(
                  quiz: quiz,
                  answers: answers,
                  correctCount: correctCount,
                  totalQuestions: totalQuestions,
                );
              },
            ),
      ),
    );
  }
}

class _QuizCompletionContent extends StatelessWidget {
  const _QuizCompletionContent({
    required this.quiz,
    required this.answers,
    required this.correctCount,
    required this.totalQuestions,
  });

  final Quiz quiz;
  final List<QuizAttemptAnswer> answers;
  final int correctCount;
  final int totalQuestions;

  @override
  Widget build(BuildContext context) {
    final double ratio =
        totalQuestions == 0 ? 0 : correctCount / totalQuestions;
    final int percentage = (ratio * 100).round();
    final _PerformanceMessage performance = _performanceFor(percentage);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          EndlessPaper(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFFEAF2FC), Color(0xFFF9FBFE)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: LayoutBuilder(
                    builder: (
                      BuildContext context,
                      BoxConstraints constraints,
                    ) {
                      final bool stacked = constraints.maxWidth < 640;
                      final Widget score = _ScoreRing(
                        ratio: ratio,
                        percentage: percentage,
                      );
                      final Widget message = _CompletionMessage(
                        quiz: quiz,
                        performance: performance,
                        correctCount: correctCount,
                        totalQuestions: totalQuestions,
                      );
                      return stacked
                          ? Column(
                            children: <Widget>[
                              score,
                              const SizedBox(height: AppSpacing.lg),
                              message,
                            ],
                          )
                          : Row(
                            children: <Widget>[
                              score,
                              const SizedBox(width: AppSpacing.xl),
                              Expanded(child: message),
                            ],
                          );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _ResultMetrics(
            correctCount: correctCount,
            totalQuestions: totalQuestions,
            percentage: percentage,
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stacked = constraints.maxWidth < 560;
              final Widget reviewButton = EndlessPrimaryButton(
                key: const ValueKey<String>('review_answers_button'),
                label: 'Review answers',
                icon: Icons.fact_check_outlined,
                expand: stacked,
                onPressed:
                    answers.isEmpty
                        ? null
                        : () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => QuizReviewScreen(
                                    quiz: quiz,
                                    answers: answers,
                                    correctCount: correctCount,
                                    totalQuestions: totalQuestions,
                                  ),
                            ),
                          );
                        },
              );
              final Widget backButton = EndlessSecondaryButton(
                key: const ValueKey<String>('back_to_quizzes_button'),
                label: 'Back to quizzes',
                icon: Icons.arrow_back_rounded,
                expand: stacked,
                onPressed: () => Navigator.maybePop(context),
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    reviewButton,
                    const SizedBox(height: AppSpacing.sm),
                    backButton,
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  reviewButton,
                  const SizedBox(width: AppSpacing.sm),
                  backButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.ratio, required this.percentage});

  final double ratio;
  final int percentage;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Score $percentage percent',
      child: SizedBox.square(
        dimension: 150,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            SizedBox.square(
              dimension: 150,
              child: CircularProgressIndicator(
                value: ratio.clamp(0, 1),
                strokeWidth: 14,
                strokeCap: StrokeCap.round,
                color: AppColors.secondary,
                backgroundColor: AppColors.secondaryContainer,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '$percentage%',
                  style: endlessTitleStyle(32, color: AppColors.secondary),
                ),
                Text(
                  'SCORE',
                  style: endlessBodyStyle(
                    9,
                    weight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ).copyWith(letterSpacing: 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionMessage extends StatelessWidget {
  const _CompletionMessage({
    required this.quiz,
    required this.performance,
    required this.correctCount,
    required this.totalQuestions,
  });

  final Quiz quiz;
  final _PerformanceMessage performance;
  final int correctCount;
  final int totalQuestions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: performance.softColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'QUIZ COMPLETE',
            style: endlessBodyStyle(
              9,
              weight: FontWeight.w800,
              color: performance.color,
            ).copyWith(letterSpacing: 0.9),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          performance.title,
          style: endlessTitleStyle(27, color: performance.color),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(quiz.title, style: endlessTitleStyle(17)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '$correctCount out of $totalQuestions correct',
          style: endlessBodyStyle(
            14,
            weight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          performance.message,
          style: endlessBodyStyle(13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ResultMetrics extends StatelessWidget {
  const _ResultMetrics({
    required this.correctCount,
    required this.totalQuestions,
    required this.percentage,
  });

  final int correctCount;
  final int totalQuestions;
  final int percentage;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.center,
      children: <Widget>[
        _MetricCard(
          icon: Icons.check_circle_outline_rounded,
          label: 'Correct',
          value: '$correctCount',
        ),
        _MetricCard(
          icon: Icons.quiz_outlined,
          label: 'Questions',
          value: '$totalQuestions',
        ),
        _MetricCard(
          icon: Icons.auto_graph_rounded,
          label: 'Score',
          value: '$percentage%',
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: EndlessPaper(
        elevated: false,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(value, style: endlessTitleStyle(18)),
                  Text(
                    label,
                    style: endlessBodyStyle(
                      10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Static, read-only review of the frozen historical answer snapshots.
class QuizReviewScreen extends StatelessWidget {
  const QuizReviewScreen({
    super.key,
    required this.quiz,
    required this.answers,
    required this.correctCount,
    required this.totalQuestions,
  });

  final Quiz quiz;
  final List<QuizAttemptAnswer> answers;
  final int correctCount;
  final int totalQuestions;

  @override
  Widget build(BuildContext context) {
    return _QuizPageFrame(
      title: 'Review answers',
      subtitle: quiz.title,
      onBack: () => Navigator.maybePop(context),
      maxWidth: 900,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ReviewSummary(
              correctCount: correctCount,
              totalQuestions: totalQuestions,
            ),
            const SizedBox(height: AppSpacing.md),
            for (int index = 0; index < answers.length; index++) ...<Widget>[
              _AnswerReviewCard(index: index, answer: answers[index]),
              if (index != answers.length - 1)
                const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({
    required this.correctCount,
    required this.totalQuestions,
  });

  final int correctCount;
  final int totalQuestions;

  @override
  Widget build(BuildContext context) {
    return EndlessPaper(
      elevated: false,
      color: AppColors.primaryContainer.withValues(alpha: 0.48),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Answer review', style: endlessTitleStyle(17)),
                Text(
                  '$correctCount of $totalQuestions correct · ${_questionCountLabel(totalQuestions)}',
                  style: endlessBodyStyle(12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _questionCountLabel(int totalQuestions) =>
    totalQuestions == 1 ? '1 question' : '$totalQuestions questions';

class _AnswerReviewCard extends StatelessWidget {
  const _AnswerReviewCard({required this.index, required this.answer});

  final int index;
  final QuizAttemptAnswer answer;

  @override
  Widget build(BuildContext context) {
    final List<QuizAttemptAnswerChoiceSnapshot> choices =
        <QuizAttemptAnswerChoiceSnapshot>[...answer.choiceSnapshots]..sort(
          (
            QuizAttemptAnswerChoiceSnapshot a,
            QuizAttemptAnswerChoiceSnapshot b,
          ) => a.displayOrder.compareTo(b.displayOrder),
        );

    return EndlessPaper(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  'Question ${index + 1}',
                  style: endlessTitleStyle(17),
                ),
              ),
              _StatusBadge(correct: answer.isCorrect),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            answer.questionTextSnapshot,
            style: endlessBodyStyle(15, weight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          if (choices.isEmpty)
            Text(
              'No answer choices were recorded for this question.',
              style: endlessBodyStyle(12, color: AppColors.textSecondary),
            )
          else
            for (
              int choiceIndex = 0;
              choiceIndex < choices.length;
              choiceIndex++
            ) ...<Widget>[
              _AnswerChoiceRow(choice: choices[choiceIndex]),
              if (choiceIndex != choices.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.correct});

  final bool correct;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:
            correct ? AppColors.secondaryContainer : AppColors.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: correct ? AppColors.secondary : AppColors.error,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            correct ? 'Correct' : 'Incorrect',
            style: endlessBodyStyle(
              10,
              weight: FontWeight.w800,
              color: correct ? AppColors.secondary : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerChoiceRow extends StatelessWidget {
  const _AnswerChoiceRow({required this.choice});

  final QuizAttemptAnswerChoiceSnapshot choice;

  @override
  Widget build(BuildContext context) {
    final bool selectedWrong = choice.wasSelected && !choice.wasCorrect;
    final Color accent =
        choice.wasCorrect
            ? AppColors.secondary
            : selectedWrong
            ? AppColors.error
            : AppColors.textSecondary;
    final Color background =
        choice.wasCorrect
            ? AppColors.secondaryContainer.withValues(alpha: 0.62)
            : selectedWrong
            ? AppColors.errorContainer.withValues(alpha: 0.62)
            : AppColors.surfaceContainerHighest.withValues(alpha: 0.55);
    final IconData icon =
        choice.wasCorrect
            ? Icons.check_circle_rounded
            : selectedWrong
            ? Icons.cancel_rounded
            : Icons.circle_outlined;
    final String? label =
        choice.wasSelected && choice.wasCorrect
            ? 'Your answer · Correct answer'
            : choice.wasSelected
            ? 'Your answer'
            : choice.wasCorrect
            ? 'Correct answer'
            : null;

    return Semantics(
      label:
          label == null
              ? choice.choiceTextSnapshot
              : '$label. ${choice.choiceTextSnapshot}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                choice.wasCorrect || selectedWrong
                    ? accent.withValues(alpha: 0.3)
                    : AppColors.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    choice.choiceTextSnapshot,
                    style: endlessBodyStyle(13, weight: FontWeight.w600),
                  ),
                  if (label != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: endlessBodyStyle(
                        10,
                        weight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizPageFrame extends StatelessWidget {
  const _QuizPageFrame({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.child,
    this.maxWidth = 820,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EndlessQuizColors.pageBackground,
      body: EndlessQuizBackdrop(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              EndlessQuizHeader(
                title: title,
                subtitle: subtitle,
                onBack: onBack,
              ),
              Expanded(
                child: EndlessPageBody(maxWidth: maxWidth, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _errorMessage(Object error) {
  return error is AppFailure ? error.message : 'Please try again in a moment.';
}

_PerformanceMessage _performanceFor(int percentage) {
  if (percentage == 100) {
    return (
      title: 'Excellent work!',
      message: 'You answered every question correctly.',
      color: AppColors.secondary,
      softColor: AppColors.secondaryContainer,
    );
  }
  // Seventy percent is the existing BayMath passing/proficiency boundary.
  if (percentage >= 70) {
    return (
      title: 'Nice work!',
      message:
          'You are building strong understanding. Review the details to keep improving.',
      color: AppColors.primary,
      softColor: AppColors.primaryContainer,
    );
  }
  return (
    title: 'Keep practicing',
    message:
        'Review each answer, learn from it, and try again when you are ready.',
    color: AppColors.tertiary,
    softColor: AppColors.tertiaryContainer,
  );
}

typedef _PerformanceMessage =
    ({String title, String message, Color color, Color softColor});
