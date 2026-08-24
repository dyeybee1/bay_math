-- =============================================================================
-- Migration: 0041_admin_dashboard_tile_drilldowns.sql
-- Adds drill-down data behind 5 of the Admin Dashboard's 6 summary tiles
-- (0039/0040). Flutter wiring (models/repository/providers/screens) is a
-- separate, later change; this migration is SQL only.
--
-- WHICH TILES GET A DRILL-DOWN (product decision) — Total Students does
-- NOT get one in this migration (out of scope, not requested). The other
-- five do, each shaped differently per spec:
--   - Total Teachers                 -> flat list of teachers
--   - Total Sections                 -> flat list of sections (sections
--                                        only — no per-student rows)
--   - Total Quiz Attempts            -> two levels: grade level first,
--                                        then (tapping a grade) that
--                                        grade's sections — no per-student
--                                        level
--   - Average Mathematics Score      -> two levels, same grade-then-
--                                        section shape as Total Quiz
--                                        Attempts, no per-student level.
--                                        Level 1 reuses the EXISTING
--                                        app.admin_dashboard_score_by_grade
--                                        (0039) unchanged — it already
--                                        returns exactly this. Only level
--                                        2 (score by section within a
--                                        grade) is new here.
--   - Students Requiring Intervention -> flat list of the actual students
--                                        counted by that tile (0040's
--                                        rule: avg < 70 OR >= 2 missed/
--                                        unfinished)
--
-- Every new function below follows the exact same 3-layer shape and
-- security posture 0039/0040 already established: internal `app.v_*`
-- views (`security_invoker = true`, unreachable from PostgREST), plain
-- `plpgsql security definer set search_path = public` `app.admin_dashboard_*`
-- functions each starting with the `app.is_admin()` guard, and thin
-- `public.admin_dashboard_*` wrappers (`security invoker`, one-line
-- pass-through) so the Flutter client can reach them via `.rpc(...)`. No
-- existing object is dropped; two existing views gain new columns via
-- `create or replace view` (see each view's own note below) and one
-- existing function (app.admin_dashboard_summary_tiles) is untouched.
-- =============================================================================


-- =============================================================================
-- View 2 (extended) — app.v_admin_completed_quiz_attempts
--
-- Adds section_id (the historical section_id frozen on the quiz_attempts
-- row at insert time, per 0010 — the same "attempt's own section snapshot"
-- concept 0037's header already establishes for the Teacher Dashboard).
-- Appended as the LAST column so no existing named-column consumer
-- (app.v_admin_current_quiz_attempts, app.admin_dashboard_summary_tiles'
-- total_quiz_attempts COUNT(*)) is affected — neither reads section_id nor
-- uses `select *`. Needed by app.admin_dashboard_quiz_attempts_by_grade and
-- app.admin_dashboard_quiz_attempts_by_section (below): the Total Quiz
-- Attempts tile counts EVERY completed attempt including superseded
-- retakes (0039's own stated reasoning), so its grade/section breakdown
-- must attribute by each individual attempt's own frozen section — not by
-- a student's CURRENT section (app.v_admin_active_student_sections) or
-- current-attempt-only data (app.v_admin_current_quiz_attempts) which
-- would silently drop superseded rows and disagree with the parent tile's
-- own count.
-- =============================================================================
create or replace view app.v_admin_completed_quiz_attempts
with (security_invoker = true) as
select
  qa.id                as quiz_attempt_id,
  qa.student_id,
  qa.quiz_id,
  qa.school_year_id,
  round(100.0 * qa.score / nullif(qa.total_questions, 0), 1) as score_percent,
  qa.section_id
from public.quiz_attempts qa
where qa.submitted_at is not null
  and qa.school_year_id in (select school_year_id from app.v_admin_current_school_year_ids);

comment on view app.v_admin_completed_quiz_attempts is
  'Admin Dashboard (0039, extended 0041) internal building block: one row per completed (submitted_at is not null) regular-quiz attempt in the current school year(s), including superseded retake attempts — intentionally NOT deduped. section_id (0041) is the historical section_id frozen on the quiz_attempts row at insert time (0010), appended last so no existing named-column consumer is affected. Backs the Total Quiz Attempts raw activity count AND (0041) its grade/section breakdown; every score/proficiency/intervention metric instead reads app.v_admin_current_quiz_attempts (view 3), which IS deduped. Endless Quiz excluded by construction. security_invoker; only ever read from inside SECURITY DEFINER app.admin_dashboard_* functions.';


-- =============================================================================
-- View 6 (extended) — app.v_admin_active_student_sections
--
-- Adds section_name (from public.sections.name), appended last, needed by
-- app.admin_dashboard_intervention_students (below) to show each flagged
-- student's current section by name without a second join at the call
-- site. Introduced in 0040; no existing consumer (app.v_admin_expected_
-- quizzes, app.v_admin_missed_or_unfinished_counts) reads section_name or
-- uses `select *`, so this is a safe append.
-- =============================================================================
create or replace view app.v_admin_active_student_sections
with (security_invoker = true) as
select
  se.student_id,
  sec.id as section_id,
  sec.grade_level,
  sec.name as section_name
from public.student_enrollments se
join public.sections sec on sec.id = se.section_id
join app.v_admin_active_students act on act.student_id = se.student_id
where se.status = 'active'
  and sec.school_year_id in (select school_year_id from app.v_admin_current_school_year_ids)
  and sec.status = 'active';

comment on view app.v_admin_active_student_sections is
  'Admin Dashboard (0040, extended 0041) internal building block: one row per currently-active student (app.v_admin_active_students) and the section_id/grade_level/section_name (0041, appended last) of their current active enrollment (current school year, section status = ''active''). Feeds app.v_admin_expected_quizzes/app.v_admin_missed_or_unfinished_counts (0040) and app.admin_dashboard_intervention_students (0041). security_invoker; only ever read from inside SECURITY DEFINER app.admin_dashboard_* functions.';


-- =============================================================================
-- Function — app.admin_dashboard_teachers_list
--
-- Flat list backing the Total Teachers tile: every approved teacher
-- (same population admin_dashboard_summary_tiles.total_teachers counts —
-- profiles.role = 'teacher' and status = 'approved', deliberately NOT
-- year-scoped, same reasoning as that tile: profiles has no
-- school_year_id, and a newly-approved teacher may have no current-year
-- section yet). section_count IS year-scoped (current school year,
-- status = 'active' sections only) since it answers "how many sections is
-- this teacher currently assigned to", a meaningfully different question
-- from the teacher's own approval status.
-- =============================================================================
create or replace function app.admin_dashboard_teachers_list()
returns table (
  teacher_id     uuid,
  full_name      text,
  email          text,
  section_count  int
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not app.is_admin() then
    raise exception 'admin_dashboard_teachers_list: admin access required'
      using errcode = '42501';
  end if;

  return query
  select
    p.id,
    p.full_name,
    p.email,
    (
      select count(*)
      from public.teacher_sections ts
      join public.sections sec on sec.id = ts.section_id
      where ts.teacher_id = p.id
        and sec.school_year_id in (select school_year_id from app.v_admin_current_school_year_ids)
        and sec.status = 'active'
    )::int as section_count
  from public.profiles p
  where p.role = 'teacher'
    and p.status = 'approved'
  order by p.full_name;
end;
$$;

comment on function app.admin_dashboard_teachers_list() is
  'Admin Dashboard (0041) drill-down for the Total Teachers tile: one row per approved teacher (same population as admin_dashboard_summary_tiles.total_teachers, 0039 — unscoped by school year). section_count is current-school-year, status=''active'' section assignments only. SECURITY DEFINER + app.is_admin() guard.';

revoke all on function app.admin_dashboard_teachers_list() from public, anon, authenticated;
grant execute on function app.admin_dashboard_teachers_list() to authenticated;


-- =============================================================================
-- Function — app.admin_dashboard_sections_list
--
-- Flat list backing the Total Sections tile: one row per current-school-
-- year, status='active' section (same population
-- admin_dashboard_summary_tiles.total_sections counts) — sections only,
-- deliberately no per-student rows (per spec). primary_teacher_name is
-- the section's is_primary=true teacher_sections row (0005: at most one
-- per section); 'Unassigned' when a section has none yet, rather than
-- NULL, since this is a display list, not a value meant for further
-- computation.
-- =============================================================================
create or replace function app.admin_dashboard_sections_list()
returns table (
  section_id            uuid,
  section_name          text,
  grade_level            grade_level,
  primary_teacher_name  text,
  student_count          int
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not app.is_admin() then
    raise exception 'admin_dashboard_sections_list: admin access required'
      using errcode = '42501';
  end if;

  return query
  with sections_scope as (
    select sec.id, sec.name, sec.grade_level
    from public.sections sec
    where sec.school_year_id in (select school_year_id from app.v_admin_current_school_year_ids)
      and sec.status = 'active'
  ),
  primary_teacher as (
    select ts.section_id, p.full_name
    from public.teacher_sections ts
    join public.profiles p on p.id = ts.teacher_id
    where ts.is_primary = true
  )
  select
    s.id,
    s.name,
    s.grade_level,
    coalesce(pt.full_name, 'Unassigned'),
    count(se.student_id)::int as student_count
  from sections_scope s
  left join primary_teacher pt on pt.section_id = s.id
  left join public.student_enrollments se on se.section_id = s.id and se.status = 'active'
  group by s.id, s.name, s.grade_level, pt.full_name
  order by s.grade_level, s.name;
end;
$$;

comment on function app.admin_dashboard_sections_list() is
  'Admin Dashboard (0041) drill-down for the Total Sections tile: one row per current-school-year, status=''active'' section (same population as admin_dashboard_summary_tiles.total_sections, 0039). primary_teacher_name from teacher_sections.is_primary=true (0005), ''Unassigned'' when none. student_count is distinct actively-enrolled students. SECURITY DEFINER + app.is_admin() guard.';

revoke all on function app.admin_dashboard_sections_list() from public, anon, authenticated;
grant execute on function app.admin_dashboard_sections_list() to authenticated;


-- =============================================================================
-- Function — app.admin_dashboard_quiz_attempts_by_grade
--
-- Level 1 of the Total Quiz Attempts drill-down: one row per grade_level
-- enum value, always (mirrors admin_dashboard_score_by_grade's
-- always-one-row-per-grade pattern), total_quiz_attempts = count of
-- app.v_admin_completed_quiz_attempts rows (every completed attempt,
-- including superseded retakes — same population as the parent tile)
-- attributed to that attempt's OWN frozen section_id's grade_level. This
-- necessarily sums to the same total the Total Quiz Attempts tile itself
-- shows.
-- =============================================================================
create or replace function app.admin_dashboard_quiz_attempts_by_grade()
returns table (
  grade_level           grade_level,
  total_quiz_attempts   int
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not app.is_admin() then
    raise exception 'admin_dashboard_quiz_attempts_by_grade: admin access required'
      using errcode = '42501';
  end if;

  return query
  with grade_levels as (
    select unnest(enum_range(null::grade_level)) as grade_level
  ),
  attempts_with_grade as (
    select sec.grade_level, ca.quiz_attempt_id
    from app.v_admin_completed_quiz_attempts ca
    join public.sections sec on sec.id = ca.section_id
  )
  select
    gl.grade_level,
    count(awg.quiz_attempt_id)::int as total_quiz_attempts
  from grade_levels gl
  left join attempts_with_grade awg on awg.grade_level = gl.grade_level
  group by gl.grade_level
  order by gl.grade_level;
end;
$$;

comment on function app.admin_dashboard_quiz_attempts_by_grade() is
  'Admin Dashboard (0041) drill-down level 1 for the Total Quiz Attempts tile: one row per grade_level enum value, always. total_quiz_attempts counts every app.v_admin_completed_quiz_attempts row (0039/0041 — includes superseded retakes, same population as the parent tile''s own count) attributed by each attempt''s own frozen section_id (0010) -> that section''s grade_level, not any student''s current section. SECURITY DEFINER + app.is_admin() guard.';

revoke all on function app.admin_dashboard_quiz_attempts_by_grade() from public, anon, authenticated;
grant execute on function app.admin_dashboard_quiz_attempts_by_grade() to authenticated;


-- =============================================================================
-- Function — app.admin_dashboard_quiz_attempts_by_section
--
-- Level 2 of the Total Quiz Attempts drill-down: reached by tapping one
-- grade from level 1. One row per current-school-year, status='active'
-- section in that grade (a section with zero attempts still appears, with
-- total_quiz_attempts = 0), counting the same
-- app.v_admin_completed_quiz_attempts population as level 1, attributed
-- by the attempt's own frozen section_id (not current enrollment).
-- p_grade_level is required (no "all grades" mode) since this function is
-- only ever reached from level 1 with a specific grade already chosen.
-- =============================================================================
create or replace function app.admin_dashboard_quiz_attempts_by_section(
  p_grade_level grade_level
)
returns table (
  section_id            uuid,
  section_name          text,
  total_quiz_attempts   int
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not app.is_admin() then
    raise exception 'admin_dashboard_quiz_attempts_by_section: admin access required'
      using errcode = '42501';
  end if;

  if p_grade_level is null then
    raise exception 'admin_dashboard_quiz_attempts_by_section: p_grade_level is required'
      using errcode = '22004';
  end if;

  return query
  with sections_scope as (
    select sec.id, sec.name
    from public.sections sec
    where sec.grade_level = p_grade_level
      and sec.school_year_id in (select school_year_id from app.v_admin_current_school_year_ids)
      and sec.status = 'active'
  )
  select
    s.id,
    s.name,
    count(ca.quiz_attempt_id)::int as total_quiz_attempts
  from sections_scope s
  left join app.v_admin_completed_quiz_attempts ca on ca.section_id = s.id
  group by s.id, s.name
  order by s.name;
end;
$$;

comment on function app.admin_dashboard_quiz_attempts_by_section(grade_level) is
  'Admin Dashboard (0041) drill-down level 2 for the Total Quiz Attempts tile (reached by tapping a grade from admin_dashboard_quiz_attempts_by_grade): one row per current-school-year, status=''active'' section in p_grade_level (required — always called with a specific grade already chosen), including sections with zero attempts. total_quiz_attempts uses the same app.v_admin_completed_quiz_attempts population as level 1, attributed by each attempt''s own frozen section_id. SECURITY DEFINER + app.is_admin() guard.';

revoke all on function app.admin_dashboard_quiz_attempts_by_section(grade_level) from public, anon, authenticated;
grant execute on function app.admin_dashboard_quiz_attempts_by_section(grade_level) to authenticated;


-- =============================================================================
-- Function — app.admin_dashboard_score_by_section
--
-- Level 2 of the Average Mathematics Score drill-down: reached by tapping
-- one grade from level 1, which is the EXISTING (unchanged)
-- app.admin_dashboard_score_by_grade (0039) — that function already
-- returns exactly the "one row per grade, average + student count" shape
-- level 1 needs, so nothing new was required for it. This function is the
-- new level 2: one row per current-school-year, status='active' section
-- in p_grade_level, average_score_percent/student_count computed the same
-- way admin_dashboard_score_by_grade computes its own per-grade figures —
-- via app.v_admin_active_student_sections (currently-active students'
-- CURRENT section) joined to app.v_admin_student_average_scores (each
-- such student's own average over their current, deduped attempts) — just
-- grouped by section instead of by grade. A section with zero qualifying
-- students still appears, with average_score_percent NULL and
-- student_count 0 (mirrors admin_dashboard_score_by_grade's own
-- never-omit-a-row behavior, one level down).
-- =============================================================================
create or replace function app.admin_dashboard_score_by_section(
  p_grade_level grade_level
)
returns table (
  section_id              uuid,
  section_name            text,
  average_score_percent   numeric,
  student_count           int
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not app.is_admin() then
    raise exception 'admin_dashboard_score_by_section: admin access required'
      using errcode = '42501';
  end if;

  if p_grade_level is null then
    raise exception 'admin_dashboard_score_by_section: p_grade_level is required'
      using errcode = '22004';
  end if;

  return query
  with sections_scope as (
    select sec.id, sec.name
    from public.sections sec
    where sec.grade_level = p_grade_level
      and sec.school_year_id in (select school_year_id from app.v_admin_current_school_year_ids)
      and sec.status = 'active'
  ),
  students_in_section as (
    select ass.section_id, ass.student_id
    from app.v_admin_active_student_sections ass
    where ass.grade_level = p_grade_level
  )
  select
    s.id,
    s.name,
    round(avg(sas.average_score_percent), 1) as average_score_percent,
    count(distinct sis.student_id)::int as student_count
  from sections_scope s
  left join students_in_section sis on sis.section_id = s.id
  left join app.v_admin_student_average_scores sas on sas.student_id = sis.student_id
  group by s.id, s.name
  order by s.name;
end;
$$;

comment on function app.admin_dashboard_score_by_section(grade_level) is
  'Admin Dashboard (0041) drill-down level 2 for the Average Mathematics Score tile (reached by tapping a grade from the EXISTING app.admin_dashboard_score_by_grade, 0039, which already serves as level 1 unchanged). One row per current-school-year, status=''active'' section in p_grade_level (required), including sections with zero qualifying students (NULL average, 0 count). average_score_percent averages app.v_admin_student_average_scores over students currently enrolled in that section (app.v_admin_active_student_sections), one vote per student. SECURITY DEFINER + app.is_admin() guard.';

revoke all on function app.admin_dashboard_score_by_section(grade_level) from public, anon, authenticated;
grant execute on function app.admin_dashboard_score_by_section(grade_level) to authenticated;


-- =============================================================================
-- Function — app.admin_dashboard_intervention_students
--
-- Flat list backing the Students Requiring Intervention tile: every
-- currently-active student (app.v_admin_active_students) matching the
-- EXACT SAME rule app.admin_dashboard_summary_tiles (0040) counts —
-- average_score_percent < 70 OR >= 2 missed/unfinished expected internal
-- quizzes — so this list's row count always equals that tile's number.
-- section_name is the student's current section
-- (app.v_admin_active_student_sections, 0041). full_name comes from
-- public.students directly (SECURITY DEFINER; same posture 0037's
-- dashboard_competency_mastery and this migration's own functions already
-- use to read rows an unprivileged caller couldn't).
-- =============================================================================
create or replace function app.admin_dashboard_intervention_students()
returns table (
  student_id                    uuid,
  full_name                     text,
  section_name                  text,
  average_score_percent         numeric,
  missed_or_unfinished_count    int
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not app.is_admin() then
    raise exception 'admin_dashboard_intervention_students: admin access required'
      using errcode = '42501';
  end if;

  return query
  select
    st.id,
    st.full_name,
    ass.section_name,
    sas.average_score_percent,
    coalesce(moc.missed_or_unfinished_count, 0) as missed_or_unfinished_count
  from app.v_admin_active_students act
  join public.students st on st.id = act.student_id
  join app.v_admin_active_student_sections ass on ass.student_id = act.student_id
  left join app.v_admin_student_average_scores sas on sas.student_id = act.student_id
  left join app.v_admin_missed_or_unfinished_counts moc on moc.student_id = act.student_id
  where (sas.average_score_percent is not null and sas.average_score_percent < 70)
     or coalesce(moc.missed_or_unfinished_count, 0) >= 2
  order by st.full_name;
end;
$$;

comment on function app.admin_dashboard_intervention_students() is
  'Admin Dashboard (0041) drill-down for the Students Requiring Intervention tile: one row per currently-active student matching the identical rule app.admin_dashboard_summary_tiles (0040) counts — average_score_percent < 70 (app.v_admin_student_average_scores) OR >= 2 missed/unfinished expected internal quizzes (app.v_admin_missed_or_unfinished_counts, 0040) — so this list''s row count always equals that tile''s number. section_name from app.v_admin_active_student_sections (0041). SECURITY DEFINER + app.is_admin() guard.';

revoke all on function app.admin_dashboard_intervention_students() from public, anon, authenticated;
grant execute on function app.admin_dashboard_intervention_students() to authenticated;


-- =============================================================================
-- public wrappers — thin pass-through, `security invoker` (default,
-- omitted below), exact one-line `select * from app.<fn>(...)` pattern
-- 0039/0040 already use. Reachable from the Flutter client via
-- `.rpc('admin_dashboard_teachers_list'/...)`. Granted execute to
-- `authenticated` only, admin check lives entirely inside each app.*
-- function.
-- =============================================================================
create or replace function public.admin_dashboard_teachers_list()
returns table (
  teacher_id     uuid,
  full_name      text,
  email          text,
  section_count  int
)
language sql
as $$
  select * from app.admin_dashboard_teachers_list();
$$;

comment on function public.admin_dashboard_teachers_list() is
  'Public-schema pass-through to app.admin_dashboard_teachers_list (0041) so it is reachable via PostgREST from the Flutter client. No additional logic; the admin check lives entirely inside app.admin_dashboard_teachers_list.';

revoke all on function public.admin_dashboard_teachers_list() from public, anon, authenticated;
grant execute on function public.admin_dashboard_teachers_list() to authenticated;


create or replace function public.admin_dashboard_sections_list()
returns table (
  section_id            uuid,
  section_name          text,
  grade_level            grade_level,
  primary_teacher_name  text,
  student_count          int
)
language sql
as $$
  select * from app.admin_dashboard_sections_list();
$$;

comment on function public.admin_dashboard_sections_list() is
  'Public-schema pass-through to app.admin_dashboard_sections_list (0041) so it is reachable via PostgREST from the Flutter client. No additional logic; the admin check lives entirely inside app.admin_dashboard_sections_list.';

revoke all on function public.admin_dashboard_sections_list() from public, anon, authenticated;
grant execute on function public.admin_dashboard_sections_list() to authenticated;


create or replace function public.admin_dashboard_quiz_attempts_by_grade()
returns table (
  grade_level           grade_level,
  total_quiz_attempts   int
)
language sql
as $$
  select * from app.admin_dashboard_quiz_attempts_by_grade();
$$;

comment on function public.admin_dashboard_quiz_attempts_by_grade() is
  'Public-schema pass-through to app.admin_dashboard_quiz_attempts_by_grade (0041) so it is reachable via PostgREST from the Flutter client. No additional logic; the admin check lives entirely inside app.admin_dashboard_quiz_attempts_by_grade.';

revoke all on function public.admin_dashboard_quiz_attempts_by_grade() from public, anon, authenticated;
grant execute on function public.admin_dashboard_quiz_attempts_by_grade() to authenticated;


create or replace function public.admin_dashboard_quiz_attempts_by_section(
  p_grade_level grade_level
)
returns table (
  section_id            uuid,
  section_name          text,
  total_quiz_attempts   int
)
language sql
as $$
  select * from app.admin_dashboard_quiz_attempts_by_section(p_grade_level);
$$;

comment on function public.admin_dashboard_quiz_attempts_by_section(grade_level) is
  'Public-schema pass-through to app.admin_dashboard_quiz_attempts_by_section (0041) so it is reachable via PostgREST from the Flutter client. No additional logic; the admin check lives entirely inside app.admin_dashboard_quiz_attempts_by_section.';

revoke all on function public.admin_dashboard_quiz_attempts_by_section(grade_level) from public, anon, authenticated;
grant execute on function public.admin_dashboard_quiz_attempts_by_section(grade_level) to authenticated;


create or replace function public.admin_dashboard_score_by_section(
  p_grade_level grade_level
)
returns table (
  section_id              uuid,
  section_name            text,
  average_score_percent   numeric,
  student_count           int
)
language sql
as $$
  select * from app.admin_dashboard_score_by_section(p_grade_level);
$$;

comment on function public.admin_dashboard_score_by_section(grade_level) is
  'Public-schema pass-through to app.admin_dashboard_score_by_section (0041) so it is reachable via PostgREST from the Flutter client. No additional logic; the admin check lives entirely inside app.admin_dashboard_score_by_section.';

revoke all on function public.admin_dashboard_score_by_section(grade_level) from public, anon, authenticated;
grant execute on function public.admin_dashboard_score_by_section(grade_level) to authenticated;


create or replace function public.admin_dashboard_intervention_students()
returns table (
  student_id                    uuid,
  full_name                     text,
  section_name                  text,
  average_score_percent         numeric,
  missed_or_unfinished_count    int
)
language sql
as $$
  select * from app.admin_dashboard_intervention_students();
$$;

comment on function public.admin_dashboard_intervention_students() is
  'Public-schema pass-through to app.admin_dashboard_intervention_students (0041) so it is reachable via PostgREST from the Flutter client. No additional logic; the admin check lives entirely inside app.admin_dashboard_intervention_students.';

revoke all on function public.admin_dashboard_intervention_students() from public, anon, authenticated;
grant execute on function public.admin_dashboard_intervention_students() to authenticated;
