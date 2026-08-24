import 'worked_example.dart';

/// A Dart-side mirror of one `public.lesson_pages` row (0028) — one
/// ordered slide of a lesson's guided Student viewer.
///
/// `sectionType` is presentation-only (0028's column comment): it never
/// gates access and is used purely client-side to pick a per-page icon
/// (see the guided-mode viewer screen). It is deliberately a raw
/// nullable [String], not an enum, since the DB column itself is
/// unconstrained text — new types may be added freely later without a
/// migration, and an unrecognized/null value must fall back to a default
/// icon rather than throw.
class LessonPage {
  const LessonPage({
    required this.id,
    required this.lessonId,
    required this.displayOrder,
    this.sectionType,
    required this.title,
    required this.body,
    this.workedExample,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String lessonId;
  final int displayOrder;
  final String? sectionType;
  final String title;
  final String body;

  /// Nullable (0030). When present, the guided viewer renders the
  /// interactive step-by-step panel INSTEAD of plain [body] text for this
  /// page — see `lesson_viewer_screen.dart`. Null for every page except
  /// the two proof-of-concept examples converted in 0031.
  final WorkedExample? workedExample;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory LessonPage.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? workedExampleJson = json['worked_example'] as Map<String, dynamic>?;
    return LessonPage(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      displayOrder: json['display_order'] as int,
      sectionType: json['section_type'] as String?,
      title: json['title'] as String,
      body: json['body'] as String,
      workedExample: workedExampleJson == null ? null : WorkedExample.fromJson(workedExampleJson),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
