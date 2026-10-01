import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/endless_question.dart';
import '../../../core/models/quiz_attempt_choice.dart';
import '../../../core/models/section.dart';
import '../../../core/models/student_session.dart';
import '../../../core/providers/student_profile_provider.dart';
import '../../../core/providers/student_session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/endless_quiz_repository.dart';
import '../data/endless_quiz_leaderboard_providers.dart';
import 'endless_quiz_design.dart';
import 'endless_quiz_results_screen.dart';

const Duration _kFeedbackDelay = Duration(milliseconds: 1750);

class EndlessQuizScreen extends ConsumerStatefulWidget {
  const EndlessQuizScreen({super.key});

  @override
  ConsumerState<EndlessQuizScreen> createState() => _EndlessQuizScreenState();
}

class _EndlessQuizScreenState extends ConsumerState<EndlessQuizScreen> {
  late final DateTime _startedAt = DateTime.now();

  EndlessQuestion? _currentQuestion;
  AppFailure? _loadError;
  String? _selectedChoiceId;
  bool? _isAnswerCorrect;
  bool _isBusy = false;
  int _currentStreak = 0;
  int _bestStreakSession = 0;
  int _questionsAnswered = 0;
  bool _isFinalizing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNextQuestion());
  }

  Future<void> _loadNextQuestion() async {
    setState(() {
      _isBusy = true;
      _loadError = null;
    });

    try {
      final EndlessQuizRepository? repo = ref.read(
        endlessQuizRepositoryProvider,
      );
      if (repo == null) throw const SessionExpiredFailure();

      final EndlessQuestion question = await repo.fetchQuestion();
      if (!mounted) return;

      setState(() {
        _currentQuestion = question;
        _selectedChoiceId = null;
        _isAnswerCorrect = null;
        _isBusy = false;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _loadError = failure;
        _isBusy = false;
      });
    }
  }

  Future<void> _selectChoice(String choiceId) async {
    final EndlessQuestion? question = _currentQuestion;
    if (_isBusy || question == null) return;

    setState(() {
      _selectedChoiceId = choiceId;
      _isBusy = true;
    });

    try {
      final EndlessQuizRepository? repo = ref.read(
        endlessQuizRepositoryProvider,
      );
      if (repo == null) throw const SessionExpiredFailure();

      final bool isCorrect = await repo.checkAnswer(
        questionId: question.questionId,
        choiceId: choiceId,
      );
      if (!mounted) return;

      setState(() {
        _isAnswerCorrect = isCorrect;
        _questionsAnswered += 1;
        _currentStreak = isCorrect ? _currentStreak + 1 : 0;
        _bestStreakSession = math.max(_bestStreakSession, _currentStreak);
      });

      await Future<void>.delayed(_kFeedbackDelay);
      if (!mounted) return;

      await _loadNextQuestion();
    } on AppFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      setState(() {
        _selectedChoiceId = null;
        _isBusy = false;
      });
    }
  }

  Future<void> _finishSession() async {
    if (_isFinalizing) return;
    setState(() => _isFinalizing = true);

    try {
      final StudentSession? session = ref.read(studentSessionProvider);
      final EndlessQuizRepository? repo = ref.read(
        endlessQuizRepositoryProvider,
      );
      if (session == null || repo == null) throw const SessionExpiredFailure();

      await repo.finalizeSession(
        studentId: session.studentId,
        startedAt: _startedAt,
        endedAt: DateTime.now(),
        questionsAnswered: _questionsAnswered,
        bestStreakSession: _bestStreakSession,
      );
      if (!mounted) return;

      ref.invalidate(endlessQuizLeaderboardProvider);

      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder:
                (_) => EndlessQuizResultsScreen(
                  questionsAnswered: _questionsAnswered,
                  bestStreakSession: _bestStreakSession,
                ),
          ),
        ),
      );
    } on AppFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      setState(() => _isFinalizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final GradeLevel? grade = ref.watch(ownStudentGradeLevelProvider).value;
    return Scaffold(
      backgroundColor: EndlessQuizColors.pageBackground,
      body: EndlessQuizBackdrop(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              EndlessQuizHeader(
                title: 'Endless Quiz',
                subtitle:
                    grade == null
                        ? 'Practice run'
                        : '${grade.label} · Practice run',
                onBack: () => Navigator.maybePop(context),
              ),
              Expanded(
                child: EndlessPageBody(
                  maxWidth: 1240,
                  child: _GameplayCanvas(
                    question: _currentQuestion,
                    loadError: _loadError,
                    selectedChoiceId: _selectedChoiceId,
                    answerIsCorrect: _isAnswerCorrect,
                    isBusy: _isBusy,
                    isFinalizing: _isFinalizing,
                    currentStreak: _currentStreak,
                    bestStreak: _bestStreakSession,
                    answered: _questionsAnswered,
                    onSelect: _selectChoice,
                    onRetry: _loadNextQuestion,
                    onFinish: _finishSession,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameplayCanvas extends StatelessWidget {
  const _GameplayCanvas({
    required this.question,
    required this.loadError,
    required this.selectedChoiceId,
    required this.answerIsCorrect,
    required this.isBusy,
    required this.isFinalizing,
    required this.currentStreak,
    required this.bestStreak,
    required this.answered,
    required this.onSelect,
    required this.onRetry,
    required this.onFinish,
  });

  final EndlessQuestion? question;
  final AppFailure? loadError;
  final String? selectedChoiceId;
  final bool? answerIsCorrect;
  final bool isBusy;
  final bool isFinalizing;
  final int currentStreak;
  final int bestStreak;
  final int answered;
  final ValueChanged<String> onSelect;
  final VoidCallback onRetry;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return EndlessPaper(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Column(
          children: <Widget>[
            _RunRibbon(
              currentStreak: currentStreak,
              bestStreak: bestStreak,
              answered: answered,
            ),
            Expanded(
              child: _QuestionViewport(
                question: question,
                loadError: loadError,
                selectedChoiceId: selectedChoiceId,
                answerIsCorrect: answerIsCorrect,
                isBusy: isBusy,
                currentStreak: currentStreak,
                onSelect: onSelect,
                onRetry: onRetry,
              ),
            ),
            _SessionFooter(
              isFinalizing: isFinalizing,
              onFinish: isFinalizing ? null : onFinish,
            ),
          ],
        ),
      ),
    );
  }
}

class _RunRibbon extends StatelessWidget {
  const _RunRibbon({
    required this.currentStreak,
    required this.bestStreak,
    required this.answered,
  });

  final int currentStreak;
  final int bestStreak;
  final int answered;

  @override
  Widget build(BuildContext context) {
    final bool active = currentStreak > 0;
    final Color accent = active ? EndlessQuizColors.streak : AppColors.primary;
    final Color container =
        active ? EndlessQuizColors.streakSoft : AppColors.primaryContainer;
    return Semantics(
      container: true,
      label:
          'Current streak $currentStreak. Best this session $bestStreak. Questions answered $answered.',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: container.withValues(alpha: 0.58),
          border: const Border(
            bottom: BorderSide(color: AppColors.outlineVariant),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: active ? EndlessQuizColors.streak : AppColors.primary,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  active ? 'STREAK IN MOTION' : 'START A STREAK',
                  style: endlessBodyStyle(
                    9,
                    weight: FontWeight.w800,
                    color: accent,
                  ).copyWith(letterSpacing: 0.9),
                ),
                Text(
                  '$currentStreak correct in a row',
                  style: endlessTitleStyle(
                    18,
                    color:
                        active
                            ? EndlessQuizColors.streak
                            : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _InlineRunStat(label: 'BEST THIS RUN', value: '$bestStreak'),
            Container(
              width: 1,
              height: 34,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              color: AppColors.outlineVariant,
            ),
            _InlineRunStat(label: 'ANSWERED', value: '$answered'),
          ],
        ),
      ),
    );
  }
}

class _InlineRunStat extends StatelessWidget {
  const _InlineRunStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(value, style: endlessTitleStyle(18, color: AppColors.primary)),
        Text(
          label,
          style: endlessBodyStyle(
            8.5,
            weight: FontWeight.w800,
            color: AppColors.textSecondary,
          ).copyWith(letterSpacing: 0.6),
        ),
      ],
    );
  }
}

