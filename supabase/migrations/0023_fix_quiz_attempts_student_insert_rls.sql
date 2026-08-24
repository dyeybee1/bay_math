-- =============================================================================
-- Migration: 0023_fix_quiz_attempts_student_insert_rls.sql
-- Phase 6 (Quiz-Taking) prerequisite fix — found while implementing
-- `findOrCreateActiveAttempt`, NOT part of the originally-scoped six items.
-- Flagged to the project owner before writing this, per this project's own
-- "don't touch/redesign approved migrations unless you find an actual bug —
-- flag it, don't fix it silently" rule; this migration is the follow-up
-- after that flag, kept separate from 0015 so it's independently reviewable
-- and revertible.
--
-- THE BUG
-- `quiz_attempts_student_insert` (0015)'s WITH CHECK contains:
--
--   join public.sections s on s.id = se.section_id
--   where ... and s.school_year_id = quiz_attempts.school_year_id
--
-- `sections` has no student-visible SELECT policy at all (0015's own
-- section header: "Student: indirect only"). Postgres RLS re-applies a
-- table's own policies to every subquery that touches it, regardless of
-- which other policy's USING/WITH CHECK clause embeds that subquery — this
-- is the exact same recursive-RLS bug this project's own 0013/0015 audit
-- already found and fixed for `student_enrollments` (via
-- `app.student_has_section()`, a SECURITY DEFINER helper that intentionally
-- breaks the recursion). That fix was never extended to this `sections`
-- join, so today this WITH CHECK's EXISTS(...) always evaluates false for
-- a student caller — every `quiz_attempts` insert attempt by a student
-- fails RLS (42501), regardless of what values the app sends. Nothing in
-- application code can route around this: students have no legitimate way
-- to read `sections.school_year_id` client-side either, so this must be
-- fixed at the RLS layer, not worked around above it.
--
-- THE FIX
-- Add `app.student_section_school_year(p_section_id)`, mirroring
-- `app.student_has_section(p_section_id)` exactly (same SECURITY DEFINER
-- pattern, same narrow purpose: break the recursion for one trusted
-- lookup), then rewrite the policy to call it instead of joining
-- `sections` directly. Only the WITH CHECK changes — same scope discipline
-- as 0018 item 5's `quiz_questions_teacher_write` fix (USING is untouched,
-- since this is about preventing new unauthorized inserts, not retroactively
-- restricting visibility of rows already valid when created).
-- =============================================================================

create or replace function app.student_section_school_year(p_section_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select school_year_id
  from public.sections
  where id = p_section_id;
$$;

comment on function app.student_section_school_year(uuid) is
  'Returns the school_year_id for a given section, bypassing RLS. SECURITY DEFINER, mirroring app.student_has_section() — exists solely so student-facing WITH CHECK clauses (quiz_attempts_student_insert) can validate a section''s school year without a raw join against `sections`, which has no student-visible SELECT policy and would otherwise silently return zero rows for a student caller (same recursive-RLS bug already fixed elsewhere for student_enrollments; see 0013/0015). Phase 6 prerequisite fix.';

-- Required for the WITH CHECK call itself: every function call anywhere in
-- SQL, including inside an RLS expression, is checked against the calling
-- role's own EXECUTE grant — SECURITY DEFINER changes whose privileges the
-- function body runs WITH, not whether the caller may invoke it at all.
-- Mirrors the existing grant on app.student_has_section(uuid) (0016).
grant execute on function app.student_section_school_year(uuid) to authenticated;

-- Public-schema pass-through wrapper (mirrors the 0020/0024 pattern) so the
-- Flutter client can also resolve this value directly — the WITH CHECK
-- grant above only lets the *policy* call it during an insert; the client
-- still needs the actual value to put in the insert payload's
-- school_year_id column in the first place, and `app` is not a
-- PostgREST-exposed schema (0001).
create or replace function public.student_section_school_year(p_section_id uuid)
returns uuid
language sql
as $$
  select app.student_section_school_year(p_section_id);
$$;

comment on function public.student_section_school_year(uuid) is
  'Public-schema pass-through to app.student_section_school_year (0023) so it is reachable via PostgREST for the Flutter client to resolve a section''s school_year_id before submitting a quiz_attempts insert. No additional logic. Low-sensitivity by design (a section_id -> school_year_id mapping only), granted broadly to authenticated like other section-scoping helpers.';

grant execute on function public.student_section_school_year(uuid) to authenticated;

drop policy if exists quiz_attempts_student_insert on public.quiz_attempts;

create policy quiz_attempts_student_insert on public.quiz_attempts for insert
  with check (
    student_id = app.current_student_id()
    and exists (
      select 1
      from public.student_enrollments se
      where se.student_id = quiz_attempts.student_id
        and se.section_id = quiz_attempts.section_id
        and se.status = 'active'
    )
    and app.student_section_school_year(quiz_attempts.section_id) = quiz_attempts.school_year_id
    and exists (
      select 1 from public.quizzes q
      where q.id = quiz_attempts.quiz_id
        and (
          q.source_type = 'built_in'
          or exists (
            select 1 from public.quiz_sections qs
            where qs.quiz_id = q.id and qs.section_id = quiz_attempts.section_id
          )
        )
    )
  );
