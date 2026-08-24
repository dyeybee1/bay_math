import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/profile.dart';

/// Reads/writes `profiles` rows.
///
/// Phase 1 scope was deliberately narrow (the caller's own row only).
/// Phase 2 adds the Admin-scoped surface: listing Teacher accounts,
/// approving/rejecting them, and looking up specific profiles by id (for
/// displaying who's assigned to a section) — reading/writing *other*
/// users' rows, which only Admin's RLS grants permit.
class ProfilesRepository {
  const ProfilesRepository(this._client);

  final SupabaseClient _client;

  /// Returns null if no profile row exists yet for this id (e.g. a real
  /// Auth session exists but the client crashed between sign-up and the
  /// profile insert — a genuine, if rare, possibility worth handling
  /// explicitly rather than throwing).
  Future<Profile?> fetchOwnProfile(String userId) async {
    try {
      final Map<String, dynamic>? data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;
      return Profile.fromJson(data);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// All Teacher profiles, optionally filtered by [status] — used for both
  /// the pending-approval queue (`status: ProfileStatus.pending`) and the
  /// "assign teacher to section" picker (`status: ProfileStatus.approved`).
  /// Admin-only in practice: `profiles_select` RLS only returns other
  /// users' rows to Admin or to the row's own owner.
  Future<List<Profile>> fetchTeachers({ProfileStatus? status}) async {
    try {
      final PostgrestFilterBuilder<List<Map<String, dynamic>>> query =
          _client.from('profiles').select().eq('role', 'teacher');

      final PostgrestFilterBuilder<List<Map<String, dynamic>>> filtered =
          status == null ? query : query.eq('status', status.name);

      final List<Map<String, dynamic>> data =
          await filtered.order('created_at', ascending: false);
      return data.map(Profile.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Looks up multiple profiles by id in one round trip — used to resolve
  /// the display name/email/status for a list of `teacher_sections` rows
  /// without an N+1 query per assigned teacher. Returns whatever subset
  /// of [ids] actually exists; callers should not assume a 1:1 result.
  Future<List<Profile>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      final List<Map<String, dynamic>> data =
          await _client.from('profiles').select().inFilter('id', ids);
      return data.map(Profile.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Approves a pending Teacher. `approved_by`/`approved_at` are set here
  /// rather than left to a default, so the record is explicit about who
  /// approved it and when — the same status change the audit trail (via
  /// `audit_profile_status_change`, 0014) separately, automatically logs.
  Future<void> approveTeacher({required String teacherId, required String approvedByAdminId}) async {
    try {
      await _client.from('profiles').update({
        'status': 'approved',
        'approved_by': approvedByAdminId,
        'approved_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', teacherId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<void> rejectTeacher(String teacherId) async {
    try {
      await _client.from('profiles').update({'status': 'rejected'}).eq('id', teacherId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<void> archiveTeacher(String teacherId) async {
    try {
      await _client.from('profiles').update({'status': 'archived'}).eq('id', teacherId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Restores an archived Teacher directly to `approved` — not `pending`.
  /// An archived Teacher was already vetted; restoring them returns their
  /// normal access rather than re-queuing them behind the approval flow.
  Future<void> restoreTeacher(String teacherId) async {
    try {
      await _client.from('profiles').update({'status': 'approved'}).eq('id', teacherId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Admin-only (enforced server-side by `app.is_admin()`, 0049). Renames
  /// an approved Teacher via `app.update_teacher_full_name`. No secret/key
  /// is involved in this write — unlike `StudentsRepository`'s
  /// Edge-Function-only writes — so this goes straight to `.rpc()` against
  /// the `public.*` wrapper, the same shape already used by
  /// `StudentsRepository.archiveStudent`/`restoreStudent`.
  Future<void> updateTeacherFullName({
    required String teacherId,
    required String fullName,
  }) async {
    try {
      await _client.rpc<void>(
        'update_teacher_full_name',
        params: {'p_teacher_id': teacherId, 'p_full_name': fullName},
      );
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Admin-only. Updates an approved Teacher's sign-in email via the
  /// `update-teacher-email` Edge Function — deliberately NOT a direct
  /// `.rpc('update_teacher_email', ...)` call. The Edge Function wraps
  /// that RPC (which only touches `public.profiles.email`) and additionally
  /// updates the real Supabase Auth sign-in email (`auth.users.email`) via
  /// the Auth Admin API, which Postgres/PostgREST cannot reach on its own.
  /// Calling the RPC directly from here would silently desync the two.
  /// See `supabase/functions/update-teacher-email/index.ts` for the full
  /// two-table update + best-effort rollback mechanism.
  Future<void> updateTeacherEmail({
    required String teacherId,
    required String newEmail,
  }) async {
    try {
      await _client.functions.invoke(
        'update-teacher-email',
        body: <String, dynamic>{'teacher_id': teacherId, 'new_email': newEmail},
      );
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
