/// Mirrors `public.content_source_type` (0002) — shared by `lessons`,
/// `question_bank`, and `quizzes`, all three of which pair this with a
/// `created_by`/pairing CHECK constraint (`built_in` => `created_by is
/// null`; `teacher` => `created_by is not null`). Defined once here rather
/// than duplicated per-model, since it's genuinely shared, not per-table.
enum ContentSourceType {
  builtIn,
  teacher;

  static ContentSourceType fromDb(String value) => switch (value) {
        'built_in' => ContentSourceType.builtIn,
        'teacher' => ContentSourceType.teacher,
        _ => throw ArgumentError('Unknown content_source_type value: $value'),
      };

  String toDb() => switch (this) {
        ContentSourceType.builtIn => 'built_in',
        ContentSourceType.teacher => 'teacher',
      };

  String get label => switch (this) {
        ContentSourceType.builtIn => 'Built-in',
        ContentSourceType.teacher => 'My Content',
      };
}
