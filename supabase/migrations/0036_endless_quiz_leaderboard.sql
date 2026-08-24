-- =============================================================================
-- Migration: 0036_endless_quiz_leaderboard.sql
-- Per-grade Endless Quiz leaderboard — a Grade 4 student sees only Grade 4
-- students, Grade 5 -> only Grade 5, Grade 6 -> only Grade 6. Grade is
-- auto-detected from the caller's own active enrollment; a student never
-- picks or browses another grade's leaderboard.
--
-- CONFIRMED AGAINST ACTUAL SCHEMA before writing this:
--   - app.student_current_grade() (0026) already derives the caller's grade
--     from student_enrollments (status = 'active') -> sections.grade_level.
--     Reused as-is here, not duplicated — this migration adds no second
--     way to compute "the caller's grade".
--   - students.best_endless_streak (0006, integer not null default 0) is
--     the ranking metric; students.full_name (0006) is the only other
--     column this leaderboard is allowed to surface.
--   - students_student_select (0035) only permits id = app.current_student_id()
--     — there is no RLS policy letting one student see another student's
--     row at all, in either direction. A security_invoker view (the
--     pattern 0035 used for the statistics views) would therefore return
--     nothing for any row but the caller's own. SECURITY DEFINER is
--     required here, confirmed by reading 0035's policy, not assumed.
--   - student_enrollments (0006) guarantees exactly one ACTIVE row per
--     student (student_enrollments_one_active_per_student), so joining
--     student_enrollments -> sections with status = 'active' identifies
--     "active students in this grade" the same way app.student_current_grade()
--     itself does — reused, not reinvented.
--   - `app` is not in PostgREST's exposed-schema list (0001), so exactly
--     like the gap already fixed in 0020/0024/0034, the app-schema
--     functions below are unreachable from the Flutter client's .rpc(...)
--     calls without a public-schema pass-through wrapper. Without one,
--     the client gets PostgREST's "function not found" 404.
--
-- DESIGN
--   - app.endless_quiz_leaderboard_top(p_limit) and
--     app.endless_quiz_leaderboard_my_rank() both rank EVERY active student
--     in the caller's grade via RANK() (not ROW_NUMBER()) over
--     best_endless_streak desc, so tied streaks share a rank and the next
--     distinct streak skips accordingly (two students tied at rank 3 ->
--     next rank is 5). Both include students with best_endless_streak = 0
--     — there is no "> 0" filter — so a grade with no Endless Quiz activity
--     yet still returns a fully populated result (every student in the
--     grade, including the caller, at rank 1 / streak 0), never an empty
--     set.
--   - _top returns only the requested page (default 50) ordered by rank.
--     _my_rank filters that same ranked set down to the caller's own row
--     and returns exactly one row, regardless of whether that rank falls
--     inside or outside the _top page — this is what powers a "You're
--     #56" card client-side even when the caller isn't in the top 50.
--   - Returned columns are deliberately narrow: rank, full_name,
--     best_endless_streak only. No username, student_number, or any other
--     students column is exposed — this is a scoped, narrow exception to
--     the project's "own data only" pattern, not a general students-table
--     read.
--   - SECURITY DEFINER, set search_path = public, matching
--     app.student_current_grade() (0026).
--   - Both the app-schema functions AND the public wrappers are granted
--     execute to authenticated, matching every existing student-facing
--     app-schema function without exception (app.current_student_id(),
--     app.student_current_grade(), app.student_has_section(), etc. — all
--     0016/0023/0026). This project never relies on Postgres's default
--     PUBLIC execute grant for anything security-relevant — only the
--     service_role-only svc_* functions (0018) and
--     verify_student_credentials (0017) explicitly revoke it; every other
--     app-schema function is explicitly re-granted instead, per the
--     project's own stated preference for explicit over implicit on
--     security-relevant grants (see 0035 header).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- app.endless_quiz_leaderboard_top
-- Top p_limit (default 50) active students in the caller's own grade,
-- ranked by best_endless_streak desc. RANK() over the full grade population
-- (no best_endless_streak > 0 filter), then paged with LIMIT.
-- ---------------------------------------------------------------------------
create or replace function app.endless_quiz_leaderboard_top(p_limit int default 50)
returns table (
  rank                bigint,
  full_name           text,
  best_endless_streak integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    rank() over (order by st.best_endless_streak desc) as rank,
    st.full_name,
    st.best_endless_streak
  from public.students st
  join public.student_enrollments se
    on se.student_id = st.id
    and se.status = 'active'
  join public.sections sec
    on sec.id = se.section_id
  where sec.grade_level = app.student_current_grade()
  order by rank
  limit p_limit;
$$;

comment on function app.endless_quiz_leaderboard_top(int) is
  'Top p_limit (default 50) active students in the calling student''s own grade (auto-detected via app.student_current_grade(), 0026 — not duplicated here), ranked by students.best_endless_streak desc using RANK() so tied streaks share a rank. Includes every active student in the grade, even at streak 0 — no "> 0" filter — so the result is never empty. Columns limited to rank/full_name/best_endless_streak by design; see 0036 header re: why SECURITY DEFINER is required (students_student_select, 0035, has no cross-student SELECT policy). Added 0036 for the Endless Quiz leaderboard screen.';

grant execute on function app.endless_quiz_leaderboard_top(int) to authenticated;

-- ---------------------------------------------------------------------------
-- app.endless_quiz_leaderboard_my_rank
-- Same grade, same full-population RANK() as above; filtered down to
-- exactly the caller's own row so the client can show "You're #N" even
-- when N is outside the _top page.
-- ---------------------------------------------------------------------------
create or replace function app.endless_quiz_leaderboard_my_rank()
returns table (
  rank                bigint,
  full_name           text,
  best_endless_streak integer
)
language sql
stable
security definer
set search_path = public
as $$
  select ranked.rank, ranked.full_name, ranked.best_endless_streak
  from (
    select
      rank() over (order by st.best_endless_streak desc) as rank,
      st.id,
      st.full_name,
      st.best_endless_streak
    from public.students st
    join public.student_enrollments se
      on se.student_id = st.id
      and se.status = 'active'
    join public.sections sec
      on sec.id = se.section_id
    where sec.grade_level = app.student_current_grade()
  ) ranked
  where ranked.id = app.current_student_id();
$$;

comment on function app.endless_quiz_leaderboard_my_rank() is
  'The calling student''s own rank within the same grade-scoped, full-population RANK() ordering as app.endless_quiz_leaderboard_top() (0036) — same grade, same "no > 0 filter" population, so the two are always consistent with each other. Returns exactly one row (the caller has exactly one active enrollment, per student_enrollments_one_active_per_student, 0006), whether or not that rank falls inside the _top page. Powers a "You''re #N" card client-side. Added 0036.';

grant execute on function app.endless_quiz_leaderboard_my_rank() to authenticated;

-- ---------------------------------------------------------------------------
-- public wrappers — thin pass-through, security invoker (default, omitted),
-- exact one-line `select app.<fn>(...)` pattern already used in
-- 0020/0024/0034. No additional logic. Without these, `app` is not in
-- PostgREST's exposed-schema list (0001), so the Flutter client's
-- .rpc('endless_quiz_leaderboard_top'/'endless_quiz_leaderboard_my_rank')
-- calls would 404 — the exact class of bug already fixed in 0020/0024/0034.
-- ---------------------------------------------------------------------------
create or replace function public.endless_quiz_leaderboard_top(p_limit int default 50)
returns table (
  rank                bigint,
  full_name           text,
  best_endless_streak integer
)
language sql
as $$
  select * from app.endless_quiz_leaderboard_top(p_limit);
$$;

comment on function public.endless_quiz_leaderboard_top(int) is
  'Public-schema pass-through to app.endless_quiz_leaderboard_top (0036) so it is reachable via PostgREST from the Flutter client — see 0036 header comment. No additional logic.';

grant execute on function public.endless_quiz_leaderboard_top(int) to authenticated;

create or replace function public.endless_quiz_leaderboard_my_rank()
returns table (
  rank                bigint,
  full_name           text,
  best_endless_streak integer
)
language sql
as $$
  select * from app.endless_quiz_leaderboard_my_rank();
$$;

comment on function public.endless_quiz_leaderboard_my_rank() is
  'Public-schema pass-through to app.endless_quiz_leaderboard_my_rank (0036) so it is reachable via PostgREST from the Flutter client — see 0036 header comment. No additional logic.';

grant execute on function public.endless_quiz_leaderboard_my_rank() to authenticated;
