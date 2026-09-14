-- =============================================================================
-- Migration: 0091_teacher_grade_level_content_scoping.sql
--
-- Restricts the Teacher Lessons and Teacher Quizzes catalogs to built-in
-- content for grade levels the calling Teacher actually teaches.
--
-- 0026 introduced lessons.grade_level / quizzes.grade_level and scoped the
-- Student policies, but deliberately left the 0015 Teacher policies broad.
-- The Flutter repositories use direct, unfiltered table selects and rely on
-- those policies, so every approved Teacher consequently received every
-- built-in grade. This migration closes that data-access gap at RLS.
--
-- Teacher grade membership is derived only from the live relationship:
--   auth.uid() -> teacher_sections.teacher_id -> sections.grade_level
--
-- EXISTS deliberately models a set-membership check. A Teacher assigned to
-- several sections of one grade cannot duplicate catalog rows, a multi-grade
-- Teacher receives the union of those grades, and a Teacher with no section
-- assignments receives no built-in content. Admin access and Student policies
-- are unchanged. Teacher-owned content retains its existing owner visibility;
-- its section assignments continue to be protected by lesson_sections /
-- quiz_sections RLS and save_teacher_lesson's section validation.
-- =============================================================================

create or replace function app.teacher_has_grade_level(
  p_grade_level public.grade_level
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.teacher_sections ts
    join public.sections s on s.id = ts.section_id
    where ts.teacher_id = auth.uid()
      and s.grade_level = p_grade_level
  );
$$;

comment on function app.teacher_has_grade_level(public.grade_level) is
  'True when the calling Teacher has at least one teacher_sections assignment whose section has the requested grade_level. SECURITY DEFINER avoids recursive RLS while deriving the grade from authoritative section assignments. Added in 0091.';

revoke all on function app.teacher_has_grade_level(public.grade_level)
  from public, anon;
grant execute on function app.teacher_has_grade_level(public.grade_level)
  to authenticated;

drop policy if exists lessons_teacher_select on public.lessons;

create policy lessons_teacher_select on public.lessons for select
  using (
    app.is_admin()
    or (
      app.is_approved_teacher()
      and (
        (
          source_type = 'built_in'
          and app.teacher_has_grade_level(lessons.grade_level)
        )
        or (
          source_type = 'teacher'
          and created_by = auth.uid()
        )
      )
    )
  );

drop policy if exists quizzes_teacher_select on public.quizzes;

create policy quizzes_teacher_select on public.quizzes for select
  using (
    app.is_admin()
    or (
      app.is_approved_teacher()
      and (
        (
          source_type = 'built_in'
          and app.teacher_has_grade_level(quizzes.grade_level)
        )
        or (
          source_type = 'teacher'
          and created_by = auth.uid()
        )
      )
    )
  );
