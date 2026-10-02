import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/section.dart';
import '../../../core/models/student.dart';
import '../../../core/models/student_statistics.dart';
import '../../../core/providers/student_profile_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/student_statistics_providers.dart';
import '../widgets/student_avatar.dart';
import 'student_statistics_art.dart';

abstract final class _ProgressColors {
  static const Color page = Color(0xFFF4F7FD);
  static const Color blue = Color(0xFF2859DB);
  static const Color ink = Color(0xFF243753);
  static const Color muted = Color(0xFF78879E);
  static const Color line = Color(0xFFE4EAF4);
  static const Color softBlue = Color(0xFFEEF3FF);
  static const Color secondaryText = Color(0xFF3F65B9);
  static const Color barTrack = Color(0xFFE7EEFB);
}

/// Presentation for the existing statistics payload. Values and selection
/// rules remain owned by [studentStatisticsProvider] and its repository.
class StudentStatisticsScreen extends ConsumerWidget {
  const StudentStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<StudentStatistics> statistics = ref.watch(
      studentStatisticsProvider,
    );
    final AsyncValue<List<StudentCompletedLesson>> completedLessons = ref.watch(
      studentCompletedLessonsProvider,
    );

    return Scaffold(
      backgroundColor: _ProgressColors.page,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _ProgressBackdrop()),
          SafeArea(
            child: Column(
              children: <Widget>[
                const _ProgressHeader(),
                Expanded(
                  child: statistics.when(
                    loading:
                        () =>
                            const _ProgressState(child: AppLoadingIndicator()),
                    error:
                        (Object error, StackTrace _) => _ProgressState(
                          child: AppErrorState(
                            message:
                                error is AppFailure
                                    ? error.message
                                    : 'Could not load your statistics.',
                            onRetry:
                                () => ref.invalidate(studentStatisticsProvider),
                          ),
                        ),
                    data:
                        (StudentStatistics data) => SingleChildScrollView(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1400),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  MediaQuery.sizeOf(context).width >= 900
                                      ? 25
                                      : 16,
                                  20,
                                  MediaQuery.sizeOf(context).width >= 900
                                      ? 25
                                      : 16,
                                  28,
                                ),
                                child: _StatisticsContent(
                                  statistics: data,
                                  completedLessons:
                                      completedLessons.value ??
                                      const <StudentCompletedLesson>[],
                                  completionDetailsAvailable:
                                      completedLessons.hasValue,
                                ),
                              ),
                            ),
                          ),
                        ),
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

class _ProgressBackdrop extends StatelessWidget {
  const _ProgressBackdrop();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Opacity(
      opacity: 0.22,
      child: Image.asset(
        'assets/images/stat_background.png',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
    ),
  );
}

class _ProgressHeader extends ConsumerWidget {
  const _ProgressHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Student? student = ref.watch(ownStudentProfileProvider).value;
    final GradeLevel? grade = ref.watch(ownStudentGradeLevelProvider).value;
    final bool compact = MediaQuery.sizeOf(context).width < 760;

