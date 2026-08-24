import 'package:csv/csv.dart';

import '../../../core/models/teacher_dashboard.dart';
import 'progress_report_providers.dart' show masteryBandFor;

/// UTF-8 byte-order-mark prefix — identical rationale to
/// `quiz_results_csv_builder.dart`'s own `_utf8Bom`: makes Excel (and
/// other encoding-sniffing spreadsheet readers) open the exported file as
/// UTF-8 instead of mis-decoding it as Latin-1/CP1252.
const String _utf8Bom = '\uFEFF';

/// Turns the two Teacher Progress Reports data sources
/// ([TopicMasteryEntry] from the existing
/// `dashboardCompetencyMasteryProvider`, and [StudentTopicMasteryEntry]
/// from this feature's own `dashboardStudentTopicMasteryProvider`) into
/// one CSV document, and produces the matching default Save-As filename.
/// Pure/stateless by design, mirroring `QuizResultsCsvBuilder` exactly (no
/// Riverpod, no I/O) — unit-testable against hand-built lists without
/// touching Supabase or the filesystem; actual file writing happens one
/// layer up, in Part 3's screen.
class ProgressReportCsvBuilder {
  const ProgressReportCsvBuilder();

  /// Builds the full CSV document as two sections separated by one blank
  /// row, per the locked export spec:
  ///
  /// 1. Competency Mastery summary — header `Topic, Mastery %, Band,
  ///    Questions Correct, Questions Total`, one row per [competencyMastery]
  ///    entry, in the order given (the source RPC, 0037 Function 4,
  ///    already returns these `ORDER BY topic`, so this method does not
  ///    re-sort).
  /// 2. A single blank row.
  /// 3. The per-student x per-topic heatmap matrix — header `Student,
  ///    Section`, then one column per distinct topic found in
  ///    [studentTopicMastery] (alphabetically sorted — "stable sorted
  ///    order" per spec; alphabetical was chosen over "first-seen order"
  ///    because it is deterministic independent of the source RPC's row
  ///    order, so the same topic always lands in the same column across
  ///    exports even if the underlying data changes between runs). One
  ///    row per distinct student (students are de-duplicated by
  ///    `studentId`, keeping first-encounter order — the 0046 RPC already
  ///    returns rows `ORDER BY full_name, topic`, so first-encounter order
  ///    is full-name order without this method needing to re-sort); each
  ///    cell is that student's `masteryPercent` for that column's topic,
  ///    left blank when [studentTopicMastery] has no row for that exact
  ///    (student, topic) pair (per spec — a missing row means "no
  ///    answered questions for that topic", which is not the same as a
  ///    0% score and must not be rendered as one).
  ///
  /// Every field goes through `csv`'s [ListToCsvConverter], same as
  /// `QuizResultsCsvBuilder.build`, so a comma/quote/newline in a topic
  /// name or student name can never corrupt the file's column structure.
  /// The returned string is prefixed with a UTF-8 BOM (`\uFEFF`) — encode
  /// with `utf8.encode(...)` when writing to disk, not `ascii.encode`, so
  /// the BOM survives as its correct 3-byte UTF-8 form.
  String build({
    required List<TopicMasteryEntry> competencyMastery,
    required List<StudentTopicMasteryEntry> studentTopicMastery,
  }) {
    final List<List<Object?>> rows = <List<Object?>>[
      ..._competencyMasterySection(competencyMastery),
      <Object?>[],
      ..._heatmapSection(studentTopicMastery),
    ];

    final String body = const ListToCsvConverter(eol: '\r\n').convert(rows);
    return '$_utf8Bom$body';
  }

  List<List<Object?>> _competencyMasterySection(List<TopicMasteryEntry> entries) {
    return <List<Object?>>[
      <Object?>['Topic', 'Mastery %', 'Band', 'Questions Correct', 'Questions Total'],
      for (final TopicMasteryEntry entry in entries)
        <Object?>[
          entry.topic,
          _percentCell(entry.masteryPercent),
          masteryBandFor(entry.masteryPercent)?.displayLabel ?? '',
          entry.questionsCorrect,
          entry.questionsTotal,
        ],
    ];
  }

