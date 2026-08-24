import 'dart:io' show File, Platform;
import 'dart:typed_data' show Uint8List;

import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/admin_quiz_result_row.dart'
    show AdminQuizResultRow, AdminSchoolYearOption;
import '../../../core/models/admin_topic_mastery.dart';
import '../../../core/models/section.dart' show GradeLevel;
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/admin_quiz_results_providers.dart'
    show
        adminQuizResultsRepositoryProvider,
        adminQuizResultsSchoolYearsProvider;
import '../data/performance_reports_pdf_builder.dart';
import '../data/performance_reports_providers.dart';

/// Admin -> Performance Reports (0052) — Part 3: the Filters card +
/// "Overall Topic Mastery" chart, per the CONFIRMED PROJECT DECISION in
/// this phase's task (the original mockup's fixed six-item "Competency"
/// filter/wording does not match this app's real data — there is no
/// competency-bucket concept, only real `question_bank.topic` strings, one
/// per lesson-ish granularity, potentially dozens of them — so every label
/// on this screen says "Topic", not "Competency", and nothing here assumes
/// a short, fixed option count).
///
/// Deliberately returns [AppPageContainer] directly as its body, with NO
/// own [Scaffold]/[AppBar] — same shell reasoning
/// [AdminQuizResultsScreen]/[AdminDashboardScreen] give for themselves:
/// the [AdminShellScreen] `IndexedStack` already supplies that chrome.
/// Not wired into that shell yet — that's a later part, per this phase's
/// own scope.
///
/// Loading/empty/error states mirror [AdminQuizResultsScreen]'s
/// `_ResultsTable` exactly: [AppLoadingIndicator] while loading,
/// [AppErrorState] with `error.message` + a `ref.invalidate(...)` retry,
/// [AppEmptyState] for a genuinely empty result set.
///
/// Export (0052 Part 5) wires the "Export Report" button
/// ([_ExportReportButton]) to [PerformanceReportsPdfBuilder] + `file_picker`'s
/// native Save As dialog, exactly the mechanism
/// [AdminQuizResultsScreen]'s own `_ExportReportButton` already uses for
/// its own CSV export.
class AdminPerformanceReportsScreen extends ConsumerWidget {
  const AdminPerformanceReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppPageContainer(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSectionHeader(
            title: 'Performance Reports',
            subtitle: 'Analyze mastery by topic',
            action: _ExportReportButton(),
          ),
          SizedBox(height: AppSpacing.md),
          _FilterCard(),
          SizedBox(height: AppSpacing.md),
          _TopicMasterySection(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Export Report button
// ---------------------------------------------------------------------

/// "Export Report" button in the section header's trailing action slot —
/// enabled once the currently filtered [adminPerformanceReportsProvider]
/// result set has resolved to at least one row (never enabled while
/// loading, errored, or genuinely empty — same enablement shape
/// [AdminQuizResultsScreen]'s own `_ExportReportButton` uses for its own
/// result list). Uses [PerformanceReportsPdfBuilder] (pure) to build the
/// PDF bytes and filename, then `file_picker`'s native Save As dialog +
/// `dart:io File` to write it — identical mechanism to that button, just a
/// PDF (with a drawn chart, not only a table) instead of a CSV.
class _ExportReportButton extends ConsumerWidget {
  const _ExportReportButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AdminTopicMasteryRow>? rows =
        ref.watch(adminPerformanceReportsProvider).value;
    final bool canExport = rows != null && rows.isNotEmpty;

    return AppButton(
      label: 'Export Report',
      leadingIcon: Icons.description_outlined,
      onPressed: canExport ? () => _export(context, ref, rows) : null,
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<AdminTopicMasteryRow> rows,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AdminPerformanceReportsFilterSelection selection = ref.read(
      adminPerformanceReportsFilterSelectionProvider,
    );

    // Resolve the four filter dimensions' display labels for both the PDF
    // header and the filename. Grade and Topic are cheap (Grade already
    // carries its own `.label`; Topic IS the already-resolved string the
    // dropdown shows, or the "All Topics" fallback). Section and School
    // Year are id-only on the selection, so their names come from data
    // already sitting in provider caches rather than a fresh lookup:
    //  - Section: UNLIKE AdminQuizResultsScreen's own `_export` (which
    //    reads the first already-fetched row's own `sectionName`, since
    //    every Quiz Results row carries one), `admin_competency_mastery`
    //    (0052) rows carry no section id/name at all — mastery is
    //    aggregated ACROSS sections, not per-section (see
    //    AdminTopicMasteryRow's own doc comment). So this reads the same
    //    already-cached `_sectionFilterOptionsProvider` list the Section
    //    dropdown itself renders from instead.
    //  - School Year: matched out of `adminQuizResultsSchoolYearsProvider`,
    //    the same lookup list `_SchoolYearDropdown` renders from — reused
    //    verbatim here, not re-fetched, same as everywhere else on this
    //    screen.
    final String gradeLabel = selection.gradeLevel?.label ?? 'All Grades';

    String sectionLabel = 'All Sections';
    if (selection.sectionId != null) {
      final List<_SectionOption> sections =
          ref.read(_sectionFilterOptionsProvider).value ??
          const <_SectionOption>[];
      for (final _SectionOption section in sections) {
        if (section.id == selection.sectionId) {
          sectionLabel = section.name;
          break;
        }
      }
    }

    String schoolYearLabel = 'All Time';
    if (selection.schoolYearId != null) {
      final List<AdminSchoolYearOption> years =
          ref.read(adminQuizResultsSchoolYearsProvider).value ??
          const <AdminSchoolYearOption>[];
      for (final AdminSchoolYearOption year in years) {
        if (year.schoolYearId == selection.schoolYearId) {
          schoolYearLabel = year.label;
          break;
        }
      }
    }

    final String topicLabel = selection.topic ?? 'All Topics';

    const PerformanceReportsPdfBuilder builder = PerformanceReportsPdfBuilder();
    final Uint8List pdfBytes = await builder.build(
      rows: rows,
      // See PerformanceReportsPdfBuilder.build's own doc comment on
      // [schoolName]: this codebase has no school-name provider anywhere
      // to reuse (confirmed by reading every school-related file in this
      // phase's own source tree before writing this) — 'BayMath' is the
      // same literal branding string admin_dashboard_screen.dart already
      // displays verbatim ('BayMath Administration System'), reused here
      // rather than fetched a new way, per this phase's own instruction.
      schoolName: 'BayMath',
      gradeLabel: gradeLabel,
      sectionLabel: sectionLabel,
      schoolYearLabel: schoolYearLabel,
      topicLabel: topicLabel,
    );
    final String defaultFileName = builder.buildFileName(
      gradeLabel: gradeLabel,
      sectionLabel: sectionLabel,
      schoolYearLabel: schoolYearLabel,
      topicLabel: topicLabel,
    );

    final String? savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Performance Report',
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: <String>['pdf'],
    );

    if (savePath == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Export cancelled.')),
      );
      return;
    }

    try {
      final String resolvedPath =
          savePath.toLowerCase().endsWith('.pdf') ? savePath : '$savePath.pdf';
      await File(resolvedPath).writeAsBytes(pdfBytes);
      final String displayName =
          resolvedPath.split(Platform.pathSeparator).last;
      messenger.showSnackBar(
        SnackBar(content: Text('Exported to $displayName')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to export performance report. Please try again.',
          ),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------
// Filters
// ---------------------------------------------------------------------

typedef _SelectionUpdater =
    void Function(
      AdminPerformanceReportsFilterSelection Function(
        AdminPerformanceReportsFilterSelection,
      )
      update,
    );

/// Grade Level / Section / "Date Range" (School Year) / Topic filter row,
/// inside an [AppCard] with a "Filters" header — same bordered-panel shape
/// [AdminQuizResultsScreen]'s own `_FilterCard` uses.
///
/// The third dropdown is labeled "Date Range" for the identical reason
/// [AdminQuizResultsScreen]'s own `_SchoolYearDropdown` doc comment gives:
/// the mockup's visual style calls it that, but the underlying filter is
/// School Year (0051's `admin_quiz_results_school_years`, reused verbatim
/// here rather than re-fetched — see `performance_reports_providers.dart`'s
/// own header comment on why no second school-years provider was added).
class _FilterCard extends ConsumerWidget {
  const _FilterCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AdminPerformanceReportsFilterSelection selection = ref.watch(
      adminPerformanceReportsFilterSelectionProvider,
    );

    void updateSelection(
      AdminPerformanceReportsFilterSelection Function(
        AdminPerformanceReportsFilterSelection,
      )
      update,
    ) {
      ref
          .read(adminPerformanceReportsFilterSelectionProvider.notifier)
          .update(update);
    }

    // Clears a Section selection that's gone stale, mirroring
    // AdminQuizResultsScreen's own `ref.listen` on its section-options
    // provider — [_sectionFilterOptionsProvider] below re-resolves
    // whenever Grade Level changes (it deliberately ignores `sectionId`
    // itself, same reasoning as that provider's own 0051-era
    // counterpart), so a currently-selected section can fall out of the
    // newly-resolved option list without any explicit action on the
    // Section dropdown at all.
    ref.listen<AsyncValue<List<_SectionOption>>>(
      _sectionFilterOptionsProvider,
      (
        AsyncValue<List<_SectionOption>>? previous,
        AsyncValue<List<_SectionOption>> next,
      ) {
        final List<_SectionOption>? sections = next.value;
        if (sections == null) {
          return; // still loading or errored — leave selection alone
        }
        final String? currentSectionId =
            ref.read(adminPerformanceReportsFilterSelectionProvider).sectionId;
        if (currentSectionId == null) {
          return; // "All Sections" is always valid
        }
        final bool stillValid = sections.any(
          (_SectionOption s) => s.id == currentSectionId,
        );
        if (!stillValid) {
          ref
              .read(adminPerformanceReportsFilterSelectionProvider.notifier)
              .update((s) => s.withSectionId(null));
        }
      },
    );

    return AppCard(
      header: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.filter_alt_outlined),
          SizedBox(width: AppSpacing.xs),
          Text('Filters'),
        ],
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          AppDropdown<GradeLevel>(
            label: 'Grade Level',
            width: 200,
            options: <AppDropdownOption<GradeLevel>>[
              const AppDropdownOption<GradeLevel>(
                value: null,
                label: 'All Grades',
              ),
              for (final GradeLevel g in GradeLevel.values)
                AppDropdownOption<GradeLevel>(value: g, label: g.label),
            ],
            selected: selection.gradeLevel,
            onChanged:
                (GradeLevel? value) =>
                    updateSelection((s) => s.withGradeLevel(value)),
          ),
          _SectionDropdown(selection: selection, onUpdate: updateSelection),
          _SchoolYearDropdown(selection: selection, onUpdate: updateSelection),
          _TopicDropdown(selection: selection, onUpdate: updateSelection),
        ],
      ),
    );
  }
}