    return Material(
      color: Colors.white,
      child: Container(
        height: compact ? 72 : 68,
        padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 25),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _ProgressColors.line)),
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              key: const ValueKey<String>('statistics_back_button'),
              tooltip: 'Back to student home',
              onPressed: () async {
                final bool popped = await Navigator.of(context).maybePop();
                if (!popped && context.mounted) {
                  context.go(AppRoutes.studentHome);
                }
              },
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                minimumSize: const Size.square(48),
                foregroundColor: const Color(0xFF5577B1),
                backgroundColor: const Color(0xFFEDF3FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
            if (!compact) ...<Widget>[
              const SizedBox(width: 18),
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _ProgressColors.blue,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.calculate_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'BayMath',
                style: GoogleFonts.lexend(
                  color: _ProgressColors.blue,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 18),
              const SizedBox(
                width: 1,
                height: 33,
                child: ColoredBox(color: _ProgressColors.line),
              ),
            ],
            SizedBox(width: compact ? 12 : 18),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'My Progress',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(
                      color: _ProgressColors.ink,
                      fontSize: compact ? 20 : 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Every activity is a step forward.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: _ProgressColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (!compact && grade != null) ...<Widget>[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF3FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  grade.label,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF5D7AB4),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 12),
            StudentAvatar(
              fullName: student?.fullName ?? 'Student',
              avatarId: student?.avatarId,
              size: 40,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressState extends StatelessWidget {
  const _ProgressState({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: _ProgressSurface(child: child),
    ),
  );
}

class _ProgressSurface extends StatelessWidget {
  const _ProgressSurface({
    required this.child,
    this.padding = const EdgeInsets.all(19),
    this.minHeight = 0,
  });

  final Widget child;
  final EdgeInsets padding;
  final double minHeight;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: BoxConstraints(minHeight: minHeight),
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _ProgressColors.line),
      borderRadius: BorderRadius.circular(23),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x071D437A),
          blurRadius: 17,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent({
    required this.statistics,
    required this.completedLessons,
    required this.completionDetailsAvailable,
  });

  final StudentStatistics statistics;
  final List<StudentCompletedLesson> completedLessons;
  final bool completionDetailsAvailable;

  @override
  Widget build(BuildContext context) {
    final StudentSummaryTiles summary = statistics.summary;
    if (summary.lessonsTotal == 0) {
      return const _ProgressSurface(
        child: SizedBox(
          height: 320,
          child: AppEmptyState(
            icon: Icons.hourglass_empty,
            title: 'Nothing here yet for your grade',
            description:
                "There aren't any lessons or quizzes for your grade yet. "
                'Check back once your teacher adds some!',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SummaryCards(
          summary: summary,
          completedLessons: completedLessons,
          completionDetailsAvailable: completionDetailsAvailable,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget scores = _ScoresPanel(
              key: const ValueKey<String>('statistics_scores_panel'),
              scores: statistics.lessonQuizScores,
              lessonsCompleted: summary.lessonsCompleted,
            );
            final Widget accuracy = _AccuracyPanel(
              key: const ValueKey<String>('statistics_accuracy_panel'),
              accuracy: statistics.overallAccuracy,
            );
            if (constraints.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 145, child: scores),
                  const SizedBox(width: 17),
                  Expanded(flex: 100, child: accuracy),
                ],
              );
            }
            return Column(
              children: <Widget>[scores, const SizedBox(height: 16), accuracy],
            );
          },
        ),
        const SizedBox(height: 16),
        _MasteryPanel(topics: statistics.competencyMastery),
      ],
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({
    required this.summary,
    required this.completedLessons,
    required this.completionDetailsAvailable,
  });

  final StudentSummaryTiles summary;
  final List<StudentCompletedLesson> completedLessons;
  final bool completionDetailsAvailable;

  @override
  Widget build(BuildContext context) {
    final int remaining = math.max(
      0,
      summary.lessonsTotal - summary.lessonsCompleted,
    );
    final List<Widget> cards = <Widget>[
      _MetricCard(
        key: const ValueKey<String>('statistics_lessons_card'),
        kind: StatisticsIconKind.book,
        accent: const Color(0xFF628AE0),
        tint: const Color(0xFFEDF3FF),
        label: 'Lessons completed',
        value: '${summary.lessonsCompleted}',
        unit: 'of ${summary.lessonsTotal}',
        note:
            remaining == 0
                ? 'All available lessons completed!'
                : '$remaining ${remaining == 1 ? 'lesson' : 'lessons'} to go. Keep learning!',
        progress: summary.lessonsCompleted / summary.lessonsTotal,
        onTap:
            completionDetailsAvailable
                ? () => _showCompletedLessonsDialog(
                  context,
                  completedLessons: completedLessons,
                  lessonsTotal: summary.lessonsTotal,
                )
                : null,
      ),
      _MetricCard(
        key: const ValueKey<String>('statistics_average_card'),
        kind: StatisticsIconKind.target,
        accent: const Color(0xFF9276CE),
        tint: const Color(0xFFF0EAFB),
        label: 'Average quiz score',
        value:
            summary.averageScorePercent == null
                ? 'No quiz results yet'
                : formatPercent(summary.averageScorePercent),
        note:
            summary.averageScorePercent == null
                ? 'Your first quiz starts the story.'
                : 'Across ${summary.quizzesCompleted} ${summary.quizzesCompleted == 1 ? 'quiz' : 'quizzes'}.',
        noData: summary.averageScorePercent == null,
      ),
      _MetricCard(
        key: const ValueKey<String>('statistics_best_card'),
        kind: StatisticsIconKind.medal,
        accent: const Color(0xFF5B9C7A),
        tint: const Color(0xFFE8F5EE),
        label: 'Best quiz score',
        value:
            summary.bestScorePercent == null
                ? 'No quiz results yet'
                : formatPercent(summary.bestScorePercent),
        note:
            summary.bestScorePercent == null
                ? 'Your first result will appear here.'
                : 'Your highest quiz percentage.',
        noData: summary.bestScorePercent == null,
      ),
      _MetricCard(
        key: const ValueKey<String>('statistics_streak_card'),
        kind: StatisticsIconKind.flame,
        accent: const Color(0xFFDF9A44),
        tint: const Color(0xFFFFF0DD),
        label: 'Endless Quiz',
        value: '${summary.bestEndlessStreak}',
        unit: 'in a row',
        note: 'Your highest correct-answer streak.',
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns =
            constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 380
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 13,
            crossAxisSpacing: 13,
            mainAxisExtent: columns == 4 ? 174 : 165,
          ),
          itemBuilder: (BuildContext context, int index) => cards[index],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    super.key,
    required this.kind,
    required this.accent,
    required this.tint,
    required this.label,
    required this.value,
    required this.note,
    this.unit,
    this.progress,
    this.onTap,
    this.noData = false,
  });

  final StatisticsIconKind kind;
  final Color accent;
  final Color tint;
  final String label;
  final String value;
  final String note;
  final String? unit;
  final double? progress;
  final VoidCallback? onTap;
  final bool noData;

  @override
  Widget build(BuildContext context) {
    final Widget content = _ProgressSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _IconBadge(kind: kind, color: accent, tint: tint, size: 35),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: GoogleFonts.inter(
                    color: _ProgressColors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (noData)
            Text(
              value,
              style: GoogleFonts.lexend(
                color: _ProgressColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Text.rich(
              TextSpan(
                text: value,
                style: GoogleFonts.lexend(
                  color: _ProgressColors.ink,
                  fontSize: 31,
                  fontWeight: FontWeight.w800,
                ),
                children:
                    unit == null
                        ? null
                        : <InlineSpan>[
                          TextSpan(
                            text: '  $unit',
                            style: GoogleFonts.inter(
                              color: _ProgressColors.muted,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (progress != null) ...<Widget>[
            const SizedBox(height: 7),
            _AnimatedFillBar(
              fraction: progress!,
              height: 7,
              color: const Color(0xFF7D9CE8),
            ),
          ],
          const SizedBox(height: 5),
          Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: _ProgressColors.muted,
              fontSize: 10,
              height: 1.3,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: '$label: $value ${unit ?? ''}. View completed lessons.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey<String>('lessons_completed_tile'),
          borderRadius: BorderRadius.circular(23),
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.kind,
    required this.color,
    required this.tint,
    this.size = 40,
  });

  final StatisticsIconKind kind;
  final Color color;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: StatisticsIcon(kind: kind, color: color, size: size * 0.6),
  );
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.tint,
    required this.accent,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final StatisticsIconKind kind;
  final Color tint;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      _IconBadge(kind: kind, color: accent, tint: tint),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: GoogleFonts.lexend(
                color: _ProgressColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                color: _ProgressColors.muted,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
      if (trailing != null) ...<Widget>[const SizedBox(width: 8), trailing!],
    ],
  );
}

class _ScoresPanel extends StatelessWidget {
  const _ScoresPanel({
    super.key,
    required this.scores,
    required this.lessonsCompleted,
  });

  final List<LessonQuizScore> scores;
  final int lessonsCompleted;

  @override
  Widget build(BuildContext context) {
    final bool hasResults = scores.any(
      (LessonQuizScore score) => score.scorePercent != null,
    );
    return _ProgressSurface(
      minHeight: 350,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PanelHeader(
            title: 'Quiz Scores by Lesson',
            subtitle:
                'Most recent submitted quiz result for each linked lesson',
            kind: StatisticsIconKind.chart,
            tint: const Color(0xFFEDF3FF),
            accent: const Color(0xFF628AE0),
            trailing:
                hasResults ? const _SmallChip(label: 'SCORE / 100%') : null,
          ),
          if (!hasResults)
            _PanelEmpty(
              kind: StatisticsEmptyArtKind.book,
              title:
                  scores.isEmpty
                      ? 'No quiz-linked lessons yet'
                      : 'Your first score starts here.',
              description:
                  scores.isEmpty
                      ? "Your teacher hasn't linked a quiz to a lesson yet."
                      : 'Take a quiz to see your lesson scores. There is no need to rush.',
              action: _ProgressAction(
                label: 'Take a quiz',
                primary: true,
                icon: Icons.arrow_forward_rounded,
                onPressed: () => context.push(AppRoutes.studentQuizzes),
              ),
            )
          else ...<Widget>[
            const SizedBox(height: 22),
            const _ScoreAxis(),
            for (final (int index, LessonQuizScore score) in scores.indexed)
              _LessonScoreRow(score: score, index: index),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 13),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _ProgressColors.line)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    hasResults
                        ? 'Tap a scored lesson to see its result.'
                        : '$lessonsCompleted ${lessonsCompleted == 1 ? 'lesson' : 'lessons'} completed. Keep learning!',
                    style: GoogleFonts.inter(
                      color: _ProgressColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ProgressAction(
                  label: 'View lessons',
                  icon: Icons.arrow_outward_rounded,
                  onPressed: () => context.push(AppRoutes.studentLessons),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5FB),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(
        color: const Color(0xFF8091AE),
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ScoreAxis extends StatelessWidget {
  const _ScoreAxis();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double labelWidth = constraints.maxWidth < 540 ? 125 : 178;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: <Widget>[
            SizedBox(width: labelWidth + 10),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (final String value in <String>['0%', '50%', '100%'])
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF99A6BA),
                        fontSize: 9,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 43),
          ],
        ),
      );
    },
  );
}

class _LessonScoreRow extends StatelessWidget {
  const _LessonScoreRow({required this.score, required this.index});

  final LessonQuizScore score;
  final int index;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double labelWidth = constraints.maxWidth < 540 ? 125 : 178;
      final Color barColor = switch (index % 3) {
        1 => const Color(0xFFB2A0DE),
        2 => const Color(0xFF83BAA0),
        _ => const Color(0xFF93AFEA),
      };
      final bool hasScore = score.scorePercent != null;
      final Widget content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: labelWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'LESSON ${index + 1}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8C9CB5),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    score.lessonTitle,
                    style: GoogleFonts.inter(
                      color: _ProgressColors.ink,
                      fontSize: constraints.maxWidth < 540 ? 10 : 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AnimatedFillBar(
                fraction:
                    score.scorePercent == null
                        ? null
                        : score.scorePercent!.toDouble() / 100,
                height: 15,
                color: barColor,
                showMidline: true,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 33,
              child: Text(
                hasScore ? formatPercent(score.scorePercent) : '—',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  color: const Color(0xFF58769F),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
      return Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('score_row_${score.lessonId}'),
          borderRadius: BorderRadius.circular(9),
          onTap:
              hasScore ? () => _showScoreDetails(context, score, index) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: content,
          ),
        ),
      );
    },
  );
}

class _AnimatedFillBar extends StatelessWidget {
  const _AnimatedFillBar({
    required this.fraction,
    required this.height,
    required this.color,
    this.showMidline = false,
  });

  final double? fraction;
  final double height;
  final Color color;
  final bool showMidline;

  @override
  Widget build(BuildContext context) {
    final double value = (fraction ?? 0).clamp(0, 1).toDouble();
    final Widget track = ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const ColoredBox(color: _ProgressColors.barTrack),
            if (fraction != null)
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: value),
                duration:
                    MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder:
                    (BuildContext context, double progress, Widget? _) => Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: ColoredBox(
                          color: color,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
              ),
            if (showMidline)
              Align(
                alignment: Alignment.center,
                child: Container(width: 1, color: const Color(0xFFDEE7F4)),
              ),
          ],
        ),
      ),
    );
    return track;
  }
}

