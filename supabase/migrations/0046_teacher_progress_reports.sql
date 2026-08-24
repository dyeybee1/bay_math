-- =============================================================================
-- Migration: 0046_teacher_progress_reports.sql
--
-- Adds one new RPC feeding the Teacher Progress Reports per-student x
-- per-topic mastery heatmap: app.dashboard_student_topic_mastery, plus its
-- public.* pass-through wrapper. Additive only — no existing migration
-- (including 0037/0038) is modified.
--
-- SHAPE: this is app.dashboard_competency_mastery (0037, Function 4)
-- widened from "grouped by topic" to "grouped by (student, section, topic)"
-- — same sections_scope / students_scope / answered CTE skeleton, same
-- SECURITY DEFINER treatment, same grant pattern. student_id/full_name/
-- section_id/section_name are sourced the same way
-- dashboard_student_roster (0037 Function 3, as fixed by 0038) sources
-- them: sections_scope carries section_name/grade_level off
-- public.sections, students_scope joins public.student_enrollments (active
-- only) then public.students for full_name.
--
-- NOT INCLUDED (per locked product decisions — do not add later without a
-- new migration):
--   - No Quarter / grading-period filter parameter.
--   - No Easy/Medium difficulty-tag column or filter.
--   - No mastery-band/label column — mastery_percent is returned raw,
--     numeric, exactly like dashboard_competency_mastery; band bucketing
--     (<70 / 70-84 / >=85) is a client-side Dart concern.
--   - No averaging/top-N — one row per student per topic, full roster.
--
-- WHY SECURITY DEFINER (identical reasoning to app.dashboard_competency_mastery,
-- 0037 Function 4 — restated in full here per this codebase's convention of
-- not making a future reader chase a comment in a different file):
-- question_bank_teacher_select (0015) only lets a teacher read a
-- question_bank row they authored themselves, or a source_type = 'built_in'
-- row — never another teacher's source_type = 'teacher' row. This
-- function's job is: for a student in one of the CALLING teacher's own
-- sections, group that student's answered questions by
-- (student, topic). That student may have answered a question authored by
-- a different teacher than the one calling this function (shared content,
-- co-teachers on a section, section handoffs across school years) — see
-- 0037 header and 0038 header for the same underlying fact pattern
-- (teacher_sections has no one-teacher-per-section constraint). A plain
-- SECURITY INVOKER version would silently drop every such question from a
-- given student's per-topic counts — not error, just quietly under-count,
-- which is worse than an obvious failure for a report a teacher may act on.
-- SECURITY DEFINER closes exactly that one gap and no other: it does NOT
-- widen question_bank_teacher_select itself (untouched by this migration),
-- and it does not let the calling teacher browse question_bank freely or
-- see topics for questions no student of theirs has answered — the
-- `answered` CTE below only ever selects a question_bank row reached via a
-- join from a students_scope row, and students_scope itself is
-- independently re-derived (never trusted from a parameter) by calling
-- app.teacher_has_section() explicitly inside this function body for every
-- section considered, exactly mirroring dashboard_competency_mastery's own
-- re-derivation. p_section_id is filtered the same way — checked every
-- call via app.teacher_has_section(), never trusted as "already authorized
-- by the caller".
-- =============================================================================

create or replace function app.dashboard_student_topic_mastery(
  p_grade_level grade_level default null,
  p_section_id  uuid default null
)
returns table (
  student_id         uuid,
  full_name          text,
  section_id         uuid,
  section_name       text,
  topic              text,
  questions_total    int,
  questions_correct  int,
  mastery_percent    numeric
)
language sql
stable
security definer
set search_path = public
as $$
  with sections_scope as (
    select sec.id as section_id, sec.name as section_name
    from public.sections sec
    where app.teacher_has_section(sec.id)
      and (p_grade_level is null or sec.grade_level = p_grade_level)
      and (p_section_id is null or sec.id = p_section_id)
  ),
  students_scope as (
    select se.student_id, s.section_id, s.section_name, st.full_name
    from sections_scope s
    join public.student_enrollments se
      on se.section_id = s.section_id
     and se.status = 'active'
    join public.students st on st.id = se.student_id
  ),
  answered as (
    select
      ss.student_id, ss.full_name, ss.section_id, ss.section_name,
      qb.topic, qaa.is_correct
    from students_scope ss
    join public.v_student_current_quiz_attempts ca on ca.student_id = ss.student_id
    join public.quiz_attempt_answers qaa on qaa.quiz_attempt_id = ca.quiz_attempt_id
    join public.question_bank qb on qb.id = qaa.question_id
    where qb.topic is not null
  )
  select
    student_id,
    full_name,
    section_id,
    section_name,
    topic,
    count(*)::int as questions_total,
    count(*) filter (where is_correct)::int as questions_correct,
    round(100.0 * count(*) filter (where is_correct) / nullif(count(*), 0), 1) as mastery_percent
  from answered
  group by student_id, full_name, section_id, section_name, topic
  order by full_name, topic;
$$;

comment on function app.dashboard_student_topic_mastery(grade_level, uuid) is
  'Teacher Progress Reports per-student x per-topic mastery heatmap feed (0046), regular quizzes only (rides on v_student_current_quiz_attempts, 0035, same exclusion reasoning as dashboard_competency_mastery, 0037). One row per (student, topic) for every actively-enrolled student in scope — full roster, not averaged or top/bottom-N. SECURITY DEFINER — see the function-level comment above this CREATE FUNCTION for the full justification (question_bank_teacher_select, 0015, cannot see another teacher''s authored questions, which this function''s job requires, identical to dashboard_competency_mastery, 0037). Section ownership is independently re-derived via app.teacher_has_section() inside this function body on every call, for both the unfiltered and p_section_id-filtered cases — never trusted from the parameter. mastery_percent is returned raw (no band/label column) — banding is a client-side Dart concern. Grants execute to authenticated only, same as every other dashboard RPC; not exposed beyond that.';

revoke all on function app.dashboard_student_topic_mastery(grade_level, uuid) from public, anon, authenticated;
grant execute on function app.dashboard_student_topic_mastery(grade_level, uuid) to authenticated;


-- =============================================================================
-- public.dashboard_student_topic_mastery — thin pass-through, SECURITY
-- INVOKER (default, omitted below), exact one-line `select * from
-- app.<fn>(...)` pattern already used for every other dashboard RPC's
-- public wrapper (0037/0038), so this is reachable via PostgREST from the
-- Flutter client.
-- =============================================================================
create or replace function public.dashboard_student_topic_mastery(
  p_grade_level grade_level default null,
  p_section_id  uuid default null
)
returns table (
  student_id         uuid,
  full_name          text,
  section_id         uuid,
  section_name       text,
  topic              text,
  questions_total    int,
  questions_correct  int,
  mastery_percent    numeric
)
language sql
as $$
  select * from app.dashboard_student_topic_mastery(p_grade_level, p_section_id);
$$;

comment on function public.dashboard_student_topic_mastery(grade_level, uuid) is
  'Public-schema pass-through to app.dashboard_student_topic_mastery (0046) so it is reachable via PostgREST from the Flutter client.';

revoke all on function public.dashboard_student_topic_mastery(grade_level, uuid) from public, anon, authenticated;
grant execute on function public.dashboard_student_topic_mastery(grade_level, uuid) to authenticated;