/// Section filter dropdown options.
///
/// `AdminTopicMasteryRepository` (Part 2) exposes exactly one method,
/// `fetchTopicMastery` — there is no `admin_competency_mastery_sections`-
/// style lookup RPC either, and `admin_competency_mastery`'s own row shape
/// (topic/questionsTotal/questionsCorrect/masteryPercent, 0052) carries no
/// section name or id at all — mastery is aggregated ACROSS students/
/// sections, not per-section — so this screen can't derive Section options
/// from its own main data source the way a per-row table screen could.
///
/// Instead, this reuses the same workaround [AdminQuizResultsScreen]'s own
/// `_sectionFilterOptionsProvider` already established: re-call
/// `admin_quiz_results` (0051, via the existing
/// `adminQuizResultsRepositoryProvider` — no new repository/RPC surface
/// added) with the current Grade Level filter and take the distinct
/// (sectionId, sectionName) pairs out of whatever rows come back. Same
/// underlying `sections` universe as this screen's own School Year
/// dropdown already assumes by reusing `admin_quiz_results_school_years`.
///
/// TRADEOFF, flagged for review, same shape as
/// [AdminQuizResultsScreen]'s own note: this queries `admin_quiz_results`,
/// not `admin_competency_mastery`, purely to populate a dropdown, and does
/// not narrow by [AdminPerformanceReportsFilterSelection.schoolYearId] the
/// way the main [adminPerformanceReportsProvider] does, so a section that
/// only has quiz results in a school year this filter's Date Range still
/// includes can appear even after switching Date Range to a year with zero
/// results for it. Acceptable here since Quiz Results and Performance
/// Reports share the same overall students/sections/school-years universe;
/// a dedicated `admin_competency_mastery_sections`-style lookup RPC (the
/// same shape `admin_quiz_results_school_years` already is) would be the
/// cleaner long-term fix if this screen sees real usage — not built here
/// to stay inside this phase's own scope (UI only, no new SQL/repository
/// surface).
final FutureProvider<List<_SectionOption>> _sectionFilterOptionsProvider =
    FutureProvider.autoDispose<List<_SectionOption>>((ref) async {
      final AdminPerformanceReportsFilterSelection selection = ref.watch(
        adminPerformanceReportsFilterSelectionProvider,
      );
      final List<AdminQuizResultRow> rows = await ref
          .watch(adminQuizResultsRepositoryProvider)
          .fetchResults(gradeLevel: selection.gradeLevel);

      final Map<String, String> nameBySectionId = <String, String>{};
      for (final AdminQuizResultRow row in rows) {
        nameBySectionId[row.sectionId] = row.sectionName;
      }
      final List<_SectionOption> options = <_SectionOption>[
        for (final MapEntry<String, String> entry in nameBySectionId.entries)
          _SectionOption(id: entry.key, name: entry.value),
      ]..sort((_SectionOption a, _SectionOption b) => a.name.compareTo(b.name));
      return options;
    });

