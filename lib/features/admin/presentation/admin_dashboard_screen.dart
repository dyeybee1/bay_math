import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_dimensions.dart';
import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/admin_dashboard.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/admin_dashboard_providers.dart';
import 'admin_dashboard_drilldown_screens.dart';

/// Admin Dashboard (0039) — Part 5: the summary screen (tiles + charts).
/// Does NOT include the top-of-screen school year selector or
/// notification bell from the approved design — see the `// TODO`s in
/// [_DashboardHeader] below; neither an equivalent selector nor a
/// notification-bell widget exists anywhere else in this codebase yet
/// (only `selectedSchoolYearIdProvider` in `sections_screen.dart`, which
/// is that screen's own local filter state, not a reusable global
/// widget), so this phase does not invent either rather than guessing at
/// a shape a later phase would just have to redo. Does NOT include shell/
/// router wiring — that's Part 6, once this screen exists and compiles.
///
/// Deliberately returns [AppPageContainer] directly as its body, with NO
/// own [Scaffold]/[AppBar] — mirroring [TeacherDashboardScreen] and the
/// existing [AdminShellScreen] `IndexedStack` destinations
/// (`TeacherApprovalScreen`/`SchoolYearsScreen`/`SectionsScreen`): the
/// shell already supplies one `Scaffold`/`AppBar`/`NavigationRail` for all
/// of them, so nesting a second `Scaffold` here would double up on that
/// chrome the moment Part 6 embeds this as a fourth destination. For an
/// ad hoc manual check before that wiring exists, wrap it in a bare
/// `Scaffold` from OUTSIDE (e.g. `Scaffold(body: AdminDashboardScreen())`
/// in a throwaway harness) rather than adding one here.
///
/// Three independent [AsyncValue]s, not one combined gate — same choice
/// [TeacherDashboardScreen] makes and for the identical reason (see
/// `AdminDashboardRepository`'s and `admin_dashboard_providers.dart`'s own
/// doc comments, Parts 3-4): the tiles and the two charts are meant to
/// load (and fail, and retry) independently here, not as one bundled
/// payload.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppPageContainer(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _DashboardHeader(),
          SizedBox(height: AppSpacing.lg),
          _SummaryTilesSection(),
          SizedBox(height: AppSpacing.lg),
          _ScoreByGradeChartCard(),
          SizedBox(height: AppSpacing.lg),
          _ProficiencyDistributionChartCard(),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Header — admin name only
// -----------------------------------------------------------------------

class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState session = ref.watch(sessionProvider).value ?? const SessionNone();
    final String fullName = session is SessionAdmin ? session.profile.fullName : 'Admin';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text('BayMath Administration System', style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        // TODO(admin-dashboard): "School Year 2025-2026" selector from the
        // approved design. No reusable global school-year-selector widget
        // exists yet (only `selectedSchoolYearIdProvider`, local to
        // `sections_screen.dart`) — wire this up once one exists, rather
        // than inventing a one-off duplicate here.
        // TODO(admin-dashboard): notification bell from the approved
        // design. No notifications feature/widget exists anywhere in this
        // codebase yet — wire this up once one exists.
        Text(fullName, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

// -----------------------------------------------------------------------
// Summary tiles
// -----------------------------------------------------------------------

class _SummaryTilesSection extends ConsumerWidget {
  const _SummaryTilesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdminSummaryTiles> tilesAsync = ref.watch(adminSummaryTilesProvider);

    return tilesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: AppLoadingIndicator(),
      ),
      error: (error, _) => AppErrorState(
        message: error is AppFailure ? error.message : 'Could not load the summary tiles.',
        onRetry: () => ref.invalidate(adminSummaryTilesProvider),
      ),
      data: (tiles) => _SummaryTilesGrid(tiles: tiles),
    );
  }
}

