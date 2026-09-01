import 'dart:convert' show utf8;
import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/adult_workspace_colors.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/admin_quiz_result_row.dart';
import '../../../core/models/section.dart' show GradeLevel;
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/admin_quiz_results_csv_builder.dart';
import '../data/admin_quiz_results_providers.dart';

/// Admin -> Quiz Results (0051) — Part 3: the flat, school-wide results
/// table matching the approved mockup. Reads filter selection and fetched
/// rows straight from `admin_quiz_results_providers.dart` (Part 2) — the
/// only screen-local addition is [_sectionFilterOptionsProvider] below,
/// needed to populate the Section dropdown's own options (see its doc
/// comment for why Part 2's repository has nothing that already does
/// this).
///
/// Deliberately returns [AppPageContainer] directly as its body, with NO
/// own [Scaffold]/[AppBar] — same reasoning [AdminDashboardScreen] and
/// every other [AdminShellScreen] `IndexedStack` destination give for
/// themselves (`admin_dashboard_screen.dart`'s own doc comment): the
/// shell already supplies that chrome.
///
/// Loading/empty/error states below mirror `admin_dashboard_screen.dart`
/// and `sections_screen.dart` exactly (`Padding` + [AppLoadingIndicator]
/// while loading, [AppErrorState] with `error.message` + a
/// `ref.invalidate(...)` retry, [AppEmptyState] for a genuinely empty
/// result set) — no new state-handling pattern invented here.
///
/// CSV export (Part 4) wires the "Export Report" button
/// ([_ExportReportButton]) to [AdminQuizResultsCsvBuilder] + `file_picker`'s
/// native Save As dialog, exactly the mechanism
/// `teacher/presentation/quiz_results_screen.dart`'s own `_ExportCsvButton`
/// already uses.
class AdminQuizResultsScreen extends ConsumerWidget {
  const AdminQuizResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ColoredBox(
      key: Key('admin_quiz_results_screen'),
      color: AdultWorkspaceColors.canvas,
      child: AppPageContainer(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _QuizResultsPageHeader(),
            SizedBox(height: AppSpacing.lg),
            _FilterCard(),
            SizedBox(height: AppSpacing.md),
            _ResultsTable(),
          ],
        ),
      ),
    );
  }
}

