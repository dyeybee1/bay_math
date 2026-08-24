-- =============================================================================
-- Migration: 0038_teacher_dashboard_co_teacher_fix.sql
-- Phase 9 (Teacher Dashboard) follow-up fix — found while writing the co-
-- taught-section test scenario for 0037, NOT part of that migration's
-- originally-scoped four functions. Kept separate from 0037 rather than
-- edited in place, per this project's own "don't touch/redesign approved
-- migrations unless you find an actual bug — flag it, don't fix it
-- silently" rule (see 0023's header for the precedent this follows — every
-- follow-up fix in this project's history, 0019/0021/0023/0025/0034/0036,
-- is a new numbered file, never an in-place edit of the migration it
-- fixes, regardless of whether that migration had reached a shared
-- environment yet).
--
-- THE BUG
-- app.dashboard_summary_tiles and app.dashboard_student_roster (0037, both
-- SECURITY INVOKER) each build an expected_quizzes CTE as a UNION of two
-- branches: (a) built-in internal quizzes matching the student's section's
-- grade_level, and (b) teacher-created internal quizzes assigned to the
-- student's section via quiz_sections. Branch (a) reads public.quizzes
-- directly and works correctly, because quizzes_teacher_select (0015)
-- permits any approved teacher to read source_type = 'built_in' rows
-- regardless of authorship. Branch (b) ALSO reads public.quizzes directly
-- — but quizzes_teacher_select only permits a teacher to read a
-- source_type = 'teacher' row when created_by = auth.uid(). Since both
-- functions are SECURITY INVOKER, that restriction applies live during the
-- query: for a co-taught section (teacher_sections has no
-- one-teacher-per-section constraint — only one row per section may be
-- is_primary = true, see teacher_sections_one_primary_per_section, 0005 —
-- so a section can legitimately have more than one assigned teacher), a
-- quiz authored by the OTHER teacher on that section is silently excluded
-- from "expected quizzes" for students in that section, even though the
-- assignment itself (the quiz_sections row) is fully visible to the
-- calling teacher via quiz_sections_select (0015, teacher_has_section-
-- based, not authorship-based).
--
-- EFFECT: missed_or_unfinished_count can under-count, which means
-- students_needing_intervention (Function 1) and needs_intervention
-- (Function 3) can both produce false negatives — a student who genuinely
-- should be flagged for a gap in a colleague's assigned quiz isn't. This
-- is the exact same class of gap that justified
-- app.dashboard_competency_mastery's SECURITY DEFINER treatment for
-- question_bank in 0037 — just discovered in these two functions one
-- session too late to fold into that design the first time.
--
-- THE FIX — one new SECURITY DEFINER helper, called from both functions,
-- rather than each function re-solving (or worse, separately mis-solving)
-- the same gap. See the helper's own comment below for the full ownership-
-- re-verification justification, mirroring dashboard_competency_mastery's.
-- Only the previously-broken branch (b) is replaced in each caller; branch
-- (a) is untouched — it was never broken. Function 2
-- (dashboard_avg_score_by_section) is CONFIRMED unaffected: its body was
-- re-read before writing this migration, and it never joins public.quizzes
-- at all — it only aggregates over v_student_current_quiz_attempts, so
-- there is no quizzes-authorship path for this bug to reach. Function 4
-- (dashboard_competency_mastery) is untouched — it was already SECURITY
-- DEFINER and already re-derives its own section ownership; it does not
-- consume expected_quizzes at all (mastery is computed only from quizzes
-- a student actually answered, never from an "expected" set), so this bug
-- never applied to it in the first place.
-- =============================================================================


