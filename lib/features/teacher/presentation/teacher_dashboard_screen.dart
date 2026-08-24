import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/section.dart';
import '../../../core/models/teacher_dashboard.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/teacher_dashboard_providers.dart';
import 'teacher_dashboard_roster_screen.dart';
import 'teacher_intervention_screens.dart';
import 'teacher_sections_list_screen.dart';
import 'teacher_shell_screen.dart' show MySection, mySectionsProvider;

// ── Design-system tokens (dashboard-local) ──────────────────────────────────
// These mirror the HTML reference palette exactly.  They are kept private to
// this file so the global AppColors palette is not modified in this session.
abstract final class _DC {
  static const Color surface1   = Color(0xFFF0F1F4);
  static const Color surface2   = Color(0xFFFFFFFF);
  static const Color border     = Color(0xFFE3E5E9);
  static const Color textPrimary   = Color(0xFF1A1B1E);
  static const Color textSecondary = Color(0xFF62666D);
  static const Color textMuted     = Color(0xFF9599A0);
  static const Color accent     = Color(0xFF378ADD);
  static const Color success    = Color(0xFF639922);
  static const Color warning    = Color(0xFFBA7517);
}

// ── Grade-level provider (unchanged logic) ───────────────────────────────────
final Provider<List<GradeLevel>> teacherGradeLevelsProvider =
    Provider<List<GradeLevel>>((ref) {
  final List<MySection> mySections =
      ref.watch(mySectionsProvider).value ?? const <MySection>[];
  final Set<GradeLevel> grades = <GradeLevel>{
    for (final MySection s in mySections)
      if (s.section != null) s.section!.gradeLevel,
  };
  final List<GradeLevel> sorted = grades.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  return sorted;
});

// ── Root screen ──────────────────────────────────────────────────────────────
class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

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
          _ChartRow(),
        ],
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState session =
        ref.watch(sessionProvider).value ?? const SessionNone();
    final String fullName =
        session is SessionTeacher ? session.profile.fullName : 'Teacher';

    final List<MySection> mySections =
        ref.watch(mySectionsProvider).value ?? const <MySection>[];
    final List<GradeLevel> teacherGrades =
        ref.watch(teacherGradeLevelsProvider);
    final GradeLevel? selectedGrade = ref.watch(selectedGradeLevelProvider);
    final String? selectedSectionId = ref.watch(selectedSectionIdProvider);

    final List<MySection> sectionsInScope = <MySection>[
      for (final MySection s in mySections)
        if (s.section != null &&
            (selectedGrade == null ||
                s.section!.gradeLevel == selectedGrade))
          s,
    ];

    final String allSectionsLabel = selectedGrade == null
        ? 'All Sections'
        : 'All ${selectedGrade.label} Sections';

    final Widget nameText = Text(
      fullName,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: _DC.textPrimary,
      ),
    );

    final Widget gradeDropdown = _StyledDropdown<GradeLevel?>(
      value: selectedGrade,
      hint: 'All grades',
      items: <DropdownMenuItem<GradeLevel?>>[
        const DropdownMenuItem<GradeLevel?>(
            value: null, child: Text('All grades')),
        for (final GradeLevel g in teacherGrades)
          DropdownMenuItem<GradeLevel?>(value: g, child: Text(g.label)),
      ],
      onChanged: (GradeLevel? v) => selectGradeLevel(ref, v),
    );

    final Widget sectionDropdown = _StyledDropdown<String?>(
      value: selectedSectionId,
      hint: allSectionsLabel,
      items: <DropdownMenuItem<String?>>[
        DropdownMenuItem<String?>(value: null, child: Text(allSectionsLabel)),
        for (final MySection s in sectionsInScope)
          DropdownMenuItem<String?>(
              value: s.section!.id, child: Text(s.section!.name)),
      ],
      onChanged: (String? v) =>
          ref.read(selectedSectionIdProvider.notifier).state = v,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 640) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              nameText,
              const Spacer(),
              gradeDropdown,
              const SizedBox(width: 8),
              sectionDropdown,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            nameText,
            const SizedBox(height: AppSpacing.sm),
            gradeDropdown,
            const SizedBox(height: AppSpacing.sm),
            sectionDropdown,
          ],
        );
      },
    );
  }
}

