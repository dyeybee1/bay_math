import 'dart:convert' show utf8;
import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../../core/errors/app_failure.dart';
import '../../../core/models/section.dart';
import '../../../core/models/teacher_dashboard.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/progress_report_csv_builder.dart';
import '../data/progress_report_providers.dart';
import '../data/teacher_dashboard_providers.dart';
import 'teacher_intervention_screens.dart';
import 'teacher_shell_screen.dart' show MySection, mySectionsProvider;

// ─────────────────────────────────────────────────────────────────────────────
// Progress Reports design tokens — matches the HTML reference mockup.
// Scoped to this file, same pattern as `_C` in `teacher_shell_screen.dart`.
// ─────────────────────────────────────────────────────────────────────────────
abstract final class _PR {
  static const Color primary = Color(0xFF2F4FA6);
  static const Color primaryLight = Color(0xFFEEF2FC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE4E8F1);
  static const Color text = Color(0xFF1E2438);
  static const Color textMuted = Color(0xFF6B7386);
  static const Color textFaint = Color(0xFF9AA1B4);
  static const Color greenBg = Color(0xFFE4F7EC);
  static const Color greenText = Color(0xFF1E8E5A);
  static const Color amberBg = Color(0xFFFDF1DC);
  static const Color amberText = Color(0xFFB4700B);
  static const Color redBg = Color(0xFFFCE8E8);
  static const Color redText = Color(0xFFC23434);
  static const Color iconRedBg = Color(0xFFFDEBEB);
  static const Color iconRed = Color(0xFFE15353);
  static const Color iconGreenBg = Color(0xFFE6F7EE);
  static const Color iconGreen = Color(0xFF2CB673);
  static const Color iconAmberBg = Color(0xFFFEF3DC);
  static const Color iconAmber = Color(0xFFE0A420);
  static const Color trackBg = Color(0xFFEEF0F6);
  static const Color tableHeaderBg = Color(0xFFFAFBFD);
  static const double rLg = 16;
  static const double rSm = 8;
  static const List<BoxShadow> shadow = <BoxShadow>[
    BoxShadow(color: Color(0x0A1E2438), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0A1E2438), offset: Offset(0, 4), blurRadius: 16),
  ];
}

TextStyle _baloo2(double size, {FontWeight weight = FontWeight.w700, Color color = _PR.text}) =>
    GoogleFonts.baloo2(fontSize: size, fontWeight: weight, color: color);

