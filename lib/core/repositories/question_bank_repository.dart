import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure_mapper.dart';
import '../models/question_bank_item.dart';
import '../models/question_choice.dart';

/// Reads/writes `question_bank` rows and their `question_choices` rows.
///
/// Teacher visibility/write scope for `question_bank` is entirely
/// RLS-enforced (`question_bank_teacher_select`/`_insert`/`_update`/`_delete`,
/// 0015). `question_choices` writes are scoped via the owning question
/// (`question_choices_teacher_write`, 0015).
class QuestionBankRepository {
  const QuestionBankRepository(this._client);

  final SupabaseClient _client;

  /// Built-in questions plus the calling Teacher's own, optionally
  /// filtered by [search] against `prompt_text`.
  Future<List<QuestionBankItem>> fetchVisibleToTeacher({String? search}) async {
    try {
      final PostgrestFilterBuilder<List<Map<String, dynamic>>> query =
          _client.from('question_bank').select();

      final PostgrestFilterBuilder<List<Map<String, dynamic>>> filtered =
          (search == null || search.trim().isEmpty)
              ? query
              : query.ilike('prompt_text', '%${search.trim()}%');

      final List<Map<String, dynamic>> data =
          await filtered.order('created_at', ascending: false);
      return data.map(QuestionBankItem.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<String> create({
    required String promptText,
    String? topic,
    String? explanationText,
    required String createdBy,
  }) async {
    try {
      final Map<String, dynamic> row = await _client
          .from('question_bank')
          .insert({
            'source_type': 'teacher',
            'created_by': createdBy,
            'topic': topic,
            'prompt_text': promptText,
            'explanation_text': explanationText,
          })
          .select('id')
          .single();
      return row['id'] as String;
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  Future<void> update({
    required String questionId,
    required String promptText,
    String? topic,
    String? explanationText,
  }) async {
    try {
      await _client.from('question_bank').update({
        'topic': topic,
        'prompt_text': promptText,
        'explanation_text': explanationText,
      }).eq('id', questionId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Deleting a question cascades to its `question_choices` rows
  /// (`on delete cascade`, 0008); the deferred at-least-one-correct
  /// trigger explicitly skips validation once the parent question is
  /// gone (0014 audit-finding comment), so this is always safe.
  Future<void> delete(String questionId) async {
    try {
      await _client.from('question_bank').delete().eq('id', questionId);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Batch fetch — resolves choices for multiple questions (e.g. a quiz's
  /// question-picker rendering several prompts at once) without an N+1
  /// query per question.
  Future<List<QuestionChoice>> fetchChoices(List<String> questionIds) async {
    if (questionIds.isEmpty) return const [];
    try {
      final List<Map<String, dynamic>> data = await _client
          .from('question_choices')
          .select()
          .inFilter('question_id', questionIds)
          .order('display_order');
      return data.map(QuestionChoice.fromJson).toList();
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }

  /// Writes the full, final set of choices for [questionId] in one
  /// batched upsert statement.
  ///
  /// This must stay a single statement, not sequential per-choice writes:
  /// `enforce_at_least_one_correct` (0014) is a `deferrable initially
  /// deferred` constraint trigger, so it only evaluates once, at the end
  /// of whatever statement/transaction touched the rows. A batched upsert
  /// therefore sees only the final state (correct); N sequential
  /// `.update()` calls would each be their own autocommitted
  /// statement/transaction, and an intermediate one (e.g. unchecking the
  /// old correct choice before checking the new one) could transiently
  /// have zero correct choices and be rejected.
  ///
  /// [choices] must cover every choice this question currently has,
  /// keyed by [QuestionChoice.displayOrder] starting at 1 — the upsert
  /// target is the `(question_id, display_order)` unique constraint
  /// (0008), so each entry updates the existing row at that position (its
  /// `id` is preserved automatically) or inserts a new one. If the new
  /// set has fewer choices than before, trailing rows beyond the new
  /// count are deleted in a second statement — safe to run after the
  /// upsert, since the upsert has already established a valid (>=1
  /// correct) final state among the surviving rows before any deletion
  /// happens.
  Future<void> replaceChoices({
    required String questionId,
    required List<({String choiceText, bool isCorrect})> choices,
  }) async {
    try {
      await _client.from('question_choices').upsert(
        [
          for (int i = 0; i < choices.length; i++)
            {
              'question_id': questionId,
              'choice_text': choices[i].choiceText,
              'is_correct': choices[i].isCorrect,
              'display_order': i + 1,
            },
        ],
        onConflict: 'question_id,display_order',
      );

      await _client
          .from('question_choices')
          .delete()
          .eq('question_id', questionId)
          .gt('display_order', choices.length);
    } catch (error) {
      throw mapExceptionToFailure(error);
    }
  }
}