class _SectionOption {
  const _SectionOption({required this.id, required this.name});
  final String id;
  final String name;
}

class _SectionDropdown extends ConsumerWidget {
  const _SectionDropdown({required this.selection, required this.onUpdate});

  final AdminPerformanceReportsFilterSelection selection;
  final _SelectionUpdater onUpdate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<_SectionOption>> optionsAsync = ref.watch(
      _sectionFilterOptionsProvider,
    );
    final List<_SectionOption> sections =
        optionsAsync.value ?? const <_SectionOption>[];

    return AppDropdown<String>(
      // Forces Flutter to tear down/recreate the dropdown on a
      // programmatic sectionId reset (the `ref.listen` stale-selection
      // guard above) — same reasoning AdminQuizResultsScreen's own
      // `_SectionDropdown` gives for this key.
      key: ValueKey<String?>(selection.sectionId),
      label: 'Section',
      width: 200,
      enabled: !optionsAsync.isLoading,
      options: <AppDropdownOption<String>>[
        const AppDropdownOption<String>(value: null, label: 'All Sections'),
        for (final _SectionOption s in sections)
          AppDropdownOption<String>(value: s.id, label: s.name),
      ],
      selected: selection.sectionId,
      onChanged: (String? value) => onUpdate((s) => s.withSectionId(value)),
    );
  }
}