TextStyle _prInter(double size, {FontWeight weight = FontWeight.w400, Color color = _PR.text}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

enum _IconChipVariant { red, green, amber }

/// Teacher Progress Reports (0046) — Part 3: the screen itself.
///
/// Deliberately returns [AppPageContainer] directly as its body, with NO
/// own [Scaffold]/[AppBar] — exactly the same reasoning
/// [TeacherDashboardScreen] documents on itself: this screen is only ever
/// reachable as an `IndexedStack` destination inside [TeacherShellScreen],
/// which already supplies one `Scaffold`/`AppBar`/`NavigationRail` shared
/// across every destination. A second `Scaffold` here would double up on
/// that chrome the moment it's embedded (see the nav-wiring change to
/// `teacher_shell_screen.dart` alongside this file).
///
/// Section-scoped private widgets, one per visual section of the page —
/// [_SummaryTilesSection], [_FiltersSection], [_CompetencyMasterySection],
/// [_StudentMasteryHeatmapSection] — matching [TeacherDashboardScreen]'s
/// own top-level `Column` shape rather than one large `build` method.
///
/// Filter state ([selectedSectionIdProvider], [selectedTopicProvider]) is
/// shared with (`selectedSectionIdProvider`) or new-but-local-to-this-
/// feature (`selectedTopicProvider`, from `progress_report_providers.dart`)
/// — see that file's own doc comment for why the grade/section filters are
/// intentionally the *same* provider instances the Teacher Dashboard
/// screen uses, not a fresh copy. No Grade dropdown is rendered on this
/// screen (locked product decision: "Section + Competency filters only"),
/// but [selectedGradeLevelProvider] is still read here wherever the
/// existing [MySection]-filtering logic needs it, exactly the way
/// [TeacherDashboardScreen]'s `_DashboardHeader` reads it — so a grade
/// filter left selected on the Dashboard screen still narrows this
/// screen's Section dropdown correctly, per the two screens' shared-filter
/// design.
class ProgressReportsScreen extends ConsumerWidget {
  const ProgressReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppPageContainer(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PageHeader(),
          _SummaryTilesSection(),
          SizedBox(height: 24),
          _FiltersSection(),
          SizedBox(height: 16),
          _CompetencyMasterySection(),
          SizedBox(height: 24),
          _StudentMasteryHeatmapSection(),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Summary tiles — Most Difficult / Highest Mastered Competency, Students
// Requiring Intervention. All three are pure derivations over data two
// *existing* providers already fetch (dashboardCompetencyMasteryProvider,
// dashboardSummaryTilesProvider) — no new fetch provider exists for this
// section, per Part 2's own doc comment on `mostDifficultCompetency` /
// `highestMasteredCompetency`.
//
// Watched as one combined gate (both providers' loading/error states
// folded together) rather than three independently-gated tiles. This is a
// deliberate, narrower choice than [TeacherDashboardScreen]'s general
// "independent AsyncValue per section" rule: that rule applies *between*
// page sections (this section vs. the filters vs. the heatmap, each of
// which does gate independently below), not *within* one tile row backed
// by exactly two source providers. There is no existing precedent in this
// codebase for three-way-independent tile-level loading/error UI, and
// inventing one here (e.g. a spinner icon substituted per-tile) would be
// a new pattern this task's constraints say not to introduce.
// -----------------------------------------------------------------------

class _SummaryTilesSection extends ConsumerWidget {
  const _SummaryTilesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TopicMasteryEntry>> competencyAsync =
        ref.watch(dashboardCompetencyMasteryProvider);
    final AsyncValue<DashboardSummaryTiles> tilesAsync = ref.watch(dashboardSummaryTilesProvider);

    if (competencyAsync.isLoading || tilesAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: AppLoadingIndicator(),
      );
    }

    if (competencyAsync.hasError) {
      final Object error = competencyAsync.error!;
      return AppErrorState(
        message: error is AppFailure ? error.message : 'Could not load competency mastery.',
        onRetry: () => ref.invalidate(dashboardCompetencyMasteryProvider),
      );
    }

    if (tilesAsync.hasError) {
      final Object error = tilesAsync.error!;
      return AppErrorState(
        message: error is AppFailure ? error.message : 'Could not load the summary tiles.',
        onRetry: () => ref.invalidate(dashboardSummaryTilesProvider),
      );
    }

    final List<TopicMasteryEntry> competencyEntries =
        competencyAsync.value ?? const <TopicMasteryEntry>[];
    final DashboardSummaryTiles tiles = tilesAsync.value!;

    final TopicMasteryEntry? mostDifficult = mostDifficultCompetency(competencyEntries);
    final TopicMasteryEntry? highestMastered = highestMasteredCompetency(competencyEntries);

    // The needsSupport band lower bound from masteryBandFor — the single
    // source of truth for what "needs support" means in this app. Used to
    // generate the intervention card caption dynamically instead of
    // hardcoding a number here.
    const int needsSupportThreshold = 70; // mirrors masteryBandFor's `< 70` check

    return _SummaryTilesGrid(
      tiles: <_SummaryTileData>[
        _SummaryTileData(
          icon: Icons.trending_down_outlined,
          iconVariant: _IconChipVariant.red,
          label: 'Most Difficult Competency',
          value: mostDifficult == null ? '—' : mostDifficult.topic,
          caption: mostDifficult == null
              ? null
              : 'Avg. ${formatPercent(mostDifficult.masteryPercent)} mastery across sections',
        ),
        _SummaryTileData(
          icon: Icons.trending_up_outlined,
          iconVariant: _IconChipVariant.green,
          label: 'Highest Mastered Competency',
          value: highestMastered == null ? '—' : highestMastered.topic,
          caption: highestMastered == null
              ? null
              : 'Avg. ${formatPercent(highestMastered.masteryPercent)} mastery across sections',
        ),
        _SummaryTileData(
          icon: Icons.report_problem_outlined,
          iconVariant: _IconChipVariant.amber,
          label: 'Students Requiring Intervention',
          value: '${tiles.studentsNeedingIntervention} students',
          caption: 'Below $needsSupportThreshold% on 1+ competency',
          opensInterventionDrilldown: true,
        ),
      ],
    );
  }
}

class _SummaryTileData {
  const _SummaryTileData({
    required this.icon,
    required this.iconVariant,
    required this.label,
    required this.value,
    this.caption,
    this.opensInterventionDrilldown = false,
  });

  final IconData icon;
  final _IconChipVariant iconVariant;
  final String label;
  final String value;
  final String? caption;
  final bool opensInterventionDrilldown;
}

/// Three-card row that never causes a page-level horizontal scroll:
/// on wide viewports all three tiles share the row via [Expanded];
/// on narrow viewports they stack vertically via [Wrap].
class _SummaryTilesGrid extends StatelessWidget {
  const _SummaryTilesGrid({required this.tiles});

  final List<_SummaryTileData> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 600;
        if (wide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: _SummaryTile(data: tiles[i])),
                ],
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _SummaryTile(data: tiles[i]),
            ],
          ],
        );
      },
    );
  }
}

