import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
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
import 'quiz_results_screen.dart';

/// Finds (or creates) the student's active attempt for [quizId]. Resolves
/// `sectionId`/`schoolYearId` from the student's own current enrollment
/// first — students cannot read `sections` directly at all (0015), so
/// `schoolYearId` comes from `QuizAttemptsRepository.resolveSchoolYearId`
/// (0023's narrow pass-through RPC), never a client-side guess.
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

/// Sanitized content + resume state for one attempt (Connection B).
final quizContentProvider = FutureProvider.family<QuizAttemptContent, String>((
  ref,
  attemptId,
) {
  final QuizContentRepository? repo = ref.watch(quizContentRepositoryProvider);
  if (repo == null) throw const SessionExpiredFailure();
  return repo.fetchContent(attemptId);
});

/// One question at a time, Next/Previous. Deliberately a
/// `ConsumerStatefulWidget` with plain local `State` for the transient
/// "current question" / "just answered" UI (not a separate Riverpod
/// `StateNotifier`) — this project's existing screens hold exactly this
/// kind of non-persisted, per-screen UI state the same way (see
/// `student_login_screen.dart`'s `_isSubmitting`), so this follows that
/// established convention rather than introducing a new one.
///
/// "Current question" is tracked by `question_id` (`_currentQuestionId`),
/// never by list index. `quiz-content-for-attempt`'s order is stable
/// within an attempt, but keying off `question_id` here too means this
/// screen doesn't silently break again if that ever changes — an index
/// into a list is only as stable as the list itself, and question
/// identity is what actually matters for "which question is the student
/// looking at."
class QuizTakingScreen extends ConsumerStatefulWidget {
  const QuizTakingScreen({super.key, required this.quiz});

  final Quiz quiz;

  @override
  ConsumerState<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends ConsumerState<QuizTakingScreen> {
  /// The question currently on screen, by `question_id` — never an index
  /// into `content.questions`. Null before the first frame that has
  /// content to show; `_buildContent` falls back to the first question in
  /// that case. See the class doc comment above for why this is an id and
  /// not a position.
  String? _currentQuestionId;

  /// The choice tapped for the CURRENT question in THIS viewing, before
  /// any server round-trip completes. Cleared whenever the visible
  /// question changes.
  String? _selectedChoiceId;

  /// Set once `checkAnswer` (Connection B) returns for the current
  /// question in this viewing — the authoritative source for the
  /// correctness/explanation feedback shown for it. Never computed
  /// locally.
  QuizAnswerCheckResult? _checkedResult;

  /// Question IDs answered successfully during THIS screen visit, tracked
  /// locally instead of re-fetching `quiz-content-for-attempt` after every
  /// `submitAnswer`. `content.answeredQuestionIds` (from the last actual
  /// fetch) already covers everything answered before this visit — e.g. on
  /// resume — so the two are merged wherever "is this answered" is needed.
  /// Deliberately NOT persisted/reset across attempts; a fresh attempt
  /// means a fresh `_QuizTakingScreenState`.
  final Set<String> _locallyAnsweredQuestionIds = <String>{};

  bool _isCheckingAnswer = false;
  bool _isSubmittingQuiz = false;

  void _resetPerQuestionState() {
    _selectedChoiceId = null;
    _checkedResult = null;
  }

  void _goToQuestion(String questionId) {
    setState(() {
      _currentQuestionId = questionId;
      _resetPerQuestionState();
    });
  }

  Future<void> _selectChoice(
    QuizAttempt attempt,
    QuizAttemptQuestion question,
    String choiceId,
  ) async {
    // Client-side spam-tap protection (Phase 6 constraint 7) — the button
    // is already disabled while `_isCheckingAnswer` is true via
    // `AppButton`'s `isLoading`, but this guards the row taps directly too.
    if (_isCheckingAnswer || attempt.isSubmitted) return;

    setState(() {
      _selectedChoiceId = choiceId;
      _isCheckingAnswer = true;
    });

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

      // Connection B — the single place is_correct is computed. Never
      // invented locally.
      final QuizAnswerCheckResult result = await contentRepo.checkAnswer(
        attemptId: attempt.id,
        questionId: question.questionId,
        choiceId: choiceId,
      );

      if (mounted) setState(() => _checkedResult = result);

      // Connection A — relays Connection B's result into the historical
      // record. TOCTOU-safe on the repository side; a duplicate submit
      // here (e.g. a slow double-tap that got past the disabled button) is
      // a safe no-op.
      await attemptsRepo.submitAnswer(
        attemptId: attempt.id,
        questionId: question.questionId,
        questionTextSnapshot: question.promptText,
        choiceId: choiceId,
        isCorrect: result.isCorrect,
        choiceSnapshots: result.choices,
      );

      // Record the answer locally instead of invalidating
      // `quizContentProvider` and re-fetching. This provider should only
      // ever be invoked once per attempt load — re-fetching here bought
      // nothing (content itself doesn't change) and, before the Edge
      // Function's shuffle was made deterministic per attempt, this was
      // exactly what caused every answer submission to silently reshuffle
      // the remaining questions/choices out from under the student.
      if (mounted) {
        setState(() => _locallyAnsweredQuestionIds.add(question.questionId));
      }
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
      // Only clear the selection if checkAnswer itself never returned —
      // if it did (so `_checkedResult` is set) but the follow-up
      // `submitAnswer` failed, leaving `_checkedResult` set without also
      // clearing `_selectedChoiceId` would desync the two, and the build
      // method's "just answered" branch requires both together.
      if (mounted && _checkedResult == null) {
        setState(() => _selectedChoiceId = null);
      }
    } finally {
      if (mounted) setState(() => _isCheckingAnswer = false);
    }
  }

