import 'dart:io' show File, Platform;
import 'dart:typed_data' show Uint8List;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/adult_workspace_colors.dart';
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
    return const ColoredBox(
      key: Key('admin_performance_reports_screen'),
      color: AdultWorkspaceColors.canvas,
      child: AppPageContainer(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _PerformanceReportsPageHeader(),
            SizedBox(height: AppSpacing.lg),
            _FilterCard(),
            SizedBox(height: AppSpacing.md),
            _TopicMasterySection(),
          ],
        ),
      ),
    );
  }
}

class _PerformanceReportsPageHeader extends StatelessWidget {
  const _PerformanceReportsPageHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Performance Reports',
              key: const Key('performance_reports_page_title'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AdultWorkspaceColors.ink,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.35,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Review topic-level mastery across selected grades and sections.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AdultWorkspaceColors.secondaryText,
                height: 1.4,
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              heading,
              const SizedBox(height: AppSpacing.md),
              const _ExportReportButton(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: heading),
            const SizedBox(width: AppSpacing.lg),
            const _ExportReportButton(),
          ],
        );
      },
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
      key: const Key('performance_reports_export_button'),
      label: 'Export Report',
      leadingIcon: Icons.file_download_outlined,
      variant: AppButtonVariant.outlined,
      size: AppComponentSize.small,
      semanticLabel: 'Export filtered performance report',
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

bool _hasActiveFilters(AdminPerformanceReportsFilterSelection selection) =>
    selection.gradeLevel != null ||
    selection.sectionId != null ||
    selection.topic != null ||
    selection.schoolYearId != null;