/// The mockup's "Date Range" dropdown — actually School Year underneath,
/// reusing `adminQuizResultsSchoolYearsProvider` (0051) verbatim, per this
/// phase's own scope note (no second school-years provider was added in
/// Part 2). Layout/behavior copied verbatim from
/// [AdminQuizResultsScreen]'s own `_SchoolYearDropdown`.
class _SchoolYearDropdown extends ConsumerWidget {
  const _SchoolYearDropdown({required this.selection, required this.onUpdate});

  final AdminPerformanceReportsFilterSelection selection;
  final _SelectionUpdater onUpdate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminSchoolYearOption>> yearsAsync = ref.watch(
      adminQuizResultsSchoolYearsProvider,
    );
    final List<AdminSchoolYearOption> years =
        yearsAsync.value ?? const <AdminSchoolYearOption>[];

    return AppDropdown<String>(
      label: 'Date Range',
      width: 200,
      enabled: !yearsAsync.isLoading,
      options: <AppDropdownOption<String>>[
        const AppDropdownOption<String>(value: null, label: 'All Time'),
        for (final AdminSchoolYearOption y in years)
          AppDropdownOption<String>(
            value: y.schoolYearId,
            label: y.isCurrent ? '${y.label} (Current)' : y.label,
          ),
      ],
      selected: selection.schoolYearId,
      onChanged: (String? value) => onUpdate((s) => s.withSchoolYearId(value)),
    );
  }
}

/// The Topic filter dropdown — options sourced from
/// [adminPerformanceReportsTopicsProvider] (Part 2's distinct-topics
/// lookup, queried fully unfiltered so this option list never shrinks as
/// other filters narrow). Per the CONFIRMED PROJECT DECISION, this list
/// holds real `question_bank.topic` strings (lesson-title-length, one per
/// curriculum lesson in this database) rather than a fixed six-item
/// "Competency" set — potentially dozens of entries.
///
/// [AppDropdown] wraps Flutter's own [DropdownMenu], which already
/// provides both a scrollable menu and built-in type-to-search/filter
/// behavior for long option lists out of the box (confirmed by reading
/// `app_dropdown.dart` before writing this, per this phase's own
/// instruction not to assume). No changes to that shared widget were
/// needed or made; this dropdown is built the exact same way
/// [_SchoolYearDropdown]/`AdminQuizResultsScreen`'s own dropdowns are.
class _TopicDropdown extends ConsumerWidget {
  const _TopicDropdown({required this.selection, required this.onUpdate});