/// Redesigned summary tile with colored icon chip per the HTML reference.
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.data});

  final _SummaryTileData data;

  @override
  Widget build(BuildContext context) {
    final (Color chipBg, Color chipFg) = switch (data.iconVariant) {
      _IconChipVariant.red => (_PR.iconRedBg, _PR.iconRed),
      _IconChipVariant.green => (_PR.iconGreenBg, _PR.iconGreen),
      _IconChipVariant.amber => (_PR.iconAmberBg, _PR.iconAmber),
    };

    final Widget card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _PR.card,
        border: Border.all(color: _PR.border),
        borderRadius: BorderRadius.circular(_PR.rLg),
        boxShadow: _PR.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, size: 19, color: chipFg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.label,
                  style: _prInter(12.5, weight: FontWeight.w600, color: _PR.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(data.value, style: _prInter(17, weight: FontWeight.w700)),
          if (data.caption != null) ...[
            const SizedBox(height: 2),
            Text(data.caption!, style: _prInter(12, color: _PR.textFaint)),
          ],
        ],
      ),
    );

    if (!data.opensInterventionDrilldown) return card;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const TeacherInterventionStudentsScreen(),
        ),
      ),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: card),
    );
  }
}

/// Custom page header matching the HTML reference design.
class _PageHeader extends ConsumerWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Progress Reports', style: _baloo2(28)),
                const SizedBox(height: 4),
                Text(
                  'Per-student and per-topic mastery for your sections.',
                  style: _prInter(14.5, color: _PR.textMuted),
                ),
              ],
            ),
          ),
          const _ExportCsvButton(),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Filters — Section + Competency dropdowns on the left, colour legend
// (Mastered / Proficient / Needs Support dots) right-aligned. No student
// search field on this screen.
//
// The Section dropdown is built exactly the way
// [TeacherDashboardScreen]'s `_DashboardHeader` builds its own section
// selector (same `mySectionsProvider`-derived, [selectedGradeLevelProvider]
// -scoped option list, same "All ___" label logic, same raw [DropdownMenu]
// rather than the [AppDropdown] wrapper `quiz_results_screen.dart` uses
// for its filter row) — this task's constraints say to mirror that pattern
// rather than reinvent it, so the Competency dropdown below is built the
// identical way for visual consistency between the two dropdowns sharing
// this row, even though `_DashboardHeader` has no per-topic filter to
// mirror directly.
// -----------------------------------------------------------------------

class _FiltersSection extends ConsumerWidget {
  const _FiltersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<MySection> mySections = ref.watch(mySectionsProvider).value ?? const <MySection>[];
    final GradeLevel? selectedGrade = ref.watch(selectedGradeLevelProvider);
    final String? selectedSectionId = ref.watch(selectedSectionIdProvider);
    final String? selectedTopic = ref.watch(selectedTopicProvider);
    final List<TopicMasteryEntry> competencyEntries =
        ref.watch(dashboardCompetencyMasteryProvider).value ?? const <TopicMasteryEntry>[];

