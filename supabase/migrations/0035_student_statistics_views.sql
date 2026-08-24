-- =============================================================================
-- Migration: 0035_student_statistics_views.sql
-- Phase 8 (Student Statistics screen) — SQL-only part of this phase (Part 1).
-- Flutter wiring (Part 2/3) is out of scope here; this migration only adds
-- what a student needs to read their own statistics over Connection A
-- (their own forwarded JWT, plain PostgREST, RLS-governed) — the same
-- category of read `quiz_attempts`/`quiz_attempt_answers`/`lesson_progress`/
-- `endless_quiz_sessions` already use for quiz-taking. No service_role RPC
-- is introduced: every view below is a thin, security_invoker-scoped read
-- over tables that already have student SELECT policies (0015), plus two
-- narrow RLS fixes (Part 0 below) for tables that turned out not to.
--
-- CONFIRMED AGAINST ACTUAL RLS (0015) BEFORE WRITING THIS:
--   - quiz_attempts: quiz_attempts_select allows student_id = app.current_student_id().
--   - quiz_attempt_answers: quiz_attempt_answers_select joins quiz_attempts and
--     allows qa.student_id = app.current_student_id().
--   - lesson_progress: lesson_progress_select allows student_id = app.current_student_id().
--   - endless_quiz_sessions: endless_quiz_sessions_select allows
--     student_id = app.current_student_id().
--   - lessons: student SELECT already scoped correctly (lessons_student_select
--     is grade-scoped per 0026).
--   - students: NO student self-SELECT policy exists (students_select,
--     0015, only allows app.is_admin() or app.teacher_has_student(id)).
--     This is a genuine gap, not something this migration's business rules
--     can route around — rule #5 (Endless Quiz High) requires reading
--     students.best_endless_streak for the caller's own row. Fixed in
--     Part 0 below.
--   - question_bank: NO student SELECT policy exists AT ALL —
--     question_bank_teacher_select (0015) is the only SELECT policy on this
--     table, and it only permits app.is_admin() or app.is_approved_teacher().
--     RLS evaluates this per-row against the querying role regardless of
--     how the row is reached — a student joining FROM a quiz_attempt_answers
--     row they already own does NOT implicitly grant them the matching
--     question_bank row; with zero permissive policies for the student
--     role, every question_bank row is denied to a student, full stop.
--     This was caught only during review of an earlier draft of this
--     migration, which incorrectly assumed "already reachable via an owned
--     join" was sufficient — it is not; RLS has no concept of transitive
--     ownership through a join. Fixed in Part 0 below, narrowly: a student
--     may read a question_bank row only if they already have their own
--     quiz_attempt_answers row referencing it, which is exactly (and only)
--     the access v_student_topic_mastery (Part 4) needs.
--
-- POSTGRES VERSION: confirmed 17.6 (supabase/.temp/postgres-version) —
-- `security_invoker` is available (added in PG15), so every view below
-- declares it explicitly rather than relying on it being the default
-- (it is the default for `create view` with no options in PG15+, but this
-- project prefers explicit over implicit for anything security-relevant).
-- None of these views are SECURITY DEFINER anywhere, and none call any
-- SECURITY DEFINER function — they ride entirely on the querying role's
-- own RLS, exactly like every existing Connection A read in this codebase.
--
-- DECIDED — Overall Accuracy (rule #7, revised) is REGULAR QUIZZES ONLY.
-- The original plan combined regular-quiz answers with Endless Quiz
-- answers, but `endless_quiz_sessions` stores only `questions_answered`
-- and `best_streak_session` per session (0011) — no per-question table
-- exists for Endless Quiz, and a wrong answer resets the streak without
-- ending the session, so an exact correct/incorrect split for Endless Quiz
-- is NOT reconstructible from the current schema (only an approximation
-- would be possible: best_streak_session as a correct-proxy,
-- questions_answered - best_streak_session as an incorrect-proxy, exact
-- only for sessions with zero or one streak-reset). Rather than present an
-- approximate figure as if exact, the product decision is to scope
-- v_student_overall_accuracy to regular-quiz answers only, same source as
-- v_student_topic_mastery. If exact Endless Quiz accuracy is wanted later,
-- that requires a schema change (persisting a per-session correct/incorrect
-- count at write time) — a separate migration, not attempted here.
--
-- FLAGGED ASSUMPTION — lesson ordering for the "Quiz Scores by Lesson"
-- chart. `lessons` has no sequence/ordinal column (only `lesson_pages` has
-- internal `display_order`, for a lesson's own slides). Ordered by
-- `created_at` here as the most consistent available proxy for seed/authoring
-- order; Part 2 can re-sort client-side (e.g. alphabetically) if that reads
-- better.
--
-- FLAGGED ASSUMPTION — "Average Quiz Score" (rule #3) is a simple average
-- of each completed quiz's own percentage score, one vote per quiz
-- regardless of how many questions that quiz had (not a pooled
-- correct-answers-over-total-questions weighted average). This matches the
-- plain reading of "Average Quiz Score" as a tile alongside "Best Score"
-- (also per-quiz-percentage-based) in the mockup.
-- =============================================================================


-- =============================================================================
-- Part 0a — RLS fix: student self-read on `students`.
--
-- THE GAP: no SELECT policy on `public.students` allows a student to read
-- their own row (students_select, 0015, only covers Admin/Teacher). Every
-- other table this phase needs (lesson_progress, quiz_attempts,
-- quiz_attempt_answers, endless_quiz_sessions) already has one; this one
-- was evidently never added, likely because no prior phase needed a
-- student to read their own `students` row at all (Phase 6/7 only ever
-- WRITE to it indirectly, via the best-streak trigger in 0018, which is
-- SECURITY DEFINER and doesn't need a SELECT policy to do its job).
--
-- THE FIX: one additive SELECT policy, same shape as every other
-- student-self policy in this schema. USING only (no WITH CHECK — SELECT
-- policies don't have one). Does not touch students_select,
-- students_teacher_insert, or students_teacher_update.
-- =============================================================================
create policy students_student_select on public.students for select
  using (id = app.current_student_id());

comment on policy students_student_select on public.students is
  'Added 0035 (Phase 8, Student Statistics): a student may read their own students row — specifically needed for best_endless_streak (Endless Quiz High tile). Additive alongside students_select (0015, Admin/Teacher); combines via OR, per this table''s existing multi-policy-per-command pattern (see quiz_attempts_select + quiz_attempts_admin_select). password_encrypted remains unreadable regardless, via the column-level SELECT grant in 0016, which already excludes it for every authenticated caller.';


-- =============================================================================
-- Part 0b — RLS fix: student self-read on `question_bank`, scoped to
-- questions the student has already answered.
--
-- THE GAP: question_bank_teacher_select (0015) is the ONLY SELECT policy on
-- `public.question_bank`, and it only permits app.is_admin() or
-- app.is_approved_teacher(). There is no student-role policy at all. RLS
-- denies a row to a role unless some policy explicitly permits it for that
-- role — there is no "implicitly allowed because you already own a row
-- that references it via a join" concept. Without this fix,
-- v_student_topic_mastery's join to question_bank silently returns zero
-- rows for every student, always, regardless of how many questions they've
-- actually answered — this was caught during review, not by testing.
--
-- THE FIX: one additive, narrowly-scoped SELECT policy — a student may read
-- a question_bank row ONLY if they already have their own
-- quiz_attempt_answers row referencing that question_id (via their own
-- quiz_attempts row, already scoped by quiz_attempts_select). This grants
-- exactly the access v_student_topic_mastery needs and nothing more: it
-- does not let a student browse question_bank freely, list every built-in
-- question, or see any question they haven't already answered — the
-- `EXISTS` clause re-derives ownership the same way quiz_attempt_answers_select
-- itself does, rather than trusting a join path from the view.
-- =============================================================================
create policy question_bank_student_select_own_answers on public.question_bank for select
  using (
    exists (
      select 1
      from public.quiz_attempt_answers qaa
      join public.quiz_attempts qa on qa.id = qaa.quiz_attempt_id
      where qaa.question_id = question_bank.id
        and qa.student_id = app.current_student_id()
    )
  );

comment on policy question_bank_student_select_own_answers on public.question_bank is
  'Added 0035 (Phase 8, Student Statistics): a student may read a question_bank row only if they already have a quiz_attempt_answers row referencing it (via their own quiz_attempts row). Exists solely so v_student_topic_mastery can join question_bank.topic for questions the student has actually answered — grants no general question_bank browsing access. Additive alongside question_bank_teacher_select (0015); combines via OR.';


-- =============================================================================
-- Part 1 — v_student_current_quiz_attempts
--
-- The dedup building block every other view here is built on: one row per
-- (student, quiz) — the most recently SUBMITTED attempt, regardless of
-- attempt_status ('active' or 'superseded'). This is rule #2, verbatim:
-- teacher-initiated resets (0010/0014/0015) can leave a newer 'active' but
-- not-yet-submitted attempt sitting on top of a 'superseded' row that holds
-- the student's actual last real result — ORDER BY submitted_at DESC,
-- filtered to submitted_at IS NOT NULL, is what correctly ignores that
-- in-progress reset attempt rather than naively filtering on
-- attempt_status = 'active'.
--
-- Deliberately NOT filtered to app.current_student_id() here — kept general
-- or reusable the same way app.teacher_has_student()-backed reads are,
-- with student_id left as an ordinary output column. Every view below that
-- consumes this one filters it explicitly to the current student anyway
-- (matching this codebase's existing habit — see
-- QuizAttemptsRepository.fetchLatestForQuiz's own comment: RLS already
-- scopes it, but an explicit filter keeps the query shape obvious).
-- RLS on the underlying `quiz_attempts` table (quiz_attempts_select, 0015)
-- still fully applies before DISTINCT ON ever runs, so a student querying
-- this view directly only ever sees their own rows regardless.
-- =============================================================================
create view public.v_student_current_quiz_attempts
with (security_invoker = true) as
select distinct on (qa.student_id, qa.quiz_id)
  qa.id               as quiz_attempt_id,
  qa.student_id,
  qa.quiz_id,
  qa.attempt_status,
  qa.score,
  qa.total_questions,
  round(100.0 * qa.score / nullif(qa.total_questions, 0), 1) as score_percent,
  qa.submitted_at
from public.quiz_attempts qa
where qa.submitted_at is not null
order by qa.student_id, qa.quiz_id, qa.submitted_at desc;

comment on view public.v_student_current_quiz_attempts is
  'One row per (student_id, quiz_id): that quiz''s most recently SUBMITTED attempt, regardless of attempt_status. Implements rule #2 (Phase 8 statistics spec) — the "current attempt" definition every other statistics view in 0035 is built on. security_invoker: rides entirely on quiz_attempts_select (0015), never bypasses it.';

grant select on public.v_student_current_quiz_attempts to authenticated;


-- =============================================================================
-- Part 2 — v_student_summary_tiles
--
-- The four summary tiles in one row, one round trip: Lessons Completed,
-- Average Quiz Score, Best Score, Endless Quiz High (rules #3, #4, #5).
-- Driven from `students` (now student-self-readable per Part 0a above) so
-- there's always exactly one row for the caller's own student_id; every
-- other value is a LATERAL subquery so a student with zero completed
-- quizzes/lessons still gets one row back with NULLs/zeros rather than no
-- row at all (important — Part 2/3 shouldn't have to special-case "no row
-- yet" separately from "average of zero completed quizzes").
--
-- lessons_total / lessons_completed (rule #4): counts `public.lessons`
-- exactly as RLS already scopes it for a student (lessons_student_select,
-- 0015, grade-scoped per 0026) — no grade-matching logic is duplicated
-- here, it rides entirely on that existing policy. lessons_completed counts
-- only the subset of those visible lessons with a 'completed'
-- lesson_progress row for this student.
-- =============================================================================
create view public.v_student_summary_tiles
with (security_invoker = true) as
select
  s.id                              as student_id,
  s.best_endless_streak,
  coalesce(lesson_stats.lessons_total, 0)      as lessons_total,
  coalesce(lesson_stats.lessons_completed, 0)  as lessons_completed,
  coalesce(quiz_stats.quizzes_completed, 0)    as quizzes_completed,
  quiz_stats.average_score_percent,
  quiz_stats.best_score_percent
from public.students s
left join lateral (
  select
    count(*) as lessons_total,
    count(*) filter (
      where exists (
        select 1
        from public.lesson_progress lp
        where lp.lesson_id = l.id
          and lp.student_id = s.id
          and lp.status = 'completed'
      )
    ) as lessons_completed
  from public.lessons l
) lesson_stats on true
left join lateral (
  select
    count(*)                             as quizzes_completed,
    round(avg(ca.score_percent), 1)      as average_score_percent,
    round(max(ca.score_percent), 1)      as best_score_percent
  from public.v_student_current_quiz_attempts ca
  where ca.student_id = s.id
) quiz_stats on true
where s.id = app.current_student_id();

comment on view public.v_student_summary_tiles is
  'One row for the caller''s own student: best_endless_streak (Endless Quiz High, rule #5), lessons_total/lessons_completed (Lessons Completed, rule #4, grade-scoped via lessons RLS), quizzes_completed/average_score_percent/best_score_percent (Average Quiz Score + Best Score, rule #3, over v_student_current_quiz_attempts). average_score_percent is an unweighted average of each completed quiz''s own percentage (one vote per quiz) — see 0035 header. security_invoker: relies on students_student_select (0035 Part 0a), lessons_student_select (0015/0026), lesson_progress_select (0015), and v_student_current_quiz_attempts.';

grant select on public.v_student_summary_tiles to authenticated;


-- =============================================================================
-- Part 3 — v_student_lesson_quiz_scores
--
-- "Quiz Scores by Lesson" bar chart data (rule #6). One row per lesson
-- visible to the student (grade-scoped, same as above) that has a
-- non-null linked_quiz_id — lessons with linked_quiz_id IS NULL never
-- appear here at all (rule #6's "omit entirely", satisfied structurally by
-- the WHERE clause, not by returning a null/zero row for the client to
-- filter). Lessons that DO have a linked quiz but that the student hasn't
-- completed yet still appear, with score/score_percent NULL — this is a
-- distinct case from "no linked quiz" and Part 2/3 should treat it as "no
-- bar yet", not "zero score" (matches the mockup: L3–L10 show axis labels
-- with no bar drawn).
--
-- Explicitly filtered to app.current_student_id() (see Part 1's comment on
-- why v_student_current_quiz_attempts itself doesn't do this) so this
-- returns exactly one row per qualifying lesson regardless of caller —
-- for a Teacher/Admin session (current_student_id() is NULL for both), the
-- score columns are simply always NULL, consistent with this being a
-- student-facing-only view (rule #1); lesson visibility itself remains
-- entirely governed by lessons_student_select/lessons_teacher_select.
-- =============================================================================
create view public.v_student_lesson_quiz_scores
with (security_invoker = true) as
select
  l.id                as lesson_id,
  l.title             as lesson_title,
  l.linked_quiz_id    as quiz_id,
  ca.quiz_attempt_id,
  ca.score,
  ca.total_questions,
  ca.score_percent,
  ca.submitted_at
from public.lessons l
left join public.v_student_current_quiz_attempts ca
  on ca.quiz_id = l.linked_quiz_id
  and ca.student_id = app.current_student_id()
where l.linked_quiz_id is not null
order by l.created_at;

comment on view public.v_student_lesson_quiz_scores is
  'One row per RLS-visible lesson with a non-null linked_quiz_id (lessons with linked_quiz_id IS NULL never appear — rule #6). score/score_percent are NULL when the student hasn''t completed that linked quiz yet (distinct from "omitted"); Part 2 should render those as no-bar, not zero-bar, per the mockup. Ordered by lessons.created_at — no lesson ordinal column exists in this schema, see 0035 header. security_invoker, relies on lessons RLS (0015/0026) + v_student_current_quiz_attempts.';

grant select on public.v_student_lesson_quiz_scores to authenticated;


-- =============================================================================
-- Part 4 — v_student_topic_mastery
--
-- "Competency Mastery" per-topic bars (rule #8) — REGULAR QUIZZES ONLY, no
-- Endless Quiz data here at all. Groups quiz_attempt_answers (from each
-- quiz's "current" attempt per rule #2) by question_bank.topic, verbatim
-- (rule #9 — no shortening/remapping, the topic string here is displayed
-- exactly as stored). Rows with a NULL topic are excluded rather than
-- surfaced as an unlabeled bar — question_bank.topic is nullable at the
-- column level (0008) but every seeded question is expected to carry one;
-- a NULL here would indicate unseeded/incomplete content, not a real
-- competency, so it's dropped rather than guessed at.
--
-- question_bank is now readable here via question_bank_student_select_own_answers
-- (0035 Part 0b, added specifically for this view) — a student can read a
-- question_bank row only if they already have a quiz_attempt_answers row
-- referencing it, which is exactly the join below. Without Part 0b, this
-- view would silently return zero rows for every student regardless of how
-- many questions they've answered.
-- =============================================================================
create view public.v_student_topic_mastery
with (security_invoker = true) as
select
  qb.topic,
  count(*)                                             as questions_total,
  count(*) filter (where qaa.is_correct)                as questions_correct,
  round(
    100.0 * count(*) filter (where qaa.is_correct) / nullif(count(*), 0),
    1
  )                                                      as mastery_percent
from public.v_student_current_quiz_attempts ca
join public.quiz_attempt_answers qaa on qaa.quiz_attempt_id = ca.quiz_attempt_id
join public.question_bank qb on qb.id = qaa.question_id
where ca.student_id = app.current_student_id()
  and qb.topic is not null
group by qb.topic;

comment on view public.v_student_topic_mastery is
  'Regular-quizzes-only competency mastery (rule #8): question_bank.topic (used verbatim, rule #9) x correct/total over quiz_attempt_answers from each quiz''s current attempt (rule #2). Endless Quiz is deliberately excluded. NULL-topic questions are dropped, not surfaced. security_invoker; question_bank rows are reachable here via question_bank_student_select_own_answers (0035 Part 0b) — a student can only read question_bank rows they already have an answer for, so this view grants no general question_bank browsing access.';

grant select on public.v_student_topic_mastery to authenticated;


-- =============================================================================
-- Part 5 — v_student_overall_accuracy
--
-- "Overall Accuracy" pie chart (rule #7, revised) — REGULAR QUIZZES ONLY.
-- Endless Quiz is deliberately excluded: no per-question table exists for
-- it, so an exact correct/incorrect split isn't reconstructible from the
-- schema (see the "DECIDED" note at the top of this file for the full
-- reasoning and what a future exact fix would require). This view is now
-- the same source data as v_student_topic_mastery (Part 4), just
-- aggregated across all topics instead of grouped by topic. One row for
-- the caller's own student, same lateral-subquery-off-students shape as
-- Part 2, so a student with zero completed quizzes still gets one row back
-- with zeros/NULL rather than no row at all. Note this one does NOT join
-- question_bank at all (it only needs quiz_attempt_answers.is_correct), so
-- Part 0b's fix does not affect this view — it was never broken.
-- =============================================================================
create view public.v_student_overall_accuracy
with (security_invoker = true) as
select
  s.id                                          as student_id,
  coalesce(quiz_stats.correct, 0)                as correct,
  coalesce(quiz_stats.incorrect, 0)              as incorrect,
  round(
    100.0 * coalesce(quiz_stats.correct, 0)
    / nullif(coalesce(quiz_stats.correct, 0) + coalesce(quiz_stats.incorrect, 0), 0),
    1
  ) as accuracy_percent
from public.students s
left join lateral (
  select
    count(*) filter (where qaa.is_correct)     as correct,
    count(*) filter (where not qaa.is_correct) as incorrect
  from public.v_student_current_quiz_attempts ca
  join public.quiz_attempt_answers qaa on qaa.quiz_attempt_id = ca.quiz_attempt_id
  where ca.student_id = s.id
) quiz_stats on true
where s.id = app.current_student_id();

comment on view public.v_student_overall_accuracy is
  'One row for the caller''s own student: correct/incorrect/accuracy_percent across regular-quiz current attempts only (rule #2). Endless Quiz is deliberately excluded — see the "DECIDED" note at the top of 0035 for why an exact count isn''t reconstructible from the current schema. accuracy_percent is provided for convenience; Part 2 can also compute it client-side from the two raw counts. security_invoker. Does not join question_bank, so unaffected by the Part 0b RLS fix.';

grant select on public.v_student_overall_accuracy to authenticated;
