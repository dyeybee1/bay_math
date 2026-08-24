-- =============================================================================
-- Migration: 0045_teacher_quiz_results_view.sql
--
-- Adds a single flat, teacher-facing read view over quiz results:
-- student + section + quiz/assessment context + score, for a results table
-- UI. Follows the same pattern/style as 0035_student_statistics_views.sql
-- (security_invoker views riding entirely on existing RLS, never
-- SECURITY DEFINER, no new bypass of row-level access).
--
-- NAMING: named v_teacher_quiz_results rather than the literal
-- teacher_quiz_results_view suggested in the request, to match this
-- codebase's existing view-naming convention (every view in 0035 uses the
-- v_ prefix). Flagging in case the literal name is actually wanted.
--
-- SOURCE OF section_id / section_name: quiz_attempts.section_id is the
-- frozen historical snapshot captured at attempt time (0010 — "HISTORICAL
-- SNAPSHOT FIELDS", immutable after insert per 0014's trigger), so this
-- view joins `sections` directly through quiz_attempts.section_id rather
-- than through student_enrollments. This is deliberate: an enrollment-based
-- join would show the student's CURRENT section, which can silently
-- diverge from the section they were actually in when they took the quiz
-- (transfers, grade advancement). Matches quiz_attempts' own stated design
-- intent (0010) and requires no join to students/student_enrollments for
-- section context at all.
--
-- STUDENT NAME: students has no section_id of its own (0006 — "a student's
-- section is always read through student_enrollments... never owned by a
-- section directly"), so student_name is simply students.full_name via
-- quiz_attempts.student_id — no enrollment join needed here either.
--
-- RLS: security_invoker = true, explicit per 0035's stated house
-- preference (explicit over implicit for anything security-relevant, even
-- though PG15+ defaults views to security_invoker already). This view adds
-- zero new access — it rides entirely on:
--   - quiz_attempts_select (0015): app.teacher_has_section(section_id) OR
--     student_id = app.current_student_id() — a teacher querying this view
--     automatically only sees rows for their own sections, no extra
--     filtering needed here, per the task's own framing.
--   - quizzes / students / sections: no additional policy requirements
--     beyond what those tables already grant a teacher role to read
--     (title, grade_level, assessment_type, full_name, name are all
--     ordinary non-restricted columns already visible to a teacher).
--
-- EXCLUDING SUPERSEDED ATTEMPTS: attempt_status = 'superseded' rows are
-- filtered out by default below. Rationale: a superseded attempt is a
-- student's outdated/reset result (see 0010/0014 on reset_by/reset_at) —
-- showing both the old and new attempt in a results table would just
-- clutter it with a result the student/teacher already knows is stale.
-- This is a default-view decision, not a schema constraint, so it's called
-- out explicitly here in case a future "show attempt history" feature
-- wants a second view (or a parameterized query) that includes superseded
-- rows instead of filtering them.
--
-- PERCENTAGE: guarded with nullif(total_questions, 0) the same way
-- v_student_current_quiz_attempts (0035) computes score_percent, so a null
-- or zero total_questions produces NULL rather than a division error.
--
-- ADDED COLUMN NOT IN THE ORIGINAL LIST: quiz_attempt_id (quiz_attempts.id)
-- is included as the leading column, even though it wasn't in the
-- requested column list — a results table needs a stable per-row key for
-- the UI (row keys, drill-down navigation to a single attempt). Every
-- column that was requested is still present unchanged.
-- =============================================================================

create view public.v_teacher_quiz_results
with (security_invoker = true) as
select
  qa.id                                                     as quiz_attempt_id,
  st.full_name                                              as student_name,
  qa.section_id,
  sec.name                                                  as section_name,
  qa.quiz_id,
  qz.title                                                  as assessment_name,
  qz.assessment_type,
  qa.score,
  qa.total_questions,
  round(
    100.0 * qa.score / nullif(qa.total_questions, 0),
    1
  )                                                          as percentage,
  qa.submitted_at                                           as date_taken,
  case
    when qa.submitted_at is null then 'in_progress'
    else 'completed'
  end                                                        as status,
  qa.attempt_status
from public.quiz_attempts qa
join public.students st on st.id = qa.student_id
join public.sections sec on sec.id = qa.section_id
join public.quizzes qz on qz.id = qa.quiz_id
where qa.attempt_status <> 'superseded';

comment on view public.v_teacher_quiz_results is
  'Flat teacher-facing quiz results row: student + section + assessment context + score, one row per non-superseded quiz_attempts row. section_id/section_name come from quiz_attempts.section_id (the frozen historical snapshot, 0010), not student_enrollments, so results reflect the section the student was actually in when they took the quiz. Excludes attempt_status = ''superseded'' by default (see migration header for full reasoning — revisit if attempt history is ever needed). security_invoker: rides entirely on quiz_attempts_select (0015, app.teacher_has_section(section_id) OR own student_id) plus ordinary read access on students/sections/quizzes — grants no new access beyond what those policies already allow.';

grant select on public.v_teacher_quiz_results to authenticated;
