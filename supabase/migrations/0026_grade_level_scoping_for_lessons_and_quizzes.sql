-- =============================================================================
-- Migration: 0026_grade_level_scoping_for_lessons_and_quizzes.sql
-- Adds grade-level scoping to built-in lessons/quizzes, so built-in content
-- for one grade (e.g. Grade 4) is no longer visible to every student
-- regardless of grade. Schema-only — content seeding is a separate,
-- follow-up migration by design (schema first, content second).
--
-- CONFIRMED AGAINST ACTUAL SCHEMA before writing this:
--   - grade_level enum already exists (0002_enums.sql): 'grade_4' | 'grade_5'
--     | 'grade_6'. sections.grade_level already uses it (0005).
--   - lessons/quizzes (0007/0009) have no grade concept today.
--   - lessons_student_select / quizzes_student_select (0015)'s `built_in`
--     branch grants visibility to EVERY student regardless of grade —
--     confirmed by reading the policy bodies, not assumed.
--   - student_enrollments guarantees exactly one ACTIVE row per student
--     (student_enrollments_one_active_per_student, 0006), so "the student's
--     grade" is a single deterministic value, not a set.
--   - Teacher-facing list screens (lessons_screen.dart/quizzes_screen.dart,
--     via LessonsRepository/QuizzesRepository) issue flat, unfiltered
--     `.select()` calls and rely entirely on RLS for scoping — confirmed by
--     reading the repository source. Per explicit project-owner decision,
--     this migration does NOT change the teacher-facing `built_in` SELECT
--     branch: teachers continue to see built-in content across all grades.
--     Revisit later if per-grade teacher browsing becomes a real need.
--
-- DESIGN
--   - grade_level added to both lessons and quizzes, nullable at the column
--     level, but a CHECK constraint (mirroring the existing
--     *_source_created_by_pairing pattern already on both tables) requires
--     it to be non-null whenever source_type = 'built_in'. Teacher rows may
--     leave it NULL — teacher content is already scoped by explicit
--     lesson_sections/quiz_sections assignment, so grade-tagging it is
--     optional metadata, not enforced (confirmed with project owner).
--   - A new SECURITY DEFINER helper, app.student_current_grade(), returns
--     the calling student's current grade by joining student_enrollments ->
--     sections. This mirrors app.student_has_section() (0013) and
--     app.student_section_school_year() (0023): both exist specifically to
--     avoid a raw client-visible join against student_enrollments/sections
--     inside an RLS expression, since neither table has a SELECT policy
--     that would make such a raw join return rows for a student caller
--     (the exact recursive-RLS bug documented in 0013's own comments).
--   - Only the `built_in` branch of lessons_student_select and
--     quizzes_student_select changes, adding a grade match against this
--     helper. Every other policy (teacher branches, lesson_sections,
--     quiz_sections, quiz_questions, question_bank, etc.) is untouched.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------
alter table public.lessons add column grade_level grade_level;
alter table public.quizzes add column grade_level grade_level;

comment on column public.lessons.grade_level is
  'Grade the lesson is scoped to. Required for built-in content (see lessons_built_in_requires_grade); optional metadata for teacher content, which is already scoped via lesson_sections. Phase 6 addition, 0026.';
comment on column public.quizzes.grade_level is
  'Grade the quiz is scoped to. Required for built-in content (see quizzes_built_in_requires_grade); optional metadata for teacher content, which is already scoped via quiz_sections. Phase 6 addition, 0026.';

-- ---------------------------------------------------------------------------
-- Constraints — built_in must declare a grade; teacher content may not.
-- Composes with, does not replace, the existing *_source_created_by_pairing
-- constraints already on these tables.
-- ---------------------------------------------------------------------------
alter table public.lessons add constraint lessons_built_in_requires_grade check (
  (source_type = 'built_in' and grade_level is not null)
  or (source_type = 'teacher')
);

alter table public.quizzes add constraint quizzes_built_in_requires_grade check (
  (source_type = 'built_in' and grade_level is not null)
  or (source_type = 'teacher')
);

-- ---------------------------------------------------------------------------
-- Helper: the calling student's current grade, via their single active
-- enrollment. SECURITY DEFINER for the same reason as app.student_has_section
-- (0013) and app.student_section_school_year (0023) — student_enrollments
-- and sections have no student-visible SELECT policy, so a raw join inside
-- an RLS expression would silently return zero rows for every student
-- caller. Returns NULL if the caller has no active enrollment (e.g. a
-- Teacher/Admin session, where app.current_student_id() itself is NULL).
-- ---------------------------------------------------------------------------
create or replace function app.student_current_grade()
returns grade_level
language sql
stable
security definer
set search_path = public
as $$
  select s.grade_level
  from public.student_enrollments se
  join public.sections s on s.id = se.section_id
  where se.student_id = app.current_student_id()
    and se.status = 'active';
$$;

comment on function app.student_current_grade() is
  'Returns the currently authenticated student''s current grade_level, derived from their single active student_enrollments row -> sections.grade_level. SECURITY DEFINER to avoid the same recursive-RLS gap already fixed for app.student_has_section() (0013) and app.student_section_school_year() (0023). Returns NULL for any non-student session. Added 0026 for built-in lesson/quiz grade scoping.';

grant execute on function app.student_current_grade() to authenticated;

-- ---------------------------------------------------------------------------
-- RLS: rewrite only the `built_in` branch of the two student SELECT
-- policies. Teacher-facing branches, and every other policy, are untouched
-- (see design note above re: teacher browsing scope).
-- ---------------------------------------------------------------------------
drop policy if exists lessons_student_select on public.lessons;

create policy lessons_student_select on public.lessons for select
  using (
    app.current_student_id() is not null
    and (
      (source_type = 'built_in' and lessons.grade_level = app.student_current_grade())
      or exists (
        select 1 from public.lesson_sections ls
        where ls.lesson_id = lessons.id
          and app.student_has_section(ls.section_id)
      )
    )
  );

drop policy if exists quizzes_student_select on public.quizzes;

create policy quizzes_student_select on public.quizzes for select
  using (
    app.current_student_id() is not null
    and (
      (source_type = 'built_in' and quizzes.grade_level = app.student_current_grade())
      or exists (
        select 1 from public.quiz_sections qs
        where qs.quiz_id = quizzes.id
          and app.student_has_section(qs.section_id)
      )
    )
  );