  final AdminPerformanceReportsFilterSelection selection;
  final _SelectionUpdater onUpdate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<String>> topicsAsync = ref.watch(
      adminPerformanceReportsTopicsProvider,
    );
    final List<String> topics = topicsAsync.value ?? const <String>[];

    return AppDropdown<String>(
      label: 'Topic',
      width: 260,
      enabled: !topicsAsync.isLoading,
      options: <AppDropdownOption<String>>[
        const AppDropdownOption<String>(value: null, label: 'All Topics'),
        for (final String topic in topics)
          AppDropdownOption<String>(value: topic, label: topic),
      ],
      selected: selection.topic,
      onChanged: (String? value) => onUpdate((s) => s.withTopic(value)),
    );
  }
}

// ---------------------------------------------------------------------
// "Overall Topic Mastery" chart
// ---------------------------------------------------------------------

class _TopicMasterySection extends ConsumerWidget {
  const _TopicMasterySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminTopicMasteryRow>> rowsAsync = ref.watch(
      adminPerformanceReportsProvider,
    );

    return AppCard(
      header: const Text('Overall Topic Mastery'),
      child: rowsAsync.when(
        loading:
            () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: AppLoadingIndicator(),
            ),
        error:
            (error, _) => AppErrorState(
              message:
                  error is AppFailure
                      ? error.message
                      : 'Could not load topic mastery.',
              onRetry: () => ref.invalidate(adminPerformanceReportsProvider),
            ),
        data: (List<AdminTopicMasteryRow> rows) {
          if (rows.isEmpty) {
            return const AppEmptyState(
              icon: Icons.insights_outlined,
              title: 'No mastery data found',
              description: 'Try adjusting the filters above.',
            );
          }
          return _TopicMasteryChart(rows: rows);
        },
      ),
    );
  }
}

/// One horizontal bar per [AdminTopicMasteryRow], 0-100 scale, topic name
/// as the row label.
///
/// SORT ORDER — ascending by [AdminTopicMasteryRow.masteryPercent] (lowest
/// mastery first), NOT alphabetical. There is no fixed mockup order to
/// match once there can be more than six topics (per the CONFIRMED PROJECT
/// DECISION), so this is a deliberate choice, stated per this phase's own
/// instruction: an Admin opening a school-wide "Performance Reports" page
/// is most likely scanning for topics that need attention, so the
/// weakest-mastery topics surface at the top rather than requiring a scroll
/// past every alphabetically-earlier, already-strong topic first. (Unlike
/// `student_statistics_screen.dart`'s own `_CompetencyMasteryCard`, which
/// sorts alphabetically because a student is scanning for one specific
/// topic they already have in mind — a different task, a different
/// ordering choice, deliberately not copied here.)
///
/// VERTICALLY SCROLLABLE CONTAINER — per this phase's own instruction not
/// to assume a small fixed row count (topics can be curriculum-lesson-
/// sized in number). A fixed-height [SizedBox] + internal [ListView],
/// rather than letting the card grow unbounded inside the page's own
/// [AppPageContainer.scrollable] column — same "fixed chart height, own
/// scroll region" shape `student_statistics_screen.dart`'s chart cards
/// already use (`SizedBox(height: 240, child: ...)`), just taller and
/// internally list-scrollable here since the row count isn't bounded at
/// six the way a pie/pre-set bar chart's is.
///
/// CHART IMPLEMENTATION NOTE — fl_chart's `BarChart` (this package's
/// version, ^0.69.2) only ever renders bars growing vertically from the
/// bottom; there is no built-in horizontal-orientation option. Rather than
/// rotate one large multi-group `BarChart` as a whole (which would also
/// require counter-rotating every axis-title widget and re-deriving touch/
/// tooltip hit-testing under rotation — a known source of subtle bugs and
/// not something verifiable without running the app), each row below is
/// its OWN small single-bar `BarChart`, wrapped in a `RotatedBox` to grow
/// horizontally, with its axis titles and touch/tooltip both explicitly
/// disabled (the topic name and percentage are already shown as plain
/// [Text] immediately above every bar, so nothing is lost by disabling
/// the chart's own labels/tooltip). This still genuinely uses fl_chart's
/// `BarChart`/`BarChartRodData` (same rod color/`AppRadius.smallAll`
/// styling `_LessonScoresBarChart`, in the Student Statistics screen,
/// already uses) for every bar, just composed per-row instead of as one
/// chart object. FLAGGED FOR VISUAL QA: `RotatedBox(quarterTurns: 3)` is
/// the standard community workaround for this exact fl_chart limitation
/// (270° clockwise = 90° counter-clockwise, turning a bottom-up vertical
/// bar into a left-to-right horizontal one) and should be visually
/// correct, but — per this phase's own note that nothing here was run —
/// this is the one piece of this screen most worth a first-run visual
/// check; if a bar's fill direction ever looks reversed, flipping to
/// `quarterTurns: 1` is the fix.
class _TopicMasteryChart extends StatelessWidget {
  const _TopicMasteryChart({required this.rows});