-- =============================================================================
-- Helper — app.section_expected_internal_quiz_ids
--
-- WHY THIS IS SECURITY DEFINER (mirrors app.dashboard_competency_mastery,
-- 0037, exactly — spelled out here in full rather than assumed obvious,
-- so a future reader does not need to go re-read that other function's
-- comment to understand why this one is safe):
--
-- The whole reason this function exists is to read source_type = 'teacher'
-- rows from public.quizzes regardless of created_by, for quizzes assigned
-- (via quiz_sections) to a section the CALLING teacher is genuinely
-- assigned to — even when that quiz was authored by a different teacher
-- co-assigned to the same section. quizzes_teacher_select (0015) does not
-- allow that read for a plain authenticated teacher session; a SECURITY
-- INVOKER caller hits exactly the silent-exclusion bug this migration
-- fixes (see header above). SECURITY DEFINER closes exactly that one gap
-- and no other: it does NOT widen quizzes_teacher_select itself (that
-- policy is untouched by this migration), and it does not let the calling
-- teacher browse every teacher-authored quiz in the system — the ownership
-- check below runs first, and if it fails, the function returns zero rows,
-- full stop, before either UNION branch is ever evaluated.
--
-- OWNERSHIP RE-VERIFICATION — first thing the function body does: an
-- `authorized` CTE that only produces a row at all when
-- app.teacher_has_section(p_section_id) is true for the calling teacher
-- (auth.uid(), read live at call time — not a cached or caller-supplied
-- claim). Both UNION branches below are joined FROM that CTE, so if it's
-- empty, the whole function returns zero rows — a caller cannot probe an
-- arbitrary section's quiz assignments just because this function no
-- longer relies on table-level RLS internally (SECURITY DEFINER bypasses
-- RLS entirely on every table it touches, which is exactly why this
-- explicit, first-thing-in-the-body check exists as the substitute). This
-- mirrors dashboard_competency_mastery's own section_id re-derivation
-- (0037) precisely: p_section_id is never trusted as "already authorized
-- by the caller," it is checked, every call.
--
-- NARROW EXPOSURE — returns quiz_id only, nothing else. Not quiz titles,
-- not authorship, not any other quizzes column — matching
-- dashboard_competency_mastery's own "topic only, not full question
-- content" narrowness (0037 header). Not called directly by the Flutter
-- client (no public.* wrapper is created for it) — it is only ever
-- invoked from inside dashboard_summary_tiles' and
-- dashboard_student_roster's own SQL bodies, both of which run as
-- SECURITY INVOKER. Because of that, the actual role checked for
-- permission to invoke THIS nested call is the calling teacher's own
-- `authenticated` role, not an internal service account — so `authenticated`
-- must be (and is, below) explicitly granted execute, confirmed by testing
-- rather than assumed (see 0038 test notes / Definition of Done).
-- =============================================================================
create or replace function app.section_expected_internal_quiz_ids(
  p_section_id uuid
)
returns table (
  quiz_id uuid
)
language sql
stable
security definer
set search_path = public
as $$
  with authorized as (
    select p_section_id as section_id
    where app.teacher_has_section(p_section_id)
  ),
  authorized_section as (
    select a.section_id, sec.grade_level
    from authorized a
    join public.sections sec on sec.id = a.section_id
  )
  select q.id as quiz_id
  from authorized_section asec
  join public.quizzes q
    on q.source_type = 'built_in'
   and q.quiz_type = 'internal'
   and q.grade_level = asec.grade_level
  union
  select q.id as quiz_id
  from authorized a
  join public.quiz_sections qs on qs.section_id = a.section_id
  join public.quizzes q on q.id = qs.quiz_id
  where q.source_type = 'teacher'
    and q.quiz_type = 'internal';
$$;

comment on function app.section_expected_internal_quiz_ids(uuid) is
  'Added 0038 to fix a co-taught-section under-count bug in dashboard_summary_tiles / dashboard_student_roster (0037) — see 0038 header. Returns the set of internal quiz ids "expected" for a section: built-in quizzes matching the section''s grade_level, UNION teacher-created quizzes assigned to it via quiz_sections REGARDLESS of created_by (the one privilege this function adds over what a plain SECURITY INVOKER caller gets — needed because quizzes_teacher_select, 0015, only lets a teacher read their OWN teacher-authored quizzes, which silently drops a co-teacher''s assigned quizzes for a shared section). SECURITY DEFINER; the `authorized` CTE re-verifies app.teacher_has_section(p_section_id) for the live calling teacher as the first thing the function body does — every UNION branch is joined from that CTE, so an unauthorized p_section_id yields zero rows before either branch runs, mirroring app.dashboard_competency_mastery''s (0037) own ownership re-derivation exactly. Returns quiz_id only — no title/authorship/other column. Internal helper only: no public.* wrapper exists, and none is needed — it is called exclusively from inside dashboard_summary_tiles / dashboard_student_roster''s own bodies (both SECURITY INVOKER, so this nested call is checked against the calling teacher''s own authenticated role, not a service account — hence the explicit grant below).';

revoke all on function app.section_expected_internal_quiz_ids(uuid) from public, anon, authenticated;
grant execute on function app.section_expected_internal_quiz_ids(uuid) to authenticated;


