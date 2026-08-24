-- =============================================================================
-- Migration: 0016_grants.sql
-- RLS restricts ROWS, not table-level privileges — Postgres still requires an
-- explicit GRANT before any DML is possible at all. Every grant below is
-- deliberately broad at the privilege level; actual access is narrowed
-- entirely by the RLS policies in 0015. No grants are given to `anon`
-- (unauthenticated) anywhere in this schema.
--
-- Revision (post-Phase-3 hardening audit):
--   - students: SELECT/INSERT/UPDATE are now COLUMN-LEVEL grants that
--     exclude password_encrypted entirely. The general table-level grant
--     given here previously exposed the raw ciphertext to any authenticated
--     caller RLS allowed to see/write the row at all — unnecessary attack
--     surface for a column no client can usefully decrypt anyway (the
--     encryption key never touches the client at all — the app functions
--     require an encryption key parameter, sourced from a Phase 4 Edge
--     Function's environment secret, never from the client. All password
--     reads/writes now go exclusively through app.view_student_password(),
--     app.set_student_password(), and app.create_student() (0017), which
--     bypass this restriction as SECURITY DEFINER functions.
--   - DELETE removed from students and student_enrollments, matching the
--     RLS policy removal in 0015 (both are permanent-identity/historical
--     tables — see the audit findings there).
-- =============================================================================

grant usage on schema public to authenticated;

grant select, insert, update, delete on public.schools to authenticated;
grant select, insert, update, delete on public.school_years to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.sections to authenticated;
grant select, insert, update, delete on public.teacher_sections to authenticated;

-- students: column-level grants, password_encrypted intentionally excluded.
grant select (
  id, student_number, username, full_name, created_by,
  best_endless_streak, created_at, updated_at
) on public.students to authenticated;
grant insert (
  id, student_number, username, full_name, created_by,
  best_endless_streak, created_at, updated_at
) on public.students to authenticated;
grant update (
  student_number, username, full_name
) on public.students to authenticated;
-- No DELETE grant — see 0015 audit finding (students are never hard-deleted).

grant select, insert, update on public.student_enrollments to authenticated;
-- No DELETE grant — see 0015 audit finding (enrollments are closed, not deleted).

grant select, insert, update, delete on public.lessons to authenticated;
grant select, insert, update, delete on public.lesson_sections to authenticated;
grant select, insert, update       on public.lesson_progress to authenticated;
grant select, insert, update, delete on public.question_bank to authenticated;
grant select, insert, update, delete on public.question_choices to authenticated;
grant select, insert, update, delete on public.quizzes to authenticated;
grant select, insert, update, delete on public.quiz_sections to authenticated;
grant select, insert, update, delete on public.quiz_questions to authenticated;
grant select, insert, update       on public.quiz_attempts to authenticated;
-- No DELETE grant on quiz_attempts — see 0015 audit finding (historical
-- records are immutable; DELETE was never intended to be reachable for any
-- role, Admin included).
grant select, insert              on public.quiz_attempt_answers to authenticated;
grant select, insert              on public.quiz_attempt_answer_choice_snapshots to authenticated;
grant select, insert              on public.endless_quiz_sessions to authenticated;

-- audit_logs: SELECT only. INSERT is intentionally never granted directly —
-- the only write path is app.log_audit_event() (SECURITY DEFINER).
grant select on public.audit_logs to authenticated;

-- Helper functions in `app` (not API-exposed — see 0001 — but still callable
-- from within Postgres, e.g. a future public-schema wrapper RPC in Phase 4).
grant usage on schema app to authenticated;
grant execute on function app.current_profile_role() to authenticated;
grant execute on function app.is_admin() to authenticated;
grant execute on function app.is_approved_teacher() to authenticated;
grant execute on function app.teacher_has_section(uuid) to authenticated;
grant execute on function app.teacher_has_student(uuid) to authenticated;
grant execute on function app.student_has_section(uuid) to authenticated;
grant execute on function app.log_audit_event(text, text, uuid, jsonb) to authenticated;
grant execute on function app.current_student_id() to authenticated;

-- Student-credential functions (0017) are granted there, not here, since
-- they're defined in that later migration.
