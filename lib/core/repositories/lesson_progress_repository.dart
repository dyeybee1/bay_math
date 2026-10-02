import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';

/// Reads and writes `lesson_progress` rows (0007) for the signed-in student —
/// analytics only, never an access gate (schema §7.3). Every call here
/// goes over the student's own forwarded JWT via the client passed in
/// (`studentScopedClientProvider`), relying entirely on
/// `lesson_progress_student_insert`/`_update` RLS (0015), exactly like
/// `QuizAttemptsRepository` does for `quiz_attempts`.
///
/// Deliberately NOT a single generic `.upsert()` against
/// `lesson_progress_student_lesson_unique` (0007) for either method below
/// — same TOCTOU-safe insert-first-then-handle-the-conflict shape
/// `QuizAttemptsRepository.findOrCreateActiveAttempt`/`submitAnswer`
/// already use (0010's unique index there), chosen specifically because a
/// plain upsert would silently let a later `in_progress` write regress an
/// already-`completed` row (or a racing `completed` write clobber an
/// earlier `completed_at`). Neither status transition here should ever
/// move backwards, so both methods read-or-check before ever writing over
/// an existing row instead of blindly overwriting it.
class LessonProgressRepository {
  const LessonProgressRepository(this._client);

  final SupabaseClient _client;

  /// Completed lesson IDs for the signed-in student. RLS limits the read to
  /// that student's own progress rows. Returning a set makes the one-count-
  /// per-lesson rule explicit even if legacy data ever contains duplicates.
  Future<Set<String>> fetchCompletedLessonIds() async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('lesson_progress')
          .select('lesson_id')
          .eq('status', 'completed');
      return rows
          .map((Map<String, dynamic> row) => row['lesson_id'] as String)
          .toSet();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Persisted status for each of the signed-in student's lessons. RLS limits
  /// this read to their own rows; a lesson absent from the map has not started.
  Future<Map<String, String>> fetchLessonStatuses() async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('lesson_progress')
          .select('lesson_id, status');
      return <String, String>{
        for (final Map<String, dynamic> row in rows)
          row['lesson_id'] as String: row['status'] as String,
      };
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Called once on first entering guided mode for a lesson. If the
  /// student already has a `lesson_progress` row for this lesson — at
  /// ANY status, including already `completed` — this is a no-op:
  /// re-entering guided mode must never downgrade a `completed` row back
  /// to `in_progress`. Relies on the insert simply losing the unique-index
  /// race rather than reading the current status first, since "a row
  /// already exists" is itself sufficient reason to leave it untouched.
  Future<void> markInProgress({
    required String studentId,
    required String lessonId,
  }) async {
    try {
      await _client.from('lesson_progress').insert({
        'student_id': studentId,
        'lesson_id': lessonId,
        'status': 'in_progress',
        'started_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        return; // a row already exists — never downgrade it
      }
      throw mapExceptionToFailure(error);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Called once on reaching the lesson's final page. Idempotent per the
  /// same discipline as `QuizAttemptsRepository.finalize`: if the existing
  /// row is already `completed`, this leaves it (and its original
  /// `completed_at`) untouched rather than re-writing over it.
  Future<void> markCompleted({
    required String studentId,
    required String lessonId,
  }) async {
    final String nowIso = DateTime.now().toUtc().toIso8601String();
    try {
      try {
        await _client.from('lesson_progress').insert({
          'student_id': studentId,
          'lesson_id': lessonId,
          'status': 'completed',
          'started_at': nowIso,
          'completed_at': nowIso,
        });
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;

        final Map<String, dynamic> existing =
            await _client
                .from('lesson_progress')
                .select()
                .eq('student_id', studentId)
                .eq('lesson_id', lessonId)
                .single();
        if (existing['status'] == 'completed') return;

        await _client
            .from('lesson_progress')
            .update({'status': 'completed', 'completed_at': nowIso})
            .eq('student_id', studentId)
            .eq('lesson_id', lessonId);
      }
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