  List<List<Object?>> _heatmapSection(List<StudentTopicMasteryEntry> entries) {
    final List<String> topics = entries.map((entry) => entry.topic).toSet().toList()..sort();

    // De-duplicated student list, first-encounter order (see [build]'s
    // doc comment for why that equals full-name order here without an
    // explicit re-sort).
    final List<StudentTopicMasteryEntry> studentsInOrder = <StudentTopicMasteryEntry>[];
    final Set<String> seenStudentIds = <String>{};
    for (final StudentTopicMasteryEntry entry in entries) {
      if (seenStudentIds.add(entry.studentId)) {
        studentsInOrder.add(entry);
      }
    }

    // studentId -> topic -> masteryPercent, for O(1) cell lookup below
    // instead of re-scanning `entries` per cell.
    final Map<String, Map<String, num>> masteryByStudentThenTopic = <String, Map<String, num>>{};
    for (final StudentTopicMasteryEntry entry in entries) {
      (masteryByStudentThenTopic[entry.studentId] ??= <String, num>{})[entry.topic] =
          entry.masteryPercent;
    }

    return <List<Object?>>[
      <Object?>['Student', 'Section', for (final String topic in topics) topic],
      for (final StudentTopicMasteryEntry student in studentsInOrder)
        <Object?>[
          student.fullName,
          student.sectionName,
          for (final String topic in topics)
            _percentCell(masteryByStudentThenTopic[student.studentId]?[topic]),
        ],
    ];
  }

  /// Blank-if-missing mastery percent cell, whole-number-if-round —
  /// mirrors `QuizResultsCsvBuilder._scoreCell`'s exact formatting
  /// rule (`85` not `85.0`, but `84.5` kept as-is), for the same reason:
  /// this is exported data, not a display string, so there is no '%'
  /// suffix or '—' placeholder here either.
  String _percentCell(num? percent) {
    if (percent == null) return '';
    return percent == percent.roundToDouble()
        ? percent.toInt().toString()
        : percent.toString();
  }

  /// Suggested Save-As filename: `<Grade>-<Section>_ProgressReport_<Date>.csv`
  /// (e.g. `4-A_ProgressReport_2026-08-11.csv`), following
  /// `QuizResultsCsvBuilder.buildFileName`'s exact naming convention and
  /// sanitization rules.
  ///
  /// Unlike the quiz-results export, a Progress Report is frequently
  /// unfiltered (Part 3's grade/section filters both default to "All"),
  /// so [gradeLevelLabel] and [sectionName] are nullable here — `null`
  /// renders as the literal `AllGrades` / `AllSections` segment rather
  /// than an empty filename segment, so the file is still identifiable
  /// at a glance when exported with no filter applied. When provided,
  /// [gradeLevelLabel] is handled the same way as
  /// `QuizResultsCsvBuilder.buildFileName` (e.g. `Section.gradeLevel.label`
  /// reading `"Grade 4"` — only the leading digits are kept) and
  /// [sectionName] is the plain `Section.name` (e.g. `"A"`). [date]
  /// defaults to [DateTime.now] but is an explicit parameter so tests
  /// don't depend on wall-clock time.
  String buildFileName({
    String? gradeLevelLabel,
    String? sectionName,
    DateTime? date,
  }) {
    final DateTime resolvedDate = date ?? DateTime.now();
    final String isoDate =
        '${resolvedDate.year.toString().padLeft(4, '0')}-'
        '${resolvedDate.month.toString().padLeft(2, '0')}-'
        '${resolvedDate.day.toString().padLeft(2, '0')}';

    final String gradePart = gradeLevelLabel == null
        ? 'AllGrades'
        : (RegExp(r'\d+').firstMatch(gradeLevelLabel)?.group(0) ?? _sanitize(gradeLevelLabel));
    final String sectionPart = sectionName == null ? 'AllSections' : _sanitize(sectionName);

    return '$gradePart-${sectionPart}_ProgressReport_$isoDate.csv';
  }

  /// Collapses anything that isn't a letter/digit into a single `-`, and
  /// trims leading/trailing `-` — identical to
  /// `QuizResultsCsvBuilder._sanitize`, kept as its own private copy here
  /// rather than shared, since that method is private to its own file and
  /// this class is not allowed to modify that file.
  String _sanitize(String input) =>
      input.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}