// Compact dropdown styled to match the reference (white bg, 1-px border,
// 8-px radius, 36-px height, 13-px text).
class _StyledDropdown<T> extends StatelessWidget {
  const _StyledDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _DC.surface2,
        border: Border.all(color: _DC.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint,
              style:
                  const TextStyle(fontSize: 13, color: _DC.textPrimary)),
          isDense: true,
          style:
              const TextStyle(fontSize: 13, color: _DC.textPrimary),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Summary tiles ────────────────────────────────────────────────────────────
class _SummaryTilesSection extends ConsumerWidget {
  const _SummaryTilesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardSummaryTiles> tilesAsync =
        ref.watch(dashboardSummaryTilesProvider);

    return tilesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: AppLoadingIndicator(),
      ),
      error: (error, _) => AppErrorState(
        message: error is AppFailure
            ? error.message
            : 'Could not load the summary tiles.',
        onRetry: () => ref.invalidate(dashboardSummaryTilesProvider),
      ),
      data: (tiles) => _SummaryTilesGrid(tiles: tiles),
    );
  }
}

enum _TileDrilldown { roster, intervention, sectionsList }

class _DashboardTileData {
  const _DashboardTileData({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.drilldown = _TileDrilldown.roster,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final _TileDrilldown drilldown;
}

class _SummaryTilesGrid extends StatelessWidget {
  const _SummaryTilesGrid({required this.tiles});

  final DashboardSummaryTiles tiles;

  @override
  Widget build(BuildContext context) {
    final List<_DashboardTileData> data = <_DashboardTileData>[
      _DashboardTileData(
        icon: Icons.groups_outlined,
        iconColor: _DC.accent,
        label: 'Total sections',
        value: '${tiles.totalSections}',
        drilldown: _TileDrilldown.sectionsList,
      ),
      _DashboardTileData(
        icon: Icons.people_outline,
        iconColor: _DC.accent,
        label: 'Total students',
        value: '${tiles.totalStudents}',
      ),
      _DashboardTileData(
        icon: Icons.track_changes_outlined,
        iconColor: _DC.success,
        label: 'Average quiz score',
        value: formatPercent(tiles.averageQuizScorePercent),
      ),
      _DashboardTileData(
        icon: Icons.warning_amber_outlined,
        iconColor: _DC.warning,
        label: 'Students needing help',
        value: '${tiles.studentsNeedingIntervention}',
        drilldown: _TileDrilldown.intervention,
      ),
    ];

    // Responsive Wrap: tiles flow to the next line instead of overflowing.
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        for (final _DashboardTileData d in data)
          LayoutBuilder(
            builder: (context, constraints) {
              // Each tile is at least 160 px wide; on wider layouts they share
              // the full width in groups of 4, 2, or 1.
              return ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 160),
                child: _StatCard(data: d),
              );
            },
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _DashboardTileData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => switch (data.drilldown) {
            _TileDrilldown.intervention =>
              const TeacherInterventionStudentsScreen(),
            _TileDrilldown.sectionsList => const TeacherSectionsListScreen(),
            _TileDrilldown.roster => const TeacherDashboardRosterScreen(),
          },
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _DC.surface1,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(data.icon, size: 20, color: data.iconColor),
            const SizedBox(height: 10),
            Text(
              data.label,
              style: const TextStyle(
                  fontSize: 13, color: _DC.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              data.value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: _DC.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chart row (2-column on wide, stacked on narrow) ──────────────────────────
class _ChartRow extends StatelessWidget {
  const _ChartRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 640) {
          return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _AverageScoreBySectionCard()),
              SizedBox(width: 12),
              Expanded(child: _CompetencyMasteryChartCard()),
            ],
          );
        }
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _AverageScoreBySectionCard(),
            SizedBox(height: 12),
            _CompetencyMasteryChartCard(),
          ],
        );
      },
    );
  }
}

// ── Average per section card ─────────────────────────────────────────────────
class _AverageScoreBySectionCard extends ConsumerWidget {
  const _AverageScoreBySectionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SectionAverageScore>> dataAsync =
        ref.watch(dashboardAverageScoreBySectionProvider);

