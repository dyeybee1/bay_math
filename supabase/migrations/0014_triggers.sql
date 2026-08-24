-- =============================================================================
-- Migration: 0014_triggers.sql
-- Implements every trigger-based enforcement item from the Phase 3 request:
--   1. updated_at maintenance (housekeeping, not from the explicit list, but
--      required by every table's own NOT NULL updated_at column).
--   2. Preventing modification of historical snapshot fields after insert
--      (quiz_attempts frozen fields; full immutability on the two answer
--      snapshot tables).
--   3. Enforcing at least one correct choice per question.
--   4. Preventing quiz_questions rows on non-Internal quizzes.
--   5. Trigger-detectable audit events (reset, approval, assignment) — see
--      the note near the bottom on which audit actions CANNOT be triggers.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Generic updated_at maintenance
-- ---------------------------------------------------------------------------
create or replace function app.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger set_updated_at before update on public.schools
  for each row execute function app.set_updated_at();
create trigger set_updated_at before update on public.school_years
  for each row execute function app.set_updated_at();
create trigger set_updated_at before update on public.profiles
  for each row execute function app.set_updated_at();
create trigger set_updated_at before update on public.sections
  for each row execute function app.set_updated_at();
create trigger set_updated_at before update on public.teacher_sections
  for each row execute function app.set_updated_at();
create trigger set_updated_at before update on public.students
  for each row execute function app.set_updated_at();
create trigger set_updated_at before update on public.student_enrollments
  for each row execute function app.set_updated_at();
create trigger set_updated_at before update on public.lessons
  for each row execute function app.set_updated_at();
create trigger set_updated_at before update on public.lesson_progress
  for each row execute function app.set_updated_at();
create trigger set_updated_at before update on public.question_bank
  for each row execute function app.set_updated_at();
create trigger set_updated_at before update on public.quizzes
  for each row execute function app.set_updated_at();
create trigger set_updated_at before update on public.quiz_attempts
  for each row execute function app.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2a. quiz_attempts — protect frozen historical-context fields after insert
-- (schema §3.16: student_id/quiz_id/section_id/school_year_id/opened_at are
-- all "captured once, frozen" — attempt_status/score/submitted_at/reset_by/
-- reset_at/total_questions remain legitimately updatable, e.g. on reset).
-- ---------------------------------------------------------------------------
create or replace function app.quiz_attempts_protect_frozen_fields()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.student_id      is distinct from old.student_id
     or new.quiz_id       is distinct from old.quiz_id
     or new.section_id    is distinct from old.section_id
     or new.school_year_id is distinct from old.school_year_id
     or new.opened_at     is distinct from old.opened_at then
    raise exception
      'quiz_attempts: student_id, quiz_id, section_id, school_year_id, and opened_at are frozen historical context and cannot be modified after insert (attempt id %)',
      old.id;
  end if;
  return new;
end;
$$;

create trigger protect_frozen_fields before update on public.quiz_attempts
  for each row execute function app.quiz_attempts_protect_frozen_fields();

-- ---------------------------------------------------------------------------
-- 2b. quiz_attempt_answers / quiz_attempt_answer_choice_snapshots —
-- fully immutable after insert. Nothing about a submitted answer or its
-- snapshot ever legitimately changes (grading happens at insert time, per
-- the one-attempt-immediate-reveal policy) — so the simplest, most airtight
-- enforcement is to block ALL updates outright, not field-by-field.
-- ---------------------------------------------------------------------------
create or replace function app.block_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  raise exception
    '% rows are immutable historical snapshots and cannot be updated (id %)',
    tg_table_name, old.id;
end;
$$;

create trigger block_update before update on public.quiz_attempt_answers
  for each row execute function app.block_update();

create trigger block_update before update on public.quiz_attempt_answer_choice_snapshots
  for each row execute function app.block_update();

-- ---------------------------------------------------------------------------
-- 3. Every question in question_bank must have at least one correct choice.
-- Cross-row invariant (schema §3.12 / §9 Recommendation 5) — implemented as
-- a deferred constraint trigger so a question and its choices can be
-- inserted in the same transaction without ordering problems; the check
-- runs once at COMMIT against the final state.
--
-- AUDIT FINDING (Severity: HIGH, fixed here): the original version always
-- re-counted correct choices for the affected question_id, with no check
-- for whether the parent question_bank row itself still exists. Deleting a
-- question (which the RLS policies explicitly permit an owning teacher/
-- admin to do) cascades to delete all of its question_choices rows too —
-- and each of those cascaded deletes fired this same deferred trigger,
-- which would find zero remaining correct choices and raise an exception,
-- making it IMPOSSIBLE to ever delete a question that had choices (i.e.
-- every real question). The fix: skip the check entirely once the parent
-- question is gone — there is nothing left to validate.
-- ---------------------------------------------------------------------------
create or replace function app.question_choices_enforce_at_least_one_correct()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_question_id uuid;
  v_correct_count integer;
begin
  v_question_id := coalesce(new.question_id, old.question_id);

  if not exists (select 1 from public.question_bank where id = v_question_id) then
    -- Parent question was deleted (this row arrived here via ON DELETE
    -- CASCADE) — nothing to validate.
    return null;
  end if;

  select count(*) into v_correct_count
  from public.question_choices
  where question_id = v_question_id and is_correct = true;

  if v_correct_count = 0 then
    raise exception
      'question_bank %: every question must have at least one correct choice',
      v_question_id;
  end if;

  return null; -- constraint trigger return value is ignored
end;
$$;

create constraint trigger enforce_at_least_one_correct
  after insert or update or delete on public.question_choices
  deferrable initially deferred
  for each row execute function app.question_choices_enforce_at_least_one_correct();

-- ---------------------------------------------------------------------------
-- 4. quiz_questions rows must only exist for quiz_type = 'internal'.
-- Cross-table invariant (schema §3.15 / §9 Recommendation 5).
-- ---------------------------------------------------------------------------
create or replace function app.quiz_questions_enforce_internal_only()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_quiz_type quiz_type;
begin
  select quiz_type into v_quiz_type from public.quizzes where id = new.quiz_id;

  if v_quiz_type is distinct from 'internal' then
    raise exception
      'quiz_questions: quiz % is not an Internal Quiz (quiz_type = %); External Activities cannot have quiz_questions rows',
      new.quiz_id, v_quiz_type;
  end if;

  return new;
end;
$$;

create trigger enforce_internal_only before insert or update on public.quiz_questions
  for each row execute function app.quiz_questions_enforce_internal_only();

-- ---------------------------------------------------------------------------
-- 5. Trigger-detectable audit events.
--
-- IMPORTANT SCOPE NOTE: only state transitions that are actually visible as
-- a row change belong here. Credential view/print/export (schema §10) have
-- no corresponding row mutation — viewing a password changes nothing in the
-- database — so those CANNOT be captured by a trigger and must be logged by
-- the application explicitly calling app.log_audit_event() at the moment
-- they happen (a Phase 4 concern). The three events below ARE row-level
-- state transitions and are captured here.
-- ---------------------------------------------------------------------------

-- 5a. Quiz attempt reset (active -> superseded transition).
create or replace function app.audit_quiz_attempt_reset()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.attempt_status = 'active' and new.attempt_status = 'superseded' then
    perform app.log_audit_event(
      'quiz_attempt_reset',
      'quiz_attempts',
      new.id,
      jsonb_build_object(
        'student_id', new.student_id,
        'quiz_id', new.quiz_id,
        'reset_by', new.reset_by
      )
    );
  end if;
  return new;
end;
$$;

create trigger audit_reset after update on public.quiz_attempts
  for each row execute function app.audit_quiz_attempt_reset();

-- 5b. Teacher approval/rejection/suspension (profiles.status transition).
create or replace function app.audit_profile_status_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.role = 'teacher' and old.status is distinct from new.status then
    perform app.log_audit_event(
      'teacher_status_changed',
      'profiles',
      new.id,
      jsonb_build_object('from_status', old.status, 'to_status', new.status)
    );
  end if;
  return new;
end;
$$;

create trigger audit_status_change after update on public.profiles
  for each row execute function app.audit_profile_status_change();

-- 5c. Teacher/section (re)assignment.
create or replace function app.audit_teacher_section_assigned()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  perform app.log_audit_event(
    'teacher_section_assigned',
    'teacher_sections',
    new.id,
    jsonb_build_object(
      'teacher_id', new.teacher_id,
      'section_id', new.section_id,
      'is_primary', new.is_primary,
      'assigned_by', new.assigned_by
    )
  );
  return new;
end;
$$;

create trigger audit_assignment after insert on public.teacher_sections
  for each row execute function app.audit_teacher_section_assigned();
