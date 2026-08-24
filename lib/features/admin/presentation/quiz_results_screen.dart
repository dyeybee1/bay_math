import 'dart:convert' show utf8;
import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
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
    return const AppPageContainer(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSectionHeader(
            title: 'Quiz Results',
            subtitle: 'School-wide monitoring of assessment results',
            action: _ExportReportButton(),
          ),
          SizedBox(height: AppSpacing.md),
          _FilterCard(),
          SizedBox(height: AppSpacing.md),
          _ResultsTable(),
        ],
      ),
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
      label: 'Export Report',
      leadingIcon: Icons.description_outlined,
      onPressed: canExport ? () => _export(context, ref, rows) : null,
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<AdminQuizResultRow> rows,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AdminQuizResultsFilterSelection selection =
        ref.read(adminQuizResultsFilterSelectionProvider);

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
      messenger.showSnackBar(const SnackBar(content: Text('Export cancelled.')));
      return;
    }

    try {
      final String resolvedPath =
          savePath.toLowerCase().endsWith('.csv') ? savePath : '$savePath.csv';
      await File(resolvedPath).writeAsBytes(utf8.encode(csvContent));
      final String displayName = resolvedPath.split(Platform.pathSeparator).last;
      messenger.showSnackBar(SnackBar(content: Text('Exported to $displayName')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to export quiz results. Please try again.')),
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
  final AdminQuizResultsFilterSelection selection =
      ref.watch(adminQuizResultsFilterSelectionProvider);
  final List<AdminQuizResultRow> rows =
      await ref.watch(adminQuizResultsRepositoryProvider).fetchResults(
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

/// Grade Level / Section / Assessment Type / "Date Range" (School Year)
/// filter row, inside a [AppCard] with a "Filters" header, matching the
/// mockup's bordered filter panel.
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
    final AdminQuizResultsFilterSelection selection =
        ref.watch(adminQuizResultsFilterSelectionProvider);

    void updateSelection(
      AdminQuizResultsFilterSelection Function(AdminQuizResultsFilterSelection) update,
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
    ref.listen<AsyncValue<List<_SectionOption>>>(_sectionFilterOptionsProvider,
        (AsyncValue<List<_SectionOption>>? previous, AsyncValue<List<_SectionOption>> next) {
      final List<_SectionOption>? sections = next.value;
      if (sections == null) return; // still loading or errored — leave selection alone
      final String? currentSectionId =
          ref.read(adminQuizResultsFilterSelectionProvider).sectionId;
      if (currentSectionId == null) return; // "All Sections" is always valid
      final bool stillValid = sections.any((_SectionOption s) => s.id == currentSectionId);
      if (!stillValid) {
        ref
            .read(adminQuizResultsFilterSelectionProvider.notifier)
            .update((s) => s.withSectionId(null));
      }
    });

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
              const AppDropdownOption<GradeLevel>(value: null, label: 'All Grades'),
              for (final GradeLevel g in GradeLevel.values)
                AppDropdownOption<GradeLevel>(value: g, label: g.label),
            ],
            selected: selection.gradeLevel,
            onChanged: (GradeLevel? value) =>
                updateSelection((s) => s.withGradeLevel(value)),
          ),
          _SectionDropdown(selection: selection, onUpdate: updateSelection),
          AppDropdown<AdminQuizResultsAssessmentTypeFilter>(
            label: 'Assessment Type',
            width: 200,
            options: <AppDropdownOption<AdminQuizResultsAssessmentTypeFilter>>[
              for (final AdminQuizResultsAssessmentTypeFilter f
                  in AdminQuizResultsAssessmentTypeFilter.values)
                AppDropdownOption<AdminQuizResultsAssessmentTypeFilter>(value: f, label: f.label),
            ],
            selected: selection.assessmentTypeFilter,
            onChanged: (AdminQuizResultsAssessmentTypeFilter? value) => updateSelection(
              (s) => s.withAssessmentTypeFilter(value ?? AdminQuizResultsAssessmentTypeFilter.all),
            ),
          ),
          _SchoolYearDropdown(selection: selection, onUpdate: updateSelection),
        ],
      ),
    );
  }
}

typedef _SelectionUpdater = void Function(
  AdminQuizResultsFilterSelection Function(AdminQuizResultsFilterSelection) update,
);

class _SectionDropdown extends ConsumerWidget {
  const _SectionDropdown({required this.selection, required this.onUpdate});

  final AdminQuizResultsFilterSelection selection;
  final _SelectionUpdater onUpdate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<_SectionOption>> optionsAsync =
        ref.watch(_sectionFilterOptionsProvider);
    final List<_SectionOption> sections = optionsAsync.value ?? const <_SectionOption>[];

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

/// The mockup's "Date Range" dropdown — actually School Year underneath.
/// See [_FilterCard]'s own doc comment for the label decision.
class _SchoolYearDropdown extends ConsumerWidget {
  const _SchoolYearDropdown({required this.selection, required this.onUpdate});

  final AdminQuizResultsFilterSelection selection;
  final _SelectionUpdater onUpdate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminSchoolYearOption>> yearsAsync =
        ref.watch(adminQuizResultsSchoolYearsProvider);
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

// ---------------------------------------------------------------------
// Results table
// ---------------------------------------------------------------------

class _ResultsTable extends ConsumerWidget {
  const _ResultsTable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminQuizResultRow>> resultsAsync =
        ref.watch(adminQuizResultsProvider);