class _QuestionViewport extends StatelessWidget {
  const _QuestionViewport({
    required this.question,
    required this.loadError,
    required this.selectedChoiceId,
    required this.answerIsCorrect,
    required this.isBusy,
    required this.currentStreak,
    required this.onSelect,
    required this.onRetry,
  });

  final EndlessQuestion? question;
  final AppFailure? loadError;
  final String? selectedChoiceId;
  final bool? answerIsCorrect;
  final bool isBusy;
  final int currentStreak;
  final ValueChanged<String> onSelect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (question == null) {
      if (loadError != null) {
        if (loadError is NoEndlessQuestionsFailure) {
          return EndlessStatePanel(
            title: 'No questions available yet',
            message: loadError!.message,
            icon: Icons.quiz_outlined,
          );
        }
        return EndlessStatePanel(
          title: 'Could not load a question',
          message: loadError!.message,
          icon: Icons.cloud_off_outlined,
          actionLabel: 'Try again',
          onAction: onRetry,
        );
      }
      return const EndlessStatePanel(
        title: 'Finding your next question',
        message: 'Your practice run will continue in a moment.',
        icon: Icons.search_rounded,
        loading: true,
      );
    }

    final bool answered = selectedChoiceId != null && answerIsCorrect != null;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool short = constraints.maxHeight < 390;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: short ? AppSpacing.md : AppSpacing.lg,
            vertical: short ? AppSpacing.sm : AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'NEXT STEP IN YOUR RUN',
                      style: endlessBodyStyle(
                        9,
                        weight: FontWeight.w800,
                        color: AppColors.primary,
                      ).copyWith(letterSpacing: 0.7),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    answered
                        ? 'Moving to the next question…'
                        : 'Choose one answer',
                    style: endlessBodyStyle(11, color: AppColors.textSecondary),
                  ),
                ],
              ),
              SizedBox(height: short ? AppSpacing.sm : AppSpacing.md),
              Semantics(
                label: 'Question. ${question!.promptText}',
                child: Text(
                  question!.promptText,
                  style: endlessTitleStyle(
                    short ? 18 : 21,
                    weight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: short ? AppSpacing.md : AppSpacing.lg),
              _ChoiceGrid(
                choices: question!.choices,
                selectedChoiceId: selectedChoiceId,
                answerIsCorrect: answerIsCorrect,
                enabled: !isBusy,
                onSelect: onSelect,
              ),
              if (answered) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _AnswerFeedback(
                  isCorrect: answerIsCorrect!,
                  currentStreak: currentStreak,
                ),
              ],
              if (loadError != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _InlineLoadError(message: loadError!.message, onRetry: onRetry),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({
    required this.choices,
    required this.selectedChoiceId,
    required this.answerIsCorrect,
    required this.enabled,
    required this.onSelect,
  });

  final List<QuizAttemptChoice> choices;
  final String? selectedChoiceId;
  final bool? answerIsCorrect;
  final bool enabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool twoColumns = constraints.maxWidth >= 720;
        final List<Widget> cards = List<Widget>.generate(choices.length, (
          int index,
        ) {
          final QuizAttemptChoice choice = choices[index];
          final bool selected = choice.choiceId == selectedChoiceId;
          final _ChoiceVisualState state =
              answerIsCorrect == null
                  ? selected
                      ? _ChoiceVisualState.selected
                      : _ChoiceVisualState.neutral
                  : selected
                  ? answerIsCorrect!
                      ? _ChoiceVisualState.correct
                      : _ChoiceVisualState.incorrect
                  : _ChoiceVisualState.locked;
          return _AnswerChoice(
            index: index,
            text: choice.choiceText,
            state: state,
            onTap:
                enabled && answerIsCorrect == null
                    ? () => onSelect(choice.choiceId)
                    : null,
          );
        });

        if (!twoColumns) {
          return Column(
            children: <Widget>[
              for (int i = 0; i < cards.length; i++) ...<Widget>[
                cards[i],
                if (i != cards.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        }

        final List<Widget> rows = <Widget>[];
        for (int i = 0; i < cards.length; i += 2) {
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: cards[i]),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child:
                        i + 1 < cards.length
                            ? cards[i + 1]
                            : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
          if (i + 2 < cards.length) {
            rows.add(const SizedBox(height: AppSpacing.sm));
          }
        }
        return Column(children: rows);
      },
    );
  }
}

enum _ChoiceVisualState { neutral, selected, correct, incorrect, locked }

class _AnswerChoice extends StatelessWidget {
  const _AnswerChoice({
    required this.index,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final int index;
  final String text;
  final _ChoiceVisualState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String letter = String.fromCharCode(65 + index);
    final ({Color fill, Color accent, String status, IconData? icon}) visual =
        switch (state) {
          _ChoiceVisualState.selected => (
            fill: AppColors.primaryContainer.withValues(alpha: 0.7),
            accent: AppColors.primary,
            status: 'Selected, checking',
            icon: Icons.hourglass_top_rounded,
          ),
          _ChoiceVisualState.correct => (
            fill: EndlessQuizColors.successSoft,
            accent: EndlessQuizColors.success,
            status: 'Correct answer',
            icon: Icons.check_circle_rounded,
          ),
          _ChoiceVisualState.incorrect => (
            fill: EndlessQuizColors.dangerSoft,
            accent: EndlessQuizColors.danger,
            status: 'Incorrect answer',
            icon: Icons.cancel_rounded,
          ),
          _ChoiceVisualState.locked => (
            fill: AppColors.surfaceContainerHighest.withValues(alpha: 0.66),
            accent: AppColors.textSecondary,
            status: 'Not selected',
            icon: null,
          ),
          _ChoiceVisualState.neutral => (
            fill: Colors.white,
            accent: AppColors.primary,
            status: 'Answer choice',
            icon: null,
          ),
        };
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      selected: state == _ChoiceVisualState.selected,
      label: 'Choice $letter. $text. ${visual.status}.',
      child: Material(
        color: visual.fill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    state == _ChoiceVisualState.neutral ||
                            state == _ChoiceVisualState.locked
                        ? AppColors.outlineVariant
                        : visual.accent.withValues(alpha: 0.68),
                width: state == _ChoiceVisualState.neutral ? 1 : 1.4,
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: visual.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    letter,
                    style: endlessTitleStyle(
                      14,
                      weight: FontWeight.w800,
                      color: visual.accent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    text,
                    style: endlessBodyStyle(
                      14,
                      weight: FontWeight.w600,
                      color:
                          state == _ChoiceVisualState.locked
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (visual.icon != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(visual.icon, color: visual.accent, size: 22),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  const _AnswerFeedback({required this.isCorrect, required this.currentStreak});

  final bool isCorrect;
  final int currentStreak;

  @override
  Widget build(BuildContext context) {
    final Color color =
        isCorrect ? EndlessQuizColors.success : EndlessQuizColors.danger;
    final Color container =
        isCorrect
            ? EndlessQuizColors.successSoft
            : EndlessQuizColors.dangerSoft;
    final String title =
        isCorrect
            ? 'Correct — keep the run going'
            : 'Streak reset — next question';
    final String detail =
        isCorrect
            ? 'Current streak: $currentStreak'
            : 'The streak is back to 0. Start fresh on the next one.';
    return Semantics(
      liveRegion: true,
      label: '$title. $detail',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: container,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              isCorrect ? Icons.check_circle_rounded : Icons.refresh_rounded,
              color: color,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: endlessBodyStyle(
                      13.5,
                      weight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    detail,
                    style: endlessBodyStyle(
                      11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

class _InlineLoadError extends StatelessWidget {
  const _InlineLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: EndlessQuizColors.dangerSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.cloud_off_outlined, color: EndlessQuizColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: endlessBodyStyle(12))),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _SessionFooter extends StatelessWidget {
  const _SessionFooter({required this.isFinalizing, required this.onFinish});

  final bool isFinalizing;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBFD),
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          TextButton.icon(
            onPressed: onFinish,
            icon:
                isFinalizing
                    ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                    : const Icon(Icons.stop_circle_outlined),
            label: Text(isFinalizing ? 'Saving run…' : 'Finish this run'),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: AppColors.error,
              textStyle: endlessBodyStyle(13, weight: FontWeight.w700),
            ),
          ),
          const Spacer(),
          const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 5),
          Text(
            'Answers advance automatically',
            style: endlessBodyStyle(11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
