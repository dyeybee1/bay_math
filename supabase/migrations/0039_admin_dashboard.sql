-- =============================================================================
-- Migration: 0039_admin_dashboard.sql
-- Admin Dashboard (Part 1 — SQL only). Flutter wiring (models/repository/
-- providers/UI) is out of scope for this migration and comes in later,
-- separate prompts. This adds three read-only aggregate endpoints powering
-- the system-wide Admin Dashboard: 6 stat cards, an "Average Score by Grade
-- Level" bar chart, and a "Proficiency Distribution" pie chart.
--
-- NO EXISTING OBJECT IS MODIFIED. Every object below is newly created.
-- Nothing from 0001-0038 is ALTERed, DROPped, or REPLACEd — in particular
-- the Teacher Dashboard (0037/0038), Student Statistics (0035), and every
-- RLS policy from 0015 are untouched. This migration is purely additive.
--
-- WHY THIS DOESN'T FOLLOW 0015's "Admin already has full RLS access, so
-- just read the tables directly" pattern:
-- RLS grants Admin unrestricted rows, but that is a floor for what an Admin
-- session CAN read, not a gate on who is allowed to call these aggregate
-- endpoints at all. If these were plain SECURITY INVOKER reads (the
-- Function 1-3 pattern from 0037), a non-admin authenticated session
-- (a Teacher) would not get an error — RLS would just quietly hand back a
-- smaller, misleadingly-scoped result (e.g. a Teacher's own visible rows
-- only, per teacher_has_section()/teacher_has_student()), which is worse
-- than an obvious failure for a dashboard whose whole premise is
-- system-wide, unscoped totals. So every outward-facing function here is
-- SECURITY DEFINER with an explicit `app.is_admin()` guard as the very
-- first statement in its body, raising 42501 for anyone else — mirroring
-- why 0037's dashboard_competency_mastery and 0038's
-- section_expected_internal_quiz_ids needed SECURITY DEFINER (closing a
-- specific, named access gap), just applied here to the whole endpoint
-- rather than one internal branch of it. Same precedent as
-- 0017_student_authentication.sql's admin/teacher-gated functions
-- (`security definer` + an explicit `if not (app.is_admin() or ...) then
-- raise exception` guard as the first statement) — SECURITY DEFINER plus
-- an explicit role check at the top of the body is this codebase's
-- established pattern for "authenticated, but only a specific role may
-- call this," not a one-off introduced by this migration.
--
-- CURRENT SCHOOL YEAR — school_years.is_current = true is enforced unique
-- PER school_id (school_years_one_current_per_school, 0003), not a single
-- global flag. Every metric below resolves it as a SET of ids via
-- app.v_admin_current_school_year_ids, never a single id, so this stays
-- correct without a rewrite if a second school is ever added (today it
-- will always be exactly one row, but nothing here assumes that).
--
-- score_percent — quiz_attempts (0010) has no score_percent column, only
-- score (numeric, nullable) and total_questions (smallint, nullable).
-- Every place below that needs a percentage computes it inline as
-- round(100.0 * qa.score / nullif(qa.total_questions, 0), 1) — the exact
-- formula public.v_student_current_quiz_attempts (0035) already uses for
-- the identical concept, reused verbatim rather than re-derived.
--
-- "COMPLETED" — submitted_at is not null is the completed signal
-- (quiz_attempt_status only has active/superseded, no completed value;
-- restated from the spec, not re-derived). Endless Quiz lives in a wholly
-- separate table (endless_quiz_sessions) and is excluded by construction:
-- nothing below ever references that table.
--
-- RETAKES — LATEST SUBMITTED ATTEMPT PER (student_id, quiz_id), NOT EVERY
-- SUBMITTED ATTEMPT (final decision, restated from the spec): a student can
-- retake a quiz, leaving an older 'superseded' attempt with submitted_at
-- still set alongside the newer attempt. Only the most-recently-SUBMITTED
-- attempt per (student_id, quiz_id) is the authoritative current result —
-- never the highest score, never a pooled average across every submitted
-- attempt. Tie-broken by `qa.id desc` after `submitted_at desc` for a
-- fully deterministic single row per (student_id, quiz_id) even in the
-- (extremely unlikely, submitted_at has microsecond precision) case of two
-- attempts sharing the same submitted_at. This is deliberately the SAME
-- rule public.v_student_current_quiz_attempts (0035) already enforces via
-- `distinct on (student_id, quiz_id) ... order by submitted_at desc`,
-- reused here as app.v_admin_current_quiz_attempts (view 3 below) rather
-- than re-derived with different logic, so "current attempt" means one
-- thing across the whole codebase (0035, 0037/0038's teacher dashboard,
-- and this admin dashboard). Every score/proficiency/intervention metric
-- below is built on app.v_admin_current_quiz_attempts. Total Quiz Attempts
-- is the one metric that intentionally is NOT deduped this way — it counts
-- every completed attempt (including superseded ones) because it answers
-- "how many completed attempts happened", an activity count, not a score
-- (see that metric's own comment below).
--
-- ARCHIVED SECTIONS — a student's current-year quiz history stays in
-- quiz_attempts forever (school_year_id/section_id are frozen historical
-- context, per 0010's own column comment), but that student only counts
-- toward Average Mathematics Score, Students Requiring Intervention,
-- Proficiency Distribution, and the Grade-Level bar chart if they
-- currently hold an ACTIVE student_enrollments row (status = 'active')
-- in a section that is BOTH in the current school year(s) AND itself
-- status = 'active' (section_status; archived sections do not count). A
-- student whose only enrollment is in an archived/inactive section, or
-- who has no active enrollment at all, contributes zero rows to any of
-- those four metrics — even if they have current-year completed attempts
-- on record. This single rule is centralized in one place,
-- app.v_admin_active_students (view 4 below), and every one of those four
-- metrics is filtered through it rather than re-deriving the condition
-- independently.
--
-- ONE VOTE PER STUDENT, NOT PER ATTEMPT — Average Mathematics Score,
-- Students Requiring Intervention, the grade-level bar chart, and the
-- proficiency pie chart all read from app.v_admin_student_average_scores,
-- which computes each student's own average score_percent across their
-- own CURRENT (deduped, see above) attempts, filtered to only students
-- currently in app.v_admin_active_students (see ARCHIVED SECTIONS above),
-- then every metric above aggregates THOSE per-student averages (average
-- of averages / bucket of averages / count of averages below a threshold)
-- — never a pooled per-attempt average, never diluted by a stale
-- superseded score sitting alongside a retake, and never including a
-- student whose only enrollment is archived. Total Quiz Attempts is the
-- one exception: it is a raw attempt count by design, unfiltered by
-- current enrollment (see its own comment below).
--
-- THREE-LAYER OBJECT SHAPE (matches the spec exactly, and mirrors 0037's
-- app.* + public.* wrapper split):
--   1. Five argument-free plain SQL views in `app` (the third,
--      app.v_admin_current_quiz_attempts, added for the retake-dedup
--      rule above; the fourth, app.v_admin_active_students, added for
--      the archived-section rule above), each `with
--      (security_invoker = true)` — internal building blocks only.
--      `app` is not in PostgREST's exposed-schema list (0001), so these
--      are unreachable from the Flutter client regardless of grants;
--      they carry no admin guard of their own because nothing external
--      can reach them directly.
--   2. Three `app.admin_dashboard_*` functions — `language plpgsql,
--      security definer, set search_path = public`, each starting with
--      the `app.is_admin()` guard. These do the actual gating.
--   3. Three thin `public.admin_dashboard_*` wrappers — plain
--      `language sql`, default (SECURITY INVOKER), one-line
--      `select * from app.<fn>();` — reachable from the Flutter client via
--      `.rpc('admin_dashboard_summary_tiles')` etc. The wrapper adds no
--      privilege of its own; the admin check lives entirely inside the
--      app.* function it wraps. Shape copied exactly from 0037's
--      public.* wrappers.
--
-- Every one of those eleven objects gets an explicit
-- `revoke all on ... from public, anon, authenticated;` followed by a
-- narrow grant to `authenticated` only (`select` for views, `execute` for
-- functions) — matching the grant convention used throughout 0037/0038.
-- `authenticated` already has `usage on schema app` (granted in 0016), so
-- no additional schema-level grant is needed for the internal views or
-- the app.* functions.
--
-- NAMING — app.v_admin_*, app.admin_dashboard_*, public.admin_dashboard_*:
-- distinct from the Teacher Dashboard's app.dashboard_* / public.dashboard_*
-- names (0037/0038), no collisions.
-- =============================================================================


-- =============================================================================
-- View 1 — app.v_admin_current_school_year_ids
--
-- Resolves "current school year" as a SET of ids (one row per school with
-- is_current = true), not a single id — see header. Every other object
-- below that needs year-scoping filters against this view rather than
-- re-deriving `is_current = true` inline, so the definition of "current"
-- lives in exactly one place.
-- =============================================================================
create view app.v_admin_current_school_year_ids
with (security_invoker = true) as
select sy.id as school_year_id
from public.school_years sy
where sy.is_current = true;

comment on view app.v_admin_current_school_year_ids is
  'Admin Dashboard (0039) internal building block: the set of school_years.id with is_current = true — a SET, not a single id, because school_years_one_current_per_school (0003) is unique per school_id, not globally, so this stays correct if a second school is ever added. security_invoker: rides on school_years RLS (0015); harmless either way since it is only ever read from inside SECURITY DEFINER app.admin_dashboard_* functions, never called directly (app is outside PostgREST''s exposed schema list, 0001).';

revoke all on app.v_admin_current_school_year_ids from public, anon, authenticated;
grant select on app.v_admin_current_school_year_ids to authenticated;


-- =============================================================================
-- View 2 — app.v_admin_completed_quiz_attempts
--
-- EVERY completed (submitted_at is not null) regular-quiz attempt for the
-- current school year(s), including superseded/older attempts left behind
-- by a retake — deliberately NOT deduped. This view exists solely to back
-- the Total Quiz Attempts tile (a raw activity count — "how many completed
-- attempts happened", not a score). Nothing else in this migration reads
-- from this view; every score/proficiency/intervention metric reads from
-- app.v_admin_current_quiz_attempts (view 3 below) instead. Endless Quiz is
-- excluded by construction — it lives in endless_quiz_sessions, never
-- referenced here.
-- =============================================================================
create view app.v_admin_completed_quiz_attempts
with (security_invoker = true) as
select
  qa.id                as quiz_attempt_id,
  qa.student_id,
  qa.quiz_id,
  qa.school_year_id,
  round(100.0 * qa.score / nullif(qa.total_questions, 0), 1) as score_percent
from public.quiz_attempts qa
where qa.submitted_at is not null
  and qa.school_year_id in (select school_year_id from app.v_admin_current_school_year_ids);

comment on view app.v_admin_completed_quiz_attempts is
  'Admin Dashboard (0039) internal building block: one row per completed (submitted_at is not null — quiz_attempt_status has no completed value) regular-quiz attempt in the current school year(s) (app.v_admin_current_school_year_ids), including superseded attempts left behind by a retake — intentionally NOT deduped. Exists solely to back the Total Quiz Attempts raw activity count; every score/proficiency/intervention metric instead reads app.v_admin_current_quiz_attempts (view 3), which IS deduped. Endless Quiz excluded by construction — endless_quiz_sessions is never referenced. security_invoker; only ever read from inside SECURITY DEFINER app.admin_dashboard_* functions.';

revoke all on app.v_admin_completed_quiz_attempts from public, anon, authenticated;
grant select on app.v_admin_completed_quiz_attempts to authenticated;


-- =============================================================================
-- View 3 — app.v_admin_current_quiz_attempts
--
-- One row per (student_id, quiz_id): that pair's most-recently-SUBMITTED
-- attempt within the current school year(s), regardless of attempt_status
-- — the SAME "current attempt" rule public.v_student_current_quiz_attempts
-- (0035) enforces via `distinct on (student_id, quiz_id) ... order by
-- submitted_at desc`, reused here rather than re-derived, and already
-- relied on by the Teacher Dashboard (0037/0038). A retake's older
-- superseded-but-submitted attempt never counts alongside the newer one;
-- the latest submission is the sole authoritative current result — never
-- the highest score. `qa.id desc` breaks a submitted_at tie
-- deterministically. This is the single source every score/proficiency/
-- intervention metric in this migration reads from (via views 4-5 below).
-- =============================================================================
create view app.v_admin_current_quiz_attempts
with (security_invoker = true) as
select distinct on (ca.student_id, ca.quiz_id)
  ca.quiz_attempt_id,
  ca.student_id,
  ca.quiz_id,
  ca.school_year_id,
  ca.score_percent
from app.v_admin_completed_quiz_attempts ca
join public.quiz_attempts qa on qa.id = ca.quiz_attempt_id
order by ca.student_id, ca.quiz_id, qa.submitted_at desc, qa.id desc;

comment on view app.v_admin_current_quiz_attempts is
  'Admin Dashboard (0039) internal building block: one row per (student_id, quiz_id) — that pair''s most-recently-SUBMITTED attempt in the current school year(s), regardless of attempt_status. Same dedup rule as public.v_student_current_quiz_attempts (0035): distinct on (student_id, quiz_id) order by submitted_at desc, reused rather than re-derived so "current attempt" means one thing across 0035, the Teacher Dashboard (0037/0038), and this Admin Dashboard. Tie-broken by qa.id desc for full determinism. A retake''s older superseded-but-submitted row never counts alongside the newer one, and the latest submission wins over the highest score. This is the sole source for app.v_admin_student_average_scores (view 5) and therefore for every score/proficiency/intervention metric below. security_invoker; only ever read from inside SECURITY DEFINER app.admin_dashboard_* functions.';

revoke all on app.v_admin_current_quiz_attempts from public, anon, authenticated;
grant select on app.v_admin_current_quiz_attempts to authenticated;


-- =============================================================================
-- View 4 — app.v_admin_active_students
--
-- One row per student who CURRENTLY (right now, not at attempt time)
-- holds an active enrollment (student_enrollments.status = 'active') in a
-- section that is BOTH in the current school year(s)
-- (app.v_admin_current_school_year_ids) AND itself status = 'active'
-- (section_status — an archived/inactive section does not count). A
-- student enrolled only in an archived section, or with no active
-- enrollment at all, has no row here. This is the single definition of
-- "currently active student" for this migration — total_students in
-- Function 1 and app.v_admin_student_average_scores (view 5) both read
-- from this view rather than re-deriving the condition independently, so
-- the archived-section rule is enforced in exactly one place.
-- student_enrollments_one_active_per_student (0006) guarantees at most one
-- active enrollment per student, so this is naturally one row per student.
-- =============================================================================
create view app.v_admin_active_students
with (security_invoker = true) as
select distinct se.student_id
from public.student_enrollments se
join public.sections sec on sec.id = se.section_id
where se.status = 'active'
  and sec.school_year_id in (select school_year_id from app.v_admin_current_school_year_ids)
  and sec.status = 'active';

comment on view app.v_admin_active_students is
  'Admin Dashboard (0039) internal building block: one row per student.id who currently holds an active student_enrollments row (status = ''active'') in a section that is both current-school-year (app.v_admin_current_school_year_ids) and itself status = ''active'' (section_status; archived/inactive sections excluded). The single source of "currently active student" for this migration — total_students (Function 1) and app.v_admin_student_average_scores (view 5, and therefore Average Mathematics Score, Students Requiring Intervention, the grade-level bar chart, and the proficiency pie chart) all filter through this view rather than re-deriving the condition. A student whose only enrollment is archived, or with no active enrollment, has no row here even if they have current-year completed quiz attempts on record. security_invoker; only ever read from inside SECURITY DEFINER app.admin_dashboard_* functions.';

revoke all on app.v_admin_active_students from public, anon, authenticated;
grant select on app.v_admin_active_students to authenticated;


-- =============================================================================
-- View 5 — app.v_admin_student_average_scores
--
-- Each CURRENTLY ACTIVE student's (app.v_admin_active_students, view 4)
-- own average score_percent across their own CURRENT (deduped, view 3)
-- attempts — one row per active student who has at least one completed
-- attempt. A student with completed attempts but no current active
-- enrollment in an active section is excluded here even though their
-- attempts exist in view 3. This is the single source every "per-student
-- average" metric in this migration reads from, so "one vote per student,
-- not per attempt, never a stale retake score, and never an
-- archived-section student" is enforced in exactly one place.
-- =============================================================================
create view app.v_admin_student_average_scores
with (security_invoker = true) as
select
  ca.student_id,
  round(avg(ca.score_percent), 1) as average_score_percent
from app.v_admin_current_quiz_attempts ca
join app.v_admin_active_students act on act.student_id = ca.student_id
group by ca.student_id;

comment on view app.v_admin_student_average_scores is
  'Admin Dashboard (0039) internal building block: one row per CURRENTLY ACTIVE student (app.v_admin_active_students — active enrollment in a current-year, status=''active'' section) with >= 1 completed attempt in the current school year(s), average_score_percent = that student''s own average score_percent across their own CURRENT, deduped attempts (app.v_admin_current_quiz_attempts — one row per (student,quiz), latest submission wins over any superseded retake). A student with completed attempts but no current active enrollment in an active section (e.g. transferred to an archived section, or no enrollment at all) has no row here — excluded from every downstream metric even though their attempts still exist in view 3. This is the sole source for Average Mathematics Score, Students Requiring Intervention, the grade-level bar chart, and the proficiency pie chart, so a student with zero completed attempts, or who is not currently active, is correctly excluded from all four. security_invoker; only ever read from inside SECURITY DEFINER app.admin_dashboard_* functions.';

revoke all on app.v_admin_student_average_scores from public, anon, authenticated;
grant select on app.v_admin_student_average_scores to authenticated;



-- =============================================================================
-- Function 1 — app.admin_dashboard_summary_tiles
--
-- The 6 stat cards, one row.
--
-- total_students now reads app.v_admin_active_students (view 4) directly
-- instead of re-deriving the active-enrollment/active-section condition
-- inline, so it shares the exact same "currently active student"
-- definition as average_mathematics_score and students_requiring_intervention
-- below (see ARCHIVED SECTIONS in the migration header).
--
-- total_teachers is deliberately NOT year-scoped — profiles has no
-- school_year_id column, and scoping via teacher_sections would undercount
-- a newly-approved teacher who has no current-year section assignment yet
-- (restated from the spec, not re-derived).
--
-- total_quiz_attempts is a raw COUNT(*) of app.v_admin_completed_quiz_attempts
-- rows — the one metric in this migration that is intentionally an
-- attempt count rather than a per-student-average aggregate (it answers
-- "how many completed attempts happened", not "how did students score"),
-- and intentionally NOT filtered through app.v_admin_active_students — a
-- completed attempt made while the student was still actively enrolled
-- still counts, even if that student's enrollment has since changed.
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
      from app.v_admin_student_average_scores sas
      where sas.average_score_percent < 70
    )::int as students_requiring_intervention;
end;
$$;

comment on function app.admin_dashboard_summary_tiles() is
  'Admin Dashboard (0039) 6 stat-card tiles, all scoped to the current school year(s) except total_teachers (profiles has no school_year_id — see 0039 header). total_students: COUNT of app.v_admin_active_students — students with a currently-active enrollment in a current-year, status=''active'' section only; a student whose only enrollment is in an archived section does not count. total_teachers: approved teachers, unscoped. total_sections: current-year sections with status = ''active'' only. total_quiz_attempts: raw COUNT of app.v_admin_completed_quiz_attempts rows, intentionally NOT filtered by app.v_admin_active_students (an activity count, not a per-student metric). average_mathematics_score: average of each currently-active student''s own average score (app.v_admin_student_average_scores, which is itself already filtered to app.v_admin_active_students), one vote per student. students_requiring_intervention: distinct students from that same per-student-average set scoring below 70 — matches the Teacher Dashboard''s own intervention threshold (app.dashboard_summary_tiles, 0037: average_score_percent < 70), by explicit decision, so the two dashboards agree on what "below average" means even though this metric is otherwise computed independently (system-wide vs teacher-scoped) and does NOT replicate the Teacher Dashboard''s second criterion (>= 2 missed/unfinished expected internal quizzes) — a student flagged only by that second criterion, with no low average score, will not appear here. SECURITY DEFINER + app.is_admin() guard — see 0039 header for why RLS alone is not sufficient gating for this endpoint.';

revoke all on function app.admin_dashboard_summary_tiles() from public, anon, authenticated;
grant execute on function app.admin_dashboard_summary_tiles() to authenticated;


-- =============================================================================
-- Function 2 — app.admin_dashboard_score_by_grade
--
-- One row per grade_level enum value (grade_4/grade_5/grade_6), even when a
-- grade level currently has zero qualifying students — mirroring 0037's
-- app.dashboard_avg_score_by_section, which likewise always returns one row
-- per section in scope rather than omitting empty ones. A grade level with
-- no qualifying students shows average_score_percent = NULL and
-- student_count = 0, so the bar chart can render an empty/zero bar instead
-- of silently missing a category.
--
-- Grade attribution uses each student's CURRENT active enrollment's
-- section (current school year), not the section frozen on any individual
-- quiz_attempts row — a student who transferred sections mid-year is
-- attributed to where they are now, not where they were when they took
-- past quizzes. The student set here is joined against
-- app.v_admin_active_students (the same "currently active student"
-- definition used everywhere else in this migration) rather than only
-- re-deriving the filter locally, even though a student's grade_level
-- still has to come from a fresh sections join (v_admin_active_students
-- itself carries no grade_level column).
-- =============================================================================
create or replace function app.admin_dashboard_score_by_grade()
returns table (
  grade_level             grade_level,
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
    raise exception 'admin_dashboard_score_by_grade: admin access required'
      using errcode = '42501';
  end if;

  return query
  with grade_levels as (
    select unnest(enum_range(null::grade_level)) as grade_level
  ),
  current_enrollment_grade as (
    select se.student_id, sec.grade_level
    from public.student_enrollments se
    join public.sections sec on sec.id = se.section_id
    join app.v_admin_active_students act on act.student_id = se.student_id
    where se.status = 'active'
      and sec.school_year_id in (select school_year_id from app.v_admin_current_school_year_ids)
      and sec.status = 'active'
  ),
  scored as (
    select ceg.grade_level, sas.student_id, sas.average_score_percent
    from current_enrollment_grade ceg
    join app.v_admin_student_average_scores sas on sas.student_id = ceg.student_id
  )
  select
    gl.grade_level,
    round(avg(sc.average_score_percent), 1) as average_score_percent,
    count(distinct sc.student_id)::int as student_count
  from grade_levels gl
  left join scored sc on sc.grade_level = gl.grade_level
  group by gl.grade_level
  order by gl.grade_level;
end;
$$;

comment on function app.admin_dashboard_score_by_grade() is
  'Admin Dashboard (0039) "Average Score by Grade Level" bar chart data: one row per grade_level enum value (grade_4/grade_5/grade_6), always — a grade with no qualifying students still appears with average_score_percent NULL and student_count 0, mirroring app.dashboard_avg_score_by_section''s (0037) always-one-row-per-section pattern. Grade attribution is via each student''s CURRENT active enrollment (student_enrollments.status = ''active'', current school year via app.v_admin_current_school_year_ids, section status = ''active''), joined against app.v_admin_active_students so the same "currently active student" definition applies here as everywhere else — not any section_id frozen on a quiz_attempts row, and not a student whose only enrollment is archived. average_score_percent averages app.v_admin_student_average_scores (0039, itself already active-student-filtered) values for students in that grade, one vote per student; student_count is the distinct student count backing that average, not an attempt count. SECURITY DEFINER + app.is_admin() guard — see 0039 header.';

revoke all on function app.admin_dashboard_score_by_grade() from public, anon, authenticated;
grant execute on function app.admin_dashboard_score_by_grade() to authenticated;


-- =============================================================================
-- Function 3 — app.admin_dashboard_proficiency_distribution
--
-- Buckets each currently-active student's own average score
-- (app.v_admin_student_average_scores — already filtered to
-- app.v_admin_active_students) into 4 proficiency bands. Unlike the
-- grade-level chart, a bucket with zero students has NO row (per spec) —
-- this is a pie chart, where an empty slice conveys nothing a missing
-- slice doesn't already convey, so there is no reason to force all 4
-- categories to appear.
--
-- percent is of the per-student-average set's row count (i.e. students
-- with >= 1 completed attempt) — NOT of Total Students from the summary
-- tiles. A student with zero completed attempts has no average to bucket
-- and is correctly excluded from both the numerator and the denominator.
-- =============================================================================
create or replace function app.admin_dashboard_proficiency_distribution()
returns table (
  bucket          text,
  student_count   int,
  percent         numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not app.is_admin() then
    raise exception 'admin_dashboard_proficiency_distribution: admin access required'
      using errcode = '42501';
  end if;

  return query
  with bucketed as (
    select
      sas.student_id,
      case
        when sas.average_score_percent >= 90 then 'Advanced'
        when sas.average_score_percent >= 75 then 'Proficient'
        when sas.average_score_percent >= 60 then 'Approaching Proficiency'
        else 'Below Basic'
      end as bucket
    from app.v_admin_student_average_scores sas
  ),
  denom as (
    select count(*) as total_n from app.v_admin_student_average_scores
  )
  select
    b.bucket,
    count(*)::int as student_count,
    round(100.0 * count(*) / nullif((select total_n from denom), 0), 1) as percent
  from bucketed b
  group by b.bucket
  order by
    case b.bucket
      when 'Advanced' then 1
      when 'Proficient' then 2
      when 'Approaching Proficiency' then 3
      when 'Below Basic' then 4
    end;
end;
$$;

comment on function app.admin_dashboard_proficiency_distribution() is
  'Admin Dashboard (0039) "Proficiency Distribution" pie chart data: buckets each currently-active student''s own average score (app.v_admin_student_average_scores, 0039 — already filtered to app.v_admin_active_students) into Advanced (90-100) / Proficient (75-89) / Approaching Proficiency (60-74) / Below Basic (<60). A bucket with zero students has no row (unlike the grade-level chart, which always returns all categories — see that function''s comment for why the two differ). percent is of the per-student-average set''s row count (currently-active students with >= 1 completed attempt), NOT of Total Students from admin_dashboard_summary_tiles — a student with zero completed attempts, or with no current active enrollment in an active section, has no average to bucket and is excluded from both numerator and denominator. SECURITY DEFINER + app.is_admin() guard — see 0039 header.';

revoke all on function app.admin_dashboard_proficiency_distribution() from public, anon, authenticated;
grant execute on function app.admin_dashboard_proficiency_distribution() to authenticated;


-- =============================================================================
-- public wrappers — thin pass-through, `security invoker` (default,
-- omitted below) in every case, exact one-line `select * from app.<fn>();`
-- pattern 0037's wrappers use. No additional logic; the admin check lives
-- entirely inside the app.* function each wrapper calls. `app` is not in
-- PostgREST's exposed-schema list (0001), so without these the Flutter
-- client's `.rpc('admin_dashboard_summary_tiles'/...)` calls would 404 —
-- the same class of gap 0020/0024/0034/0036/0037 already fixed for their
-- own app.* functions.
--
-- Granted execute to `authenticated` only (not service_role) — these are
-- called directly from an Admin's own Supabase Auth session, the same call
-- shape 0037's wrappers use, not the Edge-Function/service_role shape
-- 0018/0034 use.
-- =============================================================================
create or replace function public.admin_dashboard_summary_tiles()
returns table (
  total_students                   int,
  total_teachers                   int,
  total_sections                   int,
  total_quiz_attempts              int,
  average_mathematics_score        numeric,
  students_requiring_intervention  int
)
language sql
as $$
  select * from app.admin_dashboard_summary_tiles();
$$;

comment on function public.admin_dashboard_summary_tiles() is
  'Public-schema pass-through to app.admin_dashboard_summary_tiles (0039) so it is reachable via PostgREST from the Flutter client — see 0039 header. No additional logic; the admin check lives entirely inside app.admin_dashboard_summary_tiles.';

revoke all on function public.admin_dashboard_summary_tiles() from public, anon, authenticated;
grant execute on function public.admin_dashboard_summary_tiles() to authenticated;


create or replace function public.admin_dashboard_score_by_grade()
returns table (
  grade_level             grade_level,
  average_score_percent   numeric,
  student_count           int
)
language sql
as $$
  select * from app.admin_dashboard_score_by_grade();
$$;

comment on function public.admin_dashboard_score_by_grade() is
  'Public-schema pass-through to app.admin_dashboard_score_by_grade (0039) so it is reachable via PostgREST from the Flutter client — see 0039 header. No additional logic; the admin check lives entirely inside app.admin_dashboard_score_by_grade.';

revoke all on function public.admin_dashboard_score_by_grade() from public, anon, authenticated;
grant execute on function public.admin_dashboard_score_by_grade() to authenticated;


create or replace function public.admin_dashboard_proficiency_distribution()
returns table (
  bucket          text,
  student_count   int,
  percent         numeric
)
language sql
as $$
  select * from app.admin_dashboard_proficiency_distribution();
$$;

comment on function public.admin_dashboard_proficiency_distribution() is
  'Public-schema pass-through to app.admin_dashboard_proficiency_distribution (0039) so it is reachable via PostgREST from the Flutter client — see 0039 header. No additional logic; the admin check lives entirely inside app.admin_dashboard_proficiency_distribution.';

revoke all on function public.admin_dashboard_proficiency_distribution() from public, anon, authenticated;
grant execute on function public.admin_dashboard_proficiency_distribution() to authenticated;