    return resultsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: AppLoadingIndicator(),
      ),
      error: (error, _) => AppErrorState(
        message: error is AppFailure ? error.message : 'Could not load quiz results.',
        onRetry: () => ref.invalidate(adminQuizResultsProvider),
      ),
      data: (List<AdminQuizResultRow> rows) {
        if (rows.isEmpty) {
          return const AppEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No quiz results found',
            description: 'Try adjusting the filters above.',
          );
        }
        return _ResultsDataTable(rows: rows);
      },
    );
  }
}

/// The flat results grid: one header row of column labels, then one row
/// per [AdminQuizResultRow]. Built as a plain [Table] — this codebase has
/// no `DataTable`-based screen to match (see
/// `teacher/presentation/quiz_results_screen.dart`'s own `_ResultsMatrix`
/// doc comment: "this codebase has no `DataTable`-based screen to match,
/// and the design notes say not to introduce one"), so the same plain-
/// [Table] approach is reused here rather than introducing `DataTable` as
/// a second grid pattern. Unlike that matrix (whose column count varies
/// with the chosen quizzes), this table's six columns are fixed, so no
/// extra horizontal [SingleChildScrollView] is needed.
class _ResultsDataTable extends StatelessWidget {
  const _ResultsDataTable({required this.rows});

  final List<AdminQuizResultRow> rows;

  static const List<String> _headers = <String>[
    'Student Name',
    'Assessment Name',
    'Score',
    'Percentage',
    'Date Taken',
    'Status',
  ];

  static const Map<int, TableColumnWidth> _columnWidths = <int, TableColumnWidth>{
    0: FlexColumnWidth(2),
    1: FlexColumnWidth(2),
    2: FlexColumnWidth(1),
    3: FlexColumnWidth(1),
    4: FlexColumnWidth(1.2),
    5: FlexColumnWidth(1.3),
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle? headerStyle = textTheme.labelLarge?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return AppCard(
      padding: EdgeInsets.zero,
      child: Table(
        columnWidths: _columnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: <TableRow>[
          TableRow(
            decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
            children: <Widget>[
              for (final String h in _headers) _TableCell(child: Text(h, style: headerStyle)),
            ],
          ),
          for (final AdminQuizResultRow row in rows)
            TableRow(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
              ),
              children: <Widget>[
                _TableCell(
                  alignment: Alignment.centerLeft,
                  child: Text(row.studentName, style: textTheme.bodyMedium),
                ),
                _TableCell(
                  alignment: Alignment.centerLeft,
                  child: Text(row.assessmentName, style: textTheme.bodyMedium),
                ),
                _TableCell(
                  alignment: Alignment.centerLeft,
                  child: Text(_scoreLabel(row), style: textTheme.bodyMedium),
                ),
                _TableCell(
                  alignment: Alignment.centerLeft,
                  child: Text(formatPercent(row.percentage), style: textTheme.bodyMedium),
                ),
                _TableCell(
                  alignment: Alignment.centerLeft,
                  child: Text(_dateLabel(row.dateTaken), style: textTheme.bodyMedium),
                ),
                _TableCell(
                  alignment: Alignment.centerLeft,
                  child: _StatusPill(status: row.status, percentage: row.percentage),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// `'18/25'` style, matching the mockup — the raw score against the
  /// item count, not a recomputed fraction. `'—'` if either half is
  /// missing (see [AdminQuizResultRow.score]/`.totalQuestions`'s own doc
  /// comments for when that happens).
  String _scoreLabel(AdminQuizResultRow row) {
    final num? score = row.score;
    final int? total = row.totalQuestions;
    if (score == null || total == null) return '—';
    final String scoreText =
        score == score.roundToDouble() ? score.toInt().toString() : score.toString();
    return '$scoreText/$total';
  }

  /// `'YYYY-MM-DD'`, matching the mockup. No `intl` dependency in this
  /// project's `pubspec.yaml`, so formatted by hand rather than adding
  /// one for a single date column.
  String _dateLabel(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.child, this.alignment = Alignment.center});

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Align(alignment: alignment, child: child),
    );
  }
}

/// `'Passed'` / `'Needs Improvement'` status pill. Colored by a three-tier
/// severity computed from [percentage] at render time — success (>=70),
/// warning (50-69), error (<50) — rather than the two-value `status`
/// field alone, and rather than the mockup's own flat neutral-gray pill
/// for both states (flagged as a judgment call in this phase's earlier
/// summary notes; the written spec calls for a "colored pill" but the
/// attached mockup image itself renders both states in the same gray).
/// [AdminQuizResultStatus] itself stays exactly the two DB-computed
/// values ('passed'/'needs_improvement') — only this pill's color gets
/// the third tier. A `null` [status] (the documented edge case on that
/// field) renders as a plain dash, never a badge.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.percentage});

  final AdminQuizResultStatus? status;
  final double? percentage;

  @override
  Widget build(BuildContext context) {
    final AdminQuizResultStatus? s = status;
    if (s == null) return const Text('—');
    // status is null only in the same edge case percentage is (see
    // AdminQuizResultRow's own doc comment on both fields) — so a
    // non-null status here guarantees a non-null percentage too.
    return AppBadge(label: s.label, variant: _variantFor(percentage!));
  }

  AppBadgeVariant _variantFor(double percentage) {
    if (percentage >= 70) return AppBadgeVariant.success;
    if (percentage >= 50) return AppBadgeVariant.warning;
    return AppBadgeVariant.error;
  }
}
