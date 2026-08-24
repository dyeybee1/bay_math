-- =============================================================================
-- Migration: 0018_phase0_prerequisites.sql
-- Phase 0 of the approved Phase 4 roadmap (Phase 4.1 Architecture Revision §6).
-- Implements exactly the six items specified there — no architectural changes,
-- no scope beyond what was approved.
-- =============================================================================


-- =============================================================================
-- 1. Parameterized service_role authorization functions (Phase 4.1 §1)
--
-- Each function independently re-derives authorization from its own explicit
-- parameters against current database state — never trusting that the calling
-- Edge Function already checked anything. This is the single source of truth
-- for these operations, not application control flow.
-- =============================================================================

create or replace function app.svc_fetch_quiz_content(
  p_student_id uuid,
  p_attempt_id uuid
)
returns table (
  question_id             uuid,
  prompt_text             text,
  question_display_order  smallint,
  choice_id               uuid,
  choice_text             text,
  choice_display_order    smallint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quiz_id uuid;
begin
  select qa.quiz_id into v_quiz_id
  from public.quiz_attempts qa
  where qa.id = p_attempt_id
    and qa.student_id = p_student_id
    and qa.attempt_status = 'active';

  if v_quiz_id is null then
    raise exception
      'attempt % is not an active attempt owned by student %', p_attempt_id, p_student_id;
  end if;

  return query
    select
      qb.id,
      qb.prompt_text,
      qq.display_order,
      qc.id,
      qc.choice_text,
      qc.display_order
    from public.quiz_questions qq
    join public.question_bank qb on qb.id = qq.question_id
    join public.question_choices qc on qc.question_id = qb.id
    where qq.quiz_id = v_quiz_id
    order by qq.display_order, qc.display_order;
end;
$$;

comment on function app.svc_fetch_quiz_content(uuid, uuid) is
  'Returns sanitized (no is_correct) question/choice content for an Internal Quiz attempt. Independently re-verifies the attempt belongs to p_student_id and is active before returning anything — does not trust the caller. service_role only. Phase 4.1 §1.';

revoke all on function app.svc_fetch_quiz_content(uuid, uuid) from public, anon, authenticated;
grant execute on function app.svc_fetch_quiz_content(uuid, uuid) to service_role;


create or replace function app.svc_check_quiz_answer(
  p_student_id  uuid,
  p_attempt_id  uuid,
  p_question_id uuid,
  p_choice_id   uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quiz_id    uuid;
  v_is_correct boolean;
begin
  select qa.quiz_id into v_quiz_id
  from public.quiz_attempts qa
  where qa.id = p_attempt_id
    and qa.student_id = p_student_id
    and qa.attempt_status = 'active';

  if v_quiz_id is null then
    raise exception
      'attempt % is not an active attempt owned by student %', p_attempt_id, p_student_id;
  end if;

  if not exists (
    select 1 from public.quiz_questions
    where quiz_id = v_quiz_id and question_id = p_question_id
  ) then
    raise exception 'question % is not part of quiz %', p_question_id, v_quiz_id;
  end if;

  select is_correct into v_is_correct
  from public.question_choices
  where id = p_choice_id and question_id = p_question_id;

  if v_is_correct is null then
    raise exception 'choice % does not belong to question %', p_choice_id, p_question_id;
  end if;

  return v_is_correct;
end;
$$;

comment on function app.svc_check_quiz_answer(uuid, uuid, uuid, uuid) is
  'Authoritative correctness check for one Internal Quiz answer. Independently re-verifies attempt ownership/active status, question membership, and choice membership before returning a result. service_role only. Phase 4.1 §1.';

revoke all on function app.svc_check_quiz_answer(uuid, uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function app.svc_check_quiz_answer(uuid, uuid, uuid, uuid) to service_role;


create or replace function app.svc_fetch_endless_question(
  p_student_id uuid
)
returns table (
  question_id           uuid,
  prompt_text           text,
  choice_id             uuid,
  choice_text           text,
  choice_display_order  smallint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_question_id uuid;
begin
  if not exists (select 1 from public.students where id = p_student_id) then
    raise exception 'student % not found', p_student_id;
  end if;

  select qb.id into v_question_id
  from public.question_bank qb
  order by random()
  limit 1;

  if v_question_id is null then
    raise exception 'no questions available in question_bank';
  end if;

  return query
    select
      qb.id,
      qb.prompt_text,
      qc.id,
      qc.choice_text,
      qc.display_order
    from public.question_bank qb
    join public.question_choices qc on qc.question_id = qb.id
    where qb.id = v_question_id
    order by qc.display_order;
end;
$$;

comment on function app.svc_fetch_endless_question(uuid) is
  'Returns one sanitized (no is_correct) practice question. Endless Quiz is not scoped to a section or quiz, so the only check is that p_student_id is a real student. Question-selection logic here is a deliberately simple baseline (uniform random) — refining it (topic/difficulty targeting) is a future enhancement, not an architectural change. service_role only. Phase 4.1 §1.';

revoke all on function app.svc_fetch_endless_question(uuid) from public, anon, authenticated;
grant execute on function app.svc_fetch_endless_question(uuid) to service_role;


create or replace function app.svc_check_endless_answer(
  p_student_id  uuid,
  p_question_id uuid,
  p_choice_id   uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_correct boolean;
begin
  if not exists (select 1 from public.students where id = p_student_id) then
    raise exception 'student % not found', p_student_id;
  end if;

  select is_correct into v_is_correct
  from public.question_choices
  where id = p_choice_id and question_id = p_question_id;

  if v_is_correct is null then
    raise exception 'choice % does not belong to question %', p_choice_id, p_question_id;
  end if;

  return v_is_correct;
end;
$$;

comment on function app.svc_check_endless_answer(uuid, uuid, uuid) is
  'Authoritative correctness check for one Endless Quiz practice answer. service_role only. Phase 4.1 §1.';

revoke all on function app.svc_check_endless_answer(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function app.svc_check_endless_answer(uuid, uuid, uuid) to service_role;


-- =============================================================================
-- 2. Harden app.log_audit_event() against student-session callers (Phase 4.1 §3)
--
-- Backward compatible: signature is unchanged, so every existing caller
-- (teacher-forwarded-JWT calls in 0017, the trigger-based audit calls in 0014)
-- continues to work exactly as before. The only new behavior is an immediate,
-- explicit failure if a student's own forwarded JWT ever reaches this
-- function — which cannot happen via any code path that exists today, but
-- previously would have failed with a confusing foreign-key error instead of
-- an intentional one if it ever did.
-- =============================================================================

create or replace function app.log_audit_event(
  p_action       text,
  p_target_table text,
  p_target_id    uuid,
  p_metadata     jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_role audit_actor_role;
  v_log_id uuid;
begin
  if app.current_student_id() is not null then
    raise exception
      'app.log_audit_event: student sessions are not audited actors (Phase 4.1 §3 decision)';
  end if;

  select case role
           when 'admin' then 'admin'::audit_actor_role
           when 'teacher' then 'teacher'::audit_actor_role
         end
    into v_actor_role
    from public.profiles
    where id = auth.uid();

  if v_actor_role is null then
    v_actor_role := 'system';
  end if;

  insert into public.audit_logs (actor_profile_id, actor_role, action, target_table, target_id, metadata)
  values (auth.uid(), v_actor_role, p_action, p_target_table, p_target_id, p_metadata)
  returning id into v_log_id;

  return v_log_id;
end;
$$;

comment on function app.log_audit_event(text, text, uuid, jsonb) is
  'The sole write path into audit_logs. Explicitly rejects calls made over a student''s own forwarded JWT — student actions are not audited actors, by design (Phase 4.1 §3). service_role-authenticated calls (e.g. from student-login, which has no student JWT context yet) are unaffected.';


-- =============================================================================
-- 3. students.best_endless_streak maintenance trigger (Phase 4.1 §3)
--
-- Composes with the existing set_updated_at trigger already on `students`
-- (0014) — the UPDATE performed here automatically bumps students.updated_at
-- too, with no extra step required.
-- =============================================================================

create or replace function app.update_best_endless_streak()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.students
  set best_endless_streak = greatest(best_endless_streak, new.best_streak_session)
  where id = new.student_id;

  return new;
end;
$$;

comment on function app.update_best_endless_streak() is
  'Raises students.best_endless_streak to the new session''s peak if it exceeds the current all-time record. SECURITY DEFINER is required: the triggering INSERT into endless_quiz_sessions happens over the student''s own forwarded JWT (authenticated role), whose UPDATE grant on students is column-restricted and does not include best_endless_streak (0016) — without this, the write would fail with a permission error on every call. Phase 4.1 §3.';

create trigger update_best_streak after insert on public.endless_quiz_sessions
  for each row execute function app.update_best_endless_streak();


-- =============================================================================
-- 4. Endless Quiz summary plausibility constraint (Phase 4.1 §3)
--
-- Free, declarative rejection of the most nonsensical forged session
-- summaries. Does not fully close the self-reported-summary gap (a
-- plausible-but-fake value still passes) — that residual risk is explicitly
-- accepted per Phase 4.1 §3, not overlooked. No existing data in this table
-- to validate against yet, so a direct ADD CONSTRAINT is safe.
-- =============================================================================

alter table public.endless_quiz_sessions
  add constraint endless_quiz_sessions_streak_le_questions
  check (best_streak_session <= questions_answered);


-- =============================================================================
-- 5. Tighten quiz_questions write policy: validate referenced question
--    ownership, not just the parent quiz's (Phase 4.1 §3)
--
-- Only WITH CHECK changes — USING (which rows can be targeted for
-- update/delete) is unchanged, since this fix is about preventing new
-- unauthorized references, not retroactively restricting access to rows that
-- were already valid when created.
-- =============================================================================

drop policy if exists quiz_questions_teacher_write on public.quiz_questions;

create policy quiz_questions_teacher_write on public.quiz_questions for all
  using (
    app.is_admin()
    or exists (
      select 1 from public.quizzes q
      where q.id = quiz_questions.quiz_id
        and q.source_type = 'teacher' and q.created_by = auth.uid()
    )
  )
  with check (
    app.is_admin()
    or (
      exists (
        select 1 from public.quizzes q
        where q.id = quiz_questions.quiz_id
          and q.source_type = 'teacher' and q.created_by = auth.uid()
      )
      and exists (
        select 1 from public.question_bank qb
        where qb.id = quiz_questions.question_id
          and (qb.source_type = 'built_in' or qb.created_by = auth.uid())
      )
    )
  );


-- =============================================================================
-- 6. quiz_attempts.total_questions auto-population trigger (Phase 4.1 §3)
--
-- Upgraded from an Edge-Function responsibility ("must remember to set it")
-- to a DB-enforced guarantee. Only fires when the caller didn't already
-- supply a value, and only populates it for Internal Quizzes — left NULL for
-- External Activities, matching the schema's existing semantics (schema §3.16:
-- "nullable — snapshot of question count at attempt time (internal only)")
-- rather than writing a misleading 0.
-- =============================================================================

create or replace function app.set_total_questions_on_attempt()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_quiz_type quiz_type;
begin
  if new.total_questions is null then
    select quiz_type into v_quiz_type
    from public.quizzes
    where id = new.quiz_id;

    if v_quiz_type = 'internal' then
      select count(*) into new.total_questions
      from public.quiz_questions
      where quiz_id = new.quiz_id;
    end if;
  end if;

  return new;
end;
$$;

comment on function app.set_total_questions_on_attempt() is
  'Auto-populates quiz_attempts.total_questions at insert time for Internal Quizzes when not already supplied. Left NULL for External Activities. Phase 4.1 §3.';

create trigger set_total_questions before insert on public.quiz_attempts
  for each row execute function app.set_total_questions_on_attempt();


-- =============================================================================
-- 7. Extend frozen-field protection to include total_questions (agreed
--    hardening, not part of the original six-item scope) — added because
--    total_questions is now a database-generated snapshot value, same as
--    section_id/school_year_id, and should be equally immutable after insert.
--
-- CREATE OR REPLACE on the existing function (0014) — same signature, so the
-- existing trigger (protect_frozen_fields before update on quiz_attempts)
-- picks up the new body automatically; no trigger re-creation needed.
-- =============================================================================

create or replace function app.quiz_attempts_protect_frozen_fields()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.student_id       is distinct from old.student_id
     or new.quiz_id        is distinct from old.quiz_id
     or new.section_id     is distinct from old.section_id
     or new.school_year_id is distinct from old.school_year_id
     or new.opened_at      is distinct from old.opened_at
     or new.total_questions is distinct from old.total_questions then
    raise exception
      'quiz_attempts: student_id, quiz_id, section_id, school_year_id, opened_at, and total_questions are frozen historical context and cannot be modified after insert (attempt id %)',
      old.id;
  end if;
  return new;
end;
$$;