/// Grade Level / Section / Topic / "Date Range" (School Year) filter
/// toolbar. At normal desktop widths the four existing controls and reset
/// action share one row; narrower laptop windows wrap them without changing
/// their behavior.
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

    final bool filtersActive = _hasActiveFilters(selection);
    return Container(
      key: const Key('performance_reports_filter_toolbar'),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AdultWorkspaceColors.border),
          bottom: BorderSide(color: AdultWorkspaceColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Filter performance data',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AdultWorkspaceColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const double spacing = 10;
              const double clearWidth = 116;
              final bool singleRow = constraints.maxWidth >= 920;
              final int columns = constraints.maxWidth >= 520 ? 2 : 1;
              final double fieldWidth =
                  singleRow
                      ? (constraints.maxWidth - clearWidth - spacing * 4) / 4
                      : (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;

              final List<Widget> controls = <Widget>[
                AppDropdown<GradeLevel>(
                  key: const Key('performance_reports_grade_filter'),
                  label: 'Grade Level',
                  width: fieldWidth,
                  size: AppComponentSize.small,
                  options: <AppDropdownOption<GradeLevel>>[
                    const AppDropdownOption<GradeLevel>(
                      value: null,
                      label: 'All Grades',
                    ),
                    for (final GradeLevel grade in GradeLevel.values)
                      AppDropdownOption<GradeLevel>(
                        value: grade,
                        label: grade.label,
                      ),
                  ],
                  selected: selection.gradeLevel,
                  onChanged:
                      (GradeLevel? value) => updateSelection(
                        (AdminPerformanceReportsFilterSelection current) =>
                            current.withGradeLevel(value),
                      ),
                ),
                _SectionDropdown(
                  selection: selection,
                  onUpdate: updateSelection,
                  width: fieldWidth,
                ),
                _TopicDropdown(
                  selection: selection,
                  onUpdate: updateSelection,
                  width: fieldWidth,
                ),
                _SchoolYearDropdown(
                  selection: selection,
                  onUpdate: updateSelection,
                  width: fieldWidth,
                ),
              ];
              final Widget clearButton = SizedBox(
                width: clearWidth,
                child: TextButton(
                  key: const Key('performance_reports_clear_filters'),
                  onPressed:
                      filtersActive
                          ? () => updateSelection(
                            (_) =>
                                const AdminPerformanceReportsFilterSelection(),
                          )
                          : null,
                  child: const Text('Clear filters'),
                ),
              );

              if (singleRow) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    for (int index = 0; index < controls.length; index++) ...[
                      controls[index],
                      const SizedBox(width: spacing),
                    ],
                    clearButton,
                  ],
                );
              }

              return Wrap(
                spacing: spacing,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[...controls, clearButton],
              );
            },
          ),
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
  const _SectionDropdown({
    required this.selection,
    required this.onUpdate,
    required this.width,
  });

  final AdminPerformanceReportsFilterSelection selection;
  final _SelectionUpdater onUpdate;
  final double width;

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
      key: ValueKey<String>(
        'performance_reports_section_${selection.sectionId ?? 'all'}',
      ),
      label: 'Section',
      width: width,
      size: AppComponentSize.small,
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
  const _SchoolYearDropdown({
    required this.selection,
    required this.onUpdate,
    required this.width,
  });

  final AdminPerformanceReportsFilterSelection selection;
  final _SelectionUpdater onUpdate;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminSchoolYearOption>> yearsAsync = ref.watch(
      adminQuizResultsSchoolYearsProvider,
    );
    final List<AdminSchoolYearOption> years =
        yearsAsync.value ?? const <AdminSchoolYearOption>[];

    return AppDropdown<String>(
      key: const Key('performance_reports_date_filter'),
      label: 'Date Range',
      width: width,
      size: AppComponentSize.small,
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
  const _TopicDropdown({
    required this.selection,
    required this.onUpdate,
    required this.width,
  });

  final AdminPerformanceReportsFilterSelection selection;
  final _SelectionUpdater onUpdate;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<String>> topicsAsync = ref.watch(
      adminPerformanceReportsTopicsProvider,
    );
    final List<String> topics = topicsAsync.value ?? const <String>[];

    return AppDropdown<String>(
      key: const Key('performance_reports_topic_filter'),
      label: 'Topic',
      width: width,
      size: AppComponentSize.small,
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
    final AdminPerformanceReportsFilterSelection selection = ref.watch(
      adminPerformanceReportsFilterSelectionProvider,
    );

    return rowsAsync.when(
      loading:
          () => const _TopicMasterySurface(
            child: _MasteryStateBody(
              child: AppLoadingIndicator(message: 'Loading topic mastery'),
            ),
          ),
      error:
          (Object error, StackTrace stackTrace) => _TopicMasterySurface(
            child: _MasteryStateBody(
              child: AppErrorState(
                message:
                    error is AppFailure
                        ? error.message
                        : 'Could not load topic mastery.',
                onRetry: () => ref.invalidate(adminPerformanceReportsProvider),
              ),
            ),
          ),
      data: (List<AdminTopicMasteryRow> rows) {
        if (rows.isEmpty) {
          final bool filtersActive = _hasActiveFilters(selection);
          return _TopicMasterySurface(
            topicCount: 0,
            child: _MasteryStateBody(
              child: AppEmptyState(
                icon: Icons.insights_outlined,
                title:
                    filtersActive
                        ? 'No performance data matches the selected filters'
                        : 'No mastery data available yet',
                description:
                    filtersActive
                        ? 'Clear the filters or choose a different reporting context.'
                        : 'Topic mastery will appear after assessment data is available.',
                actionLabel: filtersActive ? 'Clear filters' : null,
                onAction:
                    filtersActive
                        ? () => ref
                            .read(
                              adminPerformanceReportsFilterSelectionProvider
                                  .notifier,
                            )
                            .update(
                              (_) =>
                                  const AdminPerformanceReportsFilterSelection(),
                            )
                        : null,
              ),
            ),
          );
        }
        return _TopicMasterySurface(
          topicCount: rows.length,
          child: _TopicMasteryChart(rows: rows),
        );
      },
    );
  }
}

class _TopicMasterySurface extends StatelessWidget {
  const _TopicMasterySurface({required this.child, this.topicCount});

  final Widget child;
  final int? topicCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('performance_reports_mastery_surface'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mediumAll,
        border: Border.all(color: AdultWorkspaceColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AdultWorkspaceColors.navy.withValues(alpha: 0.025),
            offset: const Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 13,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Overall Topic Mastery',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AdultWorkspaceColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mastery percentages reflect the currently selected filters.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AdultWorkspaceColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (topicCount != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '$topicCount ${topicCount == 1 ? 'topic' : 'topics'}',
                    key: const Key('performance_reports_topic_count'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AdultWorkspaceColors.primaryMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AdultWorkspaceColors.border),
          child,
        ],
      ),
    );
  }
}

class _MasteryStateBody extends StatelessWidget {
  const _MasteryStateBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 300, child: Center(child: child));
  }
}

