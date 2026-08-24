import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/lesson.dart';
import '../models/lesson_page.dart';

/// Reads/writes `lessons` rows and their `lesson_sections`
/// visibility-assignment rows.
///
/// Teacher visibility/write scope is entirely RLS-enforced
/// (`lessons_teacher_select`/`_insert`/`_update`/`_delete`, 0015): a
/// Teacher sees built-in lessons plus their own, and can only write their
/// own. This repository issues flat, unfiltered selects and lets RLS do
/// the scoping — same pattern as `SectionsRepository`.
class LessonsRepository {
  const LessonsRepository(this._client);

  final SupabaseClient _client;

  /// Built-in lessons plus the calling Teacher's own — RLS
  /// (`lessons_teacher_select`) already restricts the result to exactly
  /// that set, so no `.eq(...)` filter is added here.
  Future<List<Lesson>> fetchVisibleToTeacher() async {
    try {
      final List<Map<String, dynamic>> data =
          await _client.from('lessons').select().order('title', ascending: true);
      return data.map(Lesson.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<String> create({
    required String title,
    required String body,
    required String createdBy,
  }) async {
    try {
      final Map<String, dynamic> row = await _client
          .from('lessons')
          .insert({
            'title': title,
            'body': body,
            'source_type': 'teacher',
            'created_by': createdBy,
          })
          .select('id')
          .single();
      return row['id'] as String;
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<void> update({
    required String lessonId,
    required String title,
    required String body,
  }) async {
    try {
      await _client
          .from('lessons')
          .update({'title': title, 'body': body})
          .eq('id', lessonId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<void> delete(String lessonId) async {
    try {
      await _client.from('lessons').delete().eq('id', lessonId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Every `lesson_pages` row for [lessonId], ordered for guided-mode
  /// rendering — RLS (`lesson_pages_select`, 0028) re-triggers `lessons`'
  /// own SELECT policies via its EXISTS subquery, so this resolves
  /// correctly for whichever role (Admin/Teacher/Student) can already see
  /// the parent lesson; no additional filter is added here, matching
  /// every other method on this class.
  Future<List<LessonPage>> fetchPages(String lessonId) async {
    try {
      final List<Map<String, dynamic>> data = await _client
          .from('lesson_pages')
          .select()
          .eq('lesson_id', lessonId)
          .order('display_order', ascending: true);
      return data.map(LessonPage.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Section ids [lessonId] is currently assigned to.
  Future<List<String>> fetchSectionIds(String lessonId) async {
    try {
      final List<Map<String, dynamic>> data = await _client
          .from('lesson_sections')
          .select('section_id')
          .eq('lesson_id', lessonId);
      return data.map((row) => row['section_id'] as String).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<void> assign({
    required String lessonId,
    required String sectionId,
    required String assignedBy,
  }) async {
    try {
      await _client.from('lesson_sections').insert({
        'lesson_id': lessonId,
        'section_id': sectionId,
        'assigned_by': assignedBy,
      });
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<void> unassign({required String lessonId, required String sectionId}) async {
    try {
      await _client
          .from('lesson_sections')
          .delete()
          .eq('lesson_id', lessonId)
          .eq('section_id', sectionId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
