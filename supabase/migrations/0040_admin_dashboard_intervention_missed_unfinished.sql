-- =============================================================================
-- Migration: 0040_admin_dashboard_intervention_missed_unfinished.sql
-- Fixes a real discrepancy between the Teacher Dashboard (0037) and the
-- Admin Dashboard (0039): a student flagged as "needing intervention" on
-- the Teacher Dashboard purely because they have >= 2 missed/unfinished
-- expected internal quizzes (and NOT because of a low average score) was
-- invisible to students_requiring_intervention on the Admin Dashboard,
-- because 0039's app.admin_dashboard_summary_tiles only ever checked
-- average_score_percent < 70 — it never replicated the Teacher Dashboard's
-- second criterion. This was called out explicitly (and left unfixed) in
-- 0039's own function comment for admin_dashboard_summary_tiles.
--
-- NOTE ON THRESHOLDS — both dashboards already use the SAME 70% cutoff
-- (app.dashboard_summary_tiles in 0037, app.admin_dashboard_summary_tiles
-- in 0039 both use `< 70`). There was never a 60%-vs-70% mismatch in the
-- SQL; nothing about the threshold itself changes in this migration.
--
-- NO EXISTING OBJECT IS MODIFIED IN PLACE except via `create or replace`
-- on the one function below, which is the established pattern already
-- used by 0037/0039 for iterating on dashboard functions. All new views
-- are strictly additive.
--
-- APPROACH — mirrors the Teacher Dashboard's missed/unfinished rule
-- (0037 header) exactly, just computed for every currently-active student
-- system-wide (app.v_admin_active_students, 0039) instead of scoped to one
-- teacher's sections:
--   "Expected" internal quizzes for a student = built-in internal quizzes
--   matching the grade_level of the section they are CURRENTLY actively
--   enrolled in (current school year, section status = 'active' — same
--   scoping app.admin_dashboard_score_by_grade, 0039, already uses),
--   UNION teacher-created internal quizzes assigned to that section via
--   quiz_sections. "Missed" = zero quiz_attempts rows at all for that
--   (student, quiz) pair. "Unfinished" = a quiz_attempts row exists with
--   attempt_status = 'active' AND submitted_at IS NULL. Both checks run
--   only when app.v_admin_current_quiz_attempts (0039's own deduped
--   "current attempt" view) has no completed-attempt row for that pair.
-- =============================================================================


-- =============================================================================
-- View 6 — app.v_admin_active_student_sections
--
-- One row per currently-active student (app.v_admin_active_students, 0039)
-- and their current section_id/grade_level — the same current-enrollment
-- resolution app.admin_dashboard_score_by_grade (0039) already computes
-- inline, pulled out here so it is not re-derived a third time by the
-- views below.
-- =============================================================================
create view app.v_admin_active_student_sections
with (security_invoker = true) as
select
  se.student_id,
  sec.id as section_id,
  sec.grade_level
from public.student_enrollments se
join public.sections sec on sec.id = se.section_id
join app.v_admin_active_students act on act.student_id = se.student_id
where se.status = 'active'
  and sec.school_year_id in (select school_year_id from app.v_admin_current_school_year_ids)
  and sec.status = 'active';

comment on view app.v_admin_active_student_sections is
  'Admin Dashboard (0040) internal building block: one row per currently-active student (app.v_admin_active_students, 0039) and the section_id/grade_level of their current active enrollment (current school year, section status = ''active''). Same resolution app.admin_dashboard_score_by_grade (0039) computes inline for its own CTE; pulled into a view here so app.v_admin_expected_quizzes does not re-derive it a third time. security_invoker; only ever read from inside SECURITY DEFINER app.admin_dashboard_* functions.';

revoke all on app.v_admin_active_student_sections from public, anon, authenticated;
grant select on app.v_admin_active_student_sections to authenticated;


-- =============================================================================
-- View 7 — app.v_admin_expected_quizzes
--
-- Every (student_id, quiz_id) pair a currently-active student is expected
-- to have a completed attempt for — built-in internal quizzes matching
-- their current section's grade_level, UNION teacher-created internal
-- quizzes assigned to their current section via quiz_sections. Identical
-- rule to the Teacher Dashboard's expected_quizzes CTE (0037), just driven
-- off app.v_admin_active_student_sections instead of a single teacher's
-- RLS-scoped sections. External Activities (quiz_type = 'external_activity')
-- are excluded — same reasoning as 0037 (no score, so "missed" is not a
-- meaningful signal for them).
-- =============================================================================
create view app.v_admin_expected_quizzes
with (security_invoker = true) as
select ass.student_id, q.id as quiz_id
from app.v_admin_active_student_sections ass
join public.quizzes q
  on q.source_type = 'built_in'
 and q.quiz_type = 'internal'
 and q.grade_level = ass.grade_level
union
select ass.student_id, q.id as quiz_id
from app.v_admin_active_student_sections ass
join public.quiz_sections qs on qs.section_id = ass.section_id
join public.quizzes q on q.id = qs.quiz_id
where q.source_type = 'teacher'
  and q.quiz_type = 'internal';

comment on view app.v_admin_expected_quizzes is
  'Admin Dashboard (0040) internal building block: every (student_id, quiz_id) pair a currently-active student (app.v_admin_active_student_sections) is expected to complete — built-in internal quizzes matching their current section''s grade_level, UNION teacher-created internal quizzes assigned to that section via quiz_sections. Same rule as the Teacher Dashboard''s expected_quizzes CTE (0037); External Activities excluded (no score, not a meaningful "missed" signal). security_invoker; only ever read from inside SECURITY DEFINER app.admin_dashboard_* functions.';

revoke all on app.v_admin_expected_quizzes from public, anon, authenticated;
grant select on app.v_admin_expected_quizzes to authenticated;


