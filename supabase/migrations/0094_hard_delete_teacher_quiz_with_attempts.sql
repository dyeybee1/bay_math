-- =============================================================================
-- Migration: 0094_hard_delete_teacher_quiz_with_attempts.sql
--
-- 0093 introduced an ownership-checking Teacher quiz-delete RPC but preserved
-- quiz-attempt history. Product intent now requires an explicit hard delete of
-- the complete attempt/result graph for the owned Teacher-created quiz.
--
-- This forward-only migration replaces only the internal RPC implementation.
-- The public wrapper and its grants from 0093 remain unchanged. The RPC is one
-- PostgreSQL transaction, so any failure rolls back every delete below.
--
-- Dependency order:
--   1. quiz_attempt_answer_choice_snapshots
--   2. quiz_attempt_answers
--   3. quiz_attempts
--   4. lessons.linked_quiz_id (unlink; lessons are preserved)
--   5. quiz_sections
--   6. quiz_questions
--   7. quizzes
--
-- question_bank and question_choices are intentionally preserved: the schema
-- defines question_bank as a reusable pool, and there is no authoritative
-- quiz-ownership marker that would make deleting an unlinked question safe.
-- No foreign key, RLS policy, trigger, grant, or historical migration changes.
-- =============================================================================

create or replace function app.delete_own_teacher_quiz(p_quiz_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source_type public.content_source_type;
  v_created_by uuid;
begin
  if not app.is_approved_teacher() then
    return 'not_authorized';
  end if;

  -- Locking the parent makes validation and cleanup one concurrency-safe
  -- decision. New child rows cannot acquire their FK key-share locks between
  -- this lock and the final parent delete.
  select quiz.source_type, quiz.created_by
  into v_source_type, v_created_by
  from public.quizzes quiz
  where quiz.id = p_quiz_id
  for update;

  if not found then
    return 'not_found';
  end if;

  if v_source_type <> 'teacher'::public.content_source_type
     or v_created_by is distinct from auth.uid() then
    return 'not_authorized';
  end if;

  delete from public.quiz_attempt_answer_choice_snapshots snapshot
  using public.quiz_attempt_answers answer,
        public.quiz_attempts attempt
  where snapshot.quiz_attempt_answer_id = answer.id
    and answer.quiz_attempt_id = attempt.id
    and attempt.quiz_id = p_quiz_id;

  delete from public.quiz_attempt_answers answer
  using public.quiz_attempts attempt
  where answer.quiz_attempt_id = attempt.id
    and attempt.quiz_id = p_quiz_id;

  delete from public.quiz_attempts attempt
  where attempt.quiz_id = p_quiz_id;

  update public.lessons lesson
  set linked_quiz_id = null
  where lesson.linked_quiz_id = p_quiz_id;

  delete from public.quiz_sections assignment
  where assignment.quiz_id = p_quiz_id;

  delete from public.quiz_questions link
  where link.quiz_id = p_quiz_id;

  delete from public.quizzes quiz
  where quiz.id = p_quiz_id;

  return 'deleted';
end;
$$;

comment on function app.delete_own_teacher_quiz(uuid) is
  'Approved-Teacher-only atomic hard delete for an owned source_type=teacher quiz. Deletes its snapshots, answers, attempts, section assignments, and quiz-question links; unlinks lessons; preserves reusable question-bank content.';

comment on function public.delete_own_teacher_quiz(uuid) is
  'PostgREST wrapper for app.delete_own_teacher_quiz. Returns deleted, not_authorized, or not_found. As of 0094, owned quiz attempts/results are hard-deleted atomically.';
