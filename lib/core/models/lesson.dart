import 'content_source_type.dart';
import 'section.dart';

/// A Dart-side mirror of one `public.lessons` row — built-in or
/// teacher-created instructional content. Never a prerequisite for
/// anything else (schema §7.3) — quizzes are deliberately independent of
/// lessons (0009). [linkedQuizId] (0032) doesn't change that: it's a pure
/// UI convenience shortcut, never a dependency.
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.body,
    required this.sourceType,
    this.createdBy,
    this.gradeLevel,
    this.linkedQuizId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final ContentSourceType sourceType;

  /// Null for built-in lessons (`lessons_source_created_by_pairing`, 0007).
  final String? createdBy;

  /// Required (non-null) for built-in lessons; optional metadata for
  /// teacher lessons, which are already scoped via `lesson_sections`
  /// (`lessons_built_in_requires_grade`, 0026).
  final GradeLevel? gradeLevel;

  /// Optional (0032). When present, the guided viewer offers a "Take
  /// Quiz" suggestion at the end of the lesson — never required to
  /// complete either the lesson or the quiz; see 0032's column comment.
  final String? linkedQuizId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      sourceType: ContentSourceType.fromDb(json['source_type'] as String),
      createdBy: json['created_by'] as String?,
      gradeLevel: json['grade_level'] == null
          ? null
          : GradeLevel.fromDb(json['grade_level'] as String),
      linkedQuizId: json['linked_quiz_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
