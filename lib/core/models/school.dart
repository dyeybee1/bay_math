/// A Dart-side mirror of one `public.schools` row.
///
/// Phase 2 scope: single-school deployments (schema §3.1 — "one row today;
/// no constraint forces exactly one"). [SchoolsRepository.fetchFirst] is
/// what call sites use precisely because of that assumption; multi-school
/// support later requires no schema migration, only a different query.
class School {
  const School({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
