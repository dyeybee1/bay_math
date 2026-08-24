-- =============================================================================
-- Migration: 0054_student_current_grade_public_wrapper.sql
--
-- `app.student_current_grade()` (0026) already exists and is granted to
-- `authenticated`, but only for *internal* use inside other RLS
-- expressions (lessons_student_select, quizzes_student_select) — `app` is
-- not a PostgREST-exposed schema (0001), so the Flutter client itself has
-- never been able to call it directly. The redesigned Student Home Screen
-- needs to show "Grade 6" in its header, so this adds the same
-- public-schema pass-through wrapper shape already used for
-- public.student_section_school_year (0023) / public.set_student_avatar
-- (0053) — no new logic, just makes the existing function reachable.
-- =============================================================================

create or replace function public.student_current_grade()
returns grade_level
language sql
as $$
  select app.student_current_grade();
$$;

comment on function public.student_current_grade() is
  'Public-schema pass-through to app.student_current_grade() (0026) so the student-scoped Flutter client (studentScopedClientProvider) can read the caller''s own current grade level for display (Student Home Screen header). Same wrapper shape as public.student_section_school_year (0023).';

grant execute on function public.student_current_grade() to authenticated;
