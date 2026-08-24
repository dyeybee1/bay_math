-- =============================================================================
-- Migration: 0052_admin_competency_mastery.sql
-- Admin -> Competency Mastery report (SQL only). Flutter wiring is a
-- separate, later change; this migration is purely additive SQL. NO
-- EXISTING OBJECT IS MODIFIED, ALTERed, DROPped, or REPLACEd — nothing in
-- 0001-0051 is touched.
--
-- PURPOSE — school-wide average mastery % per competency
-- (question_bank.topic), filterable by grade_level, section_id, and
-- school_year_id (NULL school_year_id = "All Time", every school year).
--
-- THREE-LAYER OBJECT SHAPE (identical to 0039-0041, 0051):
--   1. Internal `app.v_admin_competency_mastery_rows` view, `security_
--      invoker = true`, unreachable from PostgREST (`app` is not an
--      exposed schema, 0001) — building block only, no admin guard of its
--      own since nothing external can reach it directly.
--   2. `app.admin_competency_mastery(...)` — `language plpgsql`,
--      `security definer`, `set search_path = public`, starting with the
--      `app.is_admin()` guard.
--   3. Thin `public.admin_competency_mastery(...)` wrapper — plain
--      `language sql`, default (SECURITY INVOKER), one-line
--      `select * from app.admin_competency_mastery(...)`, reachable from
--      the Flutter client via `.rpc(...)`. The admin check lives entirely
--      inside the app.* function it wraps.
--
-- WHY SECURITY DEFINER (same reasoning as 0039/0051's headers, restated
-- briefly): RLS already gives an Admin session unrestricted rows on
-- quiz_attempts/quiz_attempt_answers/question_bank/sections, but that is a
-- floor on what an Admin CAN read, not a gate on who may call this
-- endpoint. A plain SECURITY INVOKER function would let a non-admin
-- authenticated session call it too. So the outward-facing function is
-- `security definer`, `set search_path = public`, starting with an
-- explicit `app.is_admin()` guard raising 42501 for anyone else.
--
-- Every object below gets an explicit
-- `revoke all on ... from public, anon, authenticated;` followed by a
-- narrow grant to `authenticated` only — matching 0037/0039-0041/0051
-- exactly. `authenticated` already has `usage on schema app` (granted in
-- 0016), so no additional schema-level grant is needed.
--
-- ROW SHAPE — per the task spec:
--   topic (text), questions_total (int), questions_correct (int),
--   mastery_percent (numeric). question_bank.topic is used verbatim (same
--   as public.v_student_topic_mastery, 0035, rule #9) — never shortened or
--   remapped. See the DATA CHECK note below on what topic actually
--   contains. NULL-topic questions are excluded, same as
--   v_student_topic_mastery.
--
-- QUALIFYING ATTEMPT — this migration reuses two different existing
-- pieces of logic for two different halves of the same metric, and this
-- note exists specifically to be explicit about which is which:
--   - WHICH ATTEMPTS COUNT: reused verbatim from 0051's qualifying-attempt
--     view, app.v_admin_quiz_results_current_attempts — Regular Internal
--     Quiz attempts only (quizzes.quiz_type = 'internal'), completed only
--     (submitted_at is not null), never a superseded attempt
--     (attempt_status <> 'superseded'), latest submitted attempt only per
--     (student_id, quiz_id) (`distinct on (student_id, quiz_id) order by
--     submitted_at desc, id desc`), across ALL school years (school_year
--     filtering is applied as a parameter below, not baked into the
--     attempt set). This view is READ from directly rather than
--     re-derived — one less place the qualifying-attempt rule could ever
--     drift out of sync with Quiz Results. Grade/section for filtering
--     come from the attempt's HISTORICAL quiz_attempts.section_id (frozen
--     at attempt time, 0010), joined to sections.grade_level / .id, same
--     source 0051 uses — the section the student was actually in when
--     they took the quiz, not their current enrollment. Archived sections
--     are excluded LIVE: the join to sections requires status = 'active',
--     evaluated at query time, not frozen — same rule 0051 view 2 uses.
--   - HOW MASTERY IS COMPUTED PER TOPIC: reused from public.
--     v_student_topic_mastery (0035) — group each qualifying attempt's
--     quiz_attempt_answers by question_bank.topic (excluding NULL topics),
--     correct = count(*) filter (where qaa.is_correct), total = count(*),
--     mastery_percent = round(100.0 * correct / nullif(total, 0), 1).
--     v_student_topic_mastery computes this per-student
--     (app.current_student_id()); this migration computes the identical
--     per-topic correct/total arithmetic aggregated across every student
--     whose qualifying attempts match the admin's grade/section/school-year
--     filters instead of one student — same formula, wider population.
--   These two pieces do not fully agree with each other independently:
--     v_student_topic_mastery's own "current attempt" building block
--     (public.v_student_current_quiz_attempts, 0035) has NO quiz_type
--     filter and does NOT exclude attempt_status = 'superseded' — it is
--     looser than 0051's qualifying-attempt rule. Per the task spec
--     ("Regular Internal Quiz attempts only... mirror 0051's qualifying
--     attempt logic"), this migration deliberately follows 0051's
--     stricter attempt-qualification rule, not 0035's looser one, while
--     reusing 0035's per-topic aggregation arithmetic on top of it. This
--     is a considered choice, not an oversight — flagging it explicitly
--     since the two existing precedents disagree and a future migration
--     should not assume they were reconciled here.
--
-- SCHOOL YEAR — p_school_year_id is nullable; NULL means "All Time" (no
-- filter at all), matching 0051's convention exactly. A non-null value
-- filters to that one value against each qualifying attempt's own frozen
-- quiz_attempts.school_year_id (carried through
-- app.v_admin_quiz_results_current_attempts).
--
-- GRADE / SECTION — p_grade_level and p_section_id are both nullable;
-- NULL means "all grades" / "all sections" respectively, same convention.
-- Declared as the `grade_level` enum type (not `text`) to match
-- app.admin_quiz_results' own p_grade_level parameter (0051) and every
-- other admin RPC in this codebase — the task note's "p_grade_level text"
-- wording is read as describing the filter's behavior, not literally
-- overriding the established enum-typed parameter convention.
--
-- SECOND RPC — CHECKED FIRST, NOT ADDED: the task asks for a
-- public.admin_competency_mastery_school_years() lookup RPC "if one
-- doesn't already exist and get reused." One already does:
-- public.admin_quiz_results_school_years() (0051) returns every
-- public.school_years row (school_year_id, label, is_current), unfiltered
-- by feature, ordered most-recent-first — exactly the shape a School Year
-- filter dropdown needs, and it is not specific to Quiz Results in any way
-- that would make reusing it here incorrect. Rather than add a second,
-- functionally-identical RPC under a new name, this migration adds NO
-- school-years lookup object; the Flutter-side Competency Mastery screen
-- should call the existing public.admin_quiz_results_school_years().
--
-- DATA CHECK (see task spec) — question_bank.topic does NOT contain the
-- six short competency labels shown in the admin mockup ("Number Sense",
-- "Fractions & Decimals", "Geometry", "Measurement", "Problem Solving",
-- "Data & Probability"). Every seed migration inspected (0027, 0044, and
-- others following the same pattern) tags question_bank.topic to the
-- OWNING LESSON'S TITLE verbatim — e.g. 'Addition and Subtraction of
-- Numbers up to 1,000,000', 'Comparing Numbers up to 1,000,000' — per
-- 0027's own header comment ("question_bank.topic is tagged to match the
-- owning lesson's title, for the Highest/Lowest Performing Topics
-- dashboard metric, schema comment, 0008") and 0035's
-- v_student_topic_mastery comment, which independently warns of the same
-- thing. This migration does NOT hardcode a mapping from the six mockup
-- labels to stored topic strings — per the task's explicit instruction,
-- the SQL returns whatever topic strings actually exist in question_bank,
-- unfiltered and unmapped (one row per distinct lesson-title-style topic
-- string, not one row per mockup label). Reconciling the six-label mockup
-- against the real lesson-title values is a separate, later decision
-- (either a display-layer grouping in Flutter, or a future schema/seed
-- change) — out of scope for this additive SQL migration.
-- =============================================================================


-- =============================================================================
-- View — app.v_admin_competency_mastery_rows
--
-- One row per (qualifying attempt, answered question): every
-- quiz_attempt_answers row belonging to a qualifying attempt from
-- app.v_admin_quiz_results_current_attempts (0051 — see migration header
-- for the exact qualifying-attempt rule reused), joined to that question's
-- question_bank.topic and to the attempt's HISTORICAL, currently-active
-- section (for grade_level / section_id filtering). NULL-topic questions
-- are excluded here, same as v_student_topic_mastery (0035).
--
-- Carries student_id, section_id, grade_level, school_year_id, topic, and
-- is_correct as raw columns — no aggregation in this view. The aggregation
-- (per-topic correct/total across whichever students match the filters)
-- happens in app.admin_competency_mastery below, so the filters can be
-- applied server-side before the group by, exactly like every other
-- app.admin_* function's view -> function split.
-- =============================================================================
create view app.v_admin_competency_mastery_rows
with (security_invoker = true) as
select
  ca.student_id,
  ca.section_id,
  sec.grade_level,
  ca.school_year_id,
  qb.topic,
  qaa.is_correct
from app.v_admin_quiz_results_current_attempts ca
join public.sections sec on sec.id = ca.section_id and sec.status = 'active'
join public.quiz_attempt_answers qaa on qaa.quiz_attempt_id = ca.quiz_attempt_id
join public.question_bank qb on qb.id = qaa.question_id
where qb.topic is not null;

comment on view app.v_admin_competency_mastery_rows is
  'Admin Competency Mastery (0052) internal building block: one row per answered question from a qualifying attempt (app.v_admin_quiz_results_current_attempts, 0051 — Regular Internal Quiz, completed, non-superseded, latest per student+quiz), joined to question_bank.topic (NULL topics excluded, same as v_student_topic_mastery, 0035) and to the attempt''s HISTORICAL, currently-active section for grade_level/section_id filtering. No aggregation here — app.admin_competency_mastery groups this by topic after applying its filters. security_invoker; only ever read from inside SECURITY DEFINER app.admin_competency_mastery.';

revoke all on app.v_admin_competency_mastery_rows from public, anon, authenticated;
grant select on app.v_admin_competency_mastery_rows to authenticated;


-- =============================================================================
-- Function — app.admin_competency_mastery
--
-- The Competency Mastery report's data source: app.v_admin_competency_
-- mastery_rows grouped by topic, after applying all three optional
-- filters server-side, mirroring v_student_topic_mastery's (0035) exact
-- correct/total/mastery_percent arithmetic — see migration header for why
-- these two pieces (0051's attempt-qualification + 0035's per-topic
-- arithmetic) are combined rather than reusing either metric wholesale.
-- =============================================================================
create or replace function app.admin_competency_mastery(
  p_school_year_id  uuid default null,
  p_grade_level     grade_level default null,
  p_section_id      uuid default null
)
returns table (
  topic             text,
  questions_total   integer,
  questions_correct integer,
  mastery_percent   numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not app.is_admin() then
    raise exception 'admin_competency_mastery: admin access required'
      using errcode = '42501';
  end if;

  return query
  select
    r.topic,
    count(*)::integer                                              as questions_total,
    count(*) filter (where r.is_correct)::integer                  as questions_correct,
    round(
      100.0 * count(*) filter (where r.is_correct) / nullif(count(*), 0),
      1
    )                                                               as mastery_percent
  from app.v_admin_competency_mastery_rows r
  where (p_grade_level is null or r.grade_level = p_grade_level)
    and (p_section_id is null or r.section_id = p_section_id)
    and (p_school_year_id is null or r.school_year_id = p_school_year_id)
  group by r.topic
  order by r.topic;
end;
$$;

comment on function app.admin_competency_mastery(uuid, grade_level, uuid) is
  'Admin Competency Mastery (0052) main data source: app.v_admin_competency_mastery_rows grouped by question_bank.topic (used verbatim, never remapped — see 0052 DATA CHECK note on what topic actually contains), after applying all three optional filters server-side. p_school_year_id NULL = "All Time" (no filter, default scope), matching app.admin_quiz_results'' (0051) convention exactly; non-null filters to that value against each qualifying attempt''s own frozen school_year_id. p_grade_level/p_section_id NULL = all grades/sections. mastery_percent reuses public.v_student_topic_mastery''s (0035) exact formula: round(100.0 * correct / nullif(total, 0), 1). SECURITY DEFINER + app.is_admin() guard — see 0052 header for why RLS alone is not sufficient gating for this endpoint (same reasoning as 0039/0051).';

revoke all on function app.admin_competency_mastery(uuid, grade_level, uuid) from public, anon, authenticated;
grant execute on function app.admin_competency_mastery(uuid, grade_level, uuid) to authenticated;


-- =============================================================================
-- public wrapper — thin pass-through, `security invoker` (default,
-- omitted below), one-line `select * from app.admin_competency_mastery(...)`
-- pattern 0039-0041/0051 already use. Reachable from the Flutter client
-- via `.rpc('admin_competency_mastery', ...)`. Granted execute to
-- `authenticated` only; the admin check lives entirely inside
-- app.admin_competency_mastery.
--
-- No public.admin_competency_mastery_school_years() wrapper is added —
-- see the 0052 header's "SECOND RPC" note: public.
-- admin_quiz_results_school_years() (0051) already covers this need and
-- is not Quiz-Results-specific in any way that would make reuse wrong.
-- =============================================================================
create or replace function public.admin_competency_mastery(
  p_school_year_id  uuid default null,
  p_grade_level     grade_level default null,
  p_section_id      uuid default null
)
returns table (
  topic             text,
  questions_total   integer,
  questions_correct integer,
  mastery_percent   numeric
)
language sql
as $$
  select * from app.admin_competency_mastery(
    p_school_year_id,
    p_grade_level,
    p_section_id
  );
$$;

comment on function public.admin_competency_mastery(uuid, grade_level, uuid) is
  'Public-schema pass-through to app.admin_competency_mastery (0052) so it is reachable via PostgREST from the Flutter client. No additional logic; the admin check lives entirely inside app.admin_competency_mastery. Pair this with the existing public.admin_quiz_results_school_years() (0051) for the School Year filter dropdown — no new lookup RPC was added for that, see 0052 header.';

revoke all on function public.admin_competency_mastery(uuid, grade_level, uuid) from public, anon, authenticated;
grant execute on function public.admin_competency_mastery(uuid, grade_level, uuid) to authenticated;
