-- =============================================================================
-- Migration: 0097_grade_scope_endless_quiz.sql
--
-- Endless Quiz originally selected directly from all of question_bank (0018).
-- That bypassed the authoritative quiz/enrollment relationships and allowed a
-- student to receive, or submit an answer for, another grade's question.
--
-- Eligibility now follows the same relationships as normal Student quizzes:
--   active Student -> active enrollment -> active section
--   -> same-grade built-in quizzes OR teacher quizzes assigned to that section
--   -> quiz_questions -> one canonical question_bank id
--
-- The helper returns DISTINCT ids so a question reused by Pre-/Post-Test or by
-- any other eligible quizzes contributes only once to the random pool. There
-- is intentionally no client-supplied grade parameter.
-- =============================================================================

create or replace function app.endless_quiz_eligible_question_ids(
  p_student_id uuid
)
returns table (question_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct link.question_id
  from public.students student
  join public.student_enrollments enrollment
    on enrollment.student_id = student.id
   and enrollment.status = 'active'
  join public.sections section
    on section.id = enrollment.section_id
   and section.status = 'active'
  join public.quizzes quiz
    on quiz.quiz_type = 'internal'
   and (
     (
       quiz.source_type = 'built_in'
       and quiz.grade_level = section.grade_level
     )
     or (
       quiz.source_type = 'teacher'
       and exists (
         select 1
         from public.quiz_sections assignment
         where assignment.quiz_id = quiz.id
           and assignment.section_id = section.id
       )
     )
   )
  join public.quiz_questions link on link.quiz_id = quiz.id
  where student.id = p_student_id
    and student.status = 'active';
$$;

comment on function app.endless_quiz_eligible_question_ids(uuid) is
  'Canonical DISTINCT Endless Quiz question ids for one active Student, derived server-side from active enrollment/section and eligible quizzes. Built-ins must match sections.grade_level; teacher quizzes must be assigned to the Student''s actual section. No client grade is accepted. Added 0097.';

revoke all on function app.endless_quiz_eligible_question_ids(uuid)
  from public, anon, authenticated;
grant execute on function app.endless_quiz_eligible_question_ids(uuid)
  to service_role;

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
set search_path = ''
as $$
declare
  v_question_id uuid;
begin
  if not exists (
    select 1
    from public.students student
    where student.id = p_student_id
      and student.status = 'active'
  ) then
    raise exception 'active student % not found', p_student_id;
  end if;

  if not exists (
    select 1
    from public.student_enrollments enrollment
    join public.sections section on section.id = enrollment.section_id
    where enrollment.student_id = p_student_id
      and enrollment.status = 'active'
      and section.status = 'active'
  ) then
    raise exception 'student % has no active enrollment', p_student_id;
  end if;

  select eligible.question_id
  into v_question_id
  from app.endless_quiz_eligible_question_ids(p_student_id) eligible
  order by random()
  limit 1;

  if v_question_id is null then
    raise exception 'no endless quiz questions available for student grade';
  end if;

  return query
    select
      question.id,
      question.prompt_text,
      choice.id,
      choice.choice_text,
      choice.display_order
    from public.question_bank question
    join public.question_choices choice
      on choice.question_id = question.id
    where question.id = v_question_id
    order by choice.display_order;
end;
$$;

comment on function app.svc_fetch_endless_question(uuid) is
  'Returns one sanitized random question from the Student''s server-derived, grade/section-eligible DISTINCT quiz question pool. Reads choices only for the selected eligible question. service_role only. Grade-scoped in 0097.';

revoke all on function app.svc_fetch_endless_question(uuid)
  from public, anon, authenticated;
grant execute on function app.svc_fetch_endless_question(uuid)
  to service_role;

create or replace function app.svc_check_endless_answer(
  p_student_id  uuid,
  p_question_id uuid,
  p_choice_id   uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_is_correct boolean;
begin
  if not exists (
    select 1
    from public.students student
    where student.id = p_student_id
      and student.status = 'active'
  ) then
    raise exception 'active student % not found', p_student_id;
  end if;

  if not exists (
    select 1
    from app.endless_quiz_eligible_question_ids(p_student_id) eligible
    where eligible.question_id = p_question_id
  ) then
    raise exception 'question % is not eligible for student %',
      p_question_id,
      p_student_id;
  end if;

  select choice.is_correct
  into v_is_correct
  from public.question_choices choice
  where choice.id = p_choice_id
    and choice.question_id = p_question_id;

  if v_is_correct is null then
    raise exception 'choice % does not belong to question %',
      p_choice_id,
      p_question_id;
  end if;

  return v_is_correct;
end;
$$;

comment on function app.svc_check_endless_answer(uuid, uuid, uuid) is
  'Authoritative Endless Quiz answer check. Rejects a question unless it belongs to the same server-derived eligible pool used by fetching, preventing direct cross-grade question-id submission. service_role only. Grade-scoped in 0097.';

revoke all on function app.svc_check_endless_answer(uuid, uuid, uuid)
  from public, anon, authenticated;
grant execute on function app.svc_check_endless_answer(uuid, uuid, uuid)
  to service_role;
