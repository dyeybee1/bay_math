import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/endless_quiz_leaderboard.dart';
import '../../../core/models/section.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/student_profile_provider.dart';
import '../data/endless_quiz_leaderboard_providers.dart';
import '../widgets/student_avatar.dart';
import 'endless_quiz_design.dart';
import 'endless_quiz_leaderboard_widgets.dart';

class EndlessQuizFullLeaderboardScreen extends ConsumerWidget {
  const EndlessQuizFullLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<EndlessQuizLeaderboardData> dataAsync = ref.watch(
      endlessQuizLeaderboardProvider,
    );
    final Student? profile = ref.watch(ownStudentProfileProvider).value;
    final GradeLevel? grade = ref.watch(ownStudentGradeLevelProvider).value;

    return Scaffold(
      backgroundColor: EndlessQuizColors.pageBackground,
      body: EndlessQuizBackdrop(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              EndlessQuizHeader(
                title: 'Streak leaderboard',
                subtitle:
                    grade == null
                        ? 'Endless Quiz · Your grade'
                        : '${grade.label} · Endless Quiz',
                onBack: () => Navigator.maybePop(context),
              ),
              Expanded(
                child: EndlessPageBody(
                  child: dataAsync.when(
                    loading:
                        () => const EndlessStatePanel(
                          title: 'Loading the leaderboard',
                          message:
                              'Gathering the best practice streaks in your grade.',
                          icon: Icons.emoji_events_outlined,
                          loading: true,
                        ),
                    error:
                        (Object error, StackTrace _) => EndlessStatePanel(
                          title: 'Could not load the leaderboard',
                          message:
                              error is AppFailure
                                  ? error.message
                                  : 'The rankings are unavailable right now.',
                          icon: Icons.cloud_off_outlined,
                          actionLabel: 'Try again',
                          onAction:
                              () => ref.invalidate(
                                endlessQuizLeaderboardProvider,
                              ),
                        ),
                    data:
                        (EndlessQuizLeaderboardData data) => _LeaderboardLayout(
                          data: data,
                          currentStudentName: profile?.fullName,
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

class _LeaderboardLayout extends StatelessWidget {
  const _LeaderboardLayout({
    required this.data,
    required this.currentStudentName,
  });

  final EndlessQuizLeaderboardData data;
  final String? currentStudentName;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool short = constraints.maxHeight < 510;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: constraints.maxWidth < 1120 ? 340 : 390,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: AppSpacing.lg, bottom: 4),
                child: _HighlightsColumn(
                  topEntries: data.topEntries.take(3).toList(),
                  myRank: data.myRank,
                  currentStudentName: currentStudentName,
                  short: short,
                ),
              ),
            ),
            Expanded(
              child: _RankingList(
                entries: data.topEntries,
                myRank: data.myRank,
                currentStudentName: currentStudentName,
                short: short,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HighlightsColumn extends StatelessWidget {
  const _HighlightsColumn({
    required this.topEntries,
    required this.myRank,
    required this.currentStudentName,
    required this.short,
  });

  final List<LeaderboardEntry> topEntries;
  final LeaderboardEntry myRank;
  final String? currentStudentName;
  final bool short;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: EdgeInsets.all(short ? AppSpacing.md : AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFFFFF4E5), Color(0xFFE7F0FB)],
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: EndlessQuizColors.streak,
                    size: 25,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Top streaks', style: endlessTitleStyle(18)),
                ],
              ),
              SizedBox(height: short ? AppSpacing.sm : AppSpacing.md),
              EndlessTopThree(
                entries: topEntries,
                currentStudentName: currentStudentName,
              ),
            ],
          ),
        ),
        SizedBox(height: short ? AppSpacing.sm : AppSpacing.md),
        _YourStanding(myRank: myRank),
      ],
    );
  }
}

class _YourStanding extends StatelessWidget {
  const _YourStanding({required this.myRank});

  final LeaderboardEntry myRank;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Your standing. Rank ${myRank.rank}. Best streak ${myRank.bestEndlessStreak}.',
      child: EndlessPaper(
        elevated: false,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'YOUR STANDING',
              style: endlessBodyStyle(
                9,
                weight: FontWeight.w800,
                color: AppColors.primary,
              ).copyWith(letterSpacing: 0.9),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                StudentAvatar(
                  fullName: myRank.fullName,
                  avatarId: myRank.avatarId,
                  size: 50,
                  highlighted: true,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        myRank.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: endlessTitleStyle(15),
                      ),
                      Text(
                        'Best streak ${myRank.bestEndlessStreak}',
                        style: endlessBodyStyle(
                          11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  children: <Widget>[
                    Text(
                      '#${myRank.rank}',
                      style: endlessTitleStyle(24, color: AppColors.primary),
                    ),
                    Text(
                      'RANK',
                      style: endlessBodyStyle(
                        8,
                        weight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ).copyWith(letterSpacing: 0.7),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  const _RankingList({
    required this.entries,
    required this.myRank,
    required this.currentStudentName,
    required this.short,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardEntry myRank;
  final String? currentStudentName;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final bool currentInPage = entries.any(
      (LeaderboardEntry entry) => entry.fullName == currentStudentName,
    );
    return EndlessPaper(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: short ? 12 : AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.format_list_numbered_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'All practice streaks',
                        style: endlessTitleStyle(18),
                      ),
                      Text(
                        'Equal streaks are ordered by name',
                        style: endlessBodyStyle(
                          10.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.64),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${entries.length} SHOWN',
                    style: endlessBodyStyle(
                      9,
                      weight: FontWeight.w800,
                      color: AppColors.primary,
                    ).copyWith(letterSpacing: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.outlineVariant),
          Expanded(
            child:
                entries.isEmpty
                    ? const EndlessStatePanel(
                      title: 'No rankings yet',
                      message:
                          'Complete an Endless Quiz run to begin the board.',
                      icon: Icons.emoji_events_outlined,
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      itemCount: entries.length + (currentInPage ? 0 : 1),
                      separatorBuilder:
                          (BuildContext context, int index) => const Divider(
                            height: 1,
                            indent: 66,
                            color: AppColors.outlineVariant,
                          ),
                      itemBuilder: (BuildContext context, int index) {
                        if (index == entries.length) {
                          return Column(
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    const Expanded(child: Divider()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                      ),
                                      child: Text(
                                        'YOUR POSITION',
                                        style: endlessBodyStyle(
                                          8.5,
                                          weight: FontWeight.w800,
                                          color: AppColors.textSecondary,
                                        ).copyWith(letterSpacing: 0.8),
                                      ),
                                    ),
                                    const Expanded(child: Divider()),
                                  ],
                                ),
                              ),
                              EndlessLeaderboardRow(
                                entry: myRank,
                                compact: short,
                                isCurrentStudent: true,
                              ),
                            ],
                          );
                        }
                        final LeaderboardEntry entry = entries[index];
                        return EndlessLeaderboardRow(
                          entry: entry,
                          compact: short,
                          isCurrentStudent:
                              entry.fullName == currentStudentName,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
