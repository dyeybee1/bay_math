import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/endless_quiz_leaderboard.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/student_profile_provider.dart';
import '../data/endless_quiz_leaderboard_providers.dart';
import 'endless_quiz_design.dart';
import 'endless_quiz_full_leaderboard_screen.dart';
import 'endless_quiz_leaderboard_widgets.dart';
import 'endless_quiz_screen.dart';

class EndlessQuizLandingScreen extends ConsumerWidget {
  const EndlessQuizLandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<EndlessQuizLeaderboardData> dataAsync = ref.watch(
      endlessQuizLeaderboardProvider,
    );
    final Student? profile = ref.watch(ownStudentProfileProvider).value;

    return Scaffold(
      backgroundColor: EndlessQuizColors.pageBackground,
      body: EndlessQuizBackdrop(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              EndlessQuizHeader(
                title: 'Endless Quiz',
                subtitle: 'A focused practice challenge',
                onBack: () => Navigator.maybePop(context),
                action: EndlessIconButton(
                  tooltip: 'How Endless Quiz works',
                  icon: Icons.info_outline_rounded,
                  onPressed: () => _showHowItWorks(context),
                ),
              ),
              Expanded(
                child: EndlessPageBody(
                  child: dataAsync.when(
                    loading:
                        () => const EndlessStatePanel(
                          title: 'Preparing your challenge',
                          message:
                              'Loading your best streak and grade rankings.',
                          icon: Icons.bolt_rounded,
                          loading: true,
                        ),
                    error:
                        (Object error, StackTrace _) => EndlessStatePanel(
                          title: 'Could not open Endless Quiz',
                          message:
                              error is AppFailure
                                  ? error.message
                                  : 'The challenge data could not be loaded right now.',
                          icon: Icons.cloud_off_outlined,
                          actionLabel: 'Try again',
                          onAction:
                              () => ref.invalidate(
                                endlessQuizLeaderboardProvider,
                              ),
                        ),
                    data:
                        (EndlessQuizLeaderboardData data) => _LandingLayout(
                          data: data,
                          profile: profile,
                          onPlay:
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const EndlessQuizScreen(),
                                ),
                              ),
                          onHowItWorks: () => _showHowItWorks(context),
                          onLeaderboard:
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) =>
                                          const EndlessQuizFullLeaderboardScreen(),
                                ),
                              ),
                        ),
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

class _LandingLayout extends StatelessWidget {
  const _LandingLayout({
    required this.data,
    required this.profile,
    required this.onPlay,
    required this.onHowItWorks,
    required this.onLeaderboard,
  });

