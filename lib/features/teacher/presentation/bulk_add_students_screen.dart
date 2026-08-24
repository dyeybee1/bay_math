// NOT COMPILER-VERIFIED: same disclosure this feature's Edge Function
// (create-students-bulk/index.ts) already makes, for the same reason — I
// still don't have a Flutter/Dart SDK to run `flutter analyze`/`flutter
// test` against this file (checked again: `dart --version` isn't
// installed here). Please run those before relying on this. (pub.dev
// itself WAS reachable in the session that swapped this file's import
// from `excel` to `excel_plus`, below — see that swap's own comment for
// what was actually verified there vs. what remains unverified.)
//
// GENUINE UNCERTAINTY, FLAGGED RATHER THAN GUESSED PAST: the exact
// `CellValue` field names below (`_xlsxCellToString`) are taken from the
// `excel` package's own published API docs and a documented usage example
// (a `switch` over `TextCellValue`/`IntCellValue`/etc.), not from having
// run this against a real .xlsx file — and `excel_plus`'s own docs state
// it mirrors `excel`'s classes/methods/enums exactly, but that claim
// itself wasn't independently re-verified field-by-field against
// `excel_plus` specifically. If the installed version's field names differ
// even slightly, that one function is the only place to fix — it's
// isolated on purpose. See its own comment below for the exact source this
// was checked against.
//
// `excel_plus` PACKAGE NAME COLLISION: `excel_plus` (a source-compatible
// drop-in fork of the `excel` package — same public API, different import
// path) exports its own `Border`/`BorderStyle` (for cell styling) which are
// known to collide with `package:flutter/material.dart`'s identically-named
// classes. This file imports it under the `xlsx` prefix specifically to
// avoid that, rather than risk an ambiguous-import compile error the
// moment anyone adds a real `Border` usage to this file later.
//
// NOTE: this was originally written against `package:excel`, then switched
// to `package:excel_plus` after `flutter pub get` surfaced a real `xml`
// version conflict between `excel` and this project's existing `pdf`
// dependency — see pubspec.yaml's comment on the `excel_plus` line for the
// full explanation. `excel_plus` is documented as a source-compatible
// drop-in for `excel` (same classes/methods/enums, only the import path
// differs), so nothing below this comment block needed to change beyond
// that one import line.

import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel_plus/excel_plus.dart' as xlsx;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/section.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/students_repository.dart';
import '../../../core/widgets/widgets.dart';
import 'section_workspace_screen.dart' show enrolledStudentsProvider;

/// Must match the cap enforced server-side in BOTH:
///   - `app.create_students_bulk`'s `v_max_batch_size`
///     (supabase/migrations/0055_bulk_create_students.sql)
///   - the `create-students-bulk` Edge Function's own `MAX_BATCH_SIZE`
///     (supabase/functions/create-students-bulk/index.ts)
/// There is no single source of truth for this number across
/// SQL/TypeScript/Dart — if either of those ever changes, this must be
/// changed to match by hand. Enforcing it here too means the person sees a
/// clear message before any network call, instead of a request the server
/// will reject anyway.
const int kBulkAddStudentsMaxBatchSize = 100;

/// A Teacher's bulk student-creation flow for one [section] — paste or
/// upload many names, preview what was parsed, submit once, then review
/// per-row results. Entered from `SectionWorkspaceScreen`'s "Bulk Add
/// Students" button, alongside (not replacing) the existing single-student
/// `_NewStudentDialog` flow.
///
/// A full [Scaffold] pushed via [Navigator], not an [AppDialog] — unlike
/// the single-student dialog, this screen's content (a paste box, a
/// scrollable preview of up to 100 names, and afterward up to 100 result
/// rows including generated passwords) is too tall to work well inside
/// [AppDialog]'s constrained-height layout.
class BulkAddStudentsScreen extends ConsumerStatefulWidget {
  const BulkAddStudentsScreen({super.key, required this.section});

  final Section section;

  @override
  ConsumerState<BulkAddStudentsScreen> createState() => _BulkAddStudentsScreenState();
}

