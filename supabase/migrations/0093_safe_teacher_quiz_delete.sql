-- =============================================================================
-- Migration: 0093_safe_teacher_quiz_delete.sql
--
-- Teacher-created quizzes were deleted through a direct PostgREST table
-- DELETE. Setup-only quizzes deleted correctly because quiz_sections and
-- quiz_questions intentionally use ON DELETE CASCADE (0009), but any quiz
-- with a historical quiz_attempt failed with SQLSTATE 23503 because
-- quiz_attempts.quiz_id intentionally uses ON DELETE RESTRICT (0010).
--
-- Historical attempts are permanent product records: authenticated has no
-- DELETE grant on quiz_attempts and 0015 explicitly prohibits hard deletion
-- for every role. This migration therefore adds one narrow RPC that:
--   * accepts approved Teachers only;
--   * deletes only source_type = teacher rows owned by auth.uid();
--   * refuses deletion when even one quiz_attempt exists;
--   * otherwise deletes the quiz atomically, allowing only the already-
--     defined setup cascades to remove quiz_sections and quiz_questions;
--   * leaves reusable question_bank/question_choices content intact;
--   * preserves lessons through the existing linked_quiz_id ON DELETE SET
--     NULL behavior (0032).
--
-- No foreign key, RLS policy, trigger, or historical migration is changed.
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

  -- The row lock makes the attempt check and delete one atomic decision. A
  -- concurrent attempt insert cannot acquire its FK key-share lock between
  -- this check and the delete.
  select q.source_type, q.created_by
  into v_source_type, v_created_by
  from public.quizzes q
  where q.id = p_quiz_id
  for update;

  if not found then
    return 'not_found';
  end if;

  if v_source_type <> 'teacher'::public.content_source_type
     or v_created_by is distinct from auth.uid() then
    return 'not_authorized';
  end if;

  if exists (
    select 1
    from public.quiz_attempts attempt
    where attempt.quiz_id = p_quiz_id
  ) then
    return 'has_attempts';
  end if;

  delete from public.quizzes quiz
  where quiz.id = p_quiz_id;

  return 'deleted';
end;
$$;

comment on function app.delete_own_teacher_quiz(uuid) is
  'Approved-Teacher-only atomic deletion for an owned source_type=teacher quiz. Returns has_attempts instead of deleting permanent quiz-attempt history. Existing setup cascades remove quiz_sections/quiz_questions; reusable question-bank content remains.';

revoke all on function app.delete_own_teacher_quiz(uuid)
  from public, anon, authenticated;
grant execute on function app.delete_own_teacher_quiz(uuid)
  to authenticated;

create or replace function public.delete_own_teacher_quiz(p_quiz_id uuid)
returns text
language sql
set search_path = ''
as $$
  select app.delete_own_teacher_quiz(p_quiz_id);
$$;

comment on function public.delete_own_teacher_quiz(uuid) is
  'PostgREST wrapper for app.delete_own_teacher_quiz. Returns deleted, has_attempts, not_authorized, or not_found.';

revoke all on function public.delete_own_teacher_quiz(uuid)
  from public, anon;
grant execute on function public.delete_own_teacher_quiz(uuid)
  to authenticated;
