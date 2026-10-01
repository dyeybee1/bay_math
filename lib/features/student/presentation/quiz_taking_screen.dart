import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/constants/app_dimensions.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/quiz.dart';
import '../../../core/models/quiz_answer_check_result.dart';
import '../../../core/models/quiz_attempt.dart';
import '../../../core/models/quiz_attempt_content.dart';
import '../../../core/models/quiz_attempt_question.dart';
import '../../../core/models/student_enrollment.dart';
import '../../../core/models/student_session.dart';
import '../../../core/providers/student_session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/quiz_attempts_repository.dart';
import '../../../core/repositories/quiz_content_repository.dart';
import '../../../core/repositories/student_enrollments_repository.dart';
import '../../../core/widgets/widgets.dart';
import '../data/student_quiz_submission_controller.dart';
import 'quiz_results_screen.dart';
import 'quiz_taking_session.dart';

abstract final class _QuizTakingPalette {
  static const Color pageBackground = Color(0xFFF3F7FC);
}

/// Finds or creates the student's active attempt using the existing,
/// student-scoped enrollment and school-year resolution flow.
final quizActiveAttemptProvider = FutureProvider.family<QuizAttempt, String>((
  ref,
  quizId,
) async {
  final StudentSession? session = ref.watch(studentSessionProvider);
  final QuizAttemptsRepository? attemptsRepo = ref.watch(
    quizAttemptsRepositoryProvider,
  );
  final StudentEnrollmentsRepository? enrollmentsRepo = ref.watch(
    studentOwnEnrollmentsRepositoryProvider,
  );

  if (session == null || attemptsRepo == null || enrollmentsRepo == null) {
    throw const SessionExpiredFailure();
  }

  final StudentEnrollment? enrollment = await enrollmentsRepo.fetchOwnActive(
    session.studentId,
  );
  if (enrollment == null) {
    throw const ValidationFailure(
      'You are not currently enrolled in a section.',
    );
  }

  final String schoolYearId = await attemptsRepo.resolveSchoolYearId(
    enrollment.sectionId,
  );

  return attemptsRepo.findOrCreateActiveAttempt(
    studentId: session.studentId,
    quizId: quizId,
    sectionId: enrollment.sectionId,
    schoolYearId: schoolYearId,
  );
});

/// Sanitized question content and resume state for one attempt.
final quizContentProvider = FutureProvider.family<QuizAttemptContent, String>((
  ref,
  attemptId,
) {
  final QuizContentRepository? repo = ref.watch(quizContentRepositoryProvider);
  if (repo == null) throw const SessionExpiredFailure();
  return repo.fetchContent(attemptId);
});

/// Landscape-only Student assessment workspace.
///
/// Choice taps update local presentation state only. The existing
/// authoritative correctness check and answer persistence run together when
/// the Student deliberately activates "Check Answer". A second activation
/// advances or finalizes, ensuring feedback is always readable first.
class QuizTakingScreen extends ConsumerStatefulWidget {
  const QuizTakingScreen({super.key, required this.quiz});

  final Quiz quiz;

