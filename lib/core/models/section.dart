/// Mirrors `public.sections.grade_level`.
///
/// The database enum uses snake_case values (`grade_4`, `grade_5`,
/// `grade_6`). Dart's lint rules (`constant_identifier_names`) expect
/// lowerCamelCase enum members, so this is a deliberate, explicit mapping
/// rather than `.byName`/`.name` round-tripping — the db string and the
/// Dart identifier are intentionally spelled differently.
enum GradeLevel {
  grade4,
  grade5,
  grade6;

  static GradeLevel fromDb(String value) => switch (value) {
        'grade_4' => GradeLevel.grade4,
        'grade_5' => GradeLevel.grade5,
        'grade_6' => GradeLevel.grade6,
        _ => throw ArgumentError('Unknown grade_level value: $value'),
      };

  String toDb() => switch (this) {
        GradeLevel.grade4 => 'grade_4',
        GradeLevel.grade5 => 'grade_5',
        GradeLevel.grade6 => 'grade_6',
      };

  /// Short, user-facing label (e.g. for section list headers/pickers).
  String get label => switch (this) {
        GradeLevel.grade4 => 'Grade 4',
        GradeLevel.grade5 => 'Grade 5',
        GradeLevel.grade6 => 'Grade 6',
      };
}

/// Mirrors `public.sections.status`.
enum SectionStatus {
  active,
  archived;

  static SectionStatus fromDb(String value) => SectionStatus.values.byName(value);
}

/// A Dart-side mirror of one `public.sections` row — a class/grade grouping
/// within a school year, the unit the section-centric architecture
/// revolves around.
class Section {
  const Section({
    required this.id,
    required this.schoolYearId,
    required this.gradeLevel,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String schoolYearId;
  final GradeLevel gradeLevel;
  final String name;
  final SectionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      id: json['id'] as String,
      schoolYearId: json['school_year_id'] as String,
      gradeLevel: GradeLevel.fromDb(json['grade_level'] as String),
      name: json['name'] as String,
      status: SectionStatus.fromDb(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