  final EndlessQuizLeaderboardData data;
  final Student? profile;
  final VoidCallback onPlay;
  final VoidCallback onHowItWorks;
  final VoidCallback onLeaderboard;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool short = constraints.maxHeight < 500;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 59,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: AppSpacing.md, bottom: 4),
                child: _ChallengeHero(
                  myRank: data.myRank,
                  short: short,
                  onPlay: onPlay,
                  onHowItWorks: onHowItWorks,
                ),
              ),
            ),
            Expanded(
              flex: 41,
              child: _LeaderboardPreview(
                entries: data.topEntries,
                myRank: data.myRank,
                currentStudentName: profile?.fullName,
                short: short,
                onViewAll: onLeaderboard,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChallengeHero extends StatelessWidget {
  const _ChallengeHero({
    required this.myRank,
    required this.short,
    required this.onPlay,
    required this.onHowItWorks,
  });

  final LeaderboardEntry myRank;
  final bool short;
  final VoidCallback onPlay;
  final VoidCallback onHowItWorks;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: short ? 430 : 520),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFE7F0FB), Color(0xFFFFF5E8)],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.onPrimaryContainer.withValues(alpha: 0.1),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -50,
            top: -55,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.68),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 38,
            top: short ? 34 : 50,
            child: _StreakEmblem(streak: myRank.bestEndlessStreak),
          ),
          Padding(
            padding: EdgeInsets.all(short ? AppSpacing.lg : AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'PRACTICE WITHOUT A FINISH LINE',
                    style: endlessBodyStyle(
                      9.5,
                      weight: FontWeight.w800,
                      color: AppColors.primary,
                    ).copyWith(letterSpacing: 0.9),
                  ),
                ),
                SizedBox(height: short ? 14 : 22),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Text(
                    'One question.\nThen one more.',
                    style: endlessTitleStyle(short ? 34 : 43),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Text(
                    'Build a run of correct answers, learn from every reset, and keep moving at your own pace.',
                    style: endlessBodyStyle(
                      short ? 13 : 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: short ? 16 : 24),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    EndlessPrimaryButton(
                      label: 'Start a run',
                      icon: Icons.play_arrow_rounded,
                      onPressed: onPlay,
                    ),
                    EndlessSecondaryButton(
                      label: 'How it works',
                      icon: Icons.lightbulb_outline_rounded,
                      onPressed: onHowItWorks,
                    ),
                  ],
                ),
                SizedBox(height: short ? AppSpacing.md : AppSpacing.xl),
                _ChallengeRuleStrip(rank: myRank.rank),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakEmblem extends StatelessWidget {
  const _StreakEmblem({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Personal best streak $streak',
      child: Container(
        width: 118,
        height: 118,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: EndlessQuizColors.streak.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.local_fire_department_rounded,
              color: EndlessQuizColors.streak,
              size: 31,
            ),
            Text(
              '$streak',
              style: endlessTitleStyle(26, color: EndlessQuizColors.streak),
            ),
            Text(
              'PERSONAL BEST',
              style: endlessBodyStyle(
                8,
                weight: FontWeight.w800,
                color: AppColors.textSecondary,
              ).copyWith(letterSpacing: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeRuleStrip extends StatelessWidget {
  const _ChallengeRuleStrip({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Each correct answer extends your streak. A mistake resets it. Grade rank $rank.',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.trending_up_rounded,
                color: AppColors.secondary,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Keep the streak moving',
                    style: endlessBodyStyle(12.5, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Correct answers add to it. A mistake resets it.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: endlessBodyStyle(
                      10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(width: 1, height: 34, color: AppColors.outlineVariant),
            const SizedBox(width: AppSpacing.md),
            Column(
              children: <Widget>[
                Text(
                  '#$rank',
                  style: endlessTitleStyle(18, color: AppColors.primary),
                ),
                Text(
                  'GRADE RANK',
                  style: endlessBodyStyle(
                    8,
                    weight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ).copyWith(letterSpacing: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardPreview extends StatelessWidget {
  const _LeaderboardPreview({
    required this.entries,
    required this.myRank,
    required this.currentStudentName,
    required this.short,
    required this.onViewAll,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardEntry myRank;
  final String? currentStudentName;
  final bool short;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final List<LeaderboardEntry> top = entries.take(3).toList();
    final List<LeaderboardEntry> rest =
        entries.skip(3).take(short ? 2 : 3).toList();
    final bool studentVisible = entries
        .take(short ? 5 : 6)
        .any((LeaderboardEntry entry) => entry.fullName == currentStudentName);

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: EndlessQuizColors.streakSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: EndlessQuizColors.streak,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Streak leaders', style: endlessTitleStyle(18)),
                    Text(
                      'Top practice runs in your grade',
                      style: endlessBodyStyle(
                        11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('See all'),
              ),
            ],
          ),
          SizedBox(height: short ? AppSpacing.sm : AppSpacing.md),
          Expanded(
            child:
                entries.isEmpty
                    ? const EndlessStatePanel(
                      title: 'No rankings yet',
                      message: 'The first completed run will begin the board.',
                      icon: Icons.flag_outlined,
                    )
                    : SingleChildScrollView(
                      child: Column(
                        children: <Widget>[
                          Container(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              short ? AppSpacing.sm : AppSpacing.md,
                              AppSpacing.md,
                              AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: EndlessTopThree(
                              entries: top,
                              currentStudentName: currentStudentName,
                            ),
                          ),
                          SizedBox(
                            height: short ? AppSpacing.xs : AppSpacing.sm,
                          ),
                          for (final LeaderboardEntry entry
                              in rest) ...<Widget>[
                            EndlessLeaderboardRow(
                              entry: entry,
                              compact: true,
                              isCurrentStudent:
                                  entry.fullName == currentStudentName,
                            ),
                            const Divider(
                              height: 1,
                              color: AppColors.outlineVariant,
                            ),
                          ],
                          if (!studentVisible) ...<Widget>[
                            const SizedBox(height: AppSpacing.sm),
                            EndlessLeaderboardRow(
                              entry: myRank,
                              compact: true,
                              isCurrentStudent: true,
                            ),
                          ],
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showHowItWorks(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder:
        (BuildContext dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 610),
            child: EndlessPaper(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'How a run works',
                          style: endlessTitleStyle(21),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _HowStep(
                    icon: Icons.touch_app_rounded,
                    title: 'Answer once',
                    description:
                        'Your choice is checked immediately and recorded only once.',
                  ),
                  const _HowStep(
                    icon: Icons.local_fire_department_rounded,
                    title: 'Grow the streak',
                    description:
                        'Each correct answer adds one to your current streak.',
                    streak: true,
                  ),
                  const _HowStep(
                    icon: Icons.refresh_rounded,
                    title: 'Reset, then continue',
                    description:
                        'A mistake resets the streak to zero. The run keeps going with a new question.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  EndlessPrimaryButton(
                    label: 'Ready to practice',
                    icon: Icons.check_rounded,
                    expand: true,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
  );
}

class _HowStep extends StatelessWidget {
  const _HowStep({
    required this.icon,
    required this.title,
    required this.description,
    this.streak = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool streak;

  @override
  Widget build(BuildContext context) {
    final Color color = streak ? EndlessQuizColors.streak : AppColors.primary;
    final Color container =
        streak ? EndlessQuizColors.streakSoft : AppColors.primaryContainer;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: container,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: endlessBodyStyle(14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
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