    return _ChartCard(
      title: 'Average per section',
      subtitle: 'Quiz score average, by section',
      child: dataAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: AppLoadingIndicator(),
        ),
        error: (error, _) => AppErrorState(
          message: error is AppFailure
              ? error.message
              : 'Could not load section averages.',
          onRetry: () =>
              ref.invalidate(dashboardAverageScoreBySectionProvider),
        ),
        data: (sections) {
          if (sections.isEmpty) {
            return const _EmptyChartNote(
              'No sections yet. Sections you are assigned to will appear here.');
          }
          return _HorizontalBarList(
            color: _DC.accent,
            labelWidth: 80,
            emptyNote: sections.length == 1
                ? 'More sections appear here as you add them.'
                : null,
            items: <_BarDatum>[
              for (final SectionAverageScore s in sections)
                _BarDatum(
                    label: s.sectionName,
                    value: s.averageQuizScorePercent),
            ],
          );
        },
      ),
    );
  }
}

// ── Competency mastery card ───────────────────────────────────────────────────
class _CompetencyMasteryChartCard extends ConsumerWidget {
  const _CompetencyMasteryChartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TopicMasteryEntry>> dataAsync =
        ref.watch(dashboardCompetencyMasteryProvider);

    return _ChartCard(
      title: 'Competency mastery',
      subtitle: 'Class average, by competency',
      child: dataAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: AppLoadingIndicator(),
        ),
        error: (error, _) => AppErrorState(
          message: error is AppFailure
              ? error.message
              : 'Could not load competency mastery.',
          onRetry: () => ref.invalidate(dashboardCompetencyMasteryProvider),
        ),
        data: (topics) {
          if (topics.isEmpty) {
            return const _EmptyChartNote(
                'No mastery data yet. Once students complete quizzes, '
                'topic mastery will appear here.');
          }
          return _HorizontalBarList(
            color: _DC.success,
            labelWidth: 130,
            emptyNote: topics.length == 1
                ? 'More competencies appear here as quizzes cover them.'
                : null,
            items: <_BarDatum>[
              for (final TopicMasteryEntry t in topics)
                _BarDatum(label: t.topic, value: t.masteryPercent),
            ],
          );
        },
      ),
    );
  }
}

// ── Shared chart card shell ───────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: _DC.surface2,
        border: Border.all(color: _DC.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _DC.textPrimary)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: _DC.textMuted)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Horizontal bar list ───────────────────────────────────────────────────────
class _BarDatum {
  const _BarDatum({required this.label, required this.value});

  final String label;

  /// Null → no quiz data yet (no bar drawn, just label + dash).
  final num? value;
}

class _HorizontalBarList extends StatelessWidget {
  const _HorizontalBarList({
    required this.items,
    required this.color,
    required this.labelWidth,
    this.emptyNote,
  });

  final List<_BarDatum> items;
  final Color color;
  final double labelWidth;

  /// Shown below the rows when the list has only 1 item, so the card
  /// doesn't look broken/empty.
  final String? emptyNote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final _BarDatum d in items) _BarRow(d, color, labelWidth),
        if (emptyNote != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              emptyNote!,
              style:
                  const TextStyle(fontSize: 12, color: _DC.textMuted),
            ),
          ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow(this.datum, this.color, this.labelWidth);

  final _BarDatum datum;
  final Color color;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final double pct =
        (datum.value ?? 0).clamp(0, 100).toDouble() / 100.0;
    final String valueText =
        datum.value == null ? '—' : formatPercent(datum.value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          // Label (fixed width, truncates with ellipsis)
          SizedBox(
            width: labelWidth,
            child: Text(
              datum.label,
              style: const TextStyle(
                  fontSize: 13, color: _DC.textPrimary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 10),
          // Bar track
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 14,
                color: _DC.surface1,
                alignment: Alignment.centerLeft,
                child: datum.value == null
                    ? const SizedBox.shrink()
                    : FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Value label (right-aligned, fixed width)
          SizedBox(
            width: 38,
            child: Text(
              valueText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _DC.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty chart note ──────────────────────────────────────────────────────────
class _EmptyChartNote extends StatelessWidget {
  const _EmptyChartNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: _DC.textMuted),
      ),
    );
  }
}