-- =============================================================================
-- app.dashboard_summary_tiles — replace the broken branch (b) of
-- expected_quizzes with a call to the new helper. Branch (a), built-in
-- quizzes, is unchanged. Every other CTE (missed_or_unfinished,
-- student_scores, student_gap_counts) and the final SELECT are unchanged —
-- they already consumed expected_quizzes generically and did not need to
-- know how it was built.
-- =============================================================================
create or replace function app.dashboard_summary_tiles(
  p_grade_level grade_level default null,
  p_section_id  uuid default null
)
returns table (
  total_sections                int,
  total_students                int,
  average_quiz_score_percent    numeric,
  students_needing_intervention int
)
language sql
stable
as $$
  with sections_scope as (
    select sec.id as section_id
    from public.sections sec
    where (p_grade_level is null or sec.grade_level = p_grade_level)
      and (p_section_id is null or sec.id = p_section_id)
  ),
  students_scope as (
    select se.student_id, s.section_id
    from sections_scope s
    join public.student_enrollments se
      on se.section_id = s.section_id
     and se.status = 'active'
  ),
  expected_quizzes as (
    select ss.student_id, q.id as quiz_id
    from students_scope ss
    join public.sections sec on sec.id = ss.section_id
    join public.quizzes q
      on q.source_type = 'built_in'
     and q.quiz_type = 'internal'
     and q.grade_level = sec.grade_level
    union
    select ss.student_id, eiq.quiz_id
    from students_scope ss
    join lateral app.section_expected_internal_quiz_ids(ss.section_id) eiq on true
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
  student_scores as (
    select ss.student_id, avg(ca.score_percent) as average_score_percent
    from students_scope ss
    left join public.v_student_current_quiz_attempts ca on ca.student_id = ss.student_id
    group by ss.student_id
  ),
  student_gap_counts as (
    select ss.student_id, count(mu.quiz_id) as missed_or_unfinished_count
    from students_scope ss
    left join missed_or_unfinished mu on mu.student_id = ss.student_id
    group by ss.student_id
  )
  select
    (select count(distinct section_id) from sections_scope)::int as total_sections,
    (select count(distinct student_id) from students_scope)::int as total_students,
    round((
      select avg(ca.score_percent)
      from students_scope ss
      join public.v_student_current_quiz_attempts ca on ca.student_id = ss.student_id
    ), 1) as average_quiz_score_percent,
    (
      select count(*)
      from students_scope ss
      left join student_scores sc on sc.student_id = ss.student_id
      left join student_gap_counts sg on sg.student_id = ss.student_id
      where (sc.average_score_percent is not null and sc.average_score_percent < 70)
         or coalesce(sg.missed_or_unfinished_count, 0) >= 2
    )::int as students_needing_intervention;
$$;

comment on function app.dashboard_summary_tiles(grade_level, uuid) is
  'Teacher Dashboard summary tiles (0037): total_sections/total_students/average_quiz_score_percent/students_needing_intervention, scoped by optional p_grade_level/p_section_id (NULL = all). SECURITY INVOKER (default) — rides entirely on sections_select/student_enrollments_select/quiz_attempts_select (0015) via app.teacher_has_section(); see 0037 header for why no extra ownership check is layered on top. average_quiz_score_percent pools v_student_current_quiz_attempts.score_percent (0035) across every in-scope student, one vote per completed quiz. students_needing_intervention counts distinct students with average_score_percent < 70 (only when they have >= 1 completed quiz) OR >= 2 missed/unfinished expected internal quizzes (External Activities excluded — see 0037 header). expected_quizzes''s teacher-authored branch calls app.section_expected_internal_quiz_ids (0038) instead of reading public.quizzes directly, so a co-teacher''s assigned quizzes on a shared section are correctly counted — see that function''s own comment for why a SECURITY DEFINER helper was required here (0038 fix; the built-in-quiz branch was never affected and is unchanged).';


-- =============================================================================
-- app.dashboard_student_roster — same replacement, same reasoning, applied
-- identically (this project's stated preference: fix the shared gap once,
-- not twice, in the same shape both places).
-- =============================================================================
create or replace function app.dashboard_student_roster(
  p_grade_level grade_level default null,
  p_section_id  uuid default null
)
returns table (
  student_id                     uuid,
  full_name                      text,
  section_id                     uuid,
  section_name                   text,
  average_quiz_score_percent     numeric,
  quizzes_completed              int,
  missed_or_unfinished_count     int,
  needs_intervention             boolean
)
language sql
stable
as $$
  with sections_scope as (
    select sec.id as section_id, sec.name as section_name, sec.grade_level
    from public.sections sec
    where (p_grade_level is null or sec.grade_level = p_grade_level)
      and (p_section_id is null or sec.id = p_section_id)
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
    select ss.student_id, eiq.quiz_id
    from students_scope ss
    join lateral app.section_expected_internal_quiz_ids(ss.section_id) eiq on true
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
      round(avg(ca.score_percent), 1) as average_quiz_score_percent,
      count(ca.quiz_attempt_id)::int as quizzes_completed
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
    ss.section_id,
    ss.section_name,
    sq.average_quiz_score_percent,
    coalesce(sq.quizzes_completed, 0) as quizzes_completed,
    coalesce(sg.missed_or_unfinished_count, 0) as missed_or_unfinished_count,
    (sq.average_quiz_score_percent is not null and sq.average_quiz_score_percent < 70)
      or coalesce(sg.missed_or_unfinished_count, 0) >= 2 as needs_intervention
  from students_scope ss
  left join student_quiz_stats sq on sq.student_id = ss.student_id
  left join student_gap_counts sg on sg.student_id = ss.student_id
  order by ss.full_name;
$$;

comment on function app.dashboard_student_roster(grade_level, uuid) is
  'Teacher Dashboard drill-down roster (0037): one row per actively-enrolled student in scope (RLS-scoped the same way as dashboard_summary_tiles, see 0037 header), with average_quiz_score_percent/quizzes_completed over v_student_current_quiz_attempts (0035) and missed_or_unfinished_count/needs_intervention using the identical rule as dashboard_summary_tiles''s students_needing_intervention, computed per student instead of pooled. SECURITY INVOKER (default). expected_quizzes''s teacher-authored branch calls app.section_expected_internal_quiz_ids (0038) instead of reading public.quizzes directly, so a co-teacher''s assigned quizzes on a shared section are correctly counted — see that function''s own comment for why a SECURITY DEFINER helper was required here (0038 fix; the built-in-quiz branch was never affected and is unchanged).';
