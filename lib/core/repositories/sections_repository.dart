import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_failure.dart';
import '../errors/failure_mapper.dart';
import '../models/section.dart';

/// Reads/writes `sections` rows. Admin-only writes (`sections_admin_write`,
/// 0015); Teachers only read sections they're assigned to
/// (`app.teacher_has_section`).
class SectionsRepository {
  const SectionsRepository(this._client);

  final SupabaseClient _client;

  /// All sections within one school year, ordered by grade level then
  /// name — the natural browsing order for an Admin managing a year's
  /// sections.
  Future<List<Section>> fetchForSchoolYear(
    String schoolYearId, {
    SectionStatus? status,
  }) async {
    try {
      final PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _client
          .from('sections')
          .select()
          .eq('school_year_id', schoolYearId);
      final PostgrestFilterBuilder<List<Map<String, dynamic>>> filtered =
          status == null ? query : query.eq('status', status.name);
      final List<Map<String, dynamic>> data = await filtered
          .order('grade_level')
          .order('name');
      return data.map(Section.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Looks up multiple sections by id in one round trip — used to resolve
  /// the display name/grade level for a Teacher's `teacher_sections` rows
  /// ("My Sections") without an N+1 query per assignment. Not in the
  /// original Phase 2 repository; added here because rendering "My
  /// Sections" needs it (mirrors `ProfilesRepository.fetchByIds`).
  Future<List<Section>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      final List<Map<String, dynamic>> data = await _client
          .from('sections')
          .select()
          .inFilter('id', ids);
      return data.map(Section.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<void> create({
    required String schoolYearId,
    required GradeLevel gradeLevel,
    required String name,
  }) async {
    try {
      await _client.from('sections').insert({
        'school_year_id': schoolYearId,
        'grade_level': gradeLevel.toDb(),
        'name': name,
      });
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Archives a section (`sections_year_grade_name_unique`, 0005, means the
  /// name isn't freed up for reuse within the same year — archiving is a
  /// status change, not a delete, consistent with the schema's general
  /// prefer-RESTRICT/soft-status approach).
  Future<void> archive(String sectionId) async {
    try {
      await _client
          .from('sections')
          .update({'status': 'archived'})
          .eq('id', sectionId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<void> restore(String sectionId) async {
    try {
      await _client
          .from('sections')
          .update({'status': 'active'})
          .eq('id', sectionId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Permanently deletes an archived section only when the backend confirms
  /// that no enrollment or quiz-attempt history depends on it.
  Future<void> deletePermanently(String sectionId) async {
    try {
      final String result = await _client.rpc<String>(
        'delete_archived_section',
        params: <String, dynamic>{'p_section_id': sectionId},
      );
      switch (result) {
        case 'deleted':
          return;
        case 'not_archived':
          throw const ValidationFailure(
            'Only archived sections can be permanently deleted.',
          );
        case 'has_student_history':
          throw const ValidationFailure(
            'This section cannot be deleted because it has student enrollment history that must be preserved.',
          );
        case 'has_quiz_history':
          throw const ValidationFailure(
            'This section cannot be deleted because it has quiz result history that must be preserved.',
          );
        case 'not_found':
          throw const NotFoundFailure('This section no longer exists.');
        case 'not_authorized':
          throw const NotAuthorizedFailure();
        default:
          throw const ServerFailure();
      }
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