class _DashboardTileData {
  const _DashboardTileData({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Drill-down navigation for this tile (0041). Null for tiles with no
  /// drill-down (Total Students — out of scope, not requested).
  final VoidCallback? onTap;
}

class _SummaryTilesGrid extends StatelessWidget {
  const _SummaryTilesGrid({required this.tiles});

  final AdminSummaryTiles tiles;

  @override
  Widget build(BuildContext context) {
    final List<_DashboardTileData> data = <_DashboardTileData>[
      _DashboardTileData(
        icon: Icons.people_outline,
        label: 'Total Students',
        value: '${tiles.totalStudents}',
      ),
      _DashboardTileData(
        icon: Icons.school_outlined,
        label: 'Total Teachers',
        value: '${tiles.totalTeachers}',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AdminTeachersListScreen()),
        ),
      ),
      _DashboardTileData(
        icon: Icons.groups_outlined,
        label: 'Total Sections',
        value: '${tiles.totalSections}',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AdminSectionsListScreen()),
        ),
      ),
      _DashboardTileData(
        icon: Icons.assignment_outlined,
        label: 'Total Quiz Attempts',
        value: '${tiles.totalQuizAttempts}',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AdminQuizAttemptsByGradeScreen()),
        ),
      ),
      _DashboardTileData(
        icon: Icons.trending_up_outlined,
        label: 'Average Mathematics Score',
        value: formatPercent(tiles.averageScore),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AdminScoreByGradeScreen()),
        ),
      ),
      _DashboardTileData(
        icon: Icons.report_problem_outlined,
        label: 'Students Requiring Intervention',
        value: '${tiles.studentsRequiringIntervention}',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AdminInterventionStudentsScreen()),
        ),
      ),
    ];

    // 3 columns on the Desktop/Web-only layout this shell targets
    // (`AdminShellScreen`'s own comment: "appropriate for the
    // Desktop/Web-only Admin experience"), matching the approved design's
    // 3-column/2-row layout for 6 tiles; 2 or 1 on narrower widths as a
    // graceful fallback, same breakpoint reasoning
    // `_SummaryTilesGrid` in `teacher_dashboard_screen.dart` uses for its
    // own (4-tile) grid.
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 600
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: columns == 1 ? 2.6 : 1.9,
          children: <Widget>[for (final _DashboardTileData d in data) _DashboardTile(data: d)],
        );
      },
    );
  }
}

/// Same visual shape as `teacher_dashboard_screen.dart`'s private
/// `_DashboardTile`. Unlike that screen (where all four tiles open the
/// SAME shared roster screen), each of these 6 tiles opens its OWN
/// metric-specific drill-down (0041) via [_DashboardTileData.onTap] — a
/// tile with no drill-down (Total Students) gets a null [AppCard.onTap],
/// which renders as a plain, non-tappable card with no ripple.
class _DashboardTile extends StatelessWidget {
  const _DashboardTile({required this.data});

  final _DashboardTileData data;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AppCard(
      size: AppComponentSize.small,
      onTap: data.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.smallAll,
            ),
            child: Icon(data.icon, size: AppDimensions.iconSmall, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            data.label,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            data.value,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// "Average Score by Grade Level" bar chart
// -----------------------------------------------------------------------

class _ScoreByGradeChartCard extends ConsumerWidget {
  const _ScoreByGradeChartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GradeLevelAverageScore>> dataAsync =
        ref.watch(adminScoreByGradeProvider);

    return AppCard(
      header: const Text('Average Score by Grade Level'),
      child: SizedBox(
        height: 260,
        child: dataAsync.when(
          loading: () => const AppLoadingIndicator(),
          error: (error, _) => AppErrorState(
            message: error is AppFailure ? error.message : 'Could not load grade-level averages.',
            onRetry: () => ref.invalidate(adminScoreByGradeProvider),
          ),
          data: (grades) {
            if (grades.isEmpty) {
              // Per 0039's own guarantee (Function 2 always returns one
              // row per GradeLevel value), this branch should not occur
              // in practice — kept as a defensive fallback rather than an
              // assumption the caller relies on unconditionally.
              return const AppEmptyState(
                icon: Icons.bar_chart_outlined,
                title: 'No grade-level data yet',
                description: 'Scores will appear here once students complete quizzes.',
              );
            }
            return _GradeScoreBarChart(data: grades);
          },
        ),
      ),
    );
  }
}

/// Structurally mirrors `teacher_dashboard_screen.dart`'s private
/// `_PercentBarChart` (same `fl_chart` `BarChart`/`BarChartData`
/// configuration, same null-value-means-no-bar-drawn handling) —
/// duplicated here rather than imported, since that class is private to
/// its own file, the same "structurally mirrors, not shared" relationship
/// that class itself has with `student_statistics_screen.dart`'s
/// `_LessonScoresBarChart`. X-axis label is each grade's [GradeLevel.label]
/// ("Grade 4"/"Grade 5"/"Grade 6") directly, matching the approved design.
class _GradeScoreBarChart extends StatelessWidget {
  const _GradeScoreBarChart({required this.data});