-- =============================================================================
-- View 8 — app.v_admin_missed_or_unfinished_counts
--
-- One row per currently-active student with their missed_or_unfinished_count
-- (0 if none) — the exact same "missed" / "unfinished" definitions as the
-- Teacher Dashboard (0037), applied system-wide instead of per-teacher.
-- Uses app.v_admin_current_quiz_attempts (0039) — the SAME deduped
-- "current attempt" view every other Admin Dashboard score metric already
-- reads — to decide whether a (student, quiz) pair already has a
-- completed attempt, so this stays consistent with the rest of 0039
-- rather than re-deriving the dedup logic a second way.
-- =============================================================================
create view app.v_admin_missed_or_unfinished_counts
with (security_invoker = true) as
with missed_or_unfinished as (
  select eq.student_id, eq.quiz_id
  from app.v_admin_expected_quizzes eq
  where not exists (
    select 1 from app.v_admin_current_quiz_attempts ca
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
)
select
  act.student_id,
  count(mu.quiz_id)::int as missed_or_unfinished_count
from app.v_admin_active_students act
left join missed_or_unfinished mu on mu.student_id = act.student_id
group by act.student_id;

comment on view app.v_admin_missed_or_unfinished_counts is
  'Admin Dashboard (0040) internal building block: one row per currently-active student (app.v_admin_active_students, 0039) with missed_or_unfinished_count over app.v_admin_expected_quizzes (0040) — "missed" = zero quiz_attempts rows for that (student,quiz) pair, "unfinished" = an attempt_status=''active''/submitted_at-is-null row exists, both checked only when app.v_admin_current_quiz_attempts (0039) has no completed-attempt row for the pair. Identical rule to the Teacher Dashboard (0037), applied system-wide. security_invoker; only ever read from inside SECURITY DEFINER app.admin_dashboard_* functions.';

revoke all on app.v_admin_missed_or_unfinished_counts from public, anon, authenticated;
grant select on app.v_admin_missed_or_unfinished_counts to authenticated;


-- =============================================================================
-- Function 1 (updated) — app.admin_dashboard_summary_tiles
--
-- Only students_requiring_intervention changes: now counts a currently-
-- active student if EITHER their average_score_percent < 70 (unchanged —
-- both dashboards already agreed on 70, see migration header) OR they have
-- >= 2 missed/unfinished expected internal quizzes
-- (app.v_admin_missed_or_unfinished_counts, new in this migration) —
-- matching the Teacher Dashboard's (0037) intervention rule exactly. Every
-- other tile (total_students/total_teachers/total_sections/
-- total_quiz_attempts/average_mathematics_score) is unchanged from 0039.
-- =============================================================================
create or replace function app.admin_dashboard_summary_tiles()
returns table (
  total_students                   int,
  total_teachers                   int,
  total_sections                   int,
  total_quiz_attempts              int,
  average_mathematics_score        numeric,
  students_requiring_intervention  int
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not app.is_admin() then
    raise exception 'admin_dashboard_summary_tiles: admin access required'
      using errcode = '42501';
  end if;

  return query
  select
    (
      select count(*)
      from app.v_admin_active_students
    )::int as total_students,
    (
      select count(*)
      from public.profiles p
      where p.role = 'teacher'
        and p.status = 'approved'
    )::int as total_teachers,
    (
      select count(*)
      from public.sections sec
      where sec.school_year_id in (select school_year_id from app.v_admin_current_school_year_ids)
        and sec.status = 'active'
    )::int as total_sections,
    (
      select count(*)
      from app.v_admin_completed_quiz_attempts
    )::int as total_quiz_attempts,
    (
      select round(avg(sas.average_score_percent), 1)
      from app.v_admin_student_average_scores sas
    ) as average_mathematics_score,
    (
      select count(*)
      from app.v_admin_active_students act
      left join app.v_admin_student_average_scores sas on sas.student_id = act.student_id
      left join app.v_admin_missed_or_unfinished_counts moc on moc.student_id = act.student_id
      where (sas.average_score_percent is not null and sas.average_score_percent < 70)
         or coalesce(moc.missed_or_unfinished_count, 0) >= 2
    )::int as students_requiring_intervention;
end;
$$;

comment on function app.admin_dashboard_summary_tiles() is
  'Admin Dashboard (0039, updated 0040) 6 stat-card tiles, all scoped to the current school year(s) except total_teachers (profiles has no school_year_id — see 0039 header). total_students: COUNT of app.v_admin_active_students. total_teachers: approved teachers, unscoped. total_sections: current-year sections with status = ''active'' only. total_quiz_attempts: raw COUNT of app.v_admin_completed_quiz_attempts rows (activity count, not per-student). average_mathematics_score: average of each currently-active student''s own average score (app.v_admin_student_average_scores), one vote per student. students_requiring_intervention (0040): distinct currently-active students with EITHER average_score_percent < 70 OR >= 2 missed/unfinished expected internal quizzes (app.v_admin_missed_or_unfinished_counts, 0040) — now matches the Teacher Dashboard''s (0037) intervention rule on both criteria, fixing the prior gap where a student flagged on the Teacher Dashboard solely for missed/unfinished quizzes never appeared here. SECURITY DEFINER + app.is_admin() guard — see 0039 header for why RLS alone is not sufficient gating for this endpoint.';

revoke all on function app.admin_dashboard_summary_tiles() from public, anon, authenticated;
grant execute on function app.admin_dashboard_summary_tiles() to authenticated;

-- public.admin_dashboard_summary_tiles wrapper is untouched — its body
-- (`select * from app.admin_dashboard_summary_tiles();`) and grants from
-- 0039 already pass through whatever the app.* function returns, so no
-- `create or replace` is needed here.
