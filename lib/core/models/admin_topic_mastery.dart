/// A Dart-side mirror of one `public.admin_competency_mastery(...)` row
/// (0052) — school-wide average mastery for one distinct
/// `question_bank.topic` value, aggregated across every student whose
/// qualifying Internal Quiz attempts match the Admin Performance Reports
/// screen's current grade/section/school-year filters.
///
/// NAMING — deliberately NOT called `TopicMastery`: that name is already
/// taken by `student_statistics.dart`'s `TopicMastery`, the per-student
/// (`app.current_student_id()`-scoped) version of this same metric. The two
/// classes have identical field shapes (topic/questionsTotal/
/// questionsCorrect/masteryPercent) because they mirror the same underlying
/// SQL formula (`round(100.0 * correct / nullif(total, 0), 1)`), but they
/// are read from different RPCs, scoped to different populations (one
/// student vs. every admin-filter-matching student), and are never meant to
/// be used interchangeably — a separate, distinctly-named class avoids any
/// ambiguity if both are ever imported into the same file.
///
/// [topic] is `question_bank.topic`, used verbatim — per 0052's own DATA
/// CHECK note, this is NOT a short competency-bucket label (there is no
/// "Number Sense" / "Geometry" grouping layer, and none is planned). In
/// this database, `topic` holds the full owning lesson's title, e.g.
/// `"Comparing Numbers up to 1,000,000"` — so the set of distinct values
/// this feature deals with may be as large as the curriculum's lesson
/// count, not a short fixed list. Every "Competency" reference elsewhere in
/// this feature's original spec is named "Topic" here for exactly this
/// reason.
class AdminTopicMasteryRow {
  const AdminTopicMasteryRow({
    required this.topic,
    required this.questionsTotal,
    required this.questionsCorrect,
    required this.masteryPercent,
  });

  final String topic;
  final int questionsTotal;
  final int questionsCorrect;

  /// `round(100.0 * questionsCorrect / nullif(questionsTotal, 0), 1)` in
  /// `app.admin_competency_mastery` (0052) — never null in practice, since
  /// the underlying view only ever emits a row via `GROUP BY r.topic`, so
  /// `questionsTotal` (the `nullif` denominator) is always at least 1 for
  /// every row that exists. Kept as `num` (not `int`), same reasoning
  /// `TopicMastery.masteryPercent`'s own doc comment gives, since the RPC
  /// rounds to one decimal place.
  final num masteryPercent;

  factory AdminTopicMasteryRow.fromJson(Map<String, dynamic> json) {
    return AdminTopicMasteryRow(
      topic: json['topic'] as String,
      questionsTotal: json['questions_total'] as int,
      questionsCorrect: json['questions_correct'] as int,
      masteryPercent: json['mastery_percent'] as num,
    );
  }
}
