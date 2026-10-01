import 'package:flutter/material.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/endless_quiz_leaderboard.dart';
import '../widgets/student_avatar.dart';
import 'endless_quiz_design.dart';

/// Kept for existing presentation callers; avatar rendering now delegates to
/// the shared Student avatar component.
String endlessInitials(String name) => studentInitials(name);

({Color color, Color container}) endlessRankColors(int rank) {
  return switch (rank) {
    1 => (
      color: EndlessQuizColors.streak,
      container: EndlessQuizColors.streakSoft,
    ),
    2 => (
      color: EndlessQuizColors.silver,
      container: EndlessQuizColors.silverSoft,
    ),
    3 => (
      color: EndlessQuizColors.bronze,
      container: EndlessQuizColors.bronzeSoft,
    ),
    _ => (color: AppColors.primary, container: AppColors.primaryContainer),
  };
}

class EndlessRankBadge extends StatelessWidget {
  const EndlessRankBadge({super.key, required this.rank, this.size = 38});

  final int rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ({Color color, Color container}) colors = endlessRankColors(rank);
    return Semantics(
      label: 'Rank $rank',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.container,
          borderRadius: BorderRadius.circular(size * 0.34),
        ),
        child: Text(
          '$rank',
          style: endlessTitleStyle(
            size * 0.33,
            weight: FontWeight.w800,
            color: colors.color,
          ),
        ),
      ),
    );
  }
}

class EndlessLeaderboardRow extends StatelessWidget {
  const EndlessLeaderboardRow({
    super.key,
    required this.entry,
    this.isCurrentStudent = false,
    this.compact = false,
  });

  final LeaderboardEntry entry;
  final bool isCurrentStudent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${isCurrentStudent ? 'You. ' : ''}Rank ${entry.rank}, ${entry.fullName}, best streak ${entry.bestEndlessStreak}',
      container: true,
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 54 : 64),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 7 : 9,
        ),
        decoration: BoxDecoration(
          color:
              isCurrentStudent
                  ? AppColors.primaryContainer.withValues(alpha: 0.55)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            EndlessRankBadge(rank: entry.rank, size: compact ? 32 : 38),
            SizedBox(width: compact ? 9 : 12),
            StudentAvatar(
              fullName: entry.fullName,
              avatarId: entry.avatarId,
              size: compact ? 34 : 40,
              highlighted: isCurrentStudent,
            ),
            SizedBox(width: compact ? 9 : 12),
            Expanded(
              child: Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      entry.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: endlessBodyStyle(
                        compact ? 12.5 : 14,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isCurrentStudent) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'YOU',
                        style: endlessBodyStyle(
                          8.5,
                          weight: FontWeight.w800,
                          color: Colors.white,
                        ).copyWith(letterSpacing: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.local_fire_department_rounded,
              color:
                  entry.bestEndlessStreak > 0
                      ? EndlessQuizColors.streak
                      : AppColors.textSecondary,
              size: compact ? 17 : 20,
            ),
            const SizedBox(width: 4),
            Text(
              '${entry.bestEndlessStreak}',
              style: endlessTitleStyle(
                compact ? 13 : 15,
                color:
                    entry.bestEndlessStreak > 0
                        ? EndlessQuizColors.streak
                        : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Open podium composition. The server-provided ranks are never rewritten;
/// tied students retain the same visible rank even when their visual slots
/// differ because of list order.
class EndlessTopThree extends StatelessWidget {
  const EndlessTopThree({
    super.key,
    required this.entries,
    required this.currentStudentName,
  });

  final List<LeaderboardEntry> entries;
  final String? currentStudentName;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const EndlessStatePanel(
        title: 'The board is ready',
        message: 'Complete an Endless Quiz session to begin the rankings.',
        icon: Icons.emoji_events_outlined,
      );
    }

    final List<LeaderboardEntry> visualOrder =
        entries.length < 2
            ? entries
            : <LeaderboardEntry>[
              entries[1],
              entries[0],
              if (entries.length > 2) entries[2],
            ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List<Widget>.generate(visualOrder.length, (int index) {
        final LeaderboardEntry entry = visualOrder[index];
        return Expanded(
          child: _TopStudent(
            entry: entry,
            isCurrentStudent: entry.fullName == currentStudentName,
            prominent: identical(entry, entries.first),
          ),
        );
      }),
    );
  }
}

class _TopStudent extends StatelessWidget {
  const _TopStudent({
    required this.entry,
    required this.isCurrentStudent,
    required this.prominent,
  });

  final LeaderboardEntry entry;
  final bool isCurrentStudent;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final ({Color color, Color container}) rankColors = endlessRankColors(
      entry.rank,
    );
    return Semantics(
      label:
          '${isCurrentStudent ? 'You. ' : ''}Rank ${entry.rank}, ${entry.fullName}, best streak ${entry.bestEndlessStreak}',
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (prominent)
              Icon(
                Icons.emoji_events_rounded,
                color: rankColors.color,
                size: 25,
              )
            else
              const SizedBox(height: 25),
            const SizedBox(height: 5),
            Container(
              width: prominent ? 76 : 66,
              height: prominent ? 76 : 66,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: rankColors.container,
                shape: BoxShape.circle,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Center(
                    child: StudentAvatar(
                      fullName: entry.fullName,
                      avatarId: entry.avatarId,
                      size: prominent ? 58 : 50,
                      highlighted: isCurrentStudent,
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: EndlessRankBadge(rank: entry.rank, size: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Text(
              entry.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: endlessBodyStyle(12.5, weight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.local_fire_department_rounded,
                  color:
                      entry.bestEndlessStreak > 0
                          ? EndlessQuizColors.streak
                          : AppColors.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 3),
                Text(
                  '${entry.bestEndlessStreak}',
                  style: endlessBodyStyle(
                    12,
                    weight: FontWeight.w800,
                    color:
                        entry.bestEndlessStreak > 0
                            ? EndlessQuizColors.streak
                            : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
