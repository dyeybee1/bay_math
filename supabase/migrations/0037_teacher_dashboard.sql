-- =============================================================================
-- Migration: 0037_teacher_dashboard.sql
-- Teacher Dashboard (Part 1 — SQL only). Flutter wiring is out of scope for
-- this migration; this adds four read functions a Teacher's own Supabase
-- Auth session calls directly via `.rpc(...)`, exactly the call shape 0036's
-- leaderboard functions use (not the Edge-Function/service_role shape
-- 0018/0034 use).
--
-- DATA SCOPE (product decision, restated) — regular quizzes + lessons only.
-- Endless Quiz is excluded entirely from every function below, matching the
-- 0035 precedent of excluding it from student statistics. There is no
-- lesson-completion metric in this migration either (none of the four
-- functions were asked for one) — "lessons" enters this migration only
-- indirectly, via quiz_type = 'internal' quizzes that may be linked to a
-- lesson; lesson-progress rows themselves are not read here.
--
-- REUSE OF public.v_student_current_quiz_attempts (0035) — every function
-- below that needs "does this student have a completed attempt for this
-- quiz" reads that view directly rather than re-deriving the dedup logic
-- (most-recently-SUBMITTED attempt, regardless of attempt_status, so a
-- newer 'active' but not-yet-submitted post-reset attempt never masks a
-- 'superseded' row holding the student's actual last real result). See
-- 0035 Part 1 for the full reasoning; not repeated here.
--
-- INTERVENTION RULE (product decision, restated) — a student in scope needs
-- intervention if EITHER:
--   (a) their average_quiz_score_percent < 70 (computed only when they have
--       at least one completed quiz — a student with zero completed
--       quizzes has a NULL average and is judged on (b) alone, not treated
--       as an automatic 0%), OR
--   (b) they have >= 2 "missed/unfinished" expected INTERNAL quizzes.
-- External Activities (quiz_type = 'external_activity') are excluded from
-- the expected-quiz set entirely — they carry no score, so "missed" is not
-- a meaningful signal for them (restated from the spec, not re-litigated).
-- "Expected" internal quizzes for a student = built-in internal quizzes
-- matching their section's grade_level, UNION teacher-created internal
-- quizzes assigned to their section via quiz_sections. "Missed" = zero
-- quiz_attempts rows at all for that (student, quiz) pair. "Unfinished" =
-- a quiz_attempts row exists with attempt_status = 'active' AND
-- submitted_at IS NULL. Both checks run only when
-- v_student_current_quiz_attempts has no completed-attempt row for that
-- pair (a completed attempt, even one sitting under a newer in-progress
-- reset attempt, means the quiz is neither missed nor unfinished).
--
-- SECURITY MODEL PER FUNCTION (product decision, restated) — Functions 1-3
-- (dashboard_summary_tiles, dashboard_avg_score_by_section,
-- dashboard_student_roster) are plain SECURITY INVOKER (the default,
-- clause omitted below): the calling teacher already has full RLS access
-- to every underlying row via app.teacher_has_section() / 
-- app.teacher_has_student(), so there is no privilege gap to close, and
-- adding SECURITY DEFINER would be an unjustified escalation. If a
-- teacher's p_section_id argument is not actually one of theirs, RLS
-- silently returns zero matching rows for that filter — that is the
-- correct, sufficient behavior; no extra application-level ownership
-- check is layered on top. Function 4 (dashboard_competency_mastery) is
-- the one exception — see its own header comment below for why.
--
-- CONFIRMED AGAINST ACTUAL RLS (0015) BEFORE WRITING THIS (not assumed):
--   - sections_select: `app.is_admin() or app.teacher_has_section(id)` —
--     querying public.sections directly, with no extra filter, already
--     returns exactly the calling teacher's own sections. This is used
--     below in place of an explicit teacher_sections -> sections join;
--     the two are equivalent because sections_select itself is defined in
--     terms of app.teacher_has_section(), so the "teacher_sections ->
--     sections" scoping path is realized by that policy, not re-walked by
--     hand.
--   - teacher_sections_select: `app.is_admin() or teacher_id = auth.uid()`
--     — consistent with the above; not queried directly by this migration
--     since sections_select already yields the same row set.
--   - student_enrollments_select: `app.is_admin() or
--     app.teacher_has_section(section_id) or student_id =
--     app.current_student_id()` — a teacher can read every active
--     enrollment row for their own sections.
--   - students_select: `app.is_admin() or app.teacher_has_student(id)` —
--     a teacher can read every students row for a student currently
--     enrolled (active) in one of their own sections. Used in Function 3
--     for full_name.
--   - quiz_attempts_select: `app.teacher_has_section(section_id) or
--     student_id = app.current_student_id()` — scoped to the historical
--     section_id frozen on the attempt row itself, at insert time (0010).
--     Functions 1/3's "missed" check queries public.quiz_attempts
--     directly (not just the view) for exactly this reason: an attempt's
--     visibility to a teacher rides on the attempt's OWN section_id
--     snapshot, which is a teacher-has-access check, not a "is this
--     student currently in one of my sections" check — both hold for the
--     common case (student never transferred), and RLS is what actually
--     enforces it either way.
--   - question_bank_teacher_select: `app.is_admin() or
--     (app.is_approved_teacher() and (source_type = 'built_in' or
--     created_by = auth.uid()))` — CONFIRMED this does NOT let a teacher
--     read another teacher's source_type = 'teacher' question_bank rows.
--     This is exactly why Function 4 needs SECURITY DEFINER: a student's
--     answered questions can include questions authored by a different
--     teacher than the one currently viewing the dashboard (e.g. content
--     shared onto a section by another teacher, or a section with more
--     than one assigned teacher), and this migration does not widen
--     question_bank_teacher_select to fix that.
--
-- No RLS policy, table, or view is modified by this migration. Every
-- object created below is new.
-- =============================================================================


-- =============================================================================
-- Function 1 — app.dashboard_summary_tiles
--
-- One row: total_sections, total_students, average_quiz_score_percent,
-- students_needing_intervention, all scoped by the optional grade/section
-- filters (NULL = "all" for that filter; when both are NULL, aggregates
-- across every section the calling teacher is assigned to).
--
-- average_quiz_score_percent is an UNWEIGHTED pool of every in-scope
-- student's v_student_current_quiz_attempts.score_percent rows — the same
-- one-vote-per-completed-quiz semantics as 0035's v_student_summary_tiles,
-- just pooled across many students instead of computed for one (rule
-- restated in the header above).
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
  'Teacher Dashboard summary tiles (0037): total_sections/total_students/average_quiz_score_percent/students_needing_intervention, scoped by optional p_grade_level/p_section_id (NULL = all). SECURITY INVOKER (default) — rides entirely on sections_select/student_enrollments_select/quiz_attempts_select (0015) via app.teacher_has_section(); see 0037 header for why no extra ownership check is layered on top. average_quiz_score_percent pools v_student_current_quiz_attempts.score_percent (0035) across every in-scope student, one vote per completed quiz. students_needing_intervention counts distinct students with average_score_percent < 70 (only when they have >= 1 completed quiz) OR >= 2 missed/unfinished expected internal quizzes (External Activities excluded — see 0037 header).';

revoke all on function app.dashboard_summary_tiles(grade_level, uuid) from public, anon, authenticated;
grant execute on function app.dashboard_summary_tiles(grade_level, uuid) to authenticated;


-- =============================================================================
-- Function 2 — app.dashboard_avg_score_by_section
--
-- One row per section in scope (grade filter only — no p_section_id; this
-- function's whole purpose is the per-section breakdown that powers the
-- "Average per Section" bar chart, so narrowing to one section would defeat
-- its own purpose). A section with zero actively-enrolled students still
-- appears, with student_count = 0 and average_quiz_score_percent NULL.
-- =============================================================================
create or replace function app.dashboard_avg_score_by_section(
  p_grade_level grade_level default null
)
returns table (
  section_id                  uuid,
  section_name                text,
  grade_level                 grade_level,
  average_quiz_score_percent  numeric,
  student_count                int
)
language sql
stable
as $$
  with sections_scope as (
    select sec.id as section_id, sec.name as section_name, sec.grade_level
    from public.sections sec
    where (p_grade_level is null or sec.grade_level = p_grade_level)
  ),
  students_scope as (
    select se.student_id, s.section_id
    from sections_scope s
    join public.student_enrollments se
      on se.section_id = s.section_id
     and se.status = 'active'
  )
  select
    s.section_id,
    s.section_name,
    s.grade_level,
    round(avg(ca.score_percent), 1) as average_quiz_score_percent,
    count(distinct ss.student_id)::int as student_count
  from sections_scope s
  left join students_scope ss on ss.section_id = s.section_id
  left join public.v_student_current_quiz_attempts ca on ca.student_id = ss.student_id
  group by s.section_id, s.section_name, s.grade_level
  order by s.section_name;
$$;

comment on function app.dashboard_avg_score_by_section(grade_level) is
  'Teacher Dashboard "Average per Section" bar chart data (0037): one row per section in scope (RLS-scoped via sections_select -> app.teacher_has_section(), see 0037 header), optionally filtered by grade. SECURITY INVOKER (default). average_quiz_score_percent pools v_student_current_quiz_attempts.score_percent (0035) across that section''s actively-enrolled students; NULL when the section has no completed quizzes yet. student_count is distinct actively-enrolled students (student_enrollments.status = ''active''), independent of whether they have completed any quiz.';

revoke all on function app.dashboard_avg_score_by_section(grade_level) from public, anon, authenticated;
grant execute on function app.dashboard_avg_score_by_section(grade_level) to authenticated;


-- =============================================================================
-- Function 3 — app.dashboard_student_roster
--
-- One row per actively-enrolled student in scope — the drill-down table.
-- Reuses the exact same missed/unfinished definition as Function 1, per
-- student rather than pooled/counted.
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
  'Teacher Dashboard drill-down roster (0037): one row per actively-enrolled student in scope (RLS-scoped the same way as dashboard_summary_tiles, see 0037 header), with average_quiz_score_percent/quizzes_completed over v_student_current_quiz_attempts (0035) and missed_or_unfinished_count/needs_intervention using the identical rule as dashboard_summary_tiles''s students_needing_intervention, computed per student instead of pooled. SECURITY INVOKER (default).';

revoke all on function app.dashboard_student_roster(grade_level, uuid) from public, anon, authenticated;
grant execute on function app.dashboard_student_roster(grade_level, uuid) to authenticated;


-- =============================================================================
-- Function 4 — app.dashboard_competency_mastery
--
-- WHY THIS ONE IS SECURITY DEFINER (the other three are not):
-- question_bank_teacher_select (0015) is CONFIRMED (see 0037 header) to
-- permit a teacher to read a question_bank row only when source_type =
-- 'built_in', OR source_type = 'teacher' AND created_by = auth.uid() —
-- i.e. a teacher can never read another teacher's own authored questions,
-- full stop, regardless of any other fact about the row. But this
-- function's whole job is: for a student in one of the CALLING teacher's
-- own sections, group that student's answered questions by
-- question_bank.topic. That student may well have answered a
-- teacher-created question authored by a *different* teacher — e.g. a
-- section with more than one assigned teacher (teacher_sections has no
-- "one teacher per section" constraint, only one PRIMARY teacher per
-- section), or content originally authored by a section's previous
-- teacher. A plain SECURITY INVOKER version of this function would
-- silently drop every such question from the mastery breakdown — not
-- error, just quietly under-count, which is worse than an obvious failure.
-- SECURITY DEFINER closes exactly that one gap and no other: it does NOT
-- widen question_bank_teacher_select itself (that policy is untouched by
-- this migration), and it does not let the calling teacher browse
-- question_bank freely or read topics for questions no student of theirs
-- has answered — the `answered` CTE below only ever selects a
-- question_bank row reached via a join from a students_scope row, and
-- students_scope itself is independently re-derived (not trusted from a
-- parameter) by calling app.teacher_has_section() explicitly inside this
-- function body for every section considered, exactly mirroring how
-- question_bank_student_select_own_answers (0035 Part 0b) scopes a
-- student to only their own answered questions. p_section_id is filtered
-- the same way — it is never trusted as "already authorized by the
-- caller", it is checked, every call, via app.teacher_has_section().
-- =============================================================================
create or replace function app.dashboard_competency_mastery(
  p_grade_level grade_level default null,
  p_section_id  uuid default null
)
returns table (
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
    select sec.id as section_id
    from public.sections sec
    where app.teacher_has_section(sec.id)
      and (p_grade_level is null or sec.grade_level = p_grade_level)
      and (p_section_id is null or sec.id = p_section_id)
  ),
  students_scope as (
    select se.student_id
    from sections_scope s
    join public.student_enrollments se
      on se.section_id = s.section_id
     and se.status = 'active'
  ),
  answered as (
    select qb.topic, qaa.is_correct
    from students_scope ss
    join public.v_student_current_quiz_attempts ca on ca.student_id = ss.student_id
    join public.quiz_attempt_answers qaa on qaa.quiz_attempt_id = ca.quiz_attempt_id
    join public.question_bank qb on qb.id = qaa.question_id
    where qb.topic is not null
  )
  select
    topic,
    count(*)::int as questions_total,
    count(*) filter (where is_correct)::int as questions_correct,
    round(100.0 * count(*) filter (where is_correct) / nullif(count(*), 0), 1) as mastery_percent
  from answered
  group by topic
  order by topic;
$$;

comment on function app.dashboard_competency_mastery(grade_level, uuid) is
  'Teacher Dashboard "Competency Mastery" per-topic breakdown (0037), regular quizzes only (rides on v_student_current_quiz_attempts, 0035 — Endless Quiz has no per-question table, same exclusion reasoning as 0035''s v_student_topic_mastery). SECURITY DEFINER — see the function-level comment above this CREATE FUNCTION for the full justification (question_bank_teacher_select, 0015, cannot see another teacher''s authored questions, which this function''s job requires). Section ownership is independently re-derived via app.teacher_has_section() inside this function body on every call, for both the unfiltered and p_section_id-filtered cases — never trusted from the parameter. Grants execute to authenticated only, same as every other function in 0037; not exposed beyond that.';

revoke all on function app.dashboard_competency_mastery(grade_level, uuid) from public, anon, authenticated;
grant execute on function app.dashboard_competency_mastery(grade_level, uuid) to authenticated;


-- =============================================================================
-- public wrappers — thin pass-through, `security invoker` (default,
-- omitted below) in every case, exact one-line `select * from app.<fn>(...)`
-- pattern already used in 0020/0024/0034/0036. No additional logic. `app`
-- is not in PostgREST's exposed-schema list (0001), so without these the
-- Flutter client's `.rpc('dashboard_summary_tiles'/...)` calls would 404 —
-- the same class of gap already fixed in 0020/0024/0034/0036.
--
-- For dashboard_competency_mastery specifically: the WRAPPER itself stays
-- SECURITY INVOKER — it adds no privilege of its own. Only the underlying
-- app.dashboard_competency_mastery is SECURITY DEFINER; the wrapper is a
-- transparent one-line pass-through exactly like the other three.
--
-- All four wrappers are granted execute to `authenticated` only (not
-- service_role) — these are called directly from the Flutter client over a
-- Teacher's own Supabase Auth session, the same call shape as 0036's
-- leaderboard functions, not the Edge-Function/service_role shape 0018/0034
-- use.
-- =============================================================================
create or replace function public.dashboard_summary_tiles(
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
as $$
  select * from app.dashboard_summary_tiles(p_grade_level, p_section_id);
$$;

comment on function public.dashboard_summary_tiles(grade_level, uuid) is
  'Public-schema pass-through to app.dashboard_summary_tiles (0037) so it is reachable via PostgREST from the Flutter client — see 0037 header comment. No additional logic.';

revoke all on function public.dashboard_summary_tiles(grade_level, uuid) from public, anon, authenticated;
grant execute on function public.dashboard_summary_tiles(grade_level, uuid) to authenticated;


create or replace function public.dashboard_avg_score_by_section(
  p_grade_level grade_level default null
)
returns table (
  section_id                  uuid,
  section_name                text,
  grade_level                 grade_level,
  average_quiz_score_percent  numeric,
  student_count                int
)
language sql
as $$
  select * from app.dashboard_avg_score_by_section(p_grade_level);
$$;

comment on function public.dashboard_avg_score_by_section(grade_level) is
  'Public-schema pass-through to app.dashboard_avg_score_by_section (0037) so it is reachable via PostgREST from the Flutter client — see 0037 header comment. No additional logic.';

revoke all on function public.dashboard_avg_score_by_section(grade_level) from public, anon, authenticated;
grant execute on function public.dashboard_avg_score_by_section(grade_level) to authenticated;


create or replace function public.dashboard_student_roster(
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
as $$
  select * from app.dashboard_student_roster(p_grade_level, p_section_id);
$$;

comment on function public.dashboard_student_roster(grade_level, uuid) is
  'Public-schema pass-through to app.dashboard_student_roster (0037) so it is reachable via PostgREST from the Flutter client — see 0037 header comment. No additional logic.';

revoke all on function public.dashboard_student_roster(grade_level, uuid) from public, anon, authenticated;
grant execute on function public.dashboard_student_roster(grade_level, uuid) to authenticated;


create or replace function public.dashboard_competency_mastery(
  p_grade_level grade_level default null,
  p_section_id  uuid default null
)
returns table (
  topic              text,
  questions_total    int,
  questions_correct  int,
  mastery_percent    numeric
)
language sql
as $$
  select * from app.dashboard_competency_mastery(p_grade_level, p_section_id);
$$;

comment on function public.dashboard_competency_mastery(grade_level, uuid) is
  'Public-schema pass-through to app.dashboard_competency_mastery (0037) so it is reachable via PostgREST from the Flutter client — see 0037 header comment. No additional logic. The wrapper itself is SECURITY INVOKER (default) and adds no privilege; only the underlying app. function is SECURITY DEFINER.';

revoke all on function public.dashboard_competency_mastery(grade_level, uuid) from public, anon, authenticated;
grant execute on function public.dashboard_competency_mastery(grade_level, uuid) to authenticated;
