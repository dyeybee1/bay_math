import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/section.dart';
import '../models/student.dart';

/// A logged-in student reading/updating their OWN `students` row.
///
/// Connection A, same trust model as `EndlessQuizRepository`/
/// `LessonProgressRepository` — built from `studentScopedClientProvider`,
/// which forwards the student's own JWT as a plain `Authorization` header.
///
/// [fetchOwnProfile] relies on `students_student_select_own` (0053) — the
/// first student-facing SELECT policy on `students`; before that migration
/// a student had no RLS-permitted way to read their own row at all.
/// [setAvatar] deliberately does NOT do a plain `.from('students').update(...)`
/// — see 0053_student_avatar.sql's own comment on why this goes through
/// the `set_student_avatar` RPC (a narrow SECURITY DEFINER write) instead
/// of a blanket student UPDATE policy/grant.
class StudentProfileRepository {
  const StudentProfileRepository(this._client);

  final SupabaseClient _client;

  static const String _ownColumns =
      'id, student_number, username, full_name, created_by, status, best_endless_streak, avatar_id, created_at, updated_at';

  /// The calling student's own row. RLS (`students_student_select_own`)
  /// guarantees this can only ever resolve to their own id — there is
  /// deliberately no `studentId` parameter here, unlike
  /// `StudentsRepository.fetchByIds`, which is a Teacher/Admin-facing call
  /// that legitimately looks up other students.
  Future<Student> fetchOwnProfile() async {
    try {
      final Map<String, dynamic> row =
          await _client.from('students').select(_ownColumns).single();
      return Student.fromJson(row);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Sets the calling student's `avatar_id` to one of the
  /// `avatar_catalog.dart` keys via the `set_student_avatar` RPC (0053).
  /// An unrecognized [avatarId] fails server-side (the
  /// `students_avatar_id_valid` check constraint, Postgres code `23514`,
  /// which [mapExceptionToFailure] doesn't special-case and so surfaces as
  /// a generic [ServerFailure]) — callers should only ever pass an id
  /// sourced from `AvatarCatalog.all`, so that path should not be
  /// reachable from the picker screen in practice.
  Future<void> setAvatar(String avatarId) async {
    try {
      await _client.rpc<void>('set_student_avatar', params: {'p_avatar_id': avatarId});
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// The calling student's current grade level, derived server-side from
  /// their active enrollment's section (`public.student_current_grade`,
  /// 0054 — a pass-through wrapper around `app.student_current_grade`,
  /// 0026). Not read directly off `sections` — that table has no
  /// student-facing SELECT policy (0015), so this goes through the
  /// SECURITY DEFINER helper the same way `EndlessQuizRepository`'s
  /// leaderboard calls already do. Null only if the student somehow has no
  /// active enrollment at all.
  Future<GradeLevel?> fetchOwnGradeLevel() async {
    try {
      final Object? value = await _client.rpc<Object?>('student_current_grade');
      if (value == null) return null;
      return GradeLevel.fromDb(value as String);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
