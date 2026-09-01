-- =============================================================================
-- Migration: 0087_fix_teacher_quiz_attempt_totals.sql
--
-- Fixes Teacher-created Internal Quiz attempts being inserted with
-- total_questions = 0 even when the quiz has questions.
--
-- ROOT CAUSE
-- `app.set_total_questions_on_attempt()` (0018) was SECURITY INVOKER. Student
-- callers cannot SELECT Teacher-owned `quiz_questions` rows under RLS, so the
-- trigger's `count(*)` observed zero rows. Built-in quizzes did not expose the
-- bug because `quiz_questions_teacher_select` permits their rows.
--
-- FIX
-- Recreate only the trigger function as SECURITY DEFINER with an empty search
-- path and fully-qualified objects. It can now count the referenced quiz's
-- rows consistently while exposing no query surface to the caller. The
-- existing trigger and all attempt creation APIs remain unchanged.
--
-- LEGACY REPAIR
-- Existing Teacher-created Internal Quiz attempts whose stored total is null
-- or zero are repaired from the greater of their recorded-answer count and
-- the quiz's current question count. The frozen-field trigger is disabled
-- only around this tightly-scoped corrective UPDATE, then immediately
-- re-enabled in the same migration transaction.
-- =============================================================================

create or replace function app.set_total_questions_on_attempt()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_quiz_type public.quiz_type;
begin
  if new.total_questions is null then
    select q.quiz_type
    into v_quiz_type
    from public.quizzes q
    where q.id = new.quiz_id;

    if v_quiz_type = 'internal' then
      select count(*)
      into new.total_questions
      from public.quiz_questions qq
      where qq.quiz_id = new.quiz_id;
    end if;
  end if;

  return new;
end;
$$;

comment on function app.set_total_questions_on_attempt() is
  'Auto-populates quiz_attempts.total_questions at insert time for Internal Quizzes. SECURITY DEFINER is required so Student-created attempts can count both built-in and Teacher-owned quiz_questions without widening Student RLS access. Empty search_path + fully-qualified objects. External Activities remain NULL. Fixed in 0087.';

-- A trigger function is not an application RPC. Remove the default function
-- EXECUTE surface; PostgreSQL triggers continue invoking it internally.
revoke all on function app.set_total_questions_on_attempt() from public;
revoke all on function app.set_total_questions_on_attempt() from anon;
revoke all on function app.set_total_questions_on_attempt() from authenticated;

alter table public.quiz_attempts disable trigger protect_frozen_fields;

with corrected_totals as (
  select
    qa.id,
    greatest(
      (
        select count(*)
        from public.quiz_attempt_answers qaa
        where qaa.quiz_attempt_id = qa.id
      ),
      (
        select count(*)
        from public.quiz_questions qq
        where qq.quiz_id = qa.quiz_id
      )
    )::smallint as corrected_total
  from public.quiz_attempts qa
  join public.quizzes q on q.id = qa.quiz_id
  where q.quiz_type = 'internal'
    and q.source_type = 'teacher'
    and coalesce(qa.total_questions, 0) = 0
)
update public.quiz_attempts qa
set total_questions = corrected.corrected_total
from corrected_totals corrected
where qa.id = corrected.id
  and corrected.corrected_total > 0;

alter table public.quiz_attempts enable trigger protect_frozen_fields;

-- Postcondition: no affected attempt may retain a zero/null denominator when
-- either its historical answers or its current quiz membership proves that
-- at least one question exists.
do $$
begin
  if exists (
    select 1
    from public.quiz_attempts qa
    join public.quizzes q on q.id = qa.quiz_id
    where q.quiz_type = 'internal'
      and q.source_type = 'teacher'
      and coalesce(qa.total_questions, 0) = 0
      and (
        exists (
          select 1
          from public.quiz_attempt_answers qaa
          where qaa.quiz_attempt_id = qa.id
        )
        or exists (
          select 1
          from public.quiz_questions qq
          where qq.quiz_id = qa.quiz_id
        )
      )
  ) then
    raise exception
      '0087: a Teacher-created Internal Quiz attempt still has an invalid zero/null total_questions value';
  end if;
end;
$$;