    // Identical scoping to _DashboardHeader's own `sectionsInScope`.
    final List<MySection> sectionsInScope = <MySection>[
      for (final MySection s in mySections)
        if (s.section != null && (selectedGrade == null || s.section!.gradeLevel == selectedGrade))
          s,
    ];
    final String allSectionsLabel =
        selectedGrade == null ? 'All Sections' : 'All ${selectedGrade.label} Sections';

    final List<String> topics = <String>{for (final TopicMasteryEntry t in competencyEntries) t.topic}
        .toList()
      ..sort();

    final Widget sectionDropdown = DropdownMenu<String?>(
      initialSelection: selectedSectionId,
      label: const Text('Section'),
      onSelected: (String? value) => ref.read(selectedSectionIdProvider.notifier).state = value,
      dropdownMenuEntries: <DropdownMenuEntry<String?>>[
        DropdownMenuEntry<String?>(value: null, label: allSectionsLabel),
        for (final MySection s in sectionsInScope)
          DropdownMenuEntry<String?>(value: s.section!.id, label: s.section!.name),
      ],
    );

    final Widget competencyDropdown = DropdownMenu<String?>(
      initialSelection: selectedTopic,
      label: const Text('Competency'),
      onSelected: (String? value) => ref.read(selectedTopicProvider.notifier).state = value,
      dropdownMenuEntries: <DropdownMenuEntry<String?>>[
        const DropdownMenuEntry<String?>(value: null, label: 'All Competencies'),
        for (final String topic in topics) DropdownMenuEntry<String?>(value: topic, label: topic),
      ],
    );

    // Legend thresholds mirror masteryBandFor's `< 70` / `>= 85` boundaries.
    const int needsSupportCutoff = 70; // same source of truth as the stat cards
    const int masteredCutoff = 85;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _PR.card,
        border: Border.all(color: _PR.border),
        borderRadius: BorderRadius.circular(_PR.rLg),
        boxShadow: _PR.shadow,
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          sectionDropdown,
          competencyDropdown,
          // Color legend — right-side of the filter bar.
          _MasteryLegend(
            masteredCutoff: masteredCutoff,
            needsSupportCutoff: needsSupportCutoff,
          ),
        ],
      ),
    );
  }
}

/// Three-dot colour legend — uses the _PR design tokens directly.
class _MasteryLegend extends StatelessWidget {
  const _MasteryLegend({
    required this.masteredCutoff,
    required this.needsSupportCutoff,
  });

  final int masteredCutoff;
  final int needsSupportCutoff;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _LegendDot(color: _PR.iconGreen, label: 'Mastered ($masteredCutoff%+)'),
        _LegendDot(
          color: _PR.iconAmber,
          label: 'Developing ($needsSupportCutoff\u2013${masteredCutoff - 1}%)',
        ),
        _LegendDot(color: _PR.iconRed, label: 'Needs Support (<$needsSupportCutoff%)'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: _prInter(12, weight: FontWeight.w500, color: _PR.textMuted)),
      ],
    );
  }
}

// -----------------------------------------------------------------------
// Competency Mastery — one row per topic: name, mastery-band pill, a
// progress bar, and the raw %. Reuses `masteryBandFor` (Part 2) rather
// than recomputing the 70/85 thresholds here, per the locked decision.
// -----------------------------------------------------------------------

class _CompetencyMasterySection extends ConsumerWidget {
  const _CompetencyMasterySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TopicMasteryEntry>> dataAsync =
        ref.watch(dashboardCompetencyMasteryProvider);
    final String? selectedTopic = ref.watch(selectedTopicProvider);

