import 'package:csv/csv.dart';

import '../../../core/models/admin_quiz_result_row.dart';

/// UTF-8 byte-order-mark prefix so Excel (and other spreadsheet readers
/// that sniff encoding from the first bytes rather than assuming UTF-8)
/// opens the exported file with special characters intact instead of
/// mis-decoding them as Latin-1/CP1252. Same constant, same reasoning, as
/// `teacher/data/quiz_results_csv_builder.dart`'s own `_utf8Bom`.
const String _utf8Bom = '\uFEFF';

/// Turns the Admin Quiz Results screen's currently filtered
/// [AdminQuizResultRow] list into CSV text, and produces the matching
/// default Save-As filename.
///
/// Deliberately NOT a port of `QuizResultsCsvBuilder`'s (teacher, 0045)
/// row/column shape — that builder pivots a single section's roster
/// against a set of quizzes into a matrix. This screen has no such
/// natural pivot (it's school-wide, many grades/sections/quizzes at
/// once), so the export is instead a flat table: one row per
/// [AdminQuizResultRow], exactly the "flat rows, one row per result"
/// shape the product spec calls for. Pure/stateless by design (no
/// Riverpod, no I/O) for the same testability reason the teacher builder
/// gives for itself — all actual file writing happens one layer up, in
/// `quiz_results_screen.dart`.
class AdminQuizResultsCsvBuilder {
  const AdminQuizResultsCsvBuilder();

  static const List<String> _headers = <String>[
    'Student Name',
    'Grade',
    'Section',
    'Assessment Name',
    'Score',
    'Percentage',
    'Date Taken',
    'Status',
  ];

  /// Builds the full CSV document for [rows].
  ///
  /// Column order is the on-screen table's own six columns (Student Name,
  /// Assessment Name, Score, Percentage, Date Taken, Status), with Grade
  /// and Section inserted right after Student Name. Grade/Section are
  /// filterable dimensions that aren't columns in the on-screen table
  /// (the mockup omits them there since the Filters card above already
  /// shows the active selection), but an admin who exports while viewing
  /// "All Grades" / "All Sections" needs that context preserved per-row
  /// in the file itself — nothing else on a flat export identifies which
  /// grade/section a given row came from.
  ///
  /// No `quiz_attempt_id` column: that field exists on
  /// [AdminQuizResultRow] purely as a stable UI row key / future
  /// drill-down handle (see the row model's own doc comment and 0051's
  /// "Row key" spec entry), not a display value — same reasoning
  /// `QuizResultRow`'s internal ids never appear in the teacher CSV
  /// either.
  ///
  /// Every field goes through `csv`'s [ListToCsvConverter] rather than
  /// hand-built string interpolation, so a comma/quote/newline in a
  /// student's name or an assessment title can never corrupt the file's
  /// column structure. The returned string is prefixed with a UTF-8 BOM
  /// (`\uFEFF`) — encode it with `utf8.encode(...)` when writing to disk,
  /// not `ascii.encode`, so the BOM survives as its correct 3-byte UTF-8
  /// form.
  String build(List<AdminQuizResultRow> rows) {
    final List<List<Object?>> csvRows = <List<Object?>>[
      _headers,
      for (final AdminQuizResultRow row in rows)
        <Object?>[
          row.studentName,
          row.gradeLevel.label,
          row.sectionName,
          row.assessmentName,
          _scoreCell(row),
          _percentageCell(row),
          _dateCell(row.dateTaken),
          row.status?.label ?? '',
        ],
    ];

    final String body = const ListToCsvConverter(eol: '\r\n').convert(csvRows);
    return '$_utf8Bom$body';
  }

  /// `'18/25'` style, matching the on-screen table's own `_scoreLabel`.
  /// Deliberately a plain empty string when either half is missing — not
  /// the on-screen '—' placeholder, same reasoning
  /// `QuizResultsCsvBuilder._scoreCell`'s own doc comment gives: an em
  /// dash in an exported data file is just noise, not part of the data.
  ///
  /// Leading `'` (apostrophe) is deliberate, NOT a typo or stray
  /// character — CSV carries no per-cell type metadata, so Excel guesses
  /// each cell's type from its text alone, and a bare `N/M` string (e.g.
  /// `10/9`, `1/0`) matches Excel's own day/month date pattern and gets
  /// silently reinterpreted as a date (`10/9` → `10-Sep`, `1/0` →
  /// `Jan-00`) the moment the file is opened. A leading apostrophe is
  /// Excel's own long-standing "force this cell to plain text" marker for
  /// exactly this situation (inherited from Lotus-1-2-3-era
  /// compatibility) — Excel hides the apostrophe itself and displays only
  /// `10/9`, while a plain text editor or another CSV parser sees the
  /// literal `'10/9` and must strip it. `_percentageCell` doesn't need
  /// this: a bare number like `72.5` never matches a date pattern.
  String _scoreCell(AdminQuizResultRow row) {
    final num? score = row.score;
    final int? total = row.totalQuestions;
    if (score == null || total == null) return '';
    final String scoreText =
        score == score.roundToDouble() ? score.toInt().toString() : score.toString();
    return "'$scoreText/$total";
  }

