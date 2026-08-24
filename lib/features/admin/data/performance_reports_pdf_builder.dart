import 'dart:typed_data' show Uint8List;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/models/admin_topic_mastery.dart';

/// Turns the Admin Performance Reports screen's currently filtered
/// [AdminTopicMasteryRow] list into a downloadable PDF, and produces the
/// matching default Save-As filename.
///
/// Mirrors `AdminQuizResultsCsvBuilder`'s (0051, Quiz Results) own shape —
/// pure/stateless (no Riverpod, no I/O; all actual file writing happens
/// one layer up, in `performance_reports_screen.dart`'s own
/// `_ExportReportButton`) — but produces PDF bytes via `Future<Uint8List>`
/// instead of a CSV `String`, since [pw.Document.save] is itself async.
///
/// CHART, NOT JUST A TABLE — per this phase's own requirement, the PDF
/// includes the same horizontal-bar "Overall Topic Mastery" visualization
/// the screen shows, not a plain data table. Built entirely out of the
/// `pdf` package's own `pw.*` widgets (a two-segment `pw.Row` of colored
/// `pw.Container`s per bar, proportioned by flex — see [_topicMasteryBar]'s
/// own doc comment) — deliberately NOT a screenshot/image-capture of the
/// on-screen `fl_chart` widget (e.g. via `RepaintBoundary`), for the exact
/// reason this phase's own task calls out: that approach is unreliable
/// across platforms and prone to capture-timing races. This also sidesteps
/// this codebase's own documented fl_chart limitation from
/// `performance_reports_screen.dart`'s `_TopicMasteryChart` doc comment
/// (no native horizontal-bar mode, worked around there with a
/// `RotatedBox` trick flagged for visual QA) — the `pdf` package's
/// `pw.Row`/`pw.Expanded` flex model draws a genuinely horizontal bar
/// directly, no rotation trick needed here at all.
class PerformanceReportsPdfBuilder {
  const PerformanceReportsPdfBuilder();

  /// Flex resolution for each bar's filled segment — mastery_percent is
  /// already rounded to one decimal place by `admin_competency_mastery`
  /// (0052), so scaling by 10 (`0.0`-`100.0` -> `0`-`1000`) before rounding
  /// to an int preserves that same one-decimal precision in the bar's
  /// drawn width instead of only ever landing on whole-percent widths.
  static const int _flexScale = 10;
  static const int _flexTotal = 100 * _flexScale;

  static const PdfColor _barColor = PdfColors.blue700;
  static const PdfColor _barTrackColor = PdfColors.grey300;
  static const PdfColor _mutedTextColor = PdfColors.grey700;
  static const PdfColor _fainterTextColor = PdfColors.grey600;

