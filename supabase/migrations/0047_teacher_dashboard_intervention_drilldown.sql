-- =============================================================================
-- Migration: 0047_teacher_dashboard_intervention_drilldown.sql
-- Adds a dedicated drill-down endpoint for the Teacher Dashboard's
-- "Students Needing Help" tile (0037) and the Teacher Progress Reports'
-- "Students Requiring Intervention" tile (0046) — both tiles are backed by
-- the same underlying rule and, as of this migration, the same drill-down
-- data, so a teacher looking at either tile sees flagged students grouped
-- Grade Level -> Section -> Student instead of a flat/mixed list. This
-- mirrors the Admin Dashboard's own intervention drill-down
-- (app.admin_dashboard_intervention_students, 0041, grade_level added in
-- 0042), just teacher-scoped instead of system-wide.
--
-- NO EXISTING OBJECT IS MODIFIED. app.dashboard_student_roster (0037) and
-- app.dashboard_summary_tiles (0037) are untouched — this migration is
-- purely additive, a new function alongside them, not a replacement.
--
-- WHY A NEW FUNCTION RATHER THAN REUSING dashboard_student_roster (0037) —
-- that function already computes everything needed (including
-- `sections_scope.grade_level` internally), but its RETURNS TABLE does not
-- expose grade_level, and it deliberately returns the FULL roster (needed
-- for its own screen, which shows every student with a "Needs Help" badge
-- on the flagged ones) rather than only flagged students. Rather than
-- widen that function's output shape (a breaking change for its existing
-- caller, TeacherDashboardRosterScreen) or filter/re-group its full result
-- client-side on every screen that wants only the flagged subset, this
-- migration adds a second, narrower function that both new drill-down
-- entry points call directly: only the students matching the intervention
-- rule, with grade_level included from the start.
--
-- SECURITY MODEL — same as 0037's Functions 1-3: plain SECURITY INVOKER
-- (default, omitted below). The calling teacher already has full RLS
-- access to their own sections'/students' rows via
-- app.teacher_has_section()/app.teacher_has_student() (0015); there is no
-- privilege gap to close, so no SECURITY DEFINER escalation is introduced.
--
-- INTERVENTION RULE — identical to 0037's dashboard_summary_tiles /
-- dashboard_student_roster: average_quiz_score_percent < 70 (only when the
-- student has >= 1 completed quiz) OR >= 2 missed/unfinished expected
-- internal quizzes. Restated here, not re-derived differently.
--
-- NO GRADE/SECTION FILTER ARGUMENTS — unlike dashboard_student_roster
-- (which takes p_grade_level/p_section_id for its own dropdown-filtered
-- screen), this function always returns the teacher's FULL flagged list
-- across every section they teach. The two new drill-down screens group
-- that single result client-side (grade -> section -> student), the exact
-- same "one fetch, group locally" shape
-- AdminInterventionStudentsScreen/AdminInterventionSectionsScreen/
-- AdminInterventionStudentNamesScreen (0041/0042) already use.
-- =============================================================================

