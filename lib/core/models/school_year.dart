/// Mirrors `public.school_years.status`.
enum SchoolYearStatus {
  active,
  closed;

  static SchoolYearStatus fromDb(String value) => SchoolYearStatus.values.byName(value);
}

/// A Dart-side mirror of one `public.school_years` row — the bounded
/// academic period everything time-bound in the app is scoped to.
class SchoolYear {
  const SchoolYear({
    required this.id,
    required this.schoolId,
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String schoolId;
  final String label;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;
  final SchoolYearStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SchoolYear.fromJson(Map<String, dynamic> json) {
    return SchoolYear(
      id: json['id'] as String,
      schoolId: json['school_id'] as String,
      label: json['label'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      isCurrent: json['is_current'] as bool,
      status: SchoolYearStatus.fromDb(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
