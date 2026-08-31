import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/adult_workspace_colors.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/admin_dashboard.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/admin_dashboard_providers.dart';
import 'admin_dashboard_drilldown_screens.dart';

/// Administrator Statistics summary. The three provider-backed regions remain
/// independent so metrics and charts continue to load, fail, and retry without
/// blocking one another.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: Key('admin_statistics_screen'),
      color: AdultWorkspaceColors.canvas,
      child: AppPageContainer(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _StatisticsHeader(),
            SizedBox(height: AppSpacing.lg),
            _SummaryMetricsSection(),
            SizedBox(height: AppSpacing.xl),
            _AnalyticsHeader(),
            SizedBox(height: AppSpacing.md),
            _AnalyticsSection(),
          ],
        ),
      ),
    );
  }
}

class _StatisticsHeader extends StatelessWidget {
  const _StatisticsHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 720;
        final Widget heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
                  const Text(
                    'SCHOOL INTELLIGENCE',
                    style: TextStyle(
                      color: AdultWorkspaceColors.primaryMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.25,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Statistics',
                    key: const Key('admin_statistics_title'),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AdultWorkspaceColors.ink,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Text(
                      'Review school participation, mathematics performance, '
                      'and students who may need additional support.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AdultWorkspaceColors.secondaryText,
                        height: 1.5,
                      ),
                    ),
                  ),
          ],
        );

        if (compact) return heading;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: heading),
            ...<Widget>[
              const SizedBox(width: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AdultWorkspaceColors.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.insights_outlined,
                      size: 17,
                      color: AdultWorkspaceColors.primary,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      'ADMIN ANALYTICS',
                      style: TextStyle(
                        color: AdultWorkspaceColors.navy,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SummaryMetricsSection extends ConsumerWidget {
  const _SummaryMetricsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdminSummaryTiles> tilesAsync = ref.watch(
      adminSummaryTilesProvider,
    );

    return tilesAsync.when(
      loading:
          () => const _SectionStateSurface(
            child: AppLoadingIndicator(message: 'Loading school statistics'),
          ),
      error:
          (Object error, StackTrace _) => _SectionStateSurface(
            child: AppErrorState(
              message:
                  error is AppFailure
                      ? error.message
                      : 'Could not load the summary statistics.',
              onRetry: () => ref.invalidate(adminSummaryTilesProvider),
            ),
          ),
      data: (AdminSummaryTiles tiles) => _StatisticsSummary(tiles: tiles),
    );
  }
}

class _StatisticsSummary extends StatelessWidget {
  const _StatisticsSummary({required this.tiles});

  final AdminSummaryTiles tiles;

  @override
  Widget build(BuildContext context) {
    final _MetricData students = _MetricData(
      icon: Icons.people_outline_rounded,
      label: 'Students',
      value: '${tiles.totalStudents}',
      supportingText: 'Active enrollment',
    );
    final _MetricData teachers = _MetricData(
      icon: Icons.school_outlined,
      label: 'Teachers',
      value: '${tiles.totalTeachers}',
      supportingText: 'Approved accounts',
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AdminTeachersListScreen(),
            ),
          ),
    );
    final _MetricData sections = _MetricData(
      icon: Icons.groups_outlined,
      label: 'Sections',
      value: '${tiles.totalSections}',
      supportingText: 'Active this school year',
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AdminSectionsListScreen(),
            ),
          ),
    );
    final _MetricData attempts = _MetricData(
      icon: Icons.assignment_outlined,
      label: 'Quiz attempts',
      value: '${tiles.totalQuizAttempts}',
      supportingText: 'Completed attempts',
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AdminQuizAttemptsByGradeScreen(),
            ),
          ),
    );
    final _MetricData averageScore = _MetricData(
      icon: Icons.trending_up_rounded,
      label: 'Average mathematics score',
      value: formatPercent(tiles.averageScore),
      supportingText: 'Across qualifying students',
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AdminScoreByGradeScreen(),
            ),
          ),
    );
    final _MetricData intervention = _MetricData(
      icon: Icons.support_outlined,
      label: 'Students requiring intervention',
      value: '${tiles.studentsRequiringIntervention}',
      supportingText: 'Review by grade and section',
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AdminInterventionStudentsScreen(),
            ),
          ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionHeading(
          title: 'School context',
          description: 'Current people and teaching structure.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _PopulationStrip(metrics: <_MetricData>[students, teachers, sections]),
        const SizedBox(height: AppSpacing.lg),
        const _SectionHeading(
          title: 'Learning and support',
          description: 'Activity, performance, and actionable attention.',
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool useRow = constraints.maxWidth >= 760;
            final Widget learningCard = _LearningOverviewCard(
              attempts: attempts,
              averageScore: averageScore,
            );
            final Widget interventionCard = _InterventionCard(
              data: intervention,
            );

            if (!useRow) {
              return Column(
                children: <Widget>[
                  learningCard,
                  const SizedBox(height: AppSpacing.sm),
                  interventionCard,
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(flex: 7, child: learningCard),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(flex: 4, child: interventionCard),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.supportingText,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String supportingText;
  final VoidCallback? onTap;
}

class _PopulationStrip extends StatelessWidget {
  const _PopulationStrip({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return _StatisticsSurface(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool stack = constraints.maxWidth < 620;
          if (stack) {
            return Column(
              children: <Widget>[
                for (
                  int index = 0;
                  index < metrics.length;
                  index++
                ) ...<Widget>[
                  _MetricCell(data: metrics[index]),
                  if (index != metrics.length - 1)
                    const Divider(
                      height: 1,
                      color: AdultWorkspaceColors.border,
                    ),
                ],
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (
                  int index = 0;
                  index < metrics.length;
                  index++
                ) ...<Widget>[
                  Expanded(child: _MetricCell(data: metrics[index])),
                  if (index != metrics.length - 1)
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AdultWorkspaceColors.border,
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: <Widget>[
          _MetricIcon(icon: data.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data.value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AdultWorkspaceColors.ink,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  data.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AdultWorkspaceColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.supportingText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AdultWorkspaceColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          if (data.onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: AdultWorkspaceColors.primaryMuted,
            ),
        ],
      ),
    );
    return _MetricInteraction(data: data, child: content);
  }
}

class _LearningOverviewCard extends StatelessWidget {
  const _LearningOverviewCard({
    required this.attempts,
    required this.averageScore,
  });

  final _MetricData attempts;
  final _MetricData averageScore;

  @override
  Widget build(BuildContext context) {
    return _StatisticsSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const _MetricIcon(icon: Icons.auto_graph_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Learning activity',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AdultWorkspaceColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Participation and mathematics performance',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AdultWorkspaceColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _LearningMetric(data: attempts)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _LearningMetric(data: averageScore)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LearningMetric extends StatelessWidget {
  const _LearningMetric({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return _MetricInteraction(
      data: data,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: AdultWorkspaceColors.paleBlue,
          borderRadius: AppRadius.mediumAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(data.icon, size: 18, color: AdultWorkspaceColors.primary),
                const Spacer(),
                if (data.onTap != null)
                  const Icon(
                    Icons.north_east_rounded,
                    size: 16,
                    color: AdultWorkspaceColors.primaryMuted,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data.value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AdultWorkspaceColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AdultWorkspaceColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data.supportingText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AdultWorkspaceColors.secondaryText,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterventionCard extends StatelessWidget {
  const _InterventionCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors semantic =
        Theme.of(context).extension<AppSemanticColors>()!;
    return _StatisticsSurface(
      borderColor: semantic.warning.withValues(alpha: 0.35),
      child: _MetricInteraction(
        data: data,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: semantic.warningContainer,
                      borderRadius: AppRadius.mediumAll,
                    ),
                    child: Icon(
                      data.icon,
                      color: semantic.onWarningContainer,
                      size: 21,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AdultWorkspaceColors.primaryMuted,
                    size: 19,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                data.value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AdultWorkspaceColors.ink,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                data.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AdultWorkspaceColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                data.supportingText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AdultWorkspaceColors.secondaryText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricInteraction extends StatelessWidget {
  const _MetricInteraction({required this.data, required this.child});

  final _MetricData data;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final String semanticLabel =
        '${data.label}: ${data.value}. ${data.supportingText}'
        '${data.onTap == null ? '' : '. Open details'}';
    if (data.onTap == null) {
      return Semantics(label: semanticLabel, child: child);
    }
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: data.onTap,
          borderRadius: AppRadius.mediumAll,
          hoverColor: AdultWorkspaceColors.softBlue.withValues(alpha: 0.75),
          focusColor: AdultWorkspaceColors.primary.withValues(alpha: 0.13),
          splashColor: AdultWorkspaceColors.primary.withValues(alpha: 0.1),
          child: child,
        ),
      ),
    );
  }
}

class _MetricIcon extends StatelessWidget {
  const _MetricIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AdultWorkspaceColors.softBlue,
        borderRadius: AppRadius.mediumAll,
      ),
      child: Icon(icon, size: 20, color: AdultWorkspaceColors.navy),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AdultWorkspaceColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AdultWorkspaceColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader();

  @override
  Widget build(BuildContext context) {
    return const _SectionHeading(
      title: 'Performance analysis',
      description: 'Grade-level outcomes and student proficiency distribution.',
    );
  }
}

class _AnalyticsSection extends StatelessWidget {
  const _AnalyticsSection();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool sideBySide = constraints.maxWidth >= 900;
        if (!sideBySide) {
          return const Column(
            children: <Widget>[
              _ScoreByGradeChartCard(),
              SizedBox(height: AppSpacing.md),
              _ProficiencyDistributionChartCard(),
            ],
          );
        }
        return const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _ScoreByGradeChartCard()),
              SizedBox(width: AppSpacing.md),
              Expanded(child: _ProficiencyDistributionChartCard()),
            ],
          ),
        );
      },
    );
  }
}

class _ScoreByGradeChartCard extends ConsumerWidget {
  const _ScoreByGradeChartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GradeLevelAverageScore>> dataAsync = ref.watch(
      adminScoreByGradeProvider,
    );

    return _AnalyticsCard(
      icon: Icons.bar_chart_rounded,
      title: 'Average score by grade level',
      description: 'Average mathematics performance across Grades 4–6.',
      child: SizedBox(
        height: 280,
        child: dataAsync.when(
          loading:
              () => const AppLoadingIndicator(
                message: 'Loading grade-level performance',
              ),
          error:
              (Object error, StackTrace _) => AppErrorState(
                message:
                    error is AppFailure
                        ? error.message
                        : 'Could not load grade-level averages.',
                onRetry: () => ref.invalidate(adminScoreByGradeProvider),
              ),
          data: (List<GradeLevelAverageScore> grades) {
            if (grades.isEmpty) {
              return const AppEmptyState(
                icon: Icons.bar_chart_outlined,
                title: 'No grade-level data yet',
                description:
                    'Scores will appear here once students complete quizzes.',
              );
            }
            final String summary = grades
                .map(
                  (GradeLevelAverageScore grade) =>
                      '${grade.gradeLevel.label}: '
                      '${formatPercent(grade.averageScore)}',
                )
                .join(', ');
            return Semantics(
              label: 'Average score by grade level. $summary',
              image: true,
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: _GradeScoreBarChart(data: grades),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GradeScoreBarChart extends StatelessWidget {
  const _GradeScoreBarChart({required this.data});

  final List<GradeLevelAverageScore> data;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 100,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine:
              (double value) => const FlLine(
                color: AdultWorkspaceColors.border,
                strokeWidth: 1,
              ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              reservedSize: 42,
              getTitlesWidget:
                  (double value, TitleMeta meta) => Text(
                    '${value.toInt()}%',
                    style: textTheme.bodySmall?.copyWith(
                      color: AdultWorkspaceColors.secondaryText,
                      fontSize: 10,
                    ),
                  ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    data[index].gradeLevel.label,
                    style: textTheme.bodySmall?.copyWith(
                      color: AdultWorkspaceColors.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (
              BarChartGroupData group,
              int groupIndex,
              BarChartRodData rod,
              int rodIndex,
            ) {
              final GradeLevelAverageScore datum = data[group.x.toInt()];
              return BarTooltipItem(
                '${datum.gradeLevel.label}\n'
                '${formatPercent(datum.averageScore)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        barGroups: <BarChartGroupData>[
          for (int index = 0; index < data.length; index++)
            BarChartGroupData(
              x: index,
              barRods:
                  data[index].averageScore == null
                      ? const <BarChartRodData>[]
                      : <BarChartRodData>[
                        BarChartRodData(
                          toY:
                              data[index].averageScore!
                                  .clamp(0, 100)
                                  .toDouble(),
                          color: AdultWorkspaceColors.primary,
                          width: 28,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppRadius.medium),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: 100,
                            color: AdultWorkspaceColors.paleBlue,
                          ),
                        ),
                      ],
            ),
        ],
      ),
    );
  }
}

class _ProficiencyDistributionChartCard extends ConsumerWidget {
  const _ProficiencyDistributionChartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProficiencyDistribution>> dataAsync = ref.watch(
      adminProficiencyDistributionProvider,
    );

    return _AnalyticsCard(
      icon: Icons.donut_large_rounded,
      title: 'Proficiency distribution',
      description: 'Students grouped by their existing proficiency thresholds.',
      child: SizedBox(
        height: 280,
        child: dataAsync.when(
          loading:
              () => const AppLoadingIndicator(
                message: 'Loading proficiency distribution',
              ),
          error:
              (Object error, StackTrace _) => AppErrorState(
                message:
                    error is AppFailure
                        ? error.message
                        : 'Could not load the proficiency distribution.',
                onRetry:
                    () => ref.invalidate(adminProficiencyDistributionProvider),
              ),
          data: (List<ProficiencyDistribution> buckets) {
            if (buckets.isEmpty) {
              return const AppEmptyState(
                icon: Icons.pie_chart_outline,
                title: 'No proficiency data yet',
                description:
                    'This chart fills in once students complete quizzes.',
              );
            }
            final String summary = buckets
                .map(
                  (ProficiencyDistribution bucket) =>
                      '${bucket.bucket.label}: ${bucket.studentCount}, '
                      '${formatPercent(bucket.percent)}',
                )
                .join(', ');
            return Semantics(
              label: 'Proficiency distribution. $summary',
              image: true,
              child: ExcludeSemantics(
                child: _ProficiencyPieChart(buckets: buckets),
              ),
            );
          },
        ),
      ),
    );
  }
}

Color _colorForBucket(
  ProficiencyBucket bucket,
  ColorScheme colorScheme,
  AppSemanticColors semantic,
) {
  return switch (bucket) {
    ProficiencyBucket.advanced => semantic.success,
    ProficiencyBucket.proficient => AdultWorkspaceColors.primary,
    ProficiencyBucket.approachingProficiency => semantic.warning,
    ProficiencyBucket.belowBasic => colorScheme.error,
  };
}

class _ProficiencyPieChart extends StatelessWidget {
  const _ProficiencyPieChart({required this.buckets});

  final List<ProficiencyDistribution> buckets;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AppSemanticColors semantic =
        Theme.of(context).extension<AppSemanticColors>()!;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 420;
        final Widget chart = SizedBox(
          width: compact ? 132 : 156,
          height: compact ? 132 : 156,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: compact ? 34 : 40,
              sections: <PieChartSectionData>[
                for (final ProficiencyDistribution bucket in buckets)
                  PieChartSectionData(
                    value: bucket.studentCount.toDouble(),
                    color: _colorForBucket(
                      bucket.bucket,
                      colorScheme,
                      semantic,
                    ),
                    title: '',
                    radius: compact ? 38 : 44,
                  ),
              ],
            ),
          ),
        );
        final Widget legend = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int index = 0; index < buckets.length; index++) ...<Widget>[
              _ProficiencyLegendRow(
                color: _colorForBucket(
                  buckets[index].bucket,
                  colorScheme,
                  semantic,
                ),
                bucket: buckets[index],
              ),
              if (index != buckets.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );

        if (compact) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              chart,
              const SizedBox(height: AppSpacing.md),
              legend,
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            chart,
            const SizedBox(width: AppSpacing.lg),
            Flexible(child: legend),
          ],
        );
      },
    );
  }
}

class _ProficiencyLegendRow extends StatelessWidget {
  const _ProficiencyLegendRow({required this.color, required this.bucket});

  final Color color;
  final ProficiencyDistribution bucket;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            bucket.bucket.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AdultWorkspaceColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${bucket.studentCount}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AdultWorkspaceColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          formatPercent(bucket.percent),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AdultWorkspaceColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _StatisticsSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MetricIcon(icon: icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: AdultWorkspaceColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AdultWorkspaceColors.secondaryText,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _SectionStateSurface extends StatelessWidget {
  const _SectionStateSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _StatisticsSurface(child: SizedBox(height: 220, child: child));
  }
}

class _StatisticsSurface extends StatelessWidget {
  const _StatisticsSurface({required this.child, this.borderColor});

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.largeAll,
        border: Border.all(color: borderColor ?? AdultWorkspaceColors.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A173D5A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
