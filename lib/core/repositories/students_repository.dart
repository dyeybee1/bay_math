import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_failure.dart';
import '../errors/failure_mapper.dart';
import '../models/section.dart';
import '../models/student.dart';

/// One `students` row paired with the section from the student's MOST
/// RECENT enrollment row (by `enrolled_at` desc) — regardless of that
/// enrollment's own status — the row shape the Account Management list
/// screen needs. This means an archived student's `section` still reflects
/// their last section (so the UI can show it and judge restore
/// eligibility), not just a currently-active one. Same pairing pattern as
/// `EnrolledStudent` (`section_workspace_screen.dart`), the other
/// direction: that one resolves an enrollment's student, this one resolves
/// a student's most-recent section.
class StudentWithSection {
  const StudentWithSection(this.student, this.section);
  final Student student;

  /// Null only when the student has no enrollment row at all — every other
  /// student (active, currently enrolled, or archived with history) has a
  /// most-recent section here, since `app.restore_student` (0050) now
  /// re-enrolls a restored student into their last section automatically
  /// rather than leaving them sectionless.
  final Section? section;
}

/// One element of the JSONB array `public.create_students_bulk` returns —
/// one per input name, in the same order — as parsed from the
/// `create-students-bulk` Edge Function's `{results: [...]}` response body.
/// Colocated here rather than in `models/`, same as `StudentWithSection`
/// above: a shape specific to one repository method's return value, not a
/// mirror of a `public.*` table row.
///
/// [index] is the input array position (0-based) — mostly useful for
/// debugging/logging, since [StudentsRepository.createBulk] already
/// returns this list in that same order, so callers rarely need to key off
/// it directly.
class BulkCreateStudentResult {
  const BulkCreateStudentResult({
    required this.index,
    required this.fullName,
    required this.success,
    this.studentId,
    this.username,
    this.password,
    this.errorCode,
    this.errorMessage,
  });

  final int index;

  /// Echoed back from the input, not looked up — may be null in the
  /// unlikely case the batch itself couldn't even attribute a name to this
  /// position (see `app.create_students_bulk`'s own result-shape comment).
  final String? fullName;

  final bool success;

  /// Non-null only when [success] is true.
  final String? studentId;

  /// Non-null only when [success] is true — generated server-side by
  /// `app.create_students_bulk`, never chosen client-side.
  final String? username;

  /// Non-null only when [success] is true. Generated server-side by the
  /// `create-students-bulk` Edge Function itself (not by
  /// `app.create_students_bulk`, which never sees a plaintext password
  /// that isn't immediately encrypted) and re-attached to this result by
  /// index — see that Edge Function's own header comment on this handoff.
  /// Shown once; this repository does not cache or persist it anywhere.
  final String? password;

  /// Non-null only when [success] is false.
  final String? errorCode;

  /// Non-null only when [success] is false. Safe to show directly — this
  /// is the same human-readable message `app.create_students_bulk`
  /// produces for an expected per-student failure (bad name, bad
  /// password, username generation exhausted), not a raw database error.
  final String? errorMessage;

  factory BulkCreateStudentResult.fromJson(Map<String, dynamic> json) {
    return BulkCreateStudentResult(
      index: json['index'] as int,
      fullName: json['full_name'] as String?,
      success: json['success'] as bool,
      studentId: json['student_id'] as String?,
      username: json['username'] as String?,
      password: json['password'] as String?,
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
    );
  }
}

/// Reads `students` rows directly (RLS-scoped via `app.teacher_has_student`,
/// 0015 — a Teacher only ever sees students currently enrolled in one of
/// their own sections; Admin sees all).
///
/// Writes NEVER go through `.rpc()` directly from this repository. Creating
/// a student, resetting a password, and viewing a password all require the
/// `password_encrypted` encryption key, which must never exist in the
/// Flutter client — so those three operations call the corresponding
/// Supabase Edge Function instead (`create-student`, `set-student-password`,
/// `view-student-password`), which holds the key as an environment secret
/// and forwards this client's own JWT to Postgres. See
/// `supabase/functions/*/index.ts` and 0017_student_authentication.sql.
///
/// `archiveStudent`/`restoreStudent` (0047) are the exception to the "no
/// `.rpc()`" rule above: unlike the three Edge-Function-only operations,
/// neither needs the encryption key at all, so they call
/// `public.archive_student`/`public.restore_student` directly, the same
/// `.rpc()`-against-a-`public.*`-wrapper shape as
/// `QuizAttemptsRepository.resolveSchoolYearId` and
/// `EndlessQuizRepository.fetchLeaderboardTop`/`fetchMyRank`.
class StudentsRepository {
  const StudentsRepository(this._client);