  Future<void> _submitQuiz(QuizAttempt attempt) async {
    if (_isSubmittingQuiz || attempt.isSubmitted) return;
    setState(() => _isSubmittingQuiz = true);

    try {
      final QuizAttemptsRepository? attemptsRepo = ref.read(
        quizAttemptsRepositoryProvider,
      );
      if (attemptsRepo == null) throw const SessionExpiredFailure();

      await attemptsRepo.finalize(attempt.id);
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
      if (mounted) setState(() => _isSubmittingQuiz = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<QuizAttempt> attemptAsync = ref.watch(
      quizActiveAttemptProvider(widget.quiz.id),
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.quiz.title)),
      body: AppPageContainer(
        scrollable: true,
        child: attemptAsync.when(
          loading: () => const AppLoadingIndicator(),
          error:
              (error, _) => AppErrorState(
                message:
                    error is AppFailure
                        ? error.message
                        : 'Could not start this quiz.',
                onRetry:
                    () => ref.invalidate(
                      quizActiveAttemptProvider(widget.quiz.id),
                    ),
              ),
          data: (attempt) => _buildContent(attempt),
        ),
      ),
    );
  }

  Widget _buildContent(QuizAttempt attempt) {
    final AsyncValue<QuizAttemptContent> contentAsync = ref.watch(
      quizContentProvider(attempt.id),
    );

    return contentAsync.when(
      loading: () => const AppLoadingIndicator(),
      error:
          (error, _) => AppErrorState(
            message:
                error is AppFailure
                    ? error.message
                    : 'Could not load the quiz content.',
            onRetry: () => ref.invalidate(quizContentProvider(attempt.id)),
          ),
      data: (content) {
        if (content.questions.isEmpty) {
          return const AppEmptyState(
            icon: Icons.quiz_outlined,
            title: 'No questions in this quiz yet',
            description: 'Check back once your teacher has added questions.',
          );
        }

        final int total = content.questions.length;

        // Look up the current question by id, not by a stored index — if
        // `_currentQuestionId` isn't set yet (first build with content) or
        // no longer matches anything (shouldn't happen given order is
        // stable per attempt, but this is the defense-in-depth fallback),
        // default to the first question rather than an arbitrary position.
        final String currentQuestionId =
            _currentQuestionId ?? content.questions.first.questionId;
        int index = content.questions.indexWhere(
          (q) => q.questionId == currentQuestionId,
        );
        if (index == -1) index = 0;
        final QuizAttemptQuestion question = content.questions[index];

        // Merge what the last fetch reported as answered with what this
        // visit has answered since — see `_locallyAnsweredQuestionIds`'s
        // doc comment for why we don't just re-fetch to pick this up.
        final Set<String> answeredQuestionIds = <String>{
          ...content.answeredQuestionIds,
          ..._locallyAnsweredQuestionIds,
        };
        final bool answeredOnServer = answeredQuestionIds.contains(
          question.questionId,
        );
        final bool isReadOnly = attempt.isSubmitted;
        final int answeredCount = answeredQuestionIds.length;
        final bool allAnswered = answeredCount >= total;

        // Local copies so Dart can actually promote these to non-null
        // within the check below — reading the fields again inside the
        // `if` would not promote and would need a force-unwrap, which is
        // exactly what crashed here before: `_checkedResult` could end up
        // set while `_selectedChoiceId` had been cleared (or vice versa)
        // by an error path, and `!` on that mismatch threw. Guarding both
        // together, from one snapshot, makes that class of bug impossible
        // here regardless of what state changes it eventually.
        final QuizAnswerCheckResult? checkedResult = _checkedResult;
        final String? selectedChoiceId = _selectedChoiceId;
        final bool justAnswered =
            checkedResult != null && selectedChoiceId != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (isReadOnly)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: AppBadge(
                  label: 'This quiz has already been submitted.',
                  variant: AppBadgeVariant.info,
                ),
              ),
            Text(
              'Question ${index + 1} of $total',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              question.promptText,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            if (justAnswered)
              _AnsweredChoiceList(
                question: question,
                result: checkedResult,
                selectedChoiceId: selectedChoiceId,
              )
            else if (answeredOnServer || isReadOnly)
              _LockedChoiceList(question: question)
            else
              _SelectableChoiceList(
                question: question,
                selectedChoiceId: selectedChoiceId,
                isEnabled: !_isCheckingAnswer,
                onSelect:
                    (choiceId) => _selectChoice(attempt, question, choiceId),
              ),
            if (justAnswered) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _FeedbackPanel(result: checkedResult),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (!allAnswered && !isReadOnly && index == total - 1)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Answer all $total questions before submitting ($answeredCount answered so far).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            Row(
              children: <Widget>[
                AppButton(
                  label: 'Previous',
                  variant: AppButtonVariant.outlined,
                  onPressed:
                      index == 0
                          ? null
                          : () => _goToQuestion(
                            content.questions[index - 1].questionId,
                          ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (index < total - 1)
                  Expanded(
                    child: AppButton(
                      label: 'Next',
                      onPressed:
                          () => _goToQuestion(
                            content.questions[index + 1].questionId,
                          ),
                    ),
                  )
                else if (!isReadOnly)
                  Expanded(
                    child: AppButton(
                      label: 'Submit Quiz',
                      isLoading: _isSubmittingQuiz,
                      onPressed:
                          allAnswered ? () => _submitQuiz(attempt) : null,
                    ),
                  )
                else
                  Expanded(
                    child: AppButton(
                      label: 'View Results',
                      onPressed:
                          () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => QuizResultsScreen(
                                    quiz: widget.quiz,
                                    attemptId: attempt.id,
                                  ),
                            ),
                          ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Interactive choice list for a not-yet-answered question.
class _SelectableChoiceList extends StatelessWidget {
  const _SelectableChoiceList({
    required this.question,
    required this.selectedChoiceId,
    required this.isEnabled,
    required this.onSelect,
  });

  final QuizAttemptQuestion question;
  final String? selectedChoiceId;
  final bool isEnabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: selectedChoiceId,
      onChanged: (value) {
        if (isEnabled && value != null) onSelect(value);
      },
      child: Column(
        children: <Widget>[
          for (final choice in question.choices)
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: choice.choiceId,
              title: Text(choice.choiceText),
            ),
        ],
      ),
    );
  }
}

/// Read-only choice list for a question already answered in a previous
/// session or view (resume support / submitted attempt). Deliberately
/// does not show correctness — that requires an authoritative
/// `check-quiz-answer` call, and re-issuing one here (for a choice the
/// student might select differently than their original answer) risks
/// showing feedback that doesn't match what was actually recorded. Full,
/// authoritative correctness for every answered question is available on
/// the results screen after the quiz is submitted.
class _LockedChoiceList extends StatelessWidget {
  const _LockedChoiceList({required this.question});

  final QuizAttemptQuestion question;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final choice in question.choices)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.radio_button_off, color: Colors.grey),
            title: Text(choice.choiceText),
            enabled: false,
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Already answered.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// Choice list right after `checkAnswer` returns for the CURRENT viewing —
/// shows which choice was picked and marks every choice's correctness,
/// using `check-quiz-answer`'s authoritative response.
class _AnsweredChoiceList extends StatelessWidget {
  const _AnsweredChoiceList({
    required this.question,
    required this.result,
    required this.selectedChoiceId,
  });

  final QuizAttemptQuestion question;
  final QuizAnswerCheckResult result;
  final String selectedChoiceId;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Map<String, CheckedChoice> byId = {
      for (final c in result.choices) c.choiceId: c,
    };

    return Column(
      children: <Widget>[
        for (final choice in question.choices)
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: false,
            leading: Icon(
              byId[choice.choiceId]?.isCorrect == true
                  ? Icons.check_circle
                  : (choice.choiceId == selectedChoiceId
                      ? Icons.cancel
                      : Icons.radio_button_off),
              color:
                  byId[choice.choiceId]?.isCorrect == true
                      ? colorScheme.primary
                      : (choice.choiceId == selectedChoiceId
                          ? colorScheme.error
                          : Colors.grey),
            ),
            title: Text(
              choice.choiceText,
              style:
                  choice.choiceId == selectedChoiceId
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null,
            ),
          ),
      ],
    );
  }
}

/// The correctness banner + explanation shown immediately after an answer
/// is checked (Phase 6 constraint 6). Skips the explanation section
/// gracefully when the question has none set.
class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({required this.result});

  final QuizAnswerCheckResult result;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      header: Text(
        result.isCorrect ? 'Correct!' : 'Not quite.',
        style: TextStyle(
          color: result.isCorrect ? colorScheme.primary : colorScheme.error,
          fontWeight: FontWeight.bold,
        ),
      ),
      child:
          result.explanationText == null ||
                  result.explanationText!.trim().isEmpty
              ? const SizedBox.shrink()
              : Text(result.explanationText!),
    );
  }
}