  @override
  ConsumerState<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends ConsumerState<QuizTakingScreen> {
  final QuizTakingSession _session = QuizTakingSession();
  final Set<String> _locallyAnsweredQuestionIds = <String>{};

  String? _currentQuestionId;

  void _goToQuestion(String questionId) {
    setState(() => _currentQuestionId = questionId);
  }

  void _selectChoice(String questionId, String choiceId) {
    final bool didSelect = _session.selectChoice(
      questionId: questionId,
      choiceId: choiceId,
    );
    if (didSelect) setState(() {});
  }

  Future<void> _checkSelectedAnswer(
    QuizAttempt attempt,
    QuizAttemptQuestion question,
  ) async {
    if (attempt.isSubmitted || !_session.beginCheck(question.questionId)) {
      return;
    }
    setState(() {});

    final String? selectedChoiceId = _session.selectedChoiceFor(
      question.questionId,
    );
    if (selectedChoiceId == null) {
      _session.failCheck(question.questionId);
      if (mounted) setState(() {});
      return;
    }

    try {
      final QuizContentRepository? contentRepo = ref.read(
        quizContentRepositoryProvider,
      );
      final QuizAttemptsRepository? attemptsRepo = ref.read(
        quizAttemptsRepositoryProvider,
      );
      if (contentRepo == null || attemptsRepo == null) {
        throw const SessionExpiredFailure();
      }

      // Correctness remains server-authoritative. The result is not exposed
      // until the existing historical answer write also succeeds.
      final QuizAnswerCheckResult result = await contentRepo.checkAnswer(
        attemptId: attempt.id,
        questionId: question.questionId,
        choiceId: selectedChoiceId,
      );

      await attemptsRepo.submitAnswer(
        attemptId: attempt.id,
        questionId: question.questionId,
        questionTextSnapshot: question.promptText,
        choiceId: selectedChoiceId,
        isCorrect: result.isCorrect,
        choiceSnapshots: result.choices,
      );

      if (!mounted) return;
      setState(() {
        _session.completeCheck(questionId: question.questionId, result: result);
        _locallyAnsweredQuestionIds.add(question.questionId);
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _session.failCheck(question.questionId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted && _session.isChecking(question.questionId)) {
        setState(() => _session.failCheck(question.questionId));
      }
    }
  }

  Future<void> _submitQuiz(QuizAttempt attempt) async {
    if (attempt.isSubmitted || !_session.beginQuizSubmission()) return;
    setState(() {});

    try {
      final StudentQuizSubmissionController? submissionController = ref.read(
        studentQuizSubmissionControllerProvider,
      );
      if (submissionController == null) throw const SessionExpiredFailure();

      await submissionController.submit(attempt.id);
      if (!mounted) return;

      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder:
                (_) =>
                    QuizResultsScreen(quiz: widget.quiz, attemptId: attempt.id),
          ),
        ),
      );
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) {
        setState(_session.endQuizSubmission);
      }
    }
  }

  void _viewResults(QuizAttempt attempt) {
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder:
              (_) =>
                  QuizResultsScreen(quiz: widget.quiz, attemptId: attempt.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<QuizAttempt> attemptAsync = ref.watch(
      quizActiveAttemptProvider(widget.quiz.id),
    );

    return Scaffold(
      backgroundColor: _QuizTakingPalette.pageBackground,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _QuizBackdrop()),
          SafeArea(
            child: Column(
              children: <Widget>[
                _QuizHeader(
                  title: widget.quiz.title,
                  onExit: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: attemptAsync.when(
                    loading:
                        () => const _QuizStateSurface(
                          child: AppLoadingIndicator(
                            size: AppComponentSize.large,
                            message: 'Preparing your quiz...',
                          ),
                        ),
                    error:
                        (Object error, StackTrace _) => _QuizStateSurface(
                          child: AppErrorState(
                            message:
                                error is AppFailure
                                    ? error.message
                                    : 'Could not start this quiz.',
                            onRetry:
                                () => ref.invalidate(
                                  quizActiveAttemptProvider(widget.quiz.id),
                                ),
                          ),
                        ),
                    data: _buildContent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(QuizAttempt attempt) {
    final AsyncValue<QuizAttemptContent> contentAsync = ref.watch(
      quizContentProvider(attempt.id),
    );

    return contentAsync.when(
      loading:
          () => const _QuizStateSurface(
            child: AppLoadingIndicator(
              size: AppComponentSize.large,
              message: 'Loading questions...',
            ),
          ),
      error:
          (Object error, StackTrace _) => _QuizStateSurface(
            child: AppErrorState(
              message:
                  error is AppFailure
                      ? error.message
                      : 'Could not load the quiz content.',
              onRetry: () => ref.invalidate(quizContentProvider(attempt.id)),
            ),
          ),
      data: (QuizAttemptContent content) {
        if (content.questions.isEmpty) {
          return const _QuizStateSurface(
            child: AppEmptyState(
              icon: Icons.quiz_outlined,
              title: 'No questions in this quiz yet',
              description: 'Check back once your teacher has added questions.',
            ),
          );
        }

        final int total = content.questions.length;
        final String currentQuestionId =
            _currentQuestionId ?? content.questions.first.questionId;
        int index = content.questions.indexWhere(
          (QuizAttemptQuestion question) =>
              question.questionId == currentQuestionId,
        );
        if (index == -1) index = 0;

        final QuizAttemptQuestion question = content.questions[index];
        final Set<String> answeredQuestionIds = <String>{
          ...content.answeredQuestionIds,
          ..._locallyAnsweredQuestionIds,
        };
        final bool answeredPreviously = answeredQuestionIds.contains(
          question.questionId,
        );
        final int answeredCount = answeredQuestionIds.length;
        final bool allAnswered = answeredCount >= total;
        final bool isReadOnly = attempt.isSubmitted;
        final String? selectedChoiceId = _session.selectedChoiceFor(
          question.questionId,
        );
        final QuizAnswerCheckResult? checkedResult = _session.checkedResultFor(
          question.questionId,
        );
        final bool isChecking = _session.isChecking(question.questionId);
        final bool hasLocalFeedback =
            selectedChoiceId != null && checkedResult != null;
        final bool isResumeLocked =
            !hasLocalFeedback && (answeredPreviously || isReadOnly);

        return _QuizWorkspace(
          question: question,
          index: index,
          total: total,
          answeredCount: answeredCount,
          selectedChoiceId: selectedChoiceId,
          checkedResult: checkedResult,
          isChecking: isChecking,
          isReadOnly: isReadOnly,
          isResumeLocked: isResumeLocked,
          allAnswered: allAnswered,
          isSubmittingQuiz: _session.isSubmittingQuiz,
          onSelect:
              (String choiceId) => _selectChoice(question.questionId, choiceId),
          onPrevious:
              index == 0 || isChecking || _session.isSubmittingQuiz
                  ? null
                  : () =>
                      _goToQuestion(content.questions[index - 1].questionId),
          onCheck:
              selectedChoiceId == null || isChecking
                  ? null
                  : () => _checkSelectedAnswer(attempt, question),
          onNext:
              index >= total - 1
                  ? null
                  : () =>
                      _goToQuestion(content.questions[index + 1].questionId),
          onFinish: allAnswered ? () => _submitQuiz(attempt) : null,
          onViewResults: () => _viewResults(attempt),
        );
      },
    );
  }
}

class _QuizBackdrop extends StatelessWidget {
  const _QuizBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const ColoredBox(color: _QuizTakingPalette.pageBackground),
          Opacity(
            opacity: 0.5,
            child: Image.asset(
              'assets/images/stat_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizHeader extends StatelessWidget {
  const _QuizHeader({required this.title, required this.onExit});

  final String title;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.98),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1480),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Semantics(
                    button: true,
                    label: 'Exit quiz',
                    child: IconButton(
                      tooltip: 'Back to quizzes',
                      onPressed: onExit,
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        backgroundColor: colorScheme.primaryContainer,
                        minimumSize: const Size.square(
                          AppDimensions.minTouchTarget,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'MATH CHECK-IN',
                          style: GoogleFonts.inter(
                            color: colorScheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.lexend(
                            color: AppColors.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.psychology_alt_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'FOCUS MODE',
                          style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizStateSurface extends StatelessWidget {
  const _QuizStateSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.onPrimaryContainer.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _QuizWorkspace extends StatelessWidget {
  const _QuizWorkspace({
    required this.question,
    required this.index,
    required this.total,
    required this.answeredCount,
    required this.selectedChoiceId,
    required this.checkedResult,
    required this.isChecking,
    required this.isReadOnly,
    required this.isResumeLocked,
    required this.allAnswered,
    required this.isSubmittingQuiz,
    required this.onSelect,
    required this.onPrevious,
    required this.onCheck,
    required this.onNext,
    required this.onFinish,
    required this.onViewResults,
  });

  final QuizAttemptQuestion question;
  final int index;
  final int total;
  final int answeredCount;
  final String? selectedChoiceId;
  final QuizAnswerCheckResult? checkedResult;
  final bool isChecking;
  final bool isReadOnly;
  final bool isResumeLocked;
  final bool allAnswered;
  final bool isSubmittingQuiz;
  final ValueChanged<String> onSelect;
  final VoidCallback? onPrevious;
  final VoidCallback? onCheck;
  final VoidCallback? onNext;
  final VoidCallback? onFinish;
  final VoidCallback onViewResults;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isShort = constraints.maxHeight < 510;
        final bool isExpanded =
            constraints.maxWidth >= 1500 && constraints.maxHeight >= 900;
        final double horizontalPadding =
            isExpanded ? AppSpacing.xl : AppSpacing.md;
        final double verticalPadding = isShort ? AppSpacing.sm : AppSpacing.md;
        final double minContentHeight =
            constraints.maxHeight - (verticalPadding * 2);

        return Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: minContentHeight > 0 ? minContentHeight : 0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _QuizProgressStrip(
                            index: index,
                            total: total,
                            answeredCount: answeredCount,
                            isReadOnly: isReadOnly,
                            compact: isShort,
                          ),
                          SizedBox(
                            height: isShort ? AppSpacing.sm : AppSpacing.md,
                          ),
                          _QuestionSurface(
                            question: question,
                            questionNumber: index + 1,
                            selectedChoiceId: selectedChoiceId,
                            checkedResult: checkedResult,
                            isChecking: isChecking,
                            isReadOnly: isReadOnly,
                            isResumeLocked: isResumeLocked,
                            compact: isShort,
                            onSelect: onSelect,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _QuizActionFooter(
              index: index,
              total: total,
              hasSelection: selectedChoiceId != null,
              hasFeedback: checkedResult != null,
              isChecking: isChecking,
              isReadOnly: isReadOnly,
              isResumeLocked: isResumeLocked,
              allAnswered: allAnswered,
              isSubmittingQuiz: isSubmittingQuiz,
              onPrevious: onPrevious,
              onCheck: onCheck,
              onNext: onNext,
              onFinish: onFinish,
              onViewResults: onViewResults,
            ),
          ],
        );
      },
    );
  }
}

class _QuizProgressStrip extends StatelessWidget {
  const _QuizProgressStrip({
    required this.index,
    required this.total,
    required this.answeredCount,
    required this.isReadOnly,
    required this.compact,
  });

  final int index;
  final int total;
  final int answeredCount;
  final bool isReadOnly;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label:
          'Question ${index + 1} of $total. $answeredCount questions answered.',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.md : AppSpacing.lg,
          vertical: compact ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${index + 1}',
                style: GoogleFonts.lexend(
                  color: colorScheme.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Question ${index + 1} of $total',
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (index + 1) / total,
                  minHeight: 7,
                  backgroundColor: colorScheme.primaryContainer,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isReadOnly
                        ? colorScheme.surfaceContainerHighest
                        : AppColors.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isReadOnly ? 'SUBMITTED' : '$answeredCount ANSWERED',
                style: GoogleFonts.inter(
                  color:
                      isReadOnly
                          ? AppColors.textSecondary
                          : AppColors.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionSurface extends StatelessWidget {
  const _QuestionSurface({
    required this.question,
    required this.questionNumber,
    required this.selectedChoiceId,
    required this.checkedResult,
    required this.isChecking,
    required this.isReadOnly,
    required this.isResumeLocked,
    required this.compact,
    required this.onSelect,
  });

  final QuizAttemptQuestion question;
  final int questionNumber;
  final String? selectedChoiceId;
  final QuizAnswerCheckResult? checkedResult;
  final bool isChecking;
  final bool isReadOnly;
  final bool isResumeLocked;
  final bool compact;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isLocked = checkedResult != null || isResumeLocked || isReadOnly;

    return Semantics(
      container: true,
      label: 'Question $questionNumber',
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.onPrimaryContainer.withValues(alpha: 0.09),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? AppSpacing.md : AppSpacing.lg,
                  vertical: compact ? 12 : AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.48),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.14),
                    ),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: compact ? 46 : 50,
                      height: compact ? 46 : 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.quiz_rounded,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'THINK IT THROUGH',
                            style: GoogleFonts.inter(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Choose the best answer',
                            style: GoogleFonts.lexend(
                              color: AppColors.textPrimary,
                              fontSize: compact ? 18 : 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isLocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.lock_rounded,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'ANSWER LOCKED',
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(
                  compact ? AppSpacing.md : AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      question.promptText,
                      style: GoogleFonts.lexend(
                        color: AppColors.textPrimary,
                        fontSize: compact ? 18 : 21,
                        fontWeight: FontWeight.w600,
                        height: 1.42,
                      ),
                    ),
                    SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
                    _AnswerChoiceGrid(
                      question: question,
                      selectedChoiceId: selectedChoiceId,
                      checkedResult: checkedResult,
                      isEnabled: !isLocked && !isChecking,
                      onSelect: onSelect,
                    ),
                    if (isResumeLocked && checkedResult == null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      const _PreviouslyAnsweredNotice(),
                    ],
                    if (checkedResult != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      _FeedbackPanel(result: checkedResult!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ChoiceVisualState { neutral, selected, correct, incorrect, locked }

class _AnswerChoiceGrid extends StatelessWidget {
  const _AnswerChoiceGrid({
    required this.question,
    required this.selectedChoiceId,
    required this.checkedResult,
    required this.isEnabled,
    required this.onSelect,
  });

  final QuizAttemptQuestion question;
  final String? selectedChoiceId;
  final QuizAnswerCheckResult? checkedResult;
  final bool isEnabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final Map<String, CheckedChoice> checkedChoices = <String, CheckedChoice>{
      for (final CheckedChoice choice
          in checkedResult?.choices ?? const <CheckedChoice>[])
        choice.choiceId: choice,
    };

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool useTwoColumns =
            constraints.maxWidth >= 820 && question.choices.length >= 4;
        const double gap = 12;
        final double itemWidth =
            useTwoColumns
                ? (constraints.maxWidth - gap) / 2
                : constraints.maxWidth;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (int index = 0; index < question.choices.length; index++)
              SizedBox(
                width: itemWidth,
                child: _AnswerChoiceCard(
                  key: ValueKey<String>(
                    'quiz-choice-${question.choices[index].choiceId}',
                  ),
                  label: _choiceLabel(index),
                  text: question.choices[index].choiceText,
                  state: _visualStateFor(
                    choiceId: question.choices[index].choiceId,
                    selectedChoiceId: selectedChoiceId,
                    checkedChoice:
                        checkedChoices[question.choices[index].choiceId],
                    isEnabled: isEnabled,
                    hasCheckedResult: checkedResult != null,
                  ),
                  onTap:
                      isEnabled
                          ? () => onSelect(question.choices[index].choiceId)
                          : null,
                ),
              ),
          ],
        );
      },
    );
  }

  _ChoiceVisualState _visualStateFor({
    required String choiceId,
    required String? selectedChoiceId,
    required CheckedChoice? checkedChoice,
    required bool isEnabled,
    required bool hasCheckedResult,
  }) {
    if (hasCheckedResult) {
      if (checkedChoice?.isCorrect == true) return _ChoiceVisualState.correct;
      if (choiceId == selectedChoiceId) return _ChoiceVisualState.incorrect;
      return _ChoiceVisualState.locked;
    }
    if (choiceId == selectedChoiceId) return _ChoiceVisualState.selected;
    return isEnabled ? _ChoiceVisualState.neutral : _ChoiceVisualState.locked;
  }

  String _choiceLabel(int index) {
    if (index < 26) return String.fromCharCode(65 + index);
    return '${index + 1}';
  }
}

class _AnswerChoiceCard extends StatelessWidget {
  const _AnswerChoiceCard({
    super.key,
    required this.label,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String label;
  final String text;
  final _ChoiceVisualState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AppSemanticColors semanticColors =
        Theme.of(context).extension<AppSemanticColors>() ??
        AppSemanticColors.light;
    final Color backgroundColor = switch (state) {
      _ChoiceVisualState.selected => colorScheme.primaryContainer.withValues(
        alpha: 0.62,
      ),
      _ChoiceVisualState.correct => semanticColors.successContainer,
      _ChoiceVisualState.incorrect => colorScheme.errorContainer,
      _ChoiceVisualState.neutral => colorScheme.surface,
      _ChoiceVisualState.locked => colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.48),
    };
    final Color borderColor = switch (state) {
      _ChoiceVisualState.selected => colorScheme.primary,
      _ChoiceVisualState.correct => semanticColors.success,
      _ChoiceVisualState.incorrect => colorScheme.error,
      _ChoiceVisualState.neutral ||
      _ChoiceVisualState.locked => colorScheme.outlineVariant,
    };
    final ({IconData icon, String label, Color color})? status =
        switch (state) {
          _ChoiceVisualState.selected => (
            icon: Icons.check_circle_outline_rounded,
            label: 'Selected',
            color: colorScheme.primary,
          ),
          _ChoiceVisualState.correct => (
            icon: Icons.check_circle_rounded,
            label: 'Correct answer',
            color: semanticColors.success,
          ),
          _ChoiceVisualState.incorrect => (
            icon: Icons.cancel_rounded,
            label: 'Your choice',
            color: colorScheme.error,
          ),
          _ChoiceVisualState.neutral || _ChoiceVisualState.locked => null,
        };
    final String stateDescription = switch (state) {
      _ChoiceVisualState.selected => 'Selected',
      _ChoiceVisualState.correct => 'Correct answer',
      _ChoiceVisualState.incorrect => 'Incorrect selected answer',
      _ChoiceVisualState.locked => 'Locked',
      _ChoiceVisualState.neutral => 'Not selected',
    };

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      selected: state == _ChoiceVisualState.selected,
      label: 'Answer $label. $text. $stateDescription.',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(
          minHeight: AppDimensions.minTouchTarget + 16,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: state == _ChoiceVisualState.neutral ? 1 : 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          state == _ChoiceVisualState.neutral ||
                                  state == _ChoiceVisualState.locked
                              ? colorScheme.surface
                              : borderColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.lexend(
                        color:
                            state == _ChoiceVisualState.neutral ||
                                    state == _ChoiceVisualState.locked
                                ? AppColors.textSecondary
                                : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight:
                            state == _ChoiceVisualState.selected ||
                                    state == _ChoiceVisualState.correct ||
                                    state == _ChoiceVisualState.incorrect
                                ? FontWeight.w700
                                : FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (status != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: status.color.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(status.icon, color: status.color, size: 17),
                          const SizedBox(width: 5),
                          Text(
                            status.label,
                            style: GoogleFonts.inter(
                              color: status.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviouslyAnsweredNotice extends StatelessWidget {
  const _PreviouslyAnsweredNotice();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      liveRegion: true,
      label:
          'This question was already answered. Detailed feedback is available after finishing the quiz.',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.lock_clock_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Already answered. You can review the recorded answer and full feedback after finishing the quiz.',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({required this.result});

  final QuizAnswerCheckResult result;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AppSemanticColors semanticColors =
        Theme.of(context).extension<AppSemanticColors>() ??
        AppSemanticColors.light;
    final Color accent =
        result.isCorrect ? semanticColors.success : colorScheme.error;
    final Color container =
        result.isCorrect
            ? semanticColors.successContainer
            : colorScheme.errorContainer;
    final Color onContainer =
        result.isCorrect
            ? semanticColors.onSuccessContainer
            : colorScheme.onErrorContainer;
    final String? explanation = result.explanationText?.trim();

    return Semantics(
      key: const ValueKey<String>('quiz-feedback-panel'),
      container: true,
      liveRegion: true,
      label:
          '${result.isCorrect ? 'Correct answer.' : 'Incorrect answer.'} ${explanation ?? ''}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: container.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.34)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                result.isCorrect
                    ? Icons.check_rounded
                    : Icons.lightbulb_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    result.isCorrect ? 'Nice work!' : "Let's learn from this",
                    style: GoogleFonts.lexend(
                      color: onContainer,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (explanation != null &&
                      explanation.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(
                      explanation,
                      style: GoogleFonts.inter(
                        color: onContainer,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.48,
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

class _QuizActionFooter extends StatelessWidget {
  const _QuizActionFooter({
    required this.index,
    required this.total,
    required this.hasSelection,
    required this.hasFeedback,
    required this.isChecking,
    required this.isReadOnly,
    required this.isResumeLocked,
    required this.allAnswered,
    required this.isSubmittingQuiz,
    required this.onPrevious,
    required this.onCheck,
    required this.onNext,
    required this.onFinish,
    required this.onViewResults,
  });

  final int index;
  final int total;
  final bool hasSelection;
  final bool hasFeedback;
  final bool isChecking;
  final bool isReadOnly;
  final bool isResumeLocked;
  final bool allAnswered;
  final bool isSubmittingQuiz;
  final VoidCallback? onPrevious;
  final VoidCallback? onCheck;
  final VoidCallback? onNext;
  final VoidCallback? onFinish;
  final VoidCallback onViewResults;

  @override
  Widget build(BuildContext context) {
    final bool isLast = index == total - 1;
    final bool canAdvance = hasFeedback || isResumeLocked || isReadOnly;
    final QuizPrimaryAction action = quizPrimaryActionFor(
      isLastQuestion: isLast,
      hasFeedback: hasFeedback,
      isResumeLocked: isResumeLocked,
      isReadOnly: isReadOnly,
    );
    final String primaryLabel;
    final IconData primaryIcon;
    final VoidCallback? primaryAction;
    final bool isLoading;

    switch (action) {
      case QuizPrimaryAction.checkAnswer:
        primaryLabel = 'Check Answer';
        primaryIcon = Icons.task_alt_rounded;
        primaryAction = hasSelection ? onCheck : null;
        isLoading = isChecking;
      case QuizPrimaryAction.nextQuestion:
        primaryLabel = 'Next Question';
        primaryIcon = Icons.arrow_forward_rounded;
        primaryAction = onNext;
        isLoading = false;
      case QuizPrimaryAction.finishQuiz:
        primaryLabel = 'Finish Quiz';
        primaryIcon = Icons.flag_rounded;
        primaryAction = allAnswered ? onFinish : null;
        isLoading = isSubmittingQuiz;
      case QuizPrimaryAction.viewResults:
        primaryLabel = 'View Results';
        primaryIcon = Icons.insights_rounded;
        primaryAction = onViewResults;
        isLoading = false;
    }

    final String guidance = _guidanceText(
      isLast: isLast,
      canAdvance: canAdvance,
    );
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.98),
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 164,
                  child: AppButton(
                    key: const ValueKey<String>('quiz-previous-action'),
                    label: 'Previous',
                    size: AppComponentSize.large,
                    variant: AppButtonVariant.outlined,
                    leadingIcon: Icons.arrow_back_rounded,
                    onPressed: onPrevious,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        canAdvance
                            ? Icons.visibility_rounded
                            : Icons.touch_app_rounded,
                        color: AppColors.textSecondary,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          guidance,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: 210,
                  child: AppButton(
                    key: const ValueKey<String>('quiz-primary-action'),
                    label: primaryLabel,
                    size: AppComponentSize.large,
                    leadingIcon:
                        primaryLabel == 'Check Answer' ? primaryIcon : null,
                    trailingIcon:
                        primaryLabel == 'Check Answer' ? null : primaryIcon,
                    isLoading: isLoading,
                    onPressed: primaryAction,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _guidanceText({required bool isLast, required bool canAdvance}) {
    if (isReadOnly) return 'This submitted quiz is available for review.';
    if (canAdvance && isLast && !allAnswered) {
      return 'Review earlier questions before finishing.';
    }
    if (canAdvance && isLast) {
      return 'Read the feedback, then finish when ready.';
    }
    if (canAdvance) return 'Read the feedback before moving on.';
    if (hasSelection) return 'You can change your choice before checking.';
    return 'Choose one answer to continue.';
  }
}
