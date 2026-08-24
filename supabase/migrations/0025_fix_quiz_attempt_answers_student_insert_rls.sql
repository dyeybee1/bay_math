-- =============================================================================
-- Migration: 0025_fix_quiz_attempt_answers_student_insert_rls.sql
-- Phase 6 (Quiz-Taking) prerequisite fix — found during live testing (every
-- answer submission failed, which the Flutter client surfaced as a crash
-- due to a separate client-side bug also fixed alongside this). NOT part
-- of the originally-scoped "no new SQL" plan. Same class of issue as 0023,
-- flagged for the same reason (see that migration's header) — this is the
-- one I missed when reviewing the RLS policies the first time around.
--
-- THE BUG
-- `quiz_attempt_answers_student_insert` (0015)'s WITH CHECK contains:
--
--   and exists (
--     select 1 from public.quiz_questions qq
--     where qq.quiz_id = qa.quiz_id and qq.question_id = quiz_attempt_answers.question_id
--   )
--
-- `quiz_questions` has no student-facing SELECT policy at all — its own
-- section header in 0015 says so explicitly: "students never query this
-- directly (served via RPC, Phase 4)". Exactly like 0023's `sections` bug:
-- Postgres re-applies a table's own RLS to every subquery that touches it,
-- regardless of which other policy's WITH CHECK embeds that subquery — so
-- this EXISTS(...) always evaluates to zero rows for a student caller,
-- meaning the WITH CHECK is always false and every student INSERT into
-- `quiz_attempt_answers` fails with 42501, unconditionally, regardless of
-- anything the Flutter app does. This is why every answer submission
-- failed during testing.
--
-- THE FIX
-- Add `app.quiz_has_question(p_quiz_id, p_question_id)`, mirroring
-- `app.student_section_school_year()` (0023) and `app.student_has_section()`
-- (0013) exactly — SECURITY DEFINER, narrow, single-purpose — then rewrite
-- the policy to call it instead of joining `quiz_questions` directly. Only
-- the WITH CHECK changes; the "answer must belong to the student's own
-- active attempt" clauses are untouched.
-- =============================================================================

create or replace function app.quiz_has_question(p_quiz_id uuid, p_question_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.quiz_questions qq
    where qq.quiz_id = p_quiz_id and qq.question_id = p_question_id
  );
$$;

comment on function app.quiz_has_question(uuid, uuid) is
  'Returns whether p_question_id belongs to p_quiz_id, bypassing RLS. SECURITY DEFINER, mirroring app.student_has_section()/app.student_section_school_year() — exists solely so quiz_attempt_answers_student_insert''s WITH CHECK can validate question membership without a raw join against quiz_questions, which has no student-visible SELECT policy and would otherwise silently return zero rows for a student caller (same recursive-RLS bug class as 0023, this time against quiz_questions instead of sections). Phase 6 prerequisite fix, found during live testing.';

grant execute on function app.quiz_has_question(uuid, uuid) to authenticated;

drop policy if exists quiz_attempt_answers_student_insert on public.quiz_attempt_answers;

create policy quiz_attempt_answers_student_insert on public.quiz_attempt_answers for insert
  with check (
    app.is_admin()
    or exists (
      select 1 from public.quiz_attempts qa
      where qa.id = quiz_attempt_answers.quiz_attempt_id
        and qa.student_id = app.current_student_id()
        and qa.attempt_status = 'active'
        and app.quiz_has_question(qa.quiz_id, quiz_attempt_answers.question_id)
    )
  );