/// One horizontal comparison row per server-provided mastery value. The
/// existing ascending order is preserved; only the rotated mini-chart
/// implementation and detached 0/25/50/75/100 scale are replaced.
class _TopicMasteryChart extends StatelessWidget {
  const _TopicMasteryChart({required this.rows});

  final List<AdminTopicMasteryRow> rows;

  static const double _estimatedRowHeight = 68;
  static const double _maxChartHeight = 520;

  @override
  Widget build(BuildContext context) {
    final List<AdminTopicMasteryRow> sorted = <AdminTopicMasteryRow>[...rows]
      ..sort(
        (AdminTopicMasteryRow a, AdminTopicMasteryRow b) =>
            a.masteryPercent.compareTo(b.masteryPercent),
      );

    final double chartHeight =
        (sorted.length * _estimatedRowHeight)
            .clamp(_estimatedRowHeight, _maxChartHeight)
            .toDouble();
    return SizedBox(
      key: const Key('performance_reports_mastery_list'),
      height: chartHeight,
      child: ListView.separated(
        primary: false,
        itemCount: sorted.length,
        separatorBuilder:
            (BuildContext context, int index) => const Divider(
              height: 1,
              indent: AppSpacing.md,
              endIndent: AppSpacing.md,
              color: AdultWorkspaceColors.border,
            ),
        itemBuilder:
            (BuildContext context, int index) =>
                _TopicMasteryBarRow(row: sorted[index]),
      ),
    );
  }
}

class _TopicMasteryBarRow extends StatefulWidget {
  const _TopicMasteryBarRow({required this.row});

  final AdminTopicMasteryRow row;

  @override
  State<_TopicMasteryBarRow> createState() => _TopicMasteryBarRowState();
}

class _TopicMasteryBarRowState extends State<_TopicMasteryBarRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AdminTopicMasteryRow row = widget.row;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color:
            _hovered
                ? AdultWorkspaceColors.paleBlue.withValues(alpha: 0.58)
                : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 13,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (constraints.maxWidth < 820) {
              return _CompactMasteryRow(row: row);
            }
            return _DesktopMasteryRow(row: row);
          },
        ),
      ),
    );
  }
}

class _DesktopMasteryRow extends StatelessWidget {
  const _DesktopMasteryRow({required this.row});

  final AdminTopicMasteryRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(width: 330, child: _TopicName(topic: row.topic)),
        const SizedBox(width: AppSpacing.xl),
        Expanded(child: _MasteryTrack(row: row)),
        const SizedBox(width: AppSpacing.lg),
        SizedBox(width: 72, child: _MasteryPercentage(row: row)),
      ],
    );
  }
}

class _CompactMasteryRow extends StatelessWidget {
  const _CompactMasteryRow({required this.row});

  final AdminTopicMasteryRow row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: _TopicName(topic: row.topic)),
            const SizedBox(width: AppSpacing.md),
            _MasteryPercentage(row: row),
          ],
        ),
        const SizedBox(height: 10),
        _MasteryTrack(row: row),
      ],
    );
  }
}

class _TopicName extends StatelessWidget {
  const _TopicName({required this.topic});

  final String topic;

  @override
  Widget build(BuildContext context) {
    return Text(
      topic,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AdultWorkspaceColors.ink,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
    );
  }
}

class _MasteryPercentage extends StatelessWidget {
  const _MasteryPercentage({required this.row});

  final AdminTopicMasteryRow row;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatPercent(row.masteryPercent),
      key: ValueKey<String>('mastery_percentage_${row.topic}'),
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AdultWorkspaceColors.navy,
        fontWeight: FontWeight.w700,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}

class _MasteryTrack extends StatelessWidget {
  const _MasteryTrack({required this.row});

  final AdminTopicMasteryRow row;

  @override
  Widget build(BuildContext context) {
    final double visualPercent =
        row.masteryPercent.clamp(0, 100).toDouble() / 100;
    return Semantics(
      label: '${row.topic}: ${formatPercent(row.masteryPercent)} mastery',
      child: ClipRRect(
        borderRadius: AppRadius.smallAll,
        child: Container(
          key: ValueKey<String>('mastery_track_${row.topic}'),
          height: 10,
          color: AdultWorkspaceColors.fieldFill,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: visualPercent,
            heightFactor: 1,
            child: const ColoredBox(color: AdultWorkspaceColors.primary),
          ),
        ),
      ),
    );
  }
}