  /// The raw percentage number (e.g. `72.5`), not the on-screen table's
  /// `formatPercent` string (`'72.5%'`) — a `%`-suffixed string is just
  /// text to a spreadsheet, while a bare number stays usable for sorting/
  /// formulas once opened in Excel. Blank, not '—', when
  /// [AdminQuizResultRow.percentage] is null, same blank-over-dash
  /// reasoning as [_scoreCell].
  String _percentageCell(AdminQuizResultRow row) {
    final double? percentage = row.percentage;
    if (percentage == null) return '';
    return percentage == percentage.roundToDouble()
        ? percentage.toInt().toString()
        : percentage.toString();
  }

  /// `'YYYY-MM-DD'`, matching the on-screen table's own `_dateLabel`. No
  /// `intl` dependency in this project's `pubspec.yaml`, so formatted by
  /// hand rather than adding one for a single date column — same
  /// reasoning the on-screen table gives for itself.
  String _dateCell(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Suggested Save-As filename:
  /// `QuizResults_<Grade>_<Section>_<AssessmentType>_<SchoolYear>_<Date>.csv`
  /// (e.g. `QuizResults_Grade4_SectionA_RegularQuiz_2025-2026_2026-08-16.csv`,
  /// or `QuizResults_AllGrades_AllSections_AllTypes_AllTime_2026-08-16.csv`
  /// for the unfiltered default).
  ///
  /// Unlike `QuizResultsCsvBuilder.buildFileName` (0045, exactly two
  /// dimensions — a section is always chosen there before export is even
  /// enabled), this screen's export can be filtered along four
  /// independent dimensions, any of which may be at its own "All ___"
  /// default. So this takes the four already-resolved display labels
  /// directly (whatever the filter dropdowns are currently showing —
  /// `'All Grades'`, `'Grade 4'`, `'All Sections'`, a section's own name,
  /// etc.) rather than looking anything up itself, and always includes
  /// all four segments (never dropping the "All ___" ones) so the
  /// filename's shape stays predictable regardless of which filters are
  /// active. [date] defaults to [DateTime.now] but is an explicit
  /// parameter so tests don't depend on wall-clock time.
  String buildFileName({
    required String gradeLabel,
    required String sectionLabel,
    required String assessmentTypeLabel,
    required String schoolYearLabel,
    DateTime? date,
  }) {
    final DateTime resolvedDate = date ?? DateTime.now();
    final String isoDate =
        '${resolvedDate.year.toString().padLeft(4, '0')}-'
        '${resolvedDate.month.toString().padLeft(2, '0')}-'
        '${resolvedDate.day.toString().padLeft(2, '0')}';

    final String gradePart = _sanitize(gradeLabel);
    final String sectionPart = _sanitize(sectionLabel);
    final String typePart = _sanitize(assessmentTypeLabel);
    final String yearPart = _sanitize(schoolYearLabel);

    return 'QuizResults_${gradePart}_${sectionPart}_${typePart}_${yearPart}_$isoDate.csv';
  }

  /// Strips anything that isn't a letter/digit — filenames must stay
  /// filesystem-safe across Windows/macOS/Linux without the caller having
  /// to think about it (labels like `'Grade 4'`, `'Pre-Test'`, `'2025-
  /// 2026'` all contain spaces/hyphens). Collapses to nothing-in-between
  /// rather than `QuizResultsCsvBuilder._sanitize`'s single-`-` collapse,
  /// since this filename already uses `_` as its own segment separator —
  /// keeping a second separator character out of each segment avoids a
  /// filename like `Grade-4` reading as two segments once it sits next to
  /// the `_` joins.
  String _sanitize(String input) => input.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '');
}
