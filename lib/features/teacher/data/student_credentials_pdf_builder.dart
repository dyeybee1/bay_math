import 'dart:typed_data' show Uint8List;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One student's login slip worth of data — [StudentCredentialsPdfBuilder]'s
/// own small input shape, not a mirror of any `public.*` table row (a
/// student's plaintext password is never persisted anywhere; this only
/// ever exists transiently, for the lifetime of one export). Colocated
/// here rather than in `core/models/`, same "shape specific to one
/// builder" reasoning `StudentWithSection`/`BulkCreateStudentResult`
/// (`students_repository.dart`) already give for their own colocated
/// models.
class StudentCredential {
  const StudentCredential({
    required this.fullName,
    required this.username,
    required this.password,
  });

  final String fullName;
  final String username;
  final String password;
}

/// Turns a section's resolved [StudentCredential] list into a downloadable,
/// cut-able PDF of one card per student, and produces the matching default
/// Save-As filename.
///
/// Same shape as `PerformanceReportsPdfBuilder` (0052) — pure/stateless (no
/// Riverpod, no I/O; all actual file writing happens one layer up, in
/// `section_workspace_screen.dart`'s own export button) — `Future<Uint8List>`
/// via [pw.Document.save] plus a separate `buildFileName` for the Save-As
/// dialog's default name.
///
/// LAYOUT — a 2-column grid of bordered cards (a "cut-and-hand-out slip"
/// sheet), NOT a table: see [_row]/[_card]'s own doc comments for the grid
/// math this class's chosen card size is built from.
///
/// CUT LINES — a plain solid `pw.Border.all(...)` around every [_card],
/// per this task's own explicit instruction: this `pdf` package version's
/// dashed-border/dashed-line API was not independently verified here (no
/// running app, no way to confirm the exact widget name/behavior without
/// risking a compile error on a guessed API), so a solid border is used as
/// the safe, guaranteed-to-render substitute for a "cut here" line. If a
/// verified dashed-border widget is available in this project's actual
/// installed `pdf` version, swapping the `pw.Border.all(...)` call inside
/// [_card] for it is a drop-in change — nothing else in this file assumes
/// a solid border specifically.
class StudentCredentialsPdfBuilder {
  const StudentCredentialsPdfBuilder();

  static const PdfColor _cardBorderColor = PdfColors.grey400;
  static const PdfColor _mutedTextColor = PdfColors.grey700;
  static const PdfColor _fainterTextColor = PdfColors.grey600;

  static const double _pageMargin = 32;

  // --- Grid math -----------------------------------------------------
  //
  // Every number below is derived from PdfPageFormat.a4's own real point
  // dimensions (595.28 x 841.89pt — 210mm/297mm at 72pt/in), NOT guessed:
  //
  //   contentWidth  = 595.28 - 2*32 (margins)            = 531.28pt
  //   contentHeight = 841.89 - 2*32 (margins)             = 777.89pt
  //
  //   2 columns, one _columnGap between them:
  //     _cardWidth = (531.28 - _columnGap) / 2
  //                = (531.28 - 14) / 2                    ≈ 258.6pt
  //
  //   _cardHeight (118) was sized from the actual content this card must
  //   hold — section label (8pt) + full name (16pt bold) + username line
  //   (13pt) + password line (13pt) + branding line (7pt), their line
  //   heights, the spacing between them, and _cardPadding (12) top+bottom
  //   — totalling ~116pt, rounded up to 118pt so the border never
  //   clips descenders.
  //
  //   Row pitch (card + the gap below it) = 118 + 10 (_rowGap) = 128pt.
  //
  //   Rows per page WITHOUT the page-1 title block:
  //     777.89 / 128 = 6.07  ->  6 rows/page (12 cards/page), using
  //     6*128 = 768pt of the available 777.89pt.
  //
  //   Page 1 additionally carries the one-time title block (title line +
  //   generated-at line + spacing ≈ 60pt), so its own usable height is
  //   777.89 - 60 = 717.89pt:
  //     717.89 / 128 = 5.61  ->  5 rows on page 1 (10 cards), 6 rows
  //     (12 cards) on every page after it.
  //
  // These row counts are the DESIGN TARGET this card size was chosen for,
  // not a hard cap this builder enforces itself — pw.MultiPage measures
  // each row's actual rendered height and breaks pages accordingly, so
  // real output should land on/very near these counts without this
  // builder ever needing to slice [credentials] into per-page chunks by
  // hand.
  static const double _columnGap = 14;
  static const double _rowGap = 10;
  static const double _cardHeight = 118;
  static const double _cardPadding = 12;

