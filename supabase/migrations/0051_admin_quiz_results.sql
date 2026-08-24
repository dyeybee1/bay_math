-- =============================================================================
-- Migration: 0051_admin_quiz_results.sql
-- Admin -> Quiz Results (Part 1 — SQL only). Flutter wiring (models/
-- repository/providers/screen) is a separate, later change; this migration
-- is purely additive SQL. NO EXISTING OBJECT IS MODIFIED, ALTERed, DROPped,
-- or REPLACEd — nothing from 0001-0050 is touched.
--
-- PURPOSE — school-wide assessment result monitoring, one flat row per
-- qualifying completed Internal Quiz attempt, with server-side filtering by
-- grade, section, assessment type, and school year. This is a Quiz Results
-- LIST, not a dashboard aggregate — it deliberately does not reuse
-- 0039-0041's "current school year only" scoping (app.v_admin_current_
-- school_year_ids); default scope here is ALL school years, per spec.
--
-- WHY SECURITY DEFINER (same reasoning as 0039's header, restated briefly):
-- RLS already gives an Admin session unrestricted rows on quiz_attempts/
-- students/sections/quizzes, but that is a floor on what an Admin CAN read,
-- not a gate on who may call this endpoint. A plain SECURITY INVOKER
-- function would let a Teacher session call it too and silently get back a
-- smaller, misleadingly-scoped result (their own sections only, per
-- app.teacher_has_section()) instead of an obvious failure — wrong for an
-- endpoint whose whole premise is unscoped, school-wide results. So the
-- outward-facing function is `security definer`, `set search_path =
-- public`, starting with an explicit `app.is_admin()` guard raising 42501
-- for anyone else, mirroring 0039/0040/0041 exactly.
--
-- THREE-LAYER OBJECT SHAPE (identical to 0039-0041):
--   1. Internal `app.v_admin_quiz_results_*` views, `security_invoker =
--      true`, unreachable from PostgREST (`app` is not an exposed schema,
--      0001) — building blocks only, no admin guard of their own since
--      nothing external can reach them directly.
--   2. `app.admin_quiz_results(...)` / `app.admin_quiz_results_school_
--      years()` — `language plpgsql`, `security definer`,
--      `set search_path = public`, each starting with the `app.is_admin()`
--      guard.
--   3. Thin `public.admin_quiz_results(...)` / `public.admin_quiz_results_
--      school_years()` wrappers — plain `language sql`, default
--      (SECURITY INVOKER), one-line `select * from app.<fn>(...)`,
--      reachable from the Flutter client via `.rpc(...)`. The admin check
--      lives entirely inside the app.* function each wraps.
--
-- Every object below gets an explicit
-- `revoke all on ... from public, anon, authenticated;` followed by a
-- narrow grant to `authenticated` only — matching 0037/0039-0041 exactly.
-- `authenticated` already has `usage on schema app` (granted in 0016), so
-- no additional schema-level grant is needed for the internal views or the
-- app.* functions.
--
-- ROW SHAPE — matches the locked spec exactly:
--   quiz_attempt_id, student_name, section_id, section_name, grade_level,
--   quiz_id, assessment_name, assessment_type, score, total_questions,
--   percentage, date_taken, status ('passed' / 'needs_improvement').
-- student_id/school_year_id are also carried through the internal views
-- (not part of the final public row shape below, since they weren't in the
-- locked column list) purely as join keys for the filter logic — see each
-- view's own comment.
--
-- QUALIFYING ATTEMPT, restated from the locked spec (every clause below is
-- a direct, unmodified restatement of a spec decision, not a re-derivation):
--   - quizzes.quiz_type = 'internal' only (External Activities excluded).
--   - quiz_attempts.submitted_at is not null (completed only; in-progress
--     attempts never appear).
--   - quiz_attempts.attempt_status <> 'superseded' (a superseded attempt
--     never appears, even if it happens to be the most-recently-submitted
--     row for that (student, quiz) pair because the newer active attempt
--     is still in progress — see view 1's own comment for why this can
--     matter even though quiz_attempts_one_active_per_student_quiz, 0010,
--     already guarantees at most one 'active' row per pair).
--   - Latest submitted attempt only, per (student_id, quiz_id) — same
--     `distinct on (student_id, quiz_id) order by submitted_at desc, id
--     desc` rule already centralized in app.v_admin_current_quiz_attempts
--     (0039). That existing view itself is NOT reused directly here (its
--     upstream app.v_admin_completed_quiz_attempts, 0039, is hard-scoped
--     to the current school year via app.v_admin_current_school_year_ids —
--     wrong for this feature's "All school years by default" scope), so
--     the same dedup RULE is re-expressed against an all-time, quiz_type-
--     filtered, non-superseded attempt set below instead — see view 1.
--   - Grade/section come from the HISTORICAL quiz_attempts.section_id
--     (frozen at attempt time, 0010) -> sections.grade_level / .name — the
--     exact same source and rationale 0045's v_teacher_quiz_results
--     already uses (the section the student was actually in when they
--     took the quiz, not their current enrollment).
--   - Archived sections are excluded LIVE: sections.status = 'active' is
--     evaluated at query time in view 2 below, not frozen at attempt time
--     and not cached — if a section is archived, its rows disappear from
--     this feature immediately; if restored, they reappear immediately.
--     This applies uniformly, including to the current school year, and
--     is a materially different rule from 0039's app.v_admin_active_
--     students (which gates on a STUDENT's current active enrollment) —
--     nothing here reads that view, since Quiz Results scopes by the
--     attempt's own frozen section, not the student's present enrollment.
--   - Assessment Type: three-way filter (pre_test / post_test / regular),
--     where regular means quizzes.assessment_type IS NULL — same mapping
--     QuizResultsAssessmentFilter (lib/features/teacher/data/
--     teacher_quiz_results_providers.dart) already uses for the identical
--     concept on the Teacher screen. See app.admin_quiz_results' own
--     comment for the exact parameter representation chosen.
--   - School Year: p_school_year_id is nullable; NULL means "All Time" (no
--     filter at all) — the Flutter-side dropdown's "All Time" option is a
--     UI-only sentinel that simply omits this parameter, not a real
--     school_years row. A non-null value filters to that ONE attempt's own
--     frozen quiz_attempts.school_year_id (post-dedup — see view 1's own
--     comment on why this is correct even though quizzes themselves are
--     not year-scoped and a retake can in principle span two different
--     school years).
-- =============================================================================


-- =============================================================================
-- View 1 — app.v_admin_quiz_results_current_attempts
--
-- One row per (student_id, quiz_id): that pair's single latest-submitted,
-- non-superseded, Internal-Quiz attempt, across ALL school years (no
-- current-year restriction — this feature's default scope is "All school
-- years", unlike 0039-0041's dashboards). Carries only join-key/raw
-- columns; display columns (names, section, assessment title, percentage,
-- status) are added in view 2.
--
-- DEDUP RULE — same `distinct on (student_id, quiz_id) order by
-- submitted_at desc, id desc` centralized in app.v_admin_current_quiz_
-- attempts (0039), re-expressed here rather than reused directly because
-- that view's upstream is hard-scoped to the current school year (wrong
-- for this all-time-by-default feature). Re-expressing it against an
-- attempt set that is ALSO already filtered to attempt_status <>
-- 'superseded' (see next paragraph) makes the DISTINCT ON a belt-and-
-- braces safety net in the common case (quiz_attempts_one_active_per_
-- student_quiz, 0010, already guarantees at most one 'active' row per
-- (student_id, quiz_id) pair once superseded rows are excluded) — kept
-- explicit anyway so the rule reads identically to its 0039 counterpart
-- and stays correct even if that invariant ever changes.
--
-- WHY attempt_status <> 'superseded' IS FILTERED HERE, SEPARATELY FROM THE
-- DEDUP RULE: an 'active' attempt does not have to be submitted yet (a
-- student can be mid-retake). If the newest 'active' attempt for a pair is
-- still in progress (submitted_at is null), the most-recently-SUBMITTED
-- row for that pair could be an older, already-'superseded' attempt left
-- behind by the retake. Filtering out attempt_status = 'superseded' rows
-- BEFORE the distinct-on ensures that scenario shows the student as having
-- no current result for that quiz (correct — they're mid-retake) rather
-- than resurfacing their stale, superseded score.
--
-- quiz_type = 'internal' is enforced here (via a join to quizzes) rather
-- than deferred to view 2, so the dedup/latest-attempt logic itself never
-- considers an External Activity attempt in the first place.
-- =============================================================================
create view app.v_admin_quiz_results_current_attempts
with (security_invoker = true) as
select distinct on (qa.student_id, qa.quiz_id)
  qa.id              as quiz_attempt_id,
  qa.student_id,
  qa.quiz_id,
  qa.section_id,
  qa.school_year_id,
  qa.score,
  qa.total_questions,
  qa.submitted_at
from public.quiz_attempts qa
join public.quizzes qz on qz.id = qa.quiz_id
where qa.submitted_at is not null
  and qa.attempt_status <> 'superseded'
  and qz.quiz_type = 'internal'
order by qa.student_id, qa.quiz_id, qa.submitted_at desc, qa.id desc;

comment on view app.v_admin_quiz_results_current_attempts is
  'Admin Quiz Results (0051) internal building block: one row per (student_id, quiz_id) — that pair''s single latest-submitted, non-superseded, Internal-Quiz attempt, across ALL school years (no current-year restriction, unlike 0039''s app.v_admin_current_quiz_attempts, which this view deliberately does not build on). Same distinct-on-submitted_at-desc-then-id-desc dedup rule as app.v_admin_current_quiz_attempts (0039), re-expressed against an attempt set already filtered to attempt_status <> ''superseded'' and quiz_type = ''internal'' — see migration header for why the superseded-exclusion happens before, not instead of, the dedup (a mid-retake student with an in-progress newest attempt must show no current result, not a resurfaced stale score). security_invoker; only ever read from inside SECURITY DEFINER app.admin_quiz_results.';

revoke all on app.v_admin_quiz_results_current_attempts from public, anon, authenticated;
grant select on app.v_admin_quiz_results_current_attempts to authenticated;


-- =============================================================================
-- View 2 — app.v_admin_quiz_results_rows
--
-- The full display row: view 1's current attempts joined out to student
-- name, the attempt's HISTORICAL section (name + grade_level, frozen at
-- attempt time per 0010 — same source/rationale as 0045's
-- v_teacher_quiz_results), and the quiz's title/assessment_type, plus the
-- computed percentage and passed/needs_improvement status.
--
-- ARCHIVED SECTIONS EXCLUDED LIVE: the join to sections requires
-- sec.status = 'active', evaluated fresh every time this view (and
-- therefore app.admin_quiz_results) is queried — not a frozen snapshot.
-- An attempt whose historical section has since been archived simply has
-- no row here; if that section is later restored to active, the row
-- reappears on the very next query. This is an inner join (not left), so
-- it doubles as the filter — no separate WHERE clause needed for it.
--
-- PERCENTAGE — reuses the exact formula already used in 0035/0039/0045:
-- round(100.0 * score / nullif(total_questions, 0), 1).
--
-- STATUS — Passed (>= 70%) / Needs Improvement (< 70%), per spec. If
-- percentage itself is NULL (only possible if total_questions is NULL or
-- 0 on an otherwise-qualifying attempt — not expected for a completed
-- Internal Quiz attempt in practice, but guarded rather than assumed),
-- status is also NULL rather than defaulting either way, so a UI bug in
-- computing the threshold can never silently mislabel an attempt with no
-- real percentage as either passed or needing improvement.
-- =============================================================================
create view app.v_admin_quiz_results_rows
with (security_invoker = true) as
select
  ca.quiz_attempt_id,
  ca.student_id,
  st.full_name                                                as student_name,
  ca.section_id,
  sec.name                                                     as section_name,
  sec.grade_level,
  ca.school_year_id,
  ca.quiz_id,
  qz.title                                                     as assessment_name,
  qz.assessment_type,
  ca.score,
  ca.total_questions,
  round(100.0 * ca.score / nullif(ca.total_questions, 0), 1)   as percentage,
  ca.submitted_at                                              as date_taken,
  case
    when round(100.0 * ca.score / nullif(ca.total_questions, 0), 1) >= 70 then 'passed'
    when round(100.0 * ca.score / nullif(ca.total_questions, 0), 1) < 70 then 'needs_improvement'
    else null
  end                                                           as status
from app.v_admin_quiz_results_current_attempts ca
join public.students st on st.id = ca.student_id
join public.sections sec on sec.id = ca.section_id and sec.status = 'active'
join public.quizzes qz on qz.id = ca.quiz_id;

comment on view app.v_admin_quiz_results_rows is
  'Admin Quiz Results (0051) internal building block: one fully-assembled display row per app.v_admin_quiz_results_current_attempts row (view 1), joined to student full_name, the attempt''s HISTORICAL section name/grade_level (frozen quiz_attempts.section_id, 0010 — same source as 0045''s v_teacher_quiz_results), and the quiz''s title/assessment_type. The join to sections requires status = ''active'', evaluated live on every query (not frozen) — an attempt whose historical section is currently archived has no row here, and reappears immediately if the section is restored; this applies even to current-school-year attempts. percentage reuses the round(100.0 * score / nullif(total_questions, 0), 1) formula from 0035/0039/0045; status is ''passed'' (>=70) / ''needs_improvement'' (<70) / NULL only in the edge case percentage itself is NULL. This is the single source app.admin_quiz_results filters and returns from. security_invoker; only ever read from inside SECURITY DEFINER app.admin_quiz_results.';

revoke all on app.v_admin_quiz_results_rows from public, anon, authenticated;
grant select on app.v_admin_quiz_results_rows to authenticated;


-- =============================================================================
-- Function 1 — app.admin_quiz_results
--
-- The Quiz Results screen's main data source: every app.v_admin_quiz_
-- results_rows row (view 2) matching all four optional filters. All
-- filtering happens server-side inside this function, via parameters —
-- never fetch-all-then-filter-client-side, per spec. Returns a plain set
-- of rows (no pre-aggregation, no pagination) so pagination can be added
-- later (e.g. LIMIT/OFFSET params, or a keyset-based cursor) without a
-- rewrite of this function's shape — deferred for this MVP, per spec.
--
-- p_assessment_type_filter — the three-way Pre-Test/Post-Test/Regular
-- filter, PLUS "no filter" (show every assessment type together) as a
-- fourth, separate state. quizzes.assessment_type (0043) is a real
-- 2-value Postgres enum (pre_test/post_test) with no third "regular"
-- value — mirroring the app-layer QuizResultsAssessmentFilter enum
-- (lib/features/teacher/data/teacher_quiz_results_providers.dart), which
-- deliberately does NOT widen the real assessment_type enum for the same
-- reason. A 4th, "no filter" state cannot be expressed by widening a
-- Postgres enum either (there is no enum value that means "don''t
-- filter"), so this parameter is `text`, accepting exactly one of
-- ''pre_test'' / ''post_test'' / ''regular'', or NULL for no filter at
-- all (every assessment type shown). Any other text value raises an
-- exception rather than silently matching zero rows. The mapping:
--   NULL          -> no filter, all assessment types included
--   ''pre_test''  -> quizzes.assessment_type = ''pre_test''
--   ''post_test'' -> quizzes.assessment_type = ''post_test''
--   ''regular''   -> quizzes.assessment_type IS NULL
--
-- p_school_year_id — NULL means "All Time" (default scope, no filter);
-- a non-null value filters to that one value against each already-deduped
-- row's own frozen school_year_id (view 1) — see migration header.
-- =============================================================================
create or replace function app.admin_quiz_results(
  p_grade_level             grade_level default null,
  p_section_id              uuid default null,
  p_assessment_type_filter  text default null,
  p_school_year_id          uuid default null
)
returns table (
  quiz_attempt_id   uuid,
  student_name      text,
  section_id        uuid,
  section_name      text,
  grade_level       grade_level,
  quiz_id           uuid,
  assessment_name   text,
  assessment_type   assessment_type,
  score             numeric,
  total_questions   smallint,
  percentage        numeric,
  date_taken        timestamptz,
  status            text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not app.is_admin() then
    raise exception 'admin_quiz_results: admin access required'
      using errcode = '42501';
  end if;

  if p_assessment_type_filter is not null
     and p_assessment_type_filter not in ('pre_test', 'post_test', 'regular') then
    raise exception 'admin_quiz_results: p_assessment_type_filter must be one of pre_test, post_test, regular, or null'
      using errcode = '22023';
  end if;

  return query
  select
    r.quiz_attempt_id,
    r.student_name,
    r.section_id,
    r.section_name,
    r.grade_level,
    r.quiz_id,
    r.assessment_name,
    r.assessment_type,
    r.score,
    r.total_questions,
    r.percentage,
    r.date_taken,
    r.status
  from app.v_admin_quiz_results_rows r
  where (p_grade_level is null or r.grade_level = p_grade_level)
    and (p_section_id is null or r.section_id = p_section_id)
    and (
      p_assessment_type_filter is null
      or (p_assessment_type_filter = 'regular' and r.assessment_type is null)
      or (p_assessment_type_filter = 'pre_test' and r.assessment_type = 'pre_test')
      or (p_assessment_type_filter = 'post_test' and r.assessment_type = 'post_test')
    )
    and (p_school_year_id is null or r.school_year_id = p_school_year_id)
  order by r.date_taken desc, r.quiz_attempt_id desc;
end;
$$;

comment on function app.admin_quiz_results(grade_level, uuid, text, uuid) is
  'Admin Quiz Results (0051) main data source: every app.v_admin_quiz_results_rows row (view 2) matching all four optional filters (grade, section, assessment type, school year), server-side. p_assessment_type_filter is one of ''pre_test'' / ''post_test'' / ''regular'' (= assessment_type IS NULL, mirroring QuizResultsAssessmentFilter) or NULL for no filter at all — any other text value raises 22023. p_school_year_id NULL = "All Time" (default scope); non-null filters to that value against each row''s own frozen school_year_id. Returns a plain row set, ordered most-recent-first, deliberately unaggregated so pagination can be layered on later without a rewrite. SECURITY DEFINER + app.is_admin() guard — see 0051 header for why RLS alone is not sufficient gating for this endpoint (same reasoning as 0039).';

revoke all on function app.admin_quiz_results(grade_level, uuid, text, uuid) from public, anon, authenticated;
grant execute on function app.admin_quiz_results(grade_level, uuid, text, uuid) to authenticated;


-- =============================================================================
-- Function 2 — app.admin_quiz_results_school_years
--
-- Lookup RPC backing the School Year filter dropdown. Searched the
-- existing migrations first (per spec) for an equivalent — none exists:
-- the only related object is app.v_admin_current_school_year_ids (0039),
-- which returns only the CURRENT year(s) (is_current = true) and is not
-- reachable from PostgREST in any case (app is outside the exposed-schema
-- list, 0001; nothing in 0039-0041 adds a public.* wrapper for it, since
-- no prior feature needed a full year list). This is therefore a new
-- object, not a reuse.
--
-- Returns EVERY school_years row (no status or is_current filter) so an
-- Admin can filter Quiz Results by any past year, not only ''active''
-- ones — consistent with this feature''s own "All school years by
-- default" scope. No app.v_* view layer for this one: it is a single flat
-- table listing with no reuse elsewhere, matching the same shape 0041''s
-- app.admin_dashboard_teachers_list/app.admin_dashboard_sections_list
-- use (a plain query straight from the SECURITY DEFINER function body,
-- no intermediate internal view). The Flutter-side "All Time" option is a
-- UI-only sentinel (NULL school_year_id, see app.admin_quiz_results''
-- comment) — it is never a row returned by this function.
-- =============================================================================
create or replace function app.admin_quiz_results_school_years()
returns table (
  school_year_id  uuid,
  label           text,
  is_current      boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not app.is_admin() then
    raise exception 'admin_quiz_results_school_years: admin access required'
      using errcode = '42501';
  end if;

  return query
  select
    sy.id,
    sy.label,
    sy.is_current
  from public.school_years sy
  order by sy.start_date desc;
end;
$$;

comment on function app.admin_quiz_results_school_years() is
  'Admin Quiz Results (0051) lookup RPC for the School Year filter dropdown: every public.school_years row (no status/is_current filter — an Admin may filter Quiz Results by any past year, not just active ones), most recent start_date first. No equivalent existed prior to this migration (searched first, per spec) — app.v_admin_current_school_year_ids, 0039, only exposes the CURRENT year(s) and has no public wrapper. The "All Time" dropdown option is a UI-only sentinel (NULL p_school_year_id on app.admin_quiz_results), never a row from this function. SECURITY DEFINER + app.is_admin() guard.';

revoke all on function app.admin_quiz_results_school_years() from public, anon, authenticated;
grant execute on function app.admin_quiz_results_school_years() to authenticated;


-- =============================================================================
-- public wrappers — thin pass-through, `security invoker` (default,
-- omitted below), one-line `select * from app.<fn>(...)` pattern
-- 0039-0041 already use. Reachable from the Flutter client via
-- `.rpc('admin_quiz_results'/'admin_quiz_results_school_years', ...)`.
-- Granted execute to `authenticated` only; the admin check lives entirely
-- inside each app.* function.
-- =============================================================================
create or replace function public.admin_quiz_results(
  p_grade_level             grade_level default null,
  p_section_id              uuid default null,
  p_assessment_type_filter  text default null,
  p_school_year_id          uuid default null
)
returns table (
  quiz_attempt_id   uuid,
  student_name      text,
  section_id        uuid,
  section_name      text,
  grade_level       grade_level,
  quiz_id           uuid,
  assessment_name   text,
  assessment_type   assessment_type,
  score             numeric,
  total_questions   smallint,
  percentage        numeric,
  date_taken        timestamptz,
  status            text
)
language sql
as $$
  select * from app.admin_quiz_results(
    p_grade_level,
    p_section_id,
    p_assessment_type_filter,
    p_school_year_id
  );
$$;

comment on function public.admin_quiz_results(grade_level, uuid, text, uuid) is
  'Public-schema pass-through to app.admin_quiz_results (0051) so it is reachable via PostgREST from the Flutter client. No additional logic; the admin check lives entirely inside app.admin_quiz_results.';

revoke all on function public.admin_quiz_results(grade_level, uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.admin_quiz_results(grade_level, uuid, text, uuid) to authenticated;


create or replace function public.admin_quiz_results_school_years()
returns table (
  school_year_id  uuid,
  label           text,
  is_current      boolean
)
language sql
as $$
  select * from app.admin_quiz_results_school_years();
$$;

comment on function public.admin_quiz_results_school_years() is
  'Public-schema pass-through to app.admin_quiz_results_school_years (0051) so it is reachable via PostgREST from the Flutter client. No additional logic; the admin check lives entirely inside app.admin_quiz_results_school_years.';

revoke all on function public.admin_quiz_results_school_years() from public, anon, authenticated;
grant execute on function public.admin_quiz_results_school_years() to authenticated;
