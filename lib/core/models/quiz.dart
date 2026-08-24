import 'content_source_type.dart';
import 'section.dart';

/// Mirrors `public.quiz_type` (0002).
enum QuizType {
  internal,
  externalActivity;

  static QuizType fromDb(String value) => switch (value) {
        'internal' => QuizType.internal,
        'external_activity' => QuizType.externalActivity,
        _ => throw ArgumentError('Unknown quiz_type value: $value'),
      };

  String toDb() => switch (this) {
        QuizType.internal => 'internal',
        QuizType.externalActivity => 'external_activity',
      };

  String get label => switch (this) {
        QuizType.internal => 'Internal Quiz',
        QuizType.externalActivity => 'External Activity',
      };
}

/// Mirrors `public.external_platform_hint` (0002) — display icon hint
/// only, never validated against the actual URL (0009 comment).
enum ExternalPlatformHint {
  googleForms,
  microsoftForms,
  youtube,
  khanAcademy,
  geogebra,
  desmos,
  pdf,
  other;

  static ExternalPlatformHint fromDb(String value) => switch (value) {
        'google_forms' => ExternalPlatformHint.googleForms,
        'microsoft_forms' => ExternalPlatformHint.microsoftForms,
        'youtube' => ExternalPlatformHint.youtube,
        'khan_academy' => ExternalPlatformHint.khanAcademy,
        'geogebra' => ExternalPlatformHint.geogebra,
        'desmos' => ExternalPlatformHint.desmos,
        'pdf' => ExternalPlatformHint.pdf,
        'other' => ExternalPlatformHint.other,
        _ => throw ArgumentError('Unknown external_platform_hint value: $value'),
      };

  String toDb() => switch (this) {
        ExternalPlatformHint.googleForms => 'google_forms',
        ExternalPlatformHint.microsoftForms => 'microsoft_forms',
        ExternalPlatformHint.youtube => 'youtube',
        ExternalPlatformHint.khanAcademy => 'khan_academy',
        ExternalPlatformHint.geogebra => 'geogebra',
        ExternalPlatformHint.desmos => 'desmos',
        ExternalPlatformHint.pdf => 'pdf',
        ExternalPlatformHint.other => 'other',
      };

  String get label => switch (this) {
        ExternalPlatformHint.googleForms => 'Google Forms',
        ExternalPlatformHint.microsoftForms => 'Microsoft Forms',
        ExternalPlatformHint.youtube => 'YouTube',
        ExternalPlatformHint.khanAcademy => 'Khan Academy',
        ExternalPlatformHint.geogebra => 'GeoGebra',
        ExternalPlatformHint.desmos => 'Desmos',
        ExternalPlatformHint.pdf => 'PDF',
        ExternalPlatformHint.other => 'Other',
      };
}

/// Mirrors `public.assessment_type` (0043) — optional Pre-Test / Post-Test
/// classification. Only ever set when `quizType == QuizType.internal`
/// (`quizzes_assessment_type_requires_internal`, 0043).
enum AssessmentType {
  preTest,
  postTest;

  static AssessmentType fromDb(String value) => switch (value) {
        'pre_test' => AssessmentType.preTest,
        'post_test' => AssessmentType.postTest,
        _ => throw ArgumentError('Unknown assessment_type value: $value'),
      };

  String toDb() => switch (this) {
        AssessmentType.preTest => 'pre_test',
        AssessmentType.postTest => 'post_test',
      };

  String get label => switch (this) {
        AssessmentType.preTest => 'Pre-Test',
        AssessmentType.postTest => 'Post-Test',
      };
}

/// A Dart-side mirror of one `public.quizzes` row — an Internal Quiz or an
/// External Activity, sharing one ownership/section model (0009). No
/// `lesson_id` — quizzes and lessons are kept completely independent
/// (0009 comment, schema §9 Recommendation 6).
class Quiz {
  const Quiz({
    required this.id,
    required this.title,
    required this.quizType,
    required this.sourceType,
    this.createdBy,
    this.gradeLevel,
    this.externalUrl,
    this.externalPlatformHint,
    this.assessmentType,
    required this.shuffleQuestions,
    required this.shuffleChoices,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final QuizType quizType;
  final ContentSourceType sourceType;

  /// Null for built-in quizzes (`quizzes_source_created_by_pairing`, 0009).
  final String? createdBy;

  /// Required (non-null) for built-in quizzes; optional metadata for
  /// teacher quizzes, which are already scoped via `quiz_sections`
  /// (`quizzes_built_in_requires_grade`, 0026).
  final GradeLevel? gradeLevel;

  /// Non-null only for External Activities (`quizzes_type_url_pairing`,
  /// 0009), always `https://`.
  final String? externalUrl;
  final ExternalPlatformHint? externalPlatformHint;

  /// Null for ordinary quizzes; only ever set when `quizType` is
  /// `QuizType.internal` (`quizzes_assessment_type_requires_internal`, 0043).
  final AssessmentType? assessmentType;
  final bool shuffleQuestions;
  final bool shuffleChoices;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] as String,
      title: json['title'] as String,
      quizType: QuizType.fromDb(json['quiz_type'] as String),
      sourceType: ContentSourceType.fromDb(json['source_type'] as String),
      createdBy: json['created_by'] as String?,
      gradeLevel: json['grade_level'] == null
          ? null
          : GradeLevel.fromDb(json['grade_level'] as String),
      externalUrl: json['external_url'] as String?,
      externalPlatformHint: json['external_platform_hint'] == null
          ? null
          : ExternalPlatformHint.fromDb(json['external_platform_hint'] as String),
      assessmentType: json['assessment_type'] == null
          ? null
          : AssessmentType.fromDb(json['assessment_type'] as String),
      shuffleQuestions: json['shuffle_questions'] as bool,
      shuffleChoices: json['shuffle_choices'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