  /// Builds the full PDF document for [credentials].
  ///
  /// [sectionLabel] is the section's already-resolved display label (e.g.
  /// `'Grade 4 — B'`) — same "caller resolves, builder just prints"
  /// division of responsibility `PerformanceReportsPdfBuilder.build`'s own
  /// label parameters already use.
  ///
  /// [generatedAt] defaults to [DateTime.now] but is an explicit parameter
  /// so tests don't depend on wall-clock time — same reasoning
  /// `PerformanceReportsPdfBuilder.build`'s own `generatedAt` parameter
  /// gives for itself.
  ///
  /// Ordering: [credentials] is rendered in the order given — this
  /// builder does not re-sort. (The export button passes the section's
  /// enrolled-students list order; there is no "most in need of a fresh
  /// slip first" concept here the way Performance Reports' own
  /// lowest-mastery-first sort has one.)
  Future<Uint8List> build({
    required List<StudentCredential> credentials,
    required String sectionLabel,
    DateTime? generatedAt,
  }) async {
    final pw.Document doc = pw.Document();
    final DateTime timestamp = generatedAt ?? DateTime.now();

    // Pair up credentials two-at-a-time into row widgets. Each row is one
    // flat item in MultiPage's own `build` list below — exactly like
    // PerformanceReportsPdfBuilder's own per-topic rows — so MultiPage's
    // pagination engine breaks between ROWS (never splitting a single
    // card's own two-column pair across a page boundary), landing on the
    // ~5/~6-rows-per-page target the grid math above was designed for.
    final List<pw.Widget> rows = <pw.Widget>[];
    for (int i = 0; i < credentials.length; i += 2) {
      final StudentCredential left = credentials[i];
      final StudentCredential? right = i + 1 < credentials.length ? credentials[i + 1] : null;
      rows.add(_row(sectionLabel, left, right));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(_pageMargin),
        // Page number only, repeated on every page — same "title prints
        // once, as the first few build() list items, not a MultiPage
        // `header:`" split PerformanceReportsPdfBuilder already uses.
        footer: (pw.Context context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: _fainterTextColor),
          ),
        ),
        build: (pw.Context context) => <pw.Widget>[
          pw.Text(
            'Student Login Credentials — $sectionLabel',
            style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated: ${_formatTimestamp(timestamp)}',
            style: const pw.TextStyle(fontSize: 9, color: _fainterTextColor),
          ),
          pw.SizedBox(height: 20),
          ...rows,
        ],
      ),
    );

    return doc.save();
  }

  /// One grid row: two side-by-side cards ([left]/[right]), separated by
  /// [_columnGap]. [right] is null for a trailing odd student — rendered
  /// as an empty [pw.Expanded] spacer rather than stretching [left] to
  /// full width, so every card in the sheet stays the same cut size.
  pw.Widget _row(String sectionLabel, StudentCredential left, StudentCredential? right) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: _rowGap),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(child: _card(sectionLabel, left)),
          pw.SizedBox(width: _columnGap),
          pw.Expanded(child: right == null ? pw.SizedBox() : _card(sectionLabel, right)),
        ],
      ),
    );
  }

  /// One cut-able card: section label (small, top) / full name (bold,
  /// prominent) / "Username: …" / "Password: …" (both large enough to
  /// read at arm's length) / a small "BayMath" branding line at the
  /// bottom. Bordered on all four sides with a plain solid line — see
  /// this class's own doc comment on why a solid border, not a dashed
  /// one, is used as the cut line here.
  pw.Widget _card(String sectionLabel, StudentCredential credential) {
    return pw.Container(
      height: _cardHeight,
      padding: const pw.EdgeInsets.all(_cardPadding),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _cardBorderColor, width: 0.75),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(sectionLabel, style: const pw.TextStyle(fontSize: 8, color: _mutedTextColor)),
          pw.Text(
            credential.fullName,
            style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Username: ${credential.username}', style: const pw.TextStyle(fontSize: 13)),
          pw.Text('Password: ${credential.password}', style: const pw.TextStyle(fontSize: 13)),
          pw.Text('BayMath', style: const pw.TextStyle(fontSize: 7, color: _fainterTextColor)),
        ],
      ),
    );
  }

  /// `'YYYY-MM-DD HH:MM'`, 24-hour — same hand-rolled convention
  /// `PerformanceReportsPdfBuilder._formatTimestamp` already uses, reused
  /// here verbatim rather than shared, since that method is private to its
  /// own file.
  String _formatTimestamp(DateTime dt) {
    final String y = dt.year.toString().padLeft(4, '0');
    final String m = dt.month.toString().padLeft(2, '0');
    final String d = dt.day.toString().padLeft(2, '0');
    final String hh = dt.hour.toString().padLeft(2, '0');
    final String mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  /// Suggested Save-As filename:
  /// `StudentCredentials_<SectionLabel>_<Date>.pdf` — e.g.
  /// `StudentCredentials_Grade4B_2026-08-20.pdf`. Same
  /// sanitize-to-alphanumeric convention as
  /// `PerformanceReportsPdfBuilder._sanitize`/`buildFileName`.
  String buildFileName({
    required String sectionLabel,
    DateTime? date,
  }) {
    final DateTime resolvedDate = date ?? DateTime.now();
    final String isoDate =
        '${resolvedDate.year.toString().padLeft(4, '0')}-'
        '${resolvedDate.month.toString().padLeft(2, '0')}-'
        '${resolvedDate.day.toString().padLeft(2, '0')}';

    final String sectionPart = _sanitize(sectionLabel);

    return 'StudentCredentials_${sectionPart}_$isoDate.pdf';
  }

  /// Strips anything that isn't a letter/digit — same filesystem-safety
  /// reasoning as `PerformanceReportsPdfBuilder._sanitize`'s own doc
  /// comment gives (this filename already uses `_` as its own segment
  /// separator, so a second separator character surviving inside a
  /// segment would misread as two segments once joined).
  String _sanitize(String input) => input.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '');
}