  final List<AdminTopicMasteryRow> rows;

  static const double _rowHeight = 56;
  static const double _barTrackHeight = 20;
  static const double _maxChartHeight = 420;

  @override
  Widget build(BuildContext context) {
    final List<AdminTopicMasteryRow> sorted = <AdminTopicMasteryRow>[...rows]
      ..sort(
        (AdminTopicMasteryRow a, AdminTopicMasteryRow b) =>
            a.masteryPercent.compareTo(b.masteryPercent),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _TopicMasteryAxisScale(),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height:
              (sorted.length * _rowHeight)
                  .clamp(_rowHeight, _maxChartHeight)
                  .toDouble(),
          child: ListView.separated(
            itemCount: sorted.length,
            separatorBuilder:
                (BuildContext context, int index) =>
                    const SizedBox(height: AppSpacing.sm),
            itemBuilder:
                (BuildContext context, int index) =>
                    _TopicMasteryBarRow(row: sorted[index]),
          ),
        ),
      ],
    );
  }
}

/// A plain "0 / 25 / 50 / 75 / 100" label row establishing the chart's
/// shared 0-100 scale — each row's own mini `BarChart` below carries its
/// own `minY: 0, maxY: 100` but has no visible axis of its own (see
/// [_TopicMasteryChart]'s own doc comment on why), so this single shared
/// header is what actually shows the scale to the admin.
class _TopicMasteryAxisScale extends StatelessWidget {
  const _TopicMasteryAxisScale();

  static const List<String> _ticks = <String>['0', '25', '50', '75', '100'];

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodySmall;
    return Row(
      children: <Widget>[
        for (final String tick in _ticks)
          Expanded(child: Text(tick, style: style)),
      ],
    );
  }
}

class _TopicMasteryBarRow extends StatelessWidget {
  const _TopicMasteryBarRow({required this.row});

  final AdminTopicMasteryRow row;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double clampedPercent = row.masteryPercent.clamp(0, 100).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // question_bank.topic used verbatim (rule #9's convention,
            // 0035/0052) — no maxLines/ellipsis, wraps naturally instead
            // of ever being cut off, same as
            // student_statistics_screen.dart's own `_TopicMasteryBar`.
            Expanded(
              child: Text(
                row.topic,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              formatPercent(row.masteryPercent),
              style: textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: _TopicMasteryChart._barTrackHeight,
          child: RotatedBox(
            quarterTurns: 1,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: 100,
                alignment: BarChartAlignment.center,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                // Disabled rather than adapted — touch/tooltip hit-testing
                // under a RotatedBox isn't something this phase can verify
                // without running the app, and the topic name + percentage
                // are already shown as plain text immediately above this
                // bar, so nothing is lost by disabling it. See
                // _TopicMasteryChart's own doc comment.
                barTouchData: BarTouchData(enabled: false),
                barGroups: <BarChartGroupData>[
                  BarChartGroupData(
                    x: 0,
                    barRods: <BarChartRodData>[
                      BarChartRodData(
                        toY: clampedPercent,
                        color: colorScheme.primary,
                        width: 16,
                        borderRadius: AppRadius.smallAll,
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 100,
                          color: colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