class _AccuracyPanel extends StatelessWidget {
  const _AccuracyPanel({super.key, required this.accuracy});

  final OverallAccuracy accuracy;

  @override
  Widget build(BuildContext context) {
    final int answered = accuracy.correct + accuracy.incorrect;
    final bool hasData = answered > 0 && accuracy.accuracyPercent != null;
    return _ProgressSurface(
      minHeight: 350,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _PanelHeader(
            title: 'Overall Accuracy',
            subtitle: 'Correct answers from completed regular quizzes',
            kind: StatisticsIconKind.target,
            tint: Color(0xFFE8F5EE),
            accent: Color(0xFF5B9C7A),
          ),
          if (!hasData)
            const _PanelEmpty(
              kind: StatisticsEmptyArtKind.target,
              title: 'No accuracy data yet',
              description:
                  'After a regular quiz, see how many answers you got right here.',
            )
          else ...<Widget>[
            const SizedBox(height: 22),
            Center(child: _AccuracyRing(percent: accuracy.accuracyPercent!)),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _AccuracyCount(
                  count: accuracy.correct,
                  label: 'correct',
                  color: const Color(0xFF7BA0E8),
                ),
                const SizedBox(width: 22),
                _AccuracyCount(
                  count: accuracy.incorrect,
                  label: 'to review',
                  color: const Color(0xFFDAE4F4),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              '${accuracy.correct} correct out of $answered answered.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _ProgressColors.muted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccuracyRing extends StatelessWidget {
  const _AccuracyRing({required this.percent});

  final num percent;

  @override
  Widget build(BuildContext context) {
    final double fraction = percent.clamp(0, 100).toDouble() / 100;
    return SizedBox.square(
      dimension: 175,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: fraction),
            duration:
                MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder:
                (BuildContext context, double value, Widget? _) => CustomPaint(
                  size: const Size.square(175),
                  painter: _AccuracyRingPainter(value),
                ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                formatPercent(percent),
                style: GoogleFonts.lexend(
                  color: _ProgressColors.ink,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'answers correct',
                style: GoogleFonts.inter(
                  color: _ProgressColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccuracyRingPainter extends CustomPainter {
  const _AccuracyRingPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect circle = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 8,
    );
    canvas.drawArc(
      circle,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = const Color(0xFFEAF0F8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13,
    );
    if (fraction > 0) {
      canvas.drawArc(
        circle,
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        Paint()
          ..color = const Color(0xFF7BA0E8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AccuracyRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

class _AccuracyCount extends StatelessWidget {
  const _AccuracyCount({
    required this.count,
    required this.label,
    required this.color,
  });

  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      CircleAvatar(radius: 3.5, backgroundColor: color),
      const SizedBox(width: 5),
      Text(
        '$count $label',
        style: GoogleFonts.inter(color: const Color(0xFF6D80A0), fontSize: 11),
      ),
    ],
  );
}

class _MasteryPanel extends StatelessWidget {
  const _MasteryPanel({required this.topics});

  final List<TopicMastery> topics;

  @override
  Widget build(BuildContext context) {
    final List<TopicMastery> sorted = <TopicMastery>[...topics]
      ..sort((TopicMastery a, TopicMastery b) => a.topic.compareTo(b.topic));
    return _ProgressSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _PanelHeader(
            title: 'Competency Mastery',
            subtitle: 'Your practice results by math topic',
            kind: StatisticsIconKind.medal,
            tint: Color(0xFFF0EAFB),
            accent: Color(0xFF9276CE),
          ),
          if (sorted.isEmpty)
            const _PanelEmpty(
              kind: StatisticsEmptyArtKind.target,
              title: 'No mastery data yet',
              description:
                  'Take a regular quiz to see your practice results by topic.',
            )
          else ...<Widget>[
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int columns =
                    constraints.maxWidth >= 900
                        ? 3
                        : constraints.maxWidth >= 520
                        ? 2
                        : 1;
                const double gap = 12;
                final double width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: <Widget>[
                    for (final (int index, TopicMastery topic)
                        in sorted.indexed)
                      SizedBox(
                        width: width,
                        child: _MasteryTopicCard(topic: topic, index: index),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _MasteryTopicCard extends StatelessWidget {
  const _MasteryTopicCard({required this.topic, required this.index});

  final TopicMastery topic;
  final int index;

  @override
  Widget build(BuildContext context) {
    final bool hasData = topic.questionsTotal > 0;
    final Color color = switch (index % 4) {
      1 => const Color(0xFFAB95D6),
      2 => const Color(0xFF85B89F),
      3 => const Color(0xFFE2B367),
      _ => const Color(0xFF8BA8E1),
    };
    return Material(
      color: const Color(0xFFFAFCFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE4EBF5)),
      ),
      child: InkWell(
        key: ValueKey<String>('mastery_topic_${topic.topic}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showTopicDetails(context, topic),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 125),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        topic.topic,
                        style: GoogleFonts.inter(
                          color: _ProgressColors.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasData
                          ? formatPercent(topic.masteryPercent)
                          : 'No data yet',
                      style: GoogleFonts.lexend(
                        color:
                            hasData
                                ? const Color(0xFF658ABF)
                                : _ProgressColors.muted,
                        fontSize: hasData ? 20 : 11,
                        fontWeight: hasData ? FontWeight.w800 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _AnimatedFillBar(
                  fraction:
                      hasData ? topic.masteryPercent.toDouble() / 100 : null,
                  height: 8,
                  color: color,
                ),
                const SizedBox(height: 10),
                Text(
                  hasData
                      ? '${topic.questionsCorrect} of ${topic.questionsTotal} answers correct'
                      : 'Try a quiz on this topic',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8394AF),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty({
    required this.kind,
    required this.title,
    required this.description,
    this.action,
  });

  final StatisticsEmptyArtKind kind;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 28, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StatisticsEmptyArt(kind: kind),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.lexend(
              color: _ProgressColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _ProgressColors.muted,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
          if (action != null) ...<Widget>[const SizedBox(height: 18), action!],
        ],
      ),
    ),
  );
}

class _ProgressAction extends StatelessWidget {
  const _ProgressAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor:
          primary ? _ProgressColors.blue : _ProgressColors.softBlue,
      foregroundColor: primary ? Colors.white : _ProgressColors.secondaryText,
      minimumSize: Size(0, primary ? 48 : 44),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label),
        const SizedBox(width: 8),
        Icon(icon, size: 18),
      ],
    ),
  );
}

Future<void> _showScoreDetails(
  BuildContext context,
  LessonQuizScore score,
  int index,
) => AppDialog.show<void>(
  context,
  title: score.lessonTitle,
  message: 'Lesson ${index + 1} · Most recent submitted linked quiz result',
  icon: Icons.bar_chart_rounded,
  content: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        formatPercent(score.scorePercent),
        style: GoogleFonts.lexend(
          color: const Color(0xFF537FD3),
          fontSize: 42,
          fontWeight: FontWeight.w800,
        ),
      ),
      if (score.score != null && score.totalQuestions != null)
        Text('Score: ${score.score} of ${score.totalQuestions} questions'),
      if (score.submittedAt != null)
        Text(
          'Submitted ${MaterialLocalizations.of(context).formatMediumDate(score.submittedAt!)}',
        ),
    ],
  ),
  actions: <Widget>[
    _ProgressAction(
      label: 'Done',
      icon: Icons.check_rounded,
      primary: true,
      onPressed: () => Navigator.of(context).pop(),
    ),
  ],
);

Future<void> _showTopicDetails(
  BuildContext context,
  TopicMastery topic,
) => AppDialog.show<void>(
  context,
  title: topic.topic,
  message: 'Practice results from completed regular quizzes',
  icon: Icons.insights_rounded,
  content: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        topic.questionsTotal > 0
            ? formatPercent(topic.masteryPercent)
            : 'No data yet',
        style: GoogleFonts.lexend(
          color: const Color(0xFF537FD3),
          fontSize: topic.questionsTotal > 0 ? 42 : 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      if (topic.questionsTotal > 0)
        Text(
          '${topic.questionsCorrect} correct out of ${topic.questionsTotal} answers',
        )
      else
        const Text('No answers recorded for this topic yet.'),
    ],
  ),
  actions: <Widget>[
    _ProgressAction(
      label: 'Done',
      icon: Icons.check_rounded,
      primary: true,
      onPressed: () => Navigator.of(context).pop(),
    ),
  ],
);

Future<void> _showCompletedLessonsDialog(
  BuildContext context, {
  required List<StudentCompletedLesson> completedLessons,
  required int lessonsTotal,
}) => AppDialog.show<void>(
  context,
  title: 'Completed lessons',
  type: AppDialogType.success,
  icon: Icons.task_alt_rounded,
  message:
      '${completedLessons.length} of $lessonsTotal '
      '${lessonsTotal == 1 ? 'lesson' : 'lessons'} completed',
  maxWidth: 560,
  content:
      completedLessons.isEmpty
          ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: AppEmptyState(
              icon: Icons.menu_book_rounded,
              title: 'No completed lessons yet',
              description: 'Finish a lesson to add it to your completed list.',
            ),
          )
          : Column(
            children: <Widget>[
              for (final StudentCompletedLesson completed in completedLessons)
                _CompletedLessonRow(completed: completed),
            ],
          ),
  actions: <Widget>[
    _ProgressAction(
      label: 'Done',
      icon: Icons.check_rounded,
      primary: true,
      onPressed: () => Navigator.of(context).pop(),
    ),
  ],
);

class _CompletedLessonRow extends StatelessWidget {
  const _CompletedLessonRow({required this.completed});

  final StudentCompletedLesson completed;

  @override
  Widget build(BuildContext context) {
    final String number = completed.lessonNumber.toString().padLeft(2, '0');
    return Container(
      key: ValueKey<String>('completed_lesson_${completed.lesson.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FD),
        border: Border.all(color: _ProgressColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 21,
            backgroundColor: const Color(0xFFEDF3FF),
            child: Text(
              number,
              style: GoogleFonts.inter(
                color: _ProgressColors.blue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'LESSON $number',
                  style: GoogleFonts.inter(
                    color: _ProgressColors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  completed.lesson.title,
                  style: GoogleFonts.inter(
                    color: _ProgressColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Color(0xFF5B9C7A)),
        ],
      ),
    );
  }
}