  final SupabaseClient _client;

  /// Explicit column list — deliberately excludes `password_encrypted`.
  /// Column-level grants (0016_grants.sql) already prevent that column from
  /// being read at all, but selecting only what the UI needs avoids relying
  /// on that as the sole safeguard.
  static const String _publicColumns =
      'id, student_number, username, full_name, created_by, status, best_endless_streak, avatar_id, created_at, updated_at';

  /// Looks up multiple students by id in one round trip — used to resolve
  /// the enrolled-student list for a section without an N+1 query per
  /// `student_enrollments` row (mirrors `ProfilesRepository.fetchByIds`).
  Future<List<Student>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      final List<Map<String, dynamic>> data = await _client
          .from('students')
          .select(_publicColumns)
          .inFilter('id', ids);
      return data.map(Student.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Creates a student account, scoped to [sectionId], and its initial
  /// active enrollment — via the `create-student` Edge Function, which
  /// wraps `app.create_student` (0017). That function already enforces
  /// "only into a section this teacher is assigned to"; this repository
  /// does not duplicate that check client-side.
  Future<String> create({
    required String username,
    required String fullName,
    required String password,
    required String sectionId,
    String? studentNumber,
  }) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'create-student',
        body: <String, dynamic>{
          'username': username,
          'full_name': fullName,
          'password': password,
          'section_id': sectionId,
          if (studentNumber != null && studentNumber.trim().isNotEmpty)
            'student_number': studentNumber.trim(),
        },
      );
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      return data['student_id'] as String;
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Creates multiple students, all into [sectionId], from [fullNames] in
  /// ONE call — via the `create-students-bulk` Edge Function, which wraps
  /// `public.create_students_bulk` (0055_bulk_create_students.sql, itself
  /// a pass-through to `app.create_students_bulk`). Unlike [create], the
  /// USERNAME and the initial PASSWORD are both generated server-side —
  /// this method only sends names out and gets one [BulkCreateStudentResult]
  /// back per name, in the same order [fullNames] was sent in.
  ///
  /// Mirrors [create]'s try/catch shape exactly (`.functions.invoke` ->
  /// `mapExceptionToFailure`), but the failure this can throw means
  /// something very different than it does for [create]: a thrown
  /// [AppFailure] here means the Edge Function's call into
  /// `create_students_bulk` itself failed/aborted, so the ENTIRE batch was
  /// rejected — NO students were created, not even the ones whose names
  /// looked fine. That is distinct from a normal, successful return where
  /// individual elements of the returned list have `success: false` for
  /// some names and `true` for others (the ordinary, expected outcome for
  /// a batch with a few unusable names in it). Callers MUST branch on
  /// these two cases separately — do not catch the thrown [AppFailure] and
  /// render it as "every name in this batch failed", since in that case
  /// the batch never ran at all. See create-students-bulk/index.ts's own
  /// header comment, which documents this exact distinction from the
  /// Edge Function side.
  Future<List<BulkCreateStudentResult>> createBulk({
    required String sectionId,
    required List<String> fullNames,
  }) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'create-students-bulk',
        body: <String, dynamic>{
          'section_id': sectionId,
          'full_names': fullNames,
        },
      );
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      final List<dynamic> results = data['results'] as List<dynamic>;
      return results
          .map(
            (dynamic row) =>
                BulkCreateStudentResult.fromJson(row as Map<String, dynamic>),
          )
          .toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Sets/resets [studentId]'s password via the `set-student-password` Edge
  /// Function (wraps `app.set_student_password`, 0017 — ownership-checked
  /// and audit-logged server-side).
  Future<void> resetPassword({
    required String studentId,
    required String newPassword,
  }) async {
    try {
      await _client.functions.invoke(
        'set-student-password',
        body: <String, dynamic>{
          'student_id': studentId,
          'new_password': newPassword,
        },
      );
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Reveals [studentId]'s current plaintext password via the
  /// `view-student-password` Edge Function (wraps
  /// `app.view_student_password`, 0017 — audit-logged on every call, not
  /// just every change).
  Future<String> viewPassword(String studentId) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'view-student-password',
        body: <String, dynamic>{'student_id': studentId},
      );
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      return data['password'] as String;
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Admin-only (enforced server-side by `app.is_admin()`, 0047). Sets
  /// [studentId]'s status to archived and atomically ends their currently-
  /// active enrollment — see `app.archive_student`'s own comment for the
  /// exact enrollment-side effect.
  Future<void> archiveStudent(String studentId) async {
    try {
      await _client.rpc<void>(
        'archive_student',
        params: {'p_student_id': studentId},
      );
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Admin-only. Sets [studentId]'s status back to active AND re-enrolls
  /// them into their most recent section, provided that section is still
  /// active (`app.restore_student`, redefined by 0050 — no longer leaves a
  /// restored student sectionless). Throws (surfaced as an `AppFailure`
  /// with a human-readable message) if that section is archived or the
  /// student has no enrollment history at all — callers should prefer
  /// pre-checking eligibility via `StudentWithSection.section` before
  /// calling this, rather than relying solely on this exception.
  Future<void> restoreStudent(String studentId) async {
    try {
      await _client.rpc<void>(
        'restore_student',
        params: {'p_student_id': studentId},
      );
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Permanently removes an archived custom Student identity and its
  /// intentionally tied enrollment, progress, quiz-result, and endless-quiz
  /// rows in one Admin-only database transaction.
  Future<void> deleteStudentPermanently(String studentId) async {
    try {
      final String result = await _client.rpc<String>(
        'delete_archived_student',
        params: <String, dynamic>{'p_student_id': studentId},
      );
      switch (result) {
        case 'deleted':
          return;
        case 'not_archived':
          throw const ValidationFailure(
            'Only archived Student accounts can be permanently deleted.',
          );
        case 'not_found':
          throw const NotFoundFailure('This Student account no longer exists.');
        case 'not_authorized':
          throw const NotAuthorizedFailure();
        default:
          throw const ServerFailure();
      }
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// All students, optionally filtered by [status] (mirrors
  /// `ProfilesRepository.fetchTeachers`'s `status` parameter), each paired
  /// with the section from their MOST RECENT enrollment row — regardless
  /// of that enrollment's own status — per `StudentWithSection.section`'s
  /// own doc comment. This means an archived student's last (pre-archive)
  /// section is still visible here, not just an active student's current
  /// one. Backs the Account Management list screen (grade level/section
  /// name, and restore-eligibility for archived students, come from
  /// `StudentWithSection.section`).
  ///
  /// Three batched round trips regardless of student count — never one
  /// query per student: all matching students, then their enrollments in
  /// one `inFilter` lookup (every row, not just active ones — see below),
  /// then those enrollments' sections in one more — same batch-join shape
  /// as `section_workspace_screen.dart`'s `enrolledStudentsProvider`
  /// (enrollments -> `StudentsRepository.fetchByIds` -> join in a map),
  /// just resolving the opposite direction and via `SectionsRepository`'s
  /// `fetchByIds` equivalent inlined here rather than a cross-repository
  /// call — no repository in this codebase depends on another (every
  /// provider in `supabase_providers.dart` builds straight off
  /// `SupabaseClient`), so the section batch-lookup is done directly
  /// against `_client` rather than reaching for `SectionsRepository`.
  Future<List<StudentWithSection>> fetchAllWithSection({
    StudentStatus? status,
  }) async {
    try {
      final PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _client
          .from('students')
          .select(_publicColumns);
      final PostgrestFilterBuilder<List<Map<String, dynamic>>> filtered =
          status == null ? query : query.eq('status', status.name);

      final List<Map<String, dynamic>> studentRows = await filtered.order(
        'full_name',
      );
      final List<Student> students = studentRows.map(Student.fromJson).toList();
      if (students.isEmpty) return const [];

      // Deliberately NOT filtered to `status: active` — a student can now
      // have multiple enrollment rows in the result (full history, not one
      // guaranteed-unique active row), most-recent-first via the order
      // below, so a restored/archived student's last section still
      // resolves.
      final List<Map<String, dynamic>> enrollmentRows = await _client
          .from('student_enrollments')
          .select('student_id, section_id')
          .inFilter('student_id', students.map((s) => s.id).toList())
          .order('enrolled_at', ascending: false);
      final Map<String, String> sectionIdByStudentId = {};
      for (final Map<String, dynamic> row in enrollmentRows) {
        final String studentId = row['student_id'] as String;
        // Rows arrive most-recent-first (see `.order` above) — keep only
        // the FIRST row seen per student so a later, older row can never
        // overwrite an already-captured newer one.
        sectionIdByStudentId.putIfAbsent(
          studentId,
          () => row['section_id'] as String,
        );
      }
      if (sectionIdByStudentId.isEmpty) {
        return [for (final Student s in students) StudentWithSection(s, null)];
      }

      final List<Map<String, dynamic>> sectionRows = await _client
          .from('sections')
          .select()
          .inFilter('id', sectionIdByStudentId.values.toSet().toList());
      final Map<String, Section> sectionsById = {
        for (final Map<String, dynamic> row in sectionRows)
          (row['id'] as String): Section.fromJson(row),
      };

      return [
        for (final Student s in students)
          StudentWithSection(s, sectionsById[sectionIdByStudentId[s.id]]),
      ];
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
