import 'package:flutter/material.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_colors.dart';
import 'endless_quiz_design.dart';
import 'endless_quiz_screen.dart';

class EndlessQuizResultsScreen extends StatelessWidget {
  const EndlessQuizResultsScreen({
    super.key,
    required this.questionsAnswered,
    required this.bestStreakSession,
  });

  final int questionsAnswered;
  final int bestStreakSession;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EndlessQuizColors.pageBackground,
      body: EndlessQuizBackdrop(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              EndlessQuizHeader(
                title: 'Run complete',
                subtitle: 'Your practice session has been saved',
                onBack: () => Navigator.maybePop(context),
              ),
              Expanded(
                child: EndlessPageBody(
                  maxWidth: 1120,
                  child: LayoutBuilder(
                    builder: (
                      BuildContext context,
                      BoxConstraints constraints,
                    ) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: _ResultsComposition(
                              questionsAnswered: questionsAnswered,
                              bestStreakSession: bestStreakSession,
                              onPlayAgain:
                                  () => Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const EndlessQuizScreen(),
                                    ),
                                  ),
                              onDone: () => Navigator.maybePop(context),
                            ),
                          ),
                        ),
                      );
                    },
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

class _ResultsComposition extends StatelessWidget {
  const _ResultsComposition({
    required this.questionsAnswered,
    required this.bestStreakSession,
    required this.onPlayAgain,
    required this.onDone,
  });

  final int questionsAnswered;
  final int bestStreakSession;
  final VoidCallback onPlayAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final bool answeredAny = questionsAnswered > 0;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.onPrimaryContainer.withValues(alpha: 0.09),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 840;
          final Widget celebration = _CelebrationStory(
            answeredAny: answeredAny,
            bestStreak: bestStreakSession,
          );
          final Widget summary = _RunSummary(
            questionsAnswered: questionsAnswered,
            bestStreak: bestStreakSession,
            onPlayAgain: onPlayAgain,
            onDone: onDone,
          );
          return compact
              ? Column(children: <Widget>[celebration, summary])
              : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(flex: 43, child: celebration),
                    Expanded(flex: 57, child: summary),
                  ],
                ),
              );
        },
      ),
    );
  }
}

class _CelebrationStory extends StatelessWidget {
  const _CelebrationStory({
    required this.answeredAny,
    required this.bestStreak,
  });

  final bool answeredAny;
  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFF3E4), Color(0xFFE8F1FB)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  shape: BoxShape.circle,
                ),
              ),
              Icon(
                answeredAny
                    ? Icons.local_fire_department_rounded
                    : Icons.flag_outlined,
                color:
                    answeredAny ? EndlessQuizColors.streak : AppColors.primary,
                size: 54,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            answeredAny ? 'You finished the run.' : 'Your run is saved.',
            style: endlessTitleStyle(29),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _message(),
            style: endlessBodyStyle(
              14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _message() {
    if (!answeredAny) {
      return 'No questions were answered this time. A fresh run is ready whenever you are.';
    }
    if (bestStreak == 0) {
      return 'Every reset is part of practice. Your next correct answer can begin a new streak.';
    }
    return 'Your best stretch was $bestStreak correct in a row. Focused practice like this builds confidence.';
  }
}

class _RunSummary extends StatelessWidget {
  const _RunSummary({
    required this.questionsAnswered,
    required this.bestStreak,
    required this.onPlayAgain,
    required this.onDone,
  });

  final int questionsAnswered;
  final int bestStreak;
  final VoidCallback onPlayAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'THIS RUN',
            style: endlessBodyStyle(
              10,
              weight: FontWeight.w800,
              color: AppColors.primary,
            ).copyWith(letterSpacing: 1),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('A clear look at your practice', style: endlessTitleStyle(22)),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            label:
                '$questionsAnswered questions answered. Best streak this run $bestStreak.',
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: AppColors.outlineVariant),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _ResultNumber(
                      value: '$questionsAnswered',
                      label: 'QUESTIONS ANSWERED',
                      color: AppColors.primary,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 64,
                    color: AppColors.outlineVariant,
                  ),
                  Expanded(
                    child: _ResultNumber(
                      value: '$bestStreak',
                      label: 'BEST STREAK',
                      color:
                          bestStreak > 0
                              ? EndlessQuizColors.streak
                              : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          EndlessPrimaryButton(
            label: 'Start another run',
            icon: Icons.replay_rounded,
            onPressed: onPlayAgain,
            expand: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onDone,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('Back to Endless Quiz'),
          ),
        ],
      ),
    );
  }
}

class _ResultNumber extends StatelessWidget {
  const _ResultNumber({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(value, style: endlessTitleStyle(35, color: color)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          style: endlessBodyStyle(
            9,
            weight: FontWeight.w800,
            color: AppColors.textSecondary,
          ).copyWith(letterSpacing: 0.8),
        ),
      ],
    );
  }
}
