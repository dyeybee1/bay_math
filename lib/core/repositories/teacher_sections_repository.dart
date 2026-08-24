import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/teacher_section.dart';

/// Reads/writes `teacher_sections` rows — the "My Sections" assignment
/// table. Admin-only writes (`teacher_sections_admin_write`, 0015);
/// Teachers only read their own assignment rows.
class TeacherSectionsRepository {
  const TeacherSectionsRepository(this._client);

  final SupabaseClient _client;

  /// All teachers currently assigned to [sectionId], primary first.
  Future<List<TeacherSection>> fetchForSection(String sectionId) async {
    try {
      final List<Map<String, dynamic>> data = await _client
          .from('teacher_sections')
          .select()
          .eq('section_id', sectionId)
          .order('is_primary', ascending: false)
          .order('assigned_at');
      return data.map(TeacherSection.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// All sections [teacherId] is currently assigned to, primary first —
  /// the "My Sections" list a Teacher's own dashboard is built around.
  /// `teacher_sections_select` (0015) permits a Teacher to read their own
  /// rows directly; no Edge Function is needed for this read.
  Future<List<TeacherSection>> fetchForTeacher(String teacherId) async {
    try {
      final List<Map<String, dynamic>> data = await _client
          .from('teacher_sections')
          .select()
          .eq('teacher_id', teacherId)
          .order('is_primary', ascending: false)
          .order('assigned_at');
      return data.map(TeacherSection.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Assigns [teacherId] to [sectionId]. If [isPrimary] is true, any
  /// existing primary teacher for this section is demoted first — two
  /// sequential statements, never one bulk one, so the
  /// `teacher_sections_one_primary_per_section` partial unique index
  /// (0005) is never violated mid-operation.
  Future<void> assignTeacher({
    required String sectionId,
    required String teacherId,
    required bool isPrimary,
    required String assignedByAdminId,
  }) async {
    try {
      if (isPrimary) {
        await _client
            .from('teacher_sections')
            .update({'is_primary': false})
            .eq('section_id', sectionId)
            .eq('is_primary', true);
      }

      await _client.from('teacher_sections').insert({
        'teacher_id': teacherId,
        'section_id': sectionId,
        'is_primary': isPrimary,
        'assigned_by': assignedByAdminId,
      });
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Makes [teacherSectionId] the primary teacher for [sectionId],
  /// demoting whichever row currently holds that flag first (same
  /// demote-then-promote ordering as [assignTeacher]).
  Future<void> setPrimary({required String teacherSectionId, required String sectionId}) async {
    try {
      await _client
          .from('teacher_sections')
          .update({'is_primary': false})
          .eq('section_id', sectionId)
          .eq('is_primary', true);

      await _client
          .from('teacher_sections')
          .update({'is_primary': true})
          .eq('id', teacherSectionId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<void> unassign(String teacherSectionId) async {
    try {
      await _client.from('teacher_sections').delete().eq('id', teacherSectionId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// All `teacher_sections` rows across every teacher, primary first
  /// within each section — used by the Account Management screen (0047,
  /// Part 4) to summarize every Teacher's section assignment(s) in one
  /// round trip, rather than one [fetchForTeacher] call per teacher row
  /// (N+1). Unlike [fetchForSection]/[fetchForTeacher] above, deliberately
  /// unscoped — Admin's own RLS grants (`teacher_sections_admin_write` /
  /// the matching admin-covering select policy, 0015) already permit
  /// reading the whole table, and this screen genuinely needs every row to
  /// build its per-teacher summary.
  Future<List<TeacherSection>> fetchAll() async {
    try {
      final List<Map<String, dynamic>> data = await _client
          .from('teacher_sections')
          .select()
          .order('is_primary', ascending: false)
          .order('assigned_at');
      return data.map(TeacherSection.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