    return Container(
      decoration: BoxDecoration(
        color: _PR.card,
        border: Border.all(color: _PR.border),
        borderRadius: BorderRadius.circular(_PR.rLg),
        boxShadow: _PR.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Competency Mastery Overview', style: _baloo2(17)),
                const SizedBox(height: 2),
                Text(
                  'Average mastery per competency, across all sections in scope',
                  style: _prInter(12.5, color: _PR.textFaint),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
            child: dataAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: AppLoadingIndicator(),
              ),
              error: (error, _) => AppErrorState(
                message: error is AppFailure
                    ? error.message
                    : 'Could not load competency mastery.',
                onRetry: () => ref.invalidate(dashboardCompetencyMasteryProvider),
              ),
              data: (topics) {
                final List<TopicMasteryEntry> filtered = selectedTopic == null
                    ? topics
                    : <TopicMasteryEntry>[
                        for (final TopicMasteryEntry t in topics)
                          if (t.topic == selectedTopic) t,
                      ];

                if (filtered.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.insights_outlined,
                    title: 'No mastery data yet',
                    description:
                        'Once students complete quizzes, topic mastery will appear here.',
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int i = 0; i < filtered.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(height: 14),
                      _CompetencyMasteryRow(entry: filtered[i]),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompetencyMasteryRow extends StatelessWidget {
  const _CompetencyMasteryRow({required this.entry});

  final TopicMasteryEntry entry;

  @override
  Widget build(BuildContext context) {
    final MasteryBand? band = masteryBandFor(entry.masteryPercent);

    final Color barColor = switch (band) {
      MasteryBand.mastered => _PR.iconGreen,
      MasteryBand.proficient => _PR.iconAmber,
      MasteryBand.needsSupport => _PR.iconRed,
      null => _PR.border,
    };

    final (Color badgeBg, Color badgeFg) = switch (band) {
      MasteryBand.mastered => (_PR.greenBg, _PR.greenText),
      MasteryBand.proficient => (_PR.amberBg, _PR.amberText),
      MasteryBand.needsSupport => (_PR.redBg, _PR.redText),
      null => (const Color(0xFFF1F2F6), _PR.textFaint),
    };

    return Row(
      children: <Widget>[
        SizedBox(
          width: 230,
          child: Text(
            entry.topic,
            style: _prInter(13.5, weight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 9,
            decoration: BoxDecoration(
              color: _PR.trackBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (entry.masteryPercent.clamp(0, 100) / 100).toDouble(),
              child: Container(
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 42,
          child: Text(
            formatPercent(entry.masteryPercent),
            textAlign: TextAlign.right,
            style: _prInter(13, weight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 100,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            band?.displayLabel ?? '\u2014',
            style: _prInter(11, weight: FontWeight.w700, color: badgeFg),
          ),
        ),
      ],
    );
  }
}


// -----------------------------------------------------------------------
// Student Mastery Heatmap — pinned-column layout mirroring
// quiz_results_table.dart's `_QRAdaptiveTable` approach:
//   • A fixed-width 'Student' column sits in a Row
//   • Competency columns + 'Overall Avg' live inside Expanded(
//     SingleChildScrollView) so only the table area scrolls horizontally
//   • The page itself never causes a page-level horizontal scroll
// -----------------------------------------------------------------------

/// Fixed cell heights — shared by the pinned column and every score column
/// so that row i on the left is always the same height as row i on the right.
const double _hmHeaderH = 48.0;
const double _hmRowH = 52.0;

/// Fixed width of the pinned student-name column.
const double _hmStudentColW = 180.0;

/// Fixed width of each competency (score) column.
const double _hmScoreColW = 120.0;

class _StudentMasteryHeatmapSection extends ConsumerWidget {
  const _StudentMasteryHeatmapSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<StudentTopicMasteryEntry>> dataAsync =
        ref.watch(dashboardStudentTopicMasteryProvider);
    final String? selectedTopic = ref.watch(selectedTopicProvider);

    return Container(
      decoration: BoxDecoration(
        color: _PR.card,
        border: Border.all(color: _PR.border),
        borderRadius: BorderRadius.circular(_PR.rLg),
        boxShadow: _PR.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Student Mastery Heatmap', style: _baloo2(17)),
                const SizedBox(height: 2),
                Text(
                  'Scroll sideways to see all competencies · student column stays fixed',
                  style: _prInter(12.5, color: _PR.textFaint),
                ),
              ],
            ),
          ),
          dataAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: AppLoadingIndicator(),
            ),
            error: (error, _) => AppErrorState(
              message:
                  error is AppFailure ? error.message : 'Could not load the mastery heatmap.',
              onRetry: () => ref.invalidate(dashboardStudentTopicMasteryProvider),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.grid_on_outlined,
                  title: 'No mastery data yet',
                  description:
                      'Once students complete quizzes, their per-topic mastery will appear here.',
                );
              }
              return _HeatmapGrid(entries: entries, selectedTopic: selectedTopic);
            },
          ),
        ],
      ),
    );
  }
}

/// Renders the actual grid. [entries] is always the FULL, unfiltered
/// dataset — [selectedTopic] narrows which columns are drawn, not which
/// rows/students appear, so a student who has no answered questions for
/// the selected topic (but does for others) still gets a row with a blank
/// cell, rather than being dropped from the roster entirely.
class _HeatmapGrid extends StatelessWidget {
  const _HeatmapGrid({required this.entries, required this.selectedTopic});

