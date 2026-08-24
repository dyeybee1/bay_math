import 'package:csv/csv.dart';

import '../../../core/models/quiz.dart';
import '../../../core/models/quiz_result_row.dart';
import '../../../core/models/student.dart';
import 'teacher_quiz_results_providers.dart' show QuizResultsMatrix;

/// UTF-8 byte-order-mark prefix so Excel (and other spreadsheet readers
/// that sniff encoding from the first bytes rather than assuming UTF-8)
/// opens the exported file with special characters intact instead of
/// mis-decoding them as Latin-1/CP1252.
const String _utf8Bom = '\uFEFF';

/// Turns an assembled [QuizResultsMatrix] into CSV text, and produces the
/// matching default Save-As filename. Pure/stateless by design (no
/// Riverpod, no I/O) so it can be unit-tested against a hand-built
/// [QuizResultsMatrix] without touching Supabase or the filesystem — all
/// actual file writing happens one layer up, in `quiz_results_screen.dart`.
class QuizResultsCsvBuilder {
  const QuizResultsCsvBuilder();

  /// Builds the full CSV document for [matrix]:
  /// - Row 1: `Student`, then one column per [QuizResultsMatrix.quizzes]
  ///   title (in matrix order).
  /// - Row 2: `Total Items`, then each quiz's
  ///   [QuizResultsMatrix.totalQuestionsByQuizId] (blank if unknown).
  /// - One row per [QuizResultsMatrix.students] (already in
  ///   `Student.fullName` order): full name, then each quiz's raw score,
  ///   blank if the student has no completed result for that quiz.
  ///
  /// Every field goes through `csv`'s [ListToCsvConverter] rather than
  /// hand-built string interpolation, so a comma/quote/newline in a
  /// student's name or a quiz title can never corrupt the file's column
  /// structure. The returned string is prefixed with a UTF-8 BOM
  /// (`\uFEFF`) — encode it with `utf8.encode(...)` when writing to disk,
  /// not `ascii.encode`, so the BOM survives as its correct 3-byte UTF-8
  /// form.
  String build(QuizResultsMatrix matrix) {
    final List<List<Object?>> rows = <List<Object?>>[
      <Object?>['Student', for (final Quiz quiz in matrix.quizzes) quiz.title],
      <Object?>[
        'Total Items',
        for (final Quiz quiz in matrix.quizzes)
          matrix.totalQuestionsByQuizId[quiz.id]?.toString() ?? '',
      ],
      for (final Student student in matrix.students)
        <Object?>[
          student.fullName,
          for (final Quiz quiz in matrix.quizzes)
            _scoreCell(matrix.cellsByStudentThenQuiz[student.id]?[quiz.id]),
        ],
    ];

    final String body = const ListToCsvConverter(eol: '\r\n').convert(rows);
    return '$_utf8Bom$body';
  }

  /// The blank-if-missing raw score for one matrix cell. Deliberately a
  /// plain empty string — not the on-screen '—' placeholder. An em dash
  /// in an exported data file is just noise for anyone opening it in a
  /// spreadsheet or importing it elsewhere; '—' is a display affordance
  /// for the grid, not part of the data.
  String _scoreCell(QuizResultRow? cell) {
    final num? score = cell?.score;
    if (score == null) return '';
    return score == score.roundToDouble() ? score.toInt().toString() : score.toString();
  }

  /// Suggested Save-As filename: `<Grade>-<Section>_<AssessmentType>_<Date>.csv`
  /// (e.g. `4-A_RegularQuiz_2026-08-11.csv`).
  ///
  /// [gradeLevelLabel] is the section's display grade label (e.g.
  /// `Section.gradeLevel.label`, which reads `"Grade 4"`) — only the
  /// leading digits are kept. [sectionName] is the plain `Section.name`
  /// (e.g. `"A"`). [assessmentTypeLabel] is
  /// `QuizResultsAssessmentFilter.label` (e.g. `"Regular Quiz"`), with
  /// all non-alphanumeric characters stripped rather than collapsed to
  /// `-`, so `"Regular Quiz"` becomes `"RegularQuiz"` and `"Pre-Test"`
  /// becomes `"PreTest"` — this class takes plain strings rather than
  /// `Section`/`QuizResultsAssessmentFilter` directly so it has no
  /// dependency on those types beyond what's needed to build a filename.
  /// [date] defaults to [DateTime.now] but is an explicit parameter so
  /// tests don't depend on wall-clock time.
  String buildFileName({
    required String gradeLevelLabel,
    required String sectionName,
    required String assessmentTypeLabel,
    DateTime? date,
  }) {
    final DateTime resolvedDate = date ?? DateTime.now();
    final String isoDate =
        '${resolvedDate.year.toString().padLeft(4, '0')}-'
        '${resolvedDate.month.toString().padLeft(2, '0')}-'
        '${resolvedDate.day.toString().padLeft(2, '0')}';

    final String gradeNumber =
        RegExp(r'\d+').firstMatch(gradeLevelLabel)?.group(0) ?? _sanitize(gradeLevelLabel);
    final String sectionPart = _sanitize(sectionName);
    final String typePart = assessmentTypeLabel.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');

    return '$gradeNumber-${sectionPart}_${typePart}_$isoDate.csv';
  }

  /// Collapses anything that isn't a letter/digit into a single `-`, and
  /// trims leading/trailing `-` — filenames must stay filesystem-safe
  /// across Windows/macOS/Linux without the caller having to think about
  /// it (section names and labels may contain spaces, em dashes, etc.).
  String _sanitize(String input) =>
      input.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}