class _BulkAddStudentsScreenState extends ConsumerState<BulkAddStudentsScreen> {
  final TextEditingController _pasteController = TextEditingController();

  List<String> _parsedNames = const [];
  String? _validationError;
  bool _isSubmitting = false;

  /// Non-null once a NORMAL (per-row) response has come back — i.e. the
  /// batch itself ran, even if some/all individual rows failed. Distinct
  /// from [_batchFailureMessage] below on purpose; see
  /// `StudentsRepository.createBulk`'s own doc comment on why these two
  /// outcomes must never be conflated.
  List<BulkCreateStudentResult>? _results;

  /// Non-null only when the ENTIRE batch call threw — nothing was
  /// created. Mutually exclusive with [_results] (only one is ever
  /// non-null at a time).
  String? _batchFailureMessage;

  /// Gate on leaving this screen while [_results] contains at least one
  /// success row the person hasn't explicitly acknowledged yet — these
  /// generated passwords are shown once, the same "deliberate, logged
  /// action" treatment this project's existing "View Password" flow gives
  /// credential display elsewhere, not something to let slip away via an
  /// accidental back-swipe.
  bool _acknowledgedResults = false;

  bool get _hasUnacknowledgedSuccess =>
      _results != null && _results!.any((r) => r.success) && !_acknowledgedResults;

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Parsing — paste box and file input both funnel into
  // `_namesFromRows`/`_parseNamesFromText` so header-row detection and
  // trim/blank-drop logic exist in exactly one place each.
  // ---------------------------------------------------------------------

  List<String> _parseNamesFromText(String raw) {
    return raw.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
  }

  bool _looksLikeHeaderRow(List<dynamic> firstRow) {
    if (firstRow.isEmpty) return false;
    final String firstCell = (firstRow.first?.toString() ?? '').trim().toLowerCase();
    return firstCell == 'name' || firstCell == 'full name' || firstCell == 'student name';
  }

  /// Shared by both the .csv and .xlsx paths once each has reduced its
  /// file format down to a plain `List<List<dynamic>>` of row cells —
  /// reads the FIRST column of each row as a name, skipping row 1 only if
  /// it looks like a header (per [_looksLikeHeaderRow]).
  List<String> _namesFromRows(List<List<dynamic>> rows) {
    if (rows.isEmpty) return const [];
    final List<List<dynamic>> dataRows =
        _looksLikeHeaderRow(rows.first) ? rows.skip(1).toList() : rows;
    return dataRows
        .map((row) => row.isEmpty ? '' : (row.first?.toString() ?? ''))
        .map((cell) => cell.trim())
        .where((cell) => cell.isNotEmpty)
        .toList();
  }

  List<String> _parseNamesFromCsvBytes(Uint8List bytes) {
    final String content = utf8.decode(bytes);
    final List<List<dynamic>> rows = const CsvToListConverter().convert(content);
    return _namesFromRows(rows);
  }

  /// `CellValue` field access checked against the `excel` package's own
  /// published API docs and its documented usage example (a `switch` over
  /// `TextCellValue()`/`FormulaCellValue()`/etc., each printing
  /// `value.value`/`value.formula`) — not run against a real file. A name
  /// column is expected to be `TextCellValue` in the overwhelming majority
  /// of real spreadsheets; the other branches here are defensive, not
  /// load-bearing.
  String? _xlsxCellToString(xlsx.CellValue? value) {
    return switch (value) {
      null => null,
      xlsx.TextCellValue() => value.value.text,
      xlsx.IntCellValue() => value.value.toString(),
      xlsx.DoubleCellValue() => value.value.toString(),
      xlsx.BoolCellValue() => value.value.toString(),
      xlsx.FormulaCellValue() => value.formula,
      _ => value.toString(),
    };
  }