  /// Builds the full PDF document for [rows].
  ///
  /// [schoolName] — per this phase's own instruction to reuse whatever
  /// already supplies a school name elsewhere in the admin app rather than
  /// fetching it a new way: this codebase has no such value anywhere.
  /// There is no `school_name` column/table, repository, or provider
  /// anywhere in `lib/`, and no `school_years_screen.dart` file exists in
  /// this phase's own source tree to check either (only
  /// `school_years_repository.dart`/`school_year.dart`, which model
  /// ACADEMIC YEARS, not a school's own name — a different "school ___"
  /// concept entirely). The only school-identifying text that already
  /// exists anywhere in this admin app is the literal branding string
  /// `admin_dashboard_screen.dart` already displays verbatim
  /// (`'BayMath Administration System'`) — this parameter's caller
  /// ([performance_reports_screen.dart]'s `_ExportReportButton`) passes
  /// that same literal string rather than this builder inventing a new
  /// fetch, per this phase's own instruction, but this is flagged here
  /// directly since "reuse an existing provider" was not actually possible
  /// as instructed — there wasn't one to reuse.
  ///
  /// [gradeLabel]/[sectionLabel]/[schoolYearLabel]/[topicLabel] are the
  /// four filter dimensions' already-resolved display labels (`'All
  /// Grades'`, a grade's own `.label`, etc.) — same "caller resolves,
  /// builder just prints" division of responsibility
  /// `AdminQuizResultsCsvBuilder.buildFileName` already uses for its own
  /// four labels.
  ///
  /// [generatedAt] defaults to [DateTime.now] but is an explicit parameter
  /// so tests don't depend on wall-clock time — same reasoning
  /// `AdminQuizResultsCsvBuilder.buildFileName`'s own `date` parameter
  /// gives for itself.
  Future<Uint8List> build({
    required List<AdminTopicMasteryRow> rows,
    required String schoolName,
    required String gradeLabel,
    required String sectionLabel,
    required String schoolYearLabel,
    required String topicLabel,
    DateTime? generatedAt,
  }) async {
    final pw.Document doc = pw.Document();
    final DateTime timestamp = generatedAt ?? DateTime.now();

    // Ascending by masteryPercent (lowest mastery first) — matches the
    // on-screen chart's own documented sort order EXACTLY
    // (`performance_reports_screen.dart`'s `_TopicMasteryChart` doc
    // comment: an admin scanning a school-wide report is most likely
    // hunting for topics that need attention). Re-sorted here rather than
    // trusting the caller to have already sorted [rows] this way, so this
    // builder's own output can never drift out of sync with the on-screen
    // order even if a future caller passes rows in a different order.
    final List<AdminTopicMasteryRow> sorted = <AdminTopicMasteryRow>[...rows]
      ..sort((AdminTopicMasteryRow a, AdminTopicMasteryRow b) =>
          a.masteryPercent.compareTo(b.masteryPercent));

    doc.addPage(
      pw.MultiPage(
        // MultiPage (not a fixed pw.Page), per this phase's own
        // requirement — the topic list can be as long as the curriculum
        // (see AdminTopicMasteryRow's own doc comment), so `build` below
        // returns a flat widget list that MultiPage paginates across as
        // many pages as needed on its own, rather than this builder
        // clipping or shrinking rows to force everything onto one page.
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        // Page number only, repeated on every page — the report's own
        // title/school-name/filter-summary header is deliberately NOT a
        // MultiPage `header:` widget (which would repeat on every page);
        // it's the first few entries in `build`'s own list below instead,
        // so it prints once, at the top of page 1 only.
        footer: (pw.Context context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: _fainterTextColor),
          ),
        ),
        build: (pw.Context context) => <pw.Widget>[
          pw.Text(schoolName, style: const pw.TextStyle(fontSize: 12, color: _mutedTextColor)),
          pw.SizedBox(height: 4),
          pw.Text(
            'Performance Reports',
            style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Analyze mastery by topic',
            style: const pw.TextStyle(fontSize: 11, color: _mutedTextColor),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Grade Level: $gradeLabel   |   Section: $sectionLabel   |   '
            'Date Range: $schoolYearLabel   |   Topic: $topicLabel',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated: ${_formatTimestamp(timestamp)}',
            style: const pw.TextStyle(fontSize: 9, color: _fainterTextColor),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Overall Topic Mastery',
            style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          _axisScaleRow(),
          pw.SizedBox(height: 6),
          pw.Divider(color: _barTrackColor, thickness: 1),
          pw.SizedBox(height: 6),
          for (final AdminTopicMasteryRow row in sorted) _topicMasteryRow(row),
        ],
      ),
    );

