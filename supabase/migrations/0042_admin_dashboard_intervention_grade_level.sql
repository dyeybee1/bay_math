-- Migration: 0042_admin_dashboard_intervention_grade_level.sql
--
-- Adds `grade_level` to the Students Requiring Intervention drill-down
-- (app.admin_dashboard_intervention_students / public wrapper, both 0041)
-- so the Flutter client can group the flagged list as Grade Level ->
-- Section -> Student, instead of surfacing student names directly.
-- app.v_admin_active_student_sections (0040, extended 0041) already
-- carries grade_level on every row this function joins against
-- (ass.grade_level) — this migration only adds it to the SELECT list and
-- RETURNS TABLE of both functions; no new view or join is needed.
--
-- CREATE OR REPLACE FUNCTION cannot change a function's output column
-- list, so both functions are dropped and recreated (same two functions
-- 0041 created; not a new object).
-- =============================================================================

drop function if exists public.admin_dashboard_intervention_students();
drop function if exists app.admin_dashboard_intervention_students();

create function app.admin_dashboard_intervention_students()
returns table (
  student_id                    uuid,
  full_name                     text,
  grade_level                   grade_level,
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
    ass.grade_level,
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
  order by ass.grade_level, ass.section_name, st.full_name;
end;
$$;

comment on function app.admin_dashboard_intervention_students() is
  'Admin Dashboard (0041, extended 0042) drill-down for the Students Requiring Intervention tile: one row per currently-active student matching the identical rule app.admin_dashboard_summary_tiles (0040) counts — average_score_percent < 70 (app.v_admin_student_average_scores) OR >= 2 missed/unfinished expected internal quizzes (app.v_admin_missed_or_unfinished_counts, 0040) — so this list''s row count always equals that tile''s number. grade_level (0042) and section_name both from app.v_admin_active_student_sections (0041). Ordered grade_level, section_name, full_name so the client can group Grade Level -> Section -> Student without re-sorting. SECURITY DEFINER + app.is_admin() guard.';

revoke all on function app.admin_dashboard_intervention_students() from public, anon, authenticated;
grant execute on function app.admin_dashboard_intervention_students() to authenticated;


create function public.admin_dashboard_intervention_students()
returns table (
  student_id                    uuid,
  full_name                     text,
  grade_level                   grade_level,
  section_name                  text,
  average_score_percent         numeric,
  missed_or_unfinished_count    int
)
language sql
as $$
  select * from app.admin_dashboard_intervention_students();
$$;

comment on function public.admin_dashboard_intervention_students() is
  'Public-schema pass-through to app.admin_dashboard_intervention_students (0041, extended 0042) so it is reachable via PostgREST from the Flutter client. No additional logic; the admin check lives entirely inside app.admin_dashboard_intervention_students.';

revoke all on function public.admin_dashboard_intervention_students() from public, anon, authenticated;
grant execute on function public.admin_dashboard_intervention_students() to authenticated;