class _QuizResultsPageHeader extends StatelessWidget {
  const _QuizResultsPageHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Quiz Results',
              key: const Key('quiz_results_page_title'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AdultWorkspaceColors.ink,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.35,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Review and export school-wide assessment results.',
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
/// enabled once the currently filtered [adminQuizResultsProvider] result
/// set has resolved to at least one row (never enabled while loading,
/// errored, or genuinely empty — same enablement shape
/// `teacher/presentation/quiz_results_screen.dart`'s own
/// `_ExportCsvButton` uses for its own [QuizResultsMatrix]). Uses
/// [AdminQuizResultsCsvBuilder] (pure) to build the CSV text and
/// filename, then `file_picker`'s native Save As dialog + `dart:io File`
/// to write it — identical mechanism to that button, just a flat row list
/// instead of a matrix.
class _ExportReportButton extends ConsumerWidget {
  const _ExportReportButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AdminQuizResultRow>? rows =
        ref.watch(adminQuizResultsProvider).value;
    final bool canExport = rows != null && rows.isNotEmpty;

    return AppButton(
      key: const Key('quiz_results_export_button'),
      label: 'Export Report',
      leadingIcon: Icons.file_download_outlined,
      variant: AppButtonVariant.outlined,
      size: AppComponentSize.small,
      semanticLabel: 'Export filtered quiz results report',
      onPressed: canExport ? () => _export(context, ref, rows) : null,
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<AdminQuizResultRow> rows,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AdminQuizResultsFilterSelection selection = ref.read(
      adminQuizResultsFilterSelectionProvider,
    );

    // Resolve the four filter dimensions' display labels for the
    // filename. Grade and Assessment Type are cheap (both already carry
    // their own `.label`). Section and School Year are id-only on the
    // selection, so their names come from data already sitting in the
    // provider cache rather than a fresh lookup:
    //  - Section: every exported row already belongs to the chosen
    //    section once `selection.sectionId` is non-null (the RPC itself
    //    filtered on it), so the first row's own `sectionName` is exactly
    //    that section's name — no separate section-options fetch needed.
    //  - School Year: matched out of `adminQuizResultsSchoolYearsProvider`,
    //    the same lookup list `_SchoolYearDropdown` renders from.
    final String gradeLabel = selection.gradeLevel?.label ?? 'All Grades';
    final String sectionLabel =
        selection.sectionId == null ? 'All Sections' : rows.first.sectionName;
    final String assessmentTypeLabel = selection.assessmentTypeFilter.label;

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

    const AdminQuizResultsCsvBuilder builder = AdminQuizResultsCsvBuilder();
    final String csvContent = builder.build(rows);
    final String defaultFileName = builder.buildFileName(
      gradeLabel: gradeLabel,
      sectionLabel: sectionLabel,
      assessmentTypeLabel: assessmentTypeLabel,
      schoolYearLabel: schoolYearLabel,
    );

    final String? savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Quiz Results',
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: <String>['csv'],
    );

    if (savePath == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Export cancelled.')),
      );
      return;
    }

    try {
      final String resolvedPath =
          savePath.toLowerCase().endsWith('.csv') ? savePath : '$savePath.csv';
      await File(resolvedPath).writeAsBytes(utf8.encode(csvContent));
      final String displayName =
          resolvedPath.split(Platform.pathSeparator).last;
      messenger.showSnackBar(
        SnackBar(content: Text('Exported to $displayName')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to export quiz results. Please try again.'),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------
// Filters
// ---------------------------------------------------------------------

/// Section filter dropdown options.
///
/// Part 2's `AdminQuizResultsRepository` exposes exactly two methods —
/// `fetchResults` (the rows themselves) and `fetchSchoolYears` (the
/// School Year dropdown's own lookup) — and 0051's SQL backs nothing
/// else; there is no `admin_quiz_results_sections`-style RPC. The
/// existing `SectionsRepository` (`sections_screen.dart`) only offers
/// `fetchForSchoolYear(schoolYearId)`, which needs a non-null school year
/// id — nothing to scope by once School Year = "All Time" (a null
/// [AdminQuizResultsFilterSelection.schoolYearId]), which is this
/// screen's own default.
///
/// Rather than adding a new repository method, this re-calls
/// `fetchResults` — the exact same RPC the results table already uses —
/// with every current filter EXCEPT `sectionId` (left at its default,
/// `null`), then takes the distinct (sectionId, sectionName) pairs out of
/// whatever rows come back. That keeps the Section list responsive to
/// Grade Level / Assessment Type / School Year (picking Grade 4 narrows
/// this to Grade 4's sections) while deliberately never being narrowed by
/// [AdminQuizResultsFilterSelection.sectionId] itself — watching the full
/// selection including `sectionId` here would make the option list
/// collapse to just the one already-chosen section, with no way back to
/// the others short of clearing the filter first.
///
/// Tradeoff, flagged for review: this issues a second `admin_quiz_results`
/// round trip on every Grade Level / Assessment Type / School Year change
/// (never on a Section change alone, since this provider doesn't watch
/// that field). A dedicated lookup RPC/repository method — the same shape
/// as `fetchSchoolYears` — would be the cleaner long-term fix if this
/// screen sees real usage; not built here to stay inside this phase's
/// scope (UI only, no new SQL/repository surface).
final FutureProvider<List<_SectionOption>> _sectionFilterOptionsProvider =
    FutureProvider.autoDispose<List<_SectionOption>>((ref) async {
      final AdminQuizResultsFilterSelection selection = ref.watch(
        adminQuizResultsFilterSelectionProvider,
      );
      final List<AdminQuizResultRow> rows = await ref
          .watch(adminQuizResultsRepositoryProvider)
          .fetchResults(
            gradeLevel: selection.gradeLevel,
            assessmentTypeFilter: selection.assessmentTypeFilter,
            schoolYearId: selection.schoolYearId,
          );

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

bool _hasActiveFilters(AdminQuizResultsFilterSelection selection) =>
    selection.gradeLevel != null ||
    selection.sectionId != null ||
    selection.assessmentTypeFilter !=
        AdminQuizResultsAssessmentTypeFilter.all ||
    selection.schoolYearId != null;

/// Grade Level / Section / Assessment Type / "Date Range" (School Year)
/// filter toolbar. At normal desktop widths all four controls and the
/// reset action share one row; narrower laptop windows wrap the same
/// controls without changing their behavior.
///
/// The fourth dropdown is labeled "Date Range" per the mockup's visual
/// style even though the underlying filter is School Year, not a literal
/// date range — confirmed against the Shared Context's own clarification
/// (values like "2025-2026" / "2026-2027" / "All Time", i.e. school
/// years, are exactly what belongs in that dropdown), not a
/// today/this-week/this-month-style range. See [_SchoolYearDropdown]'s
/// own doc comment.
class _FilterCard extends ConsumerWidget {
  const _FilterCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AdminQuizResultsFilterSelection selection = ref.watch(
      adminQuizResultsFilterSelectionProvider,
    );

    void updateSelection(
      AdminQuizResultsFilterSelection Function(AdminQuizResultsFilterSelection)
      update,
    ) {
      ref.read(adminQuizResultsFilterSelectionProvider.notifier).update(update);
    }

    // Clears a Section selection that's gone stale — [_sectionFilterOptionsProvider]
    // re-resolves whenever Grade Level / Assessment Type / School Year
    // changes (it deliberately ignores `sectionId` itself, see that
    // provider's own doc comment), so a currently-selected section can
    // fall out of the newly-resolved option list without any explicit
    // action on the Section dropdown at all (e.g. Grade Level switches
    // to Grade 5 while a Grade 4 section is still selected). Left alone,
    // that produces a contradictory filter combination that silently
    // returns zero rows. `ref.listen` (not a direct check during build)
    // because dispatching a provider update belongs in a listener
    // callback, not in the middle of this widget's own build.
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
            ref.read(adminQuizResultsFilterSelectionProvider).sectionId;
        if (currentSectionId == null) return; // "All Sections" is always valid
        final bool stillValid = sections.any(
          (_SectionOption s) => s.id == currentSectionId,
        );
        if (!stillValid) {
          ref
              .read(adminQuizResultsFilterSelectionProvider.notifier)
              .update((s) => s.withSectionId(null));
        }
      },
    );

    final bool filtersActive = _hasActiveFilters(selection);
    return Container(
      key: const Key('quiz_results_filter_toolbar'),
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
            'Filter assessment results',
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
              final bool singleRow = constraints.maxWidth >= 880;
              final int columns = constraints.maxWidth >= 520 ? 2 : 1;
              final double fieldWidth =
                  singleRow
                      ? (constraints.maxWidth - clearWidth - spacing * 4) / 4
                      : (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;

              final List<Widget> controls = <Widget>[
                AppDropdown<GradeLevel>(
                  key: const Key('quiz_results_grade_filter'),
                  label: 'Grade Level',
                  width: fieldWidth,
                  size: AppComponentSize.small,
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
                      (GradeLevel? value) => updateSelection(
                        (AdminQuizResultsFilterSelection current) =>
                            current.withGradeLevel(value),
                      ),
                ),
                _SectionDropdown(
                  selection: selection,
                  onUpdate: updateSelection,
                  width: fieldWidth,
                ),
                AppDropdown<AdminQuizResultsAssessmentTypeFilter>(
                  key: const Key('quiz_results_assessment_filter'),
                  label: 'Assessment Type',
                  width: fieldWidth,
                  size: AppComponentSize.small,
                  options: <
                    AppDropdownOption<AdminQuizResultsAssessmentTypeFilter>
                  >[
                    for (final AdminQuizResultsAssessmentTypeFilter filter
                        in AdminQuizResultsAssessmentTypeFilter.values)
                      AppDropdownOption<AdminQuizResultsAssessmentTypeFilter>(
                        value: filter,
                        label: filter.label,
                      ),
                  ],
                  selected: selection.assessmentTypeFilter,
                  onChanged:
                      (AdminQuizResultsAssessmentTypeFilter? value) =>
                          updateSelection(
                            (AdminQuizResultsFilterSelection current) =>
                                current.withAssessmentTypeFilter(
                                  value ??
                                      AdminQuizResultsAssessmentTypeFilter.all,
                                ),
                          ),
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
                  key: const Key('quiz_results_clear_filters'),
                  onPressed:
                      filtersActive
                          ? () => updateSelection(
                            (_) => const AdminQuizResultsFilterSelection(),
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

typedef _SelectionUpdater =
    void Function(
      AdminQuizResultsFilterSelection Function(AdminQuizResultsFilterSelection)
      update,
    );

class _SectionDropdown extends ConsumerWidget {
  const _SectionDropdown({
    required this.selection,
    required this.onUpdate,
    required this.width,
  });

  final AdminQuizResultsFilterSelection selection;
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
      // AppDropdown wraps DropdownMenu, whose `initialSelection` is only
      // read once on first build and isn't guaranteed to visually
      // update if `selected` changes later without a rebuild of the
      // widget itself (see _FilterCard's stale-selection reset above,
      // the first place in this codebase that resets an AppDropdown's
      // value programmatically rather than via its own onChanged). This
      // key forces Flutter to tear down and recreate the dropdown
      // whenever sectionId changes — including a programmatic reset
      // back to null — so the displayed label can't go stale.
      key: ValueKey<String>(
        'quiz_results_section_${selection.sectionId ?? 'all'}',
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

/// The mockup's "Date Range" dropdown — actually School Year underneath.
/// See [_FilterCard]'s own doc comment for the label decision.
class _SchoolYearDropdown extends ConsumerWidget {
  const _SchoolYearDropdown({
    required this.selection,
    required this.onUpdate,
    required this.width,
  });

  final AdminQuizResultsFilterSelection selection;
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
      key: const Key('quiz_results_date_filter'),
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

// ---------------------------------------------------------------------
// Results table
// ---------------------------------------------------------------------

class _ResultsTable extends ConsumerWidget {
  const _ResultsTable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminQuizResultRow>> resultsAsync = ref.watch(
      adminQuizResultsProvider,
    );
    final AdminQuizResultsFilterSelection selection = ref.watch(
      adminQuizResultsFilterSelectionProvider,
    );

    return resultsAsync.when(
      loading:
          () => const _ResultsStateSurface(
            child: AppLoadingIndicator(message: 'Loading assessment results'),
          ),
      error:
          (Object error, StackTrace stackTrace) => _ResultsStateSurface(
            child: AppErrorState(
              message:
                  error is AppFailure
                      ? error.message
                      : 'Could not load quiz results.',
              onRetry: () => ref.invalidate(adminQuizResultsProvider),
            ),
          ),
      data: (List<AdminQuizResultRow> rows) {
        if (rows.isEmpty) {
          final bool filtersActive = _hasActiveFilters(selection);
          return _ResultsStateSurface(
            child: AppEmptyState(
              icon: Icons.assignment_outlined,
              title:
                  filtersActive
                      ? 'No results match your current filters'
                      : 'No quiz results yet',
              description:
                  filtersActive
                      ? 'Clear the filters or choose a different assessment context.'
                      : 'Completed assessment results will appear here.',
              actionLabel: filtersActive ? 'Clear filters' : null,
              onAction:
                  filtersActive
                      ? () => ref
                          .read(
                            adminQuizResultsFilterSelectionProvider.notifier,
                          )
                          .update(
                            (_) => const AdminQuizResultsFilterSelection(),
                          )
                      : null,
            ),
          );
        }
        return _ResultsDataTable(rows: rows);
      },
    );
  }
}

class _ResultsStateSurface extends StatelessWidget {
  const _ResultsStateSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('quiz_results_state_surface'),
      constraints: const BoxConstraints(minHeight: 270),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.largeAll,
        border: Border.all(color: AdultWorkspaceColors.border),
      ),
      child: child,
    );
  }
}

class _ResultsDataTable extends StatelessWidget {
  const _ResultsDataTable({required this.rows});

  final List<AdminQuizResultRow> rows;

  static const double _minimumTableWidth = 1080;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('quiz_results_directory'),
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
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Assessment Results',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AdultWorkspaceColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${rows.length} ${rows.length == 1 ? 'result' : 'results'}',
                  key: const Key('quiz_results_count'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AdultWorkspaceColors.primaryMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdultWorkspaceColors.border),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double tableWidth =
                  constraints.maxWidth < _minimumTableWidth
                      ? _minimumTableWidth
                      : constraints.maxWidth;
              return SingleChildScrollView(
                key: const Key('quiz_results_table_scroll'),
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Semantics(
                    container: true,
                    label:
                        'Assessment results table with ${rows.length} ${rows.length == 1 ? 'row' : 'rows'}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const _ResultsTableHeader(),
                        for (int index = 0; index < rows.length; index++)
                          _ResultRow(
                            key: Key(
                              'quiz_result_row_${rows[index].quizAttemptId}',
                            ),
                            row: rows[index],
                            showDivider: index != rows.length - 1,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

const Map<int, TableColumnWidth> _resultColumnWidths = <int, TableColumnWidth>{
  0: FixedColumnWidth(230),
  1: FlexColumnWidth(1),
  2: FixedColumnWidth(105),
  3: FixedColumnWidth(125),
  4: FixedColumnWidth(140),
  5: FixedColumnWidth(155),
};

class _ResultsTableHeader extends StatelessWidget {
  const _ResultsTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdultWorkspaceColors.fieldFill,
      child: Table(
        key: const Key('quiz_results_table_header'),
        columnWidths: _resultColumnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: const <TableRow>[
          TableRow(
            children: <Widget>[
              _TableHeaderCell('Student Name'),
              _TableHeaderCell('Assessment Name'),
              _TableHeaderCell('Score'),
              _TableHeaderCell('Percentage'),
              _TableHeaderCell('Date Taken'),
              _TableHeaderCell('Status'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  const _TableHeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          color: AdultWorkspaceColors.secondaryText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({super.key, required this.row, required this.showDivider});

  final AdminQuizResultRow row;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return _ResultRowHoverSurface(
      child: Container(
        decoration: BoxDecoration(
          border:
              showDivider
                  ? const Border(
                    bottom: BorderSide(color: AdultWorkspaceColors.border),
                  )
                  : null,
        ),
        child: Table(
          columnWidths: _resultColumnWidths,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: <TableRow>[
            TableRow(
              children: <Widget>[
                _TableDataCell(child: _StudentNameCell(name: row.studentName)),
                _TableDataCell(
                  child: Tooltip(
                    message: row.assessmentName,
                    child: Text(
                      row.assessmentName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AdultWorkspaceColors.ink,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                _TableDataCell(child: _ResultValue(_scoreLabel(row))),
                _TableDataCell(
                  child: _ResultValue(formatPercent(row.percentage)),
                ),
                _TableDataCell(child: _ResultValue(_dateLabel(row.dateTaken))),
                _TableDataCell(child: _StatusPill(status: row.status)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TableDataCell extends StatelessWidget {
  const _TableDataCell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

class _StudentNameCell extends StatelessWidget {
  const _StudentNameCell({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AdultWorkspaceColors.softBlue,
            shape: BoxShape.circle,
          ),
          child: Text(
            _initials(name),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AdultWorkspaceColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AdultWorkspaceColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  static String _initials(String fullName) {
    final List<String> parts =
        fullName
            .trim()
            .split(RegExp(r'\s+'))
            .where((String part) => part.isNotEmpty)
            .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AdminQuizResultStatus? status;

  @override
  Widget build(BuildContext context) {
    final AdminQuizResultStatus? s = status;
    if (s == null) return const Text('—');
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AppSemanticColors? semantic =
        Theme.of(context).extension<AppSemanticColors>();
    final bool passed = s == AdminQuizResultStatus.passed;
    return Semantics(
      label: 'Status: ${s.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color:
              passed
                  ? semantic?.successContainer ?? colorScheme.secondaryContainer
                  : colorScheme.errorContainer,
          borderRadius: AppRadius.smallAll,
        ),
        child: Text(
          s.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color:
                passed
                    ? semantic?.onSuccessContainer ??
                        colorScheme.onSecondaryContainer
                    : colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

class _ResultValue extends StatelessWidget {
  const _ResultValue(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color:
            value == '—'
                ? AdultWorkspaceColors.secondaryText
                : AdultWorkspaceColors.ink,
        fontWeight: FontWeight.w500,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}

class _ResultRowHoverSurface extends StatefulWidget {
  const _ResultRowHoverSurface({required this.child});

  final Widget child;

  @override
  State<_ResultRowHoverSurface> createState() => _ResultRowHoverSurfaceState();
}

class _ResultRowHoverSurfaceState extends State<_ResultRowHoverSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color:
            _hovered
                ? AdultWorkspaceColors.paleBlue.withValues(alpha: 0.72)
                : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}

String _scoreLabel(AdminQuizResultRow row) {
  final num? score = row.score;
  final int? total = row.totalQuestions;
  if (score == null || total == null) return '—';
  final String scoreText =
      score == score.roundToDouble()
          ? score.toInt().toString()
          : score.toString();
  return '$scoreText/$total';
}

String _dateLabel(DateTime date) {
  final String year = date.year.toString().padLeft(4, '0');
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