  List<String> _parseNamesFromXlsxBytes(Uint8List bytes) {
    final xlsx.Excel workbook = xlsx.Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) return const [];
    final xlsx.Sheet? sheet = workbook.tables[workbook.tables.keys.first];
    if (sheet == null) return const [];
    final List<List<dynamic>> rows = [
      for (final List<xlsx.Data?> row in sheet.rows)
        [for (final xlsx.Data? cell in row) _xlsxCellToString(cell?.value)],
    ];
    return _namesFromRows(rows);
  }

  void _onPasteChanged(String text) {
    setState(() {
      _parsedNames = _parseNamesFromText(text);
      _validationError = null;
    });
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['csv', 'xlsx'],
      withData: true,
    );
    if (result == null) return; // person cancelled the picker

    final PlatformFile file = result.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      setState(() => _validationError = 'Could not read the selected file.');
      return;
    }

    final String extension = (file.extension ?? '').toLowerCase();
    List<String> names;
    try {
      if (extension == 'csv') {
        names = _parseNamesFromCsvBytes(bytes);
      } else if (extension == 'xlsx') {
        names = _parseNamesFromXlsxBytes(bytes);
      } else {
        setState(() => _validationError = 'Please choose a .csv or .xlsx file.');
        return;
      }
    } catch (_) {
      setState(
        () => _validationError = 'Could not read that file. Please check its format and try again.',
      );
      return;
    }

    _pasteController.clear(); // the file replaces whatever was pasted, not appended to it
    setState(() {
      _parsedNames = names;
      _validationError = null;
    });
  }

  // ---------------------------------------------------------------------
  // Submit / results.
  // ---------------------------------------------------------------------

  Future<void> _submit() async {
    if (_parsedNames.isEmpty || _parsedNames.length > kBulkAddStudentsMaxBatchSize || _isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final List<BulkCreateStudentResult> results = await ref
          .read(studentsRepositoryProvider)
          .createBulk(sectionId: widget.section.id, fullNames: _parsedNames);

      // Invalidated as soon as we know ANY row succeeded — the students
      // are already committed in the database at this point regardless of
      // whether the person has acknowledged/saved the displayed
      // passwords yet, same timing `_createStudent` already uses for the
      // single-student flow.
      if (results.any((r) => r.success)) {
        ref.invalidate(enrolledStudentsProvider(widget.section.id));
      }

      setState(() {
        _results = results;
        _acknowledgedResults = false;
        _isSubmitting = false;
      });
    } on AppFailure catch (_) {
      // Per StudentsRepository.createBulk's own doc comment: a thrown
      // AppFailure here means the batch itself never ran — NOT that every
      // name in it individually failed. Rendered as one message, never as
      // N per-row failures.
      setState(() {
        _batchFailureMessage =
            'No students were created; the batch of ${_parsedNames.length} could not be '
            'processed. Try again or contact support.';
        _isSubmitting = false;
      });
    }
  }

  /// Shown before discarding any unacknowledged success rows — whether
  /// that's leaving the screen entirely or switching back to the input
  /// view to retry just the failed names. Returns true only if the person
  /// explicitly chooses to proceed (or there was nothing to lose in the
  /// first place).
  Future<bool> _confirmDiscardUnsavedPasswords() async {
    if (!_hasUnacknowledgedSuccess) return true;
    final bool? proceed = await AppDialog.show<bool>(
      context,
      title: 'Continue without saving passwords?',
      type: AppDialogType.warning,
      message:
          "These generated passwords won't be shown again after this. Make sure you've copied "
          'or printed them first.',
      actions: <Widget>[
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: 'Continue',
          variant: AppButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    return proceed ?? false;
  }

  Future<void> _handlePopAttempt() async {
    final bool proceed = await _confirmDiscardUnsavedPasswords();
    if (proceed && mounted) {
      setState(() => _acknowledgedResults = true);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _retryFailedOnly(List<BulkCreateStudentResult> failedRows) async {
    final bool proceed = await _confirmDiscardUnsavedPasswords();
    if (!proceed) return;

    final String namesText =
        failedRows.map((r) => r.fullName ?? '').where((name) => name.isNotEmpty).join('\n');

    setState(() {
      _acknowledgedResults = true;
      _pasteController.text = namesText;
      _parsedNames = _parseNamesFromText(namesText);
      _validationError = null;
      _results = null;
      _batchFailureMessage = null;
    });
  }

  void _finishAndClose() {
    setState(() => _acknowledgedResults = true);
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------
  // Views.
  // ---------------------------------------------------------------------

  Widget _buildInputView(BuildContext context) {
    final bool isOverCap = _parsedNames.length > kBulkAddStudentsMaxBatchSize;
    final bool canSubmit = _parsedNames.isNotEmpty && !isOverCap && !_isSubmitting;

    return AppPageContainer(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Paste student names, one per line, or upload a .csv or .xlsx file — the first '
            'column of each row is read as the name.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _pasteController,
            type: AppTextFieldType.multiline,
            label: 'Student Names (one per line)',
            maxLines: 10,
            enabled: !_isSubmitting,
            onChanged: _onPasteChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Choose .csv or .xlsx File',
            variant: AppButtonVariant.outlined,
            leadingIcon: Icons.upload_file,
            size: AppComponentSize.small,
            onPressed: _isSubmitting ? null : _pickFile,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_validationError != null)
            Text(_validationError!, style: TextStyle(color: Theme.of(context).colorScheme.error))
          else if (isOverCap)
            Text(
              'Found ${_parsedNames.length} names, which is more than the limit of '
              '$kBulkAddStudentsMaxBatchSize per batch. Please split this into multiple '
              'batches of $kBulkAddStudentsMaxBatchSize or fewer.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else
            Text('${_parsedNames.length} student${_parsedNames.length == 1 ? '' : 's'} found'),
          if (_parsedNames.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              header: const Text('Preview'),
              child: SizedBox(
                height: 240,
                child: ListView.builder(
                  itemCount: _parsedNames.length,
                  itemBuilder: (context, i) => Text('${i + 1}. ${_parsedNames[i]}'),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Create ${_parsedNames.length} Student${_parsedNames.length == 1 ? '' : 's'}',
            onPressed: canSubmit ? _submit : null,
            isLoading: _isSubmitting,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(BuildContext context) {
    final List<BulkCreateStudentResult> results = _results!;
    final List<BulkCreateStudentResult> successRows =
        results.where((r) => r.success).toList();
    final List<BulkCreateStudentResult> failedRows =
        results.where((r) => !r.success).toList();
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AppPageContainer(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (successRows.isNotEmpty) ...<Widget>[
            Text('Created (${successRows.length})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Write down or print these now — passwords are shown only once.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final BulkCreateStudentResult row in successRows)
              AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                header: Text(row.fullName ?? 'Unknown student'),
                subtitle: Text('@${row.username ?? '—'}'),
                child: SelectableText('Password: ${row.password ?? '—'}'),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (failedRows.isNotEmpty) ...<Widget>[
            Text('Failed (${failedRows.length})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final BulkCreateStudentResult row in failedRows)
              AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                header: Text(row.fullName ?? 'Unknown student'),
                child: Text(
                  row.errorMessage ?? 'This student could not be created.',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Copy Failed Names Back to Retry',
              variant: AppButtonVariant.outlined,
              onPressed: () => _retryFailedOnly(failedRows),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppButton(
            label: successRows.isEmpty ? 'Close' : "Done — I've Saved These Passwords",
            onPressed: _finishAndClose,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBatchFailureView(BuildContext context) {
    return AppPageContainer(
      child: AppErrorState(
        message: _batchFailureMessage!,
        onRetry: () => setState(() => _batchFailureMessage = null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = _batchFailureMessage != null
        ? _buildBatchFailureView(context)
        : _results != null
            ? _buildResultsView(context)
            : _buildInputView(context);

    return PopScope(
      canPop: !_hasUnacknowledgedSuccess,
      onPopInvokedWithResult: (bool didPop, void _) {
        if (!didPop) _handlePopAttempt();
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Bulk Add Students — ${widget.section.name}')),
        body: body,
      ),
    );
  }
}
