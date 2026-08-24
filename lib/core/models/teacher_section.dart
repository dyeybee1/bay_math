/// A Dart-side mirror of one `public.teacher_sections` row — a Teacher <->
/// Section assignment, with a primary-teacher flag ("My Sections").
class TeacherSection {
  const TeacherSection({
    required this.id,
    required this.teacherId,
    required this.sectionId,
    required this.isPrimary,
    this.assignedBy,
    required this.assignedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String teacherId;
  final String sectionId;
  final bool isPrimary;
  final String? assignedBy;
  final DateTime assignedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TeacherSection.fromJson(Map<String, dynamic> json) {
    return TeacherSection(
      id: json['id'] as String,
      teacherId: json['teacher_id'] as String,
      sectionId: json['section_id'] as String,
      isPrimary: json['is_primary'] as bool,
      assignedBy: json['assigned_by'] as String?,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