    return doc.save();
  }

  /// The shared "0 / 25 / 50 / 75 / 100" scale header — same purpose
  /// `performance_reports_screen.dart`'s own `_TopicMasteryAxisScale`
  /// serves on-screen (a single shared axis label row above the list,
  /// rather than per-row chrome). Uses the exact same 3:5 flex split
  /// [_topicMasteryRow] gives its own label/bar columns below, so the "0"
  /// and "100" ticks line up with the actual left/right edges of every
  /// bar beneath them.
  pw.Widget _axisScaleRow() {
    return pw.Row(
      children: <pw.Widget>[
        pw.Expanded(flex: 3, child: pw.SizedBox()),
        pw.SizedBox(width: 8),
        pw.Expanded(
          flex: 5,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              for (final String tick in const <String>['0', '25', '50', '75', '100'])
                pw.Text(tick, style: const pw.TextStyle(fontSize: 8, color: _fainterTextColor)),
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        pw.SizedBox(width: 36),
      ],
    );
  }

  /// One topic's row: label (left, flex 3) / horizontal bar (middle, flex
  /// 5) / percentage (right, fixed width) — same left-to-right shape
  /// `performance_reports_screen.dart`'s own `_TopicMasteryBarRow` uses
  /// on-screen, topic label above the bar there vs. beside it here, purely
  /// because a printed page has much less usable width per row than a
  /// wide on-screen card, not a different design intent.
  ///
  /// `question_bank.topic` used verbatim, same rule #9 convention every
  /// other topic-mastery surface in this codebase follows (0035's
  /// `v_student_topic_mastery`, 0052's `admin_competency_mastery`, the
  /// on-screen chart) — no shortening, no ellipsis; `pw.Text` wraps
  /// naturally within its column exactly like `Text` does on-screen.
  pw.Widget _topicMasteryRow(AdminTopicMasteryRow row) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: <pw.Widget>[
          pw.Expanded(flex: 3, child: pw.Text(row.topic, style: const pw.TextStyle(fontSize: 9))),
          pw.SizedBox(width: 8),
          pw.Expanded(flex: 5, child: _topicMasteryBar(row.masteryPercent)),
          pw.SizedBox(width: 8),
          pw.SizedBox(
            width: 36,
            child: pw.Text(
              '${_formatPercent(row.masteryPercent)}%',
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  /// The bar itself: a fixed-height `pw.Row` of up to two flex-`pw.Expanded`
  /// `pw.Container`s — a filled (colored) segment sized to [masteryPercent]
  /// out of 100, and an unfilled (grey track) segment for the remainder.
  /// This is the standard proportional-bar technique in the `pdf` package
  /// (there is no direct percentage-width API the way CSS/Flutter's own
  /// `FractionallySizedBox` offers) — two `pw.Expanded`s whose `flex`
  /// values sum to a fixed total render as if their pixel widths were
  /// exactly proportional to those flex values.
  ///
  /// Either segment is OMITTED (not given `flex: 0`) at the 0%/100%
  /// extremes — `pw.Expanded` (mirroring Flutter's own `Expanded`) expects
  /// a positive flex, so a literal `flex: 0` risks an assertion failure at
  /// exactly the boundary values this data can legitimately produce (a
  /// topic every qualifying attempt got wrong, or every qualifying attempt
  /// got right).
  pw.Widget _topicMasteryBar(num masteryPercent) {
    final int filledFlex =
        (masteryPercent.clamp(0, 100).toDouble() * _flexScale).round().clamp(0, _flexTotal);
    final int emptyFlex = _flexTotal - filledFlex;

    final List<pw.Widget> segments = <pw.Widget>[
      if (filledFlex > 0)
        pw.Expanded(flex: filledFlex, child: pw.Container(color: _barColor)),
      if (emptyFlex > 0)
        pw.Expanded(flex: emptyFlex, child: pw.Container(color: _barTrackColor)),
    ];

    // No rounded-corner clipping here (unlike the on-screen bar's
    // `AppRadius.smallAll`) — deliberately kept to a plain rectangular
    // `pw.Container`/`pw.Row` rather than reaching for a `pdf`-package
    // clipping widget this builder can't verify the exact API of without
    // running the app; a square-cornered bar is a minor, low-risk visual
    // downgrade from the on-screen chart, not a functional one.
    return pw.Container(
      height: 10,
      child: pw.Row(children: segments),
    );
  }

  /// `'72.5'` / `'100'` — same whole-number-when-exact convention
  /// `formatPercent` (this app's shared on-screen formatter,
  /// `core/utils/formatters.dart`) uses, reimplemented here rather than
  /// imported since that formatter returns an already-`%`-suffixed
  /// `String` and this method needs the bare number so the `%` sign can be
  /// styled/positioned separately in [_topicMasteryRow] above.
  String _formatPercent(num value) {
    return value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  }

  /// `'YYYY-MM-DD HH:MM'`, 24-hour, matching this codebase's existing
  /// hand-rolled `'YYYY-MM-DD'` date formatting convention
  /// (`AdminQuizResultsCsvBuilder._dateCell`, the on-screen results
  /// table's own `_dateLabel`) rather than adding an `intl` dependency for
  /// one timestamp line.
  String _formatTimestamp(DateTime dt) {
    final String y = dt.year.toString().padLeft(4, '0');
    final String m = dt.month.toString().padLeft(2, '0');
    final String d = dt.day.toString().padLeft(2, '0');
    final String hh = dt.hour.toString().padLeft(2, '0');
    final String mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  /// Suggested Save-As filename:
  /// `PerformanceReport_<Grade>_<Section>_<DateRange>_<Topic>_<Date>.pdf`
  /// — same segment-per-filter-dimension shape and same
  /// always-include-every-segment-even-the-"All ___"-ones reasoning as
  /// `AdminQuizResultsCsvBuilder.buildFileName`'s own doc comment gives,
  /// just this screen's own four dimensions (Grade/Section/Date Range/
  /// Topic) instead of Quiz Results' four (Grade/Section/Assessment Type/
  /// School Year), and a `.pdf` extension instead of `.csv`.
  String buildFileName({
    required String gradeLabel,
    required String sectionLabel,
    required String schoolYearLabel,
    required String topicLabel,
    DateTime? date,
  }) {
    final DateTime resolvedDate = date ?? DateTime.now();
    final String isoDate =
        '${resolvedDate.year.toString().padLeft(4, '0')}-'
        '${resolvedDate.month.toString().padLeft(2, '0')}-'
        '${resolvedDate.day.toString().padLeft(2, '0')}';

    final String gradePart = _sanitize(gradeLabel);
    final String sectionPart = _sanitize(sectionLabel);
    final String yearPart = _sanitize(schoolYearLabel);
    final String topicPart = _sanitize(topicLabel);

    return 'PerformanceReport_${gradePart}_${sectionPart}_${yearPart}_${topicPart}_$isoDate.pdf';
  }

  /// Strips anything that isn't a letter/digit — same filesystem-safety
  /// reasoning and same collapse-to-nothing-in-between behavior as
  /// `AdminQuizResultsCsvBuilder._sanitize`'s own doc comment gives
  /// (this filename already uses `_` as its own segment separator, so a
  /// second separator character surviving inside a segment, e.g.
  /// `'Grade 4'` -> `'Grade-4'`, would misread as two segments once
  /// joined). A selected Topic can be a long lesson-title-style string
  /// (rule #9) — sanitized exactly the same way as every other label here,
  /// no special-casing for its length; a very long topic name simply makes
  /// for a long filename, same as it already does in the on-screen Topic
  /// dropdown.
  String _sanitize(String input) => input.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '');
}
