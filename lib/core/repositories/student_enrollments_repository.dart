import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/student_enrollment.dart';

/// Reads `student_enrollments` rows. Teacher visibility is RLS-scoped via
/// `app.teacher_has_section` (`student_enrollments_select`, 0015) — a
/// Teacher only ever sees enrollment rows for sections they're assigned to.
///
/// Writes to this table are performed atomically by `app.create_student`
/// (0017), not by this repository directly — see `StudentsRepository.create`.
class StudentEnrollmentsRepository {
  const StudentEnrollmentsRepository(this._client);

  final SupabaseClient _client;

  /// Currently-active enrollments for [sectionId] — the "who's enrolled in
  /// this section right now" list a Teacher's section workspace is built
  /// around.
  Future<List<StudentEnrollment>> fetchActiveForSection(String sectionId) async {
    try {
      final List<Map<String, dynamic>> data = await _client
          .from('student_enrollments')
          .select()
          .eq('section_id', sectionId)
          .eq('status', 'active')
          .order('enrolled_at');
      return data.map(StudentEnrollment.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// The signed-in student's own current active enrollment — Phase 6
  /// (Quiz-Taking) needs this to resolve `section_id` before starting a
  /// quiz attempt. Relies on `student_enrollments_select`'s
  /// `student_id = app.current_student_id()` clause (0015) and this
  /// [_client] being student-scoped (`studentScopedClientProvider`), not
  /// the Teacher/Admin one every other method on this class is called
  /// with. Exactly zero-or-one row by construction
  /// (`student_enrollments_one_active_per_student`, 0006) — null if
  /// somehow none exists yet.
  Future<StudentEnrollment?> fetchOwnActive(String studentId) async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('student_enrollments')
          .select()
          .eq('student_id', studentId)
          .eq('status', 'active')
          .maybeSingle();
      return row == null ? null : StudentEnrollment.fromJson(row);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