  final List<GradeLevelAverageScore> data;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 100,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(color: colorScheme.outlineVariant, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: textTheme.bodySmall),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(data[index].gradeLevel.label, style: textTheme.bodySmall),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final GradeLevelAverageScore datum = data[group.x.toInt()];
              return BarTooltipItem(
                '${datum.gradeLevel.label}\n${formatPercent(datum.averageScore)}',
                TextStyle(color: colorScheme.onInverseSurface),
              );
            },
          ),
        ),
        barGroups: <BarChartGroupData>[
          for (int i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: data[i].averageScore == null
                  ? const <BarChartRodData>[]
                  : <BarChartRodData>[
                      BarChartRodData(
                        toY: data[i].averageScore!.clamp(0, 100).toDouble(),
                        color: colorScheme.primary,
                        width: 32,
                        borderRadius: AppRadius.smallAll,
                      ),
                    ],
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// "Proficiency Distribution" pie chart
// -----------------------------------------------------------------------

class _ProficiencyDistributionChartCard extends ConsumerWidget {
  const _ProficiencyDistributionChartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProficiencyDistribution>> dataAsync =
        ref.watch(adminProficiencyDistributionProvider);

    return AppCard(
      header: const Text('Proficiency Distribution'),
      child: SizedBox(
        height: 260,
        child: dataAsync.when(
          loading: () => const AppLoadingIndicator(),
          error: (error, _) => AppErrorState(
            message:
                error is AppFailure ? error.message : 'Could not load the proficiency distribution.',
            onRetry: () => ref.invalidate(adminProficiencyDistributionProvider),
          ),
          data: (buckets) {
            // Per 0039's Function 3, a bucket with zero currently-active
            // qualifying students has no row — so an empty list here means
            // "nobody has a completed attempt yet", a valid empty state
            // rather than an error, matching that function's own comment.
            if (buckets.isEmpty) {
              return const AppEmptyState(
                icon: Icons.pie_chart_outline,
                title: 'No proficiency data yet',
                description: 'This chart fills in once students complete quizzes.',
              );
            }
            return _ProficiencyPieChart(buckets: buckets);
          },
        ),
      ),
    );
  }
}

/// [ProficiencyBucket] -> color mapping. Reuses the app's existing 4-tier
/// semantic palette (`AppSemanticColors.success/info/warning` +
/// `ColorScheme.error`) rather than introducing new chart-only colors —
/// the tiers already line up directionally with the 4 buckets (best to
/// worst): Advanced=success, Proficient=info, Approaching
/// Proficiency=warning, Below Basic=error.
Color _colorForBucket(ProficiencyBucket bucket, ColorScheme colorScheme, AppSemanticColors semantic) {
  return switch (bucket) {
    ProficiencyBucket.advanced => semantic.success,
    ProficiencyBucket.proficient => semantic.info,
    ProficiencyBucket.approachingProficiency => semantic.warning,
    ProficiencyBucket.belowBasic => colorScheme.error,
  };
}

/// Structurally mirrors `student_statistics_screen.dart`'s private
/// `_AccuracyPieChart`/`_LegendRow` (same `fl_chart` `PieChart`/
/// `PieChartData` configuration, same chart-left/legend-right `Row`
/// split) — duplicated here rather than imported since both are private
/// to their own file, extended from 2 fixed segments (correct/incorrect)
/// to the 4 [ProficiencyBucket] segments 0039 actually returns, with each
/// legend row showing the count and percent already computed server-side
/// rather than re-deriving from a raw correct/incorrect count.
class _ProficiencyPieChart extends StatelessWidget {
  const _ProficiencyPieChart({required this.buckets});

  final List<ProficiencyDistribution> buckets;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AppSemanticColors semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 32,
              sections: <PieChartSectionData>[
                for (final ProficiencyDistribution b in buckets)
                  PieChartSectionData(
                    value: b.studentCount.toDouble(),
                    color: _colorForBucket(b.bucket, colorScheme, semantic),
                    title: '',
                    radius: 60,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final ProficiencyDistribution b in buckets) ...<Widget>[
                _ProficiencyLegendRow(
                  color: _colorForBucket(b.bucket, colorScheme, semantic),
                  bucket: b,
                ),
                if (b != buckets.last) const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProficiencyLegendRow extends StatelessWidget {
  const _ProficiencyLegendRow({required this.color, required this.bucket});

  final Color color;
  final ProficiencyDistribution bucket;

  @override
  Widget build(BuildContext context) {
    final String label =
        '${bucket.bucket.label}: ${bucket.studentCount} (${formatPercent(bucket.percent)})';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}