  final List<StudentTopicMasteryEntry> entries;
  final String? selectedTopic;

  /// Computes the mean [masteryPercent] for [student] across [topics],
  /// returning `null` when the student has no data for any of them.
  num? _overallAvg(
    String studentId,
    List<String> topics,
    Map<String, Map<String, StudentTopicMasteryEntry>> byStudentThenTopic,
  ) {
    final Map<String, StudentTopicMasteryEntry>? row = byStudentThenTopic[studentId];
    if (row == null) return null;
    final List<num> vals = <num>[
      for (final String t in topics)
        if (row[t] != null) row[t]!.masteryPercent,
    ];
    if (vals.isEmpty) return null;
    return vals.reduce((num a, num b) => a + b) / vals.length;
  }

  @override
  Widget build(BuildContext context) {
    final List<String> allTopics =
        <String>{for (final StudentTopicMasteryEntry e in entries) e.topic}.toList()..sort();
    final List<String> topics = selectedTopic == null ? allTopics : <String>[selectedTopic!];

    final List<StudentTopicMasteryEntry> studentsInOrder = <StudentTopicMasteryEntry>[];
    final Set<String> seenStudentIds = <String>{};
    for (final StudentTopicMasteryEntry e in entries) {
      if (seenStudentIds.add(e.studentId)) studentsInOrder.add(e);
    }

    final Map<String, Map<String, StudentTopicMasteryEntry>> byStudentThenTopic =
        <String, Map<String, StudentTopicMasteryEntry>>{};
    for (final StudentTopicMasteryEntry e in entries) {
      (byStudentThenTopic[e.studentId] ??= <String, StudentTopicMasteryEntry>{})[e.topic] = e;
    }

    if (topics.isEmpty) {
      return const AppEmptyState(
        icon: Icons.grid_on_outlined,
        title: 'No data for this competency',
      );
    }

    // ── Pinned column ────────────────────────────────────────────────────────
    final Widget pinnedHeader = _HeatmapPinnedCell(
      height: _hmHeaderH,
      isHeader: true,
      child: Text('Student', style: _prInter(12, weight: FontWeight.w700, color: _PR.textMuted)),
    );

    // Student-name cells
    final List<Widget> pinnedRows = <Widget>[
      for (final StudentTopicMasteryEntry student in studentsInOrder)
        _HeatmapPinnedCell(
          height: _hmRowH,
          isHeader: false,
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 14,
                backgroundColor: _PR.primaryLight,
                child: Text(
                  student.fullName
                      .trim()
                      .split(RegExp(r'\s+'))
                      .take(2)
                      .map((String w) => w.isEmpty ? '' : w[0].toUpperCase())
                      .join(),
                  style: _prInter(11.5, weight: FontWeight.w700, color: _PR.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  student.fullName,
                  style: _prInter(13.5, weight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
    ];

    final Widget pinnedColumn = SizedBox(
      width: _hmStudentColW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[pinnedHeader, ...pinnedRows],
      ),
    );

    // ── Scrollable score columns ─────────────────────────────────────────────
    // All competency columns + the 'Overall Avg' column live here.
    final Widget scoreColumns = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // One column per competency topic
        for (final String topic in topics)
          Column(
            children: <Widget>[
              // Header
              _HeatmapScoreCell(
                height: _hmHeaderH,
                isHeader: true,
                child: Text(
                  topic,
                  style: _prInter(12, weight: FontWeight.w700, color: _PR.textMuted),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Data rows
              for (final StudentTopicMasteryEntry student in studentsInOrder)
                _HeatmapScoreCell(
                  height: _hmRowH,
                  isHeader: false,
                  child: _HeatmapBadge(
                    entry: byStudentThenTopic[student.studentId]?[topic],
                  ),
                ),
            ],
          ),
        // 'Overall Avg' column
        Column(
          children: <Widget>[
            _HeatmapScoreCell(
              height: _hmHeaderH,
              isHeader: true,
              child: Text(
                'Overall\nAvg',
                style: _prInter(12, weight: FontWeight.w700, color: _PR.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
            for (final StudentTopicMasteryEntry student in studentsInOrder)
              _HeatmapScoreCell(
                height: _hmRowH,
                isHeader: false,
                child: Builder(
                  builder: (BuildContext context) {
                    final num? avg = _overallAvg(
                      student.studentId,
                      allTopics,
                      byStudentThenTopic,
                    );
                    if (avg == null) {
                      return Text('\u2014', style: _prInter(13, color: _PR.textFaint));
                    }
                    return _HeatmapBadge(
                      entry: StudentTopicMasteryEntry(
                        studentId: student.studentId,
                        fullName: student.fullName,
                        sectionId: student.sectionId,
                        sectionName: student.sectionName,
                        topic: '',
                        questionsTotal: 0,
                        questionsCorrect: 0,
                        masteryPercent: avg,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ],
    );

    // ── Assemble: pinned column + scrollable area ─────────────────────────────
    final Widget tableArea = Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        border: Border.all(color: _PR.border, width: 1),
        borderRadius: BorderRadius.circular(_PR.rSm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          pinnedColumn,
          Container(width: 1, color: _PR.border),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: scoreColumns,
            ),
          ),
        ],
      ),
    );

    // ── Footer ────────────────────────────────────────────────────────────────
    final int totalStudents = studentsInOrder.length;
    final Widget footer = Container(
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 20),
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            'Showing $totalStudents of $totalStudents students',
            style: _prInter(12, color: _PR.textFaint),
          ),
          Text(
            '\u2014 = no quiz attempt yet',
            style: _prInter(12, color: _PR.textFaint),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[const SizedBox(height: 8), tableArea, footer],
    );
  }
}

class _HeatmapPinnedCell extends StatelessWidget {
  const _HeatmapPinnedCell({
    required this.height,
    required this.isHeader,
    required this.child,
  });

  final double height;
  final bool isHeader;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isHeader ? _PR.tableHeaderBg : _PR.card,
        border: const Border(
          bottom: BorderSide(color: _PR.border, width: 1),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

class _HeatmapScoreCell extends StatelessWidget {
  const _HeatmapScoreCell({
    required this.height,
    required this.isHeader,
    required this.child,
  });

  final double height;
  final bool isHeader;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _hmScoreColW,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isHeader ? _PR.tableHeaderBg : _PR.card,
        border: const Border(
          bottom: BorderSide(color: _PR.border, width: 1),
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Colored pill badge for heatmap cells — green/amber/red based on mastery.
class _HeatmapBadge extends StatelessWidget {
  const _HeatmapBadge({required this.entry});

  final StudentTopicMasteryEntry? entry;

  @override
  Widget build(BuildContext context) {
    if (entry == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F2F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('\u2014', style: _prInter(12.5, weight: FontWeight.w500, color: _PR.textFaint)),
      );
    }
    final MasteryBand? band = masteryBandFor(entry!.masteryPercent);
    final (Color bg, Color fg) = switch (band) {
      MasteryBand.mastered => (_PR.greenBg, _PR.greenText),
      MasteryBand.proficient => (_PR.amberBg, _PR.amberText),
      MasteryBand.needsSupport => (_PR.redBg, _PR.redText),
      null => (const Color(0xFFF1F2F6), _PR.textFaint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        formatPercent(entry!.masteryPercent),
        style: _prInter(12.5, weight: FontWeight.w700, color: fg),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Export to CSV — identical file-saving mechanism to
// `quiz_results_screen.dart`'s own `_ExportCsvButton`: `file_picker`'s
// native Save As dialog + `dart:io File.writeAsBytes(utf8.encode(...))`.
// Uses [ProgressReportCsvBuilder] (Part 2, pure) to build the CSV text and
// default filename from whatever the two source providers currently hold.
// -----------------------------------------------------------------------

class _ExportCsvButton extends ConsumerWidget {
  const _ExportCsvButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TopicMasteryEntry>> competencyAsync =
        ref.watch(dashboardCompetencyMasteryProvider);
    final AsyncValue<List<StudentTopicMasteryEntry>> studentTopicAsync =
        ref.watch(dashboardStudentTopicMasteryProvider);

    // Enabled once both source providers have delivered a value — not
    // gated on either being non-empty, unlike `quiz_results_screen.dart`'s
    // own button. A Progress Report legitimately can export as
    // "no data yet" (see `ProgressReportCsvBuilder.build`'s header-only
    // output for an empty list); the Quiz Results screen's non-empty gate
    // exists there because an unselected/empty matrix means "nothing was
    // ever chosen to export" (this screen has no such "pick both first"
    // precondition), so mirroring that exact gate here would block a
    // legitimate empty-state export instead of just skipping a redundant
    // safeguard.
    final bool canExport = competencyAsync.hasValue && studentTopicAsync.hasValue;

    return GestureDetector(
      onTap: canExport
          ? () => _export(context, ref, competencyAsync.value!, studentTopicAsync.value!)
          : null,
      child: MouseRegion(
        cursor: canExport ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: canExport ? _PR.primary : _PR.border,
            borderRadius: BorderRadius.circular(11),
            boxShadow: canExport
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x402F4FA6),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.file_download_outlined,
                size: 16,
                color: canExport ? Colors.white : _PR.textFaint,
              ),
              const SizedBox(width: 8),
              Text(
                'Export to CSV',
                style: _prInter(
                  14.5,
                  weight: FontWeight.w600,
                  color: canExport ? Colors.white : _PR.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<TopicMasteryEntry> competencyMastery,
    List<StudentTopicMasteryEntry> studentTopicMastery,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    // Resolve the currently-selected grade/section for the filename, the
    // same way `quiz_results_screen.dart`'s own `_ExportCsvButton._export`
    // resolves its section — except both are optional here (this screen's
    // filters default to "All", unlike Quiz Results' required selection),
    // so `null` is passed through to `buildFileName` when unset, per that
    // method's own "AllGrades"/"AllSections" fallback.
    final GradeLevel? selectedGrade = ref.read(selectedGradeLevelProvider);
    final String? selectedSectionId = ref.read(selectedSectionIdProvider);

    final List<MySection> mySections = await ref.read(mySectionsProvider.future);
    MySection? chosen;
    for (final MySection my in mySections) {
      if (my.teacherSection.sectionId == selectedSectionId) {
        chosen = my;
        break;
      }
    }

    const ProgressReportCsvBuilder builder = ProgressReportCsvBuilder();
    final String csvContent = builder.build(
      competencyMastery: competencyMastery,
      studentTopicMastery: studentTopicMastery,
    );
    final String defaultFileName = builder.buildFileName(
      gradeLevelLabel: selectedGrade?.label ?? chosen?.section?.gradeLevel.label,
      sectionName: chosen?.section?.name,
    );

    final String? savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Progress Report',
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: <String>['csv'],
    );

    if (savePath == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Export cancelled.')));
      return;
    }

    try {
      final String resolvedPath = savePath.toLowerCase().endsWith('.csv') ? savePath : '$savePath.csv';
      await File(resolvedPath).writeAsBytes(utf8.encode(csvContent));
      final String displayName = resolvedPath.split(Platform.pathSeparator).last;
      messenger.showSnackBar(SnackBar(content: Text('Exported to $displayName')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to export progress report. Please try again.')),
      );
    }
  }
}
