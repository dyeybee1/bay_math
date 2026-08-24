import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/quiz.dart';

/// Reads/writes `quizzes` rows and their `quiz_sections`
/// visibility-assignment rows. Mirrors `LessonsRepository` — Teacher
/// visibility/write scope is entirely RLS-enforced
/// (`quizzes_teacher_select`/`_insert`/`_update`/`_delete`, 0015).
class QuizzesRepository {
  const QuizzesRepository(this._client);

  final SupabaseClient _client;

  /// Built-in quizzes (Internal + External Activity) plus the calling
  /// Teacher's own.
  Future<List<Quiz>> fetchVisibleToTeacher() async {
    try {
      final List<Map<String, dynamic>> data =
          await _client.from('quizzes').select().order('title', ascending: true);
      return data.map(Quiz.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// A single quiz by id, or null if it doesn't exist or isn't visible to
  /// the caller under RLS (`quizzes_teacher_select`/`_student_select`,
  /// 0015) — e.g. a `lessons.linked_quiz_id` (0032) pointing at a quiz
  /// this particular caller can't see. `maybeSingle()` (not `single()`)
  /// deliberately turns that into a null return rather than a thrown
  /// error, since the "Take Quiz" suggestion this feeds is meant to just
  /// quietly not show up rather than surface an error state for something
  /// that was never more than a convenience shortcut.
  Future<Quiz?> fetchById(String quizId) async {
    try {
      final Map<String, dynamic>? row =
          await _client.from('quizzes').select().eq('id', quizId).maybeSingle();
      return row == null ? null : Quiz.fromJson(row);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Creates a quiz. [externalUrl]/[externalPlatformHint] are required for
  /// [QuizType.externalActivity] and must be omitted for
  /// [QuizType.internal] (`quizzes_type_url_pairing`, 0009) — enforced
  /// here client-side to fail fast with a clear message rather than a raw
  /// constraint-violation error, and enforced authoritatively by the DB
  /// regardless.
  Future<String> create({
    required String title,
    required QuizType quizType,
    required String createdBy,
    String? externalUrl,
    ExternalPlatformHint? externalPlatformHint,
    bool shuffleQuestions = true,
    bool shuffleChoices = true,
  }) async {
    try {
      final Map<String, dynamic> row = await _client
          .from('quizzes')
          .insert({
            'title': title,
            'quiz_type': quizType.toDb(),
            'source_type': 'teacher',
            'created_by': createdBy,
            'external_url': quizType == QuizType.externalActivity ? externalUrl : null,
            'external_platform_hint':
                quizType == QuizType.externalActivity ? externalPlatformHint?.toDb() : null,
            'shuffle_questions': shuffleQuestions,
            'shuffle_choices': shuffleChoices,
          })
          .select('id')
          .single();
      return row['id'] as String;
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Updates a quiz's editable meta fields. Deliberately does not accept
  /// [QuizType] — the type/URL pairing is fixed at creation
  /// (`quizzes_type_url_pairing`, 0009); switching an Internal Quiz to an
  /// External Activity (or back) isn't a supported edit, it's a new quiz.
  Future<void> update({
    required String quizId,
    required String title,
    String? externalUrl,
    ExternalPlatformHint? externalPlatformHint,
    required bool shuffleQuestions,
    required bool shuffleChoices,
  }) async {
    try {
      await _client.from('quizzes').update({
        'title': title,
        'external_url': externalUrl,
        'external_platform_hint': externalPlatformHint?.toDb(),
        'shuffle_questions': shuffleQuestions,
        'shuffle_choices': shuffleChoices,
      }).eq('id', quizId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<void> delete(String quizId) async {
    try {
      await _client.from('quizzes').delete().eq('id', quizId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<List<String>> fetchSectionIds(String quizId) async {
    try {
      final List<Map<String, dynamic>> data =
          await _client.from('quiz_sections').select('section_id').eq('quiz_id', quizId);
      return data.map((row) => row['section_id'] as String).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// The inverse of [fetchSectionIds]: every quiz id assigned to one
  /// section. Built-in quizzes never need this — their visibility is
  /// `gradeLevel`-scoped, not `quiz_sections`-scoped (see
  /// [Quiz.gradeLevel]'s own doc comment) — but a teacher-created quiz's
  /// only source of truth for "is this quiz visible in section X" is this
  /// join table, so any caller that needs to resolve a section's full
  /// quiz list (built-in + teacher-created together) needs this alongside
  /// a plain `gradeLevel` filter, not instead of it.
  Future<List<String>> fetchQuizIdsForSection(String sectionId) async {
    try {
      final List<Map<String, dynamic>> data =
          await _client.from('quiz_sections').select('quiz_id').eq('section_id', sectionId);
      return data.map((row) => row['quiz_id'] as String).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<void> assign({
    required String quizId,
    required String sectionId,
    required String assignedBy,
  }) async {
    try {
      await _client.from('quiz_sections').insert({
        'quiz_id': quizId,
        'section_id': sectionId,
        'assigned_by': assignedBy,
      });
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<void> unassign({required String quizId, required String sectionId}) async {
    try {
      await _client
          .from('quiz_sections')
          .delete()
          .eq('quiz_id', quizId)
          .eq('section_id', sectionId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