create or replace function app.dashboard_intervention_students()
returns table (
  student_id                  uuid,
  full_name                   text,
  grade_level                 grade_level,
  section_id                  uuid,
  section_name                text,
  average_quiz_score_percent  numeric,
  missed_or_unfinished_count  int
)
language sql
stable
as $$
  with sections_scope as (
    select sec.id as section_id, sec.name as section_name, sec.grade_level
    from public.sections sec
  ),
  students_scope as (
    select se.student_id, s.section_id, s.section_name, s.grade_level, st.full_name
    from sections_scope s
    join public.student_enrollments se
      on se.section_id = s.section_id
     and se.status = 'active'
    join public.students st on st.id = se.student_id
  ),
  expected_quizzes as (
    select ss.student_id, q.id as quiz_id
    from students_scope ss
    join public.quizzes q
      on q.source_type = 'built_in'
     and q.quiz_type = 'internal'
     and q.grade_level = ss.grade_level
    union
    select ss.student_id, q.id as quiz_id
    from students_scope ss
    join public.quiz_sections qs on qs.section_id = ss.section_id
    join public.quizzes q on q.id = qs.quiz_id
    where q.source_type = 'teacher'
      and q.quiz_type = 'internal'
  ),
  missed_or_unfinished as (
    select eq.student_id, eq.quiz_id
    from expected_quizzes eq
    where not exists (
      select 1 from public.v_student_current_quiz_attempts ca
      where ca.student_id = eq.student_id and ca.quiz_id = eq.quiz_id
    )
    and (
      not exists (
        select 1 from public.quiz_attempts qa
        where qa.student_id = eq.student_id and qa.quiz_id = eq.quiz_id
      )
      or exists (
        select 1 from public.quiz_attempts qa
        where qa.student_id = eq.student_id and qa.quiz_id = eq.quiz_id
          and qa.attempt_status = 'active' and qa.submitted_at is null
      )
    )
  ),
  student_quiz_stats as (
    select
      ss.student_id,
      round(avg(ca.score_percent), 1) as average_quiz_score_percent
    from students_scope ss
    left join public.v_student_current_quiz_attempts ca on ca.student_id = ss.student_id
    group by ss.student_id
  ),
  student_gap_counts as (
    select ss.student_id, count(mu.quiz_id)::int as missed_or_unfinished_count
    from students_scope ss
    left join missed_or_unfinished mu on mu.student_id = ss.student_id
    group by ss.student_id
  )
  select
    ss.student_id,
    ss.full_name,
    ss.grade_level,
    ss.section_id,
    ss.section_name,
    sq.average_quiz_score_percent,
    coalesce(sg.missed_or_unfinished_count, 0) as missed_or_unfinished_count
  from students_scope ss
  left join student_quiz_stats sq on sq.student_id = ss.student_id
  left join student_gap_counts sg on sg.student_id = ss.student_id
  where (sq.average_quiz_score_percent is not null and sq.average_quiz_score_percent < 70)
     or coalesce(sg.missed_or_unfinished_count, 0) >= 2
  order by ss.grade_level, ss.section_name, ss.full_name;
$$;

comment on function app.dashboard_intervention_students() is
  'Teacher Dashboard/Progress Reports (0047) drill-down: one row per actively-enrolled student, across every section the calling teacher teaches, matching the identical intervention rule as app.dashboard_summary_tiles/app.dashboard_student_roster (0037) — average_quiz_score_percent < 70 OR >= 2 missed/unfinished expected internal quizzes. Unlike dashboard_student_roster, only flagged students are returned (no full-roster mode) and grade_level is included, so the Flutter client can group Grade Level -> Section -> Student without a second fetch or a second query shape. No p_grade_level/p_section_id filter arguments — always the teacher''s full flagged list; the client groups it locally. SECURITY INVOKER (default) — same RLS-scoping reasoning as 0037''s Functions 1-3 (see that migration''s header): querying public.sections/public.students directly already RLS-scopes every row to the calling teacher''s own sections via app.teacher_has_section(), so no SECURITY DEFINER escalation is needed. Ordered grade_level, section_name, full_name so the client does not need to re-sort.';

revoke all on function app.dashboard_intervention_students() from public, anon, authenticated;
grant execute on function app.dashboard_intervention_students() to authenticated;


-- =============================================================================
-- public wrapper — thin pass-through, SECURITY INVOKER (default, omitted),
-- one-line `select * from app.<fn>();`, same shape 0037/0041's wrappers
-- use, reachable from the Flutter client via
-- `.rpc('dashboard_intervention_students')`.
-- =============================================================================
create or replace function public.dashboard_intervention_students()
returns table (
  student_id                  uuid,
  full_name                   text,
  grade_level                 grade_level,
  section_id                  uuid,
  section_name                text,
  average_quiz_score_percent  numeric,
  missed_or_unfinished_count  int
)
language sql
as $$
  select * from app.dashboard_intervention_students();
$$;

comment on function public.dashboard_intervention_students() is
  'Public-schema pass-through to app.dashboard_intervention_students (0047) so it is reachable via PostgREST from the Flutter client. No additional logic — SECURITY INVOKER (default), same as app.dashboard_intervention_students, since that function itself needs no privilege escalation (RLS already scopes every row read to the calling teacher).';

revoke all on function public.dashboard_intervention_students() from public, anon, authenticated;
grant execute on function public.dashboard_intervention_students() to authenticated;
