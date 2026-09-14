-- =============================================================================
-- Migration: 0089_teacher_lesson_composer.sql
--
-- Minimal persistence support for the Teacher lesson composer:
--   * backwards-compatible Draft / Published state on lessons;
--   * owner-scoped lesson_pages write policies;
--   * one transaction-safe RPC for lesson metadata, ordered blocks, and
--     section audience;
--   * a free Supabase Storage bucket for teacher-authored lesson images.
--
-- Existing lessons default to published, so built-in and already-created
-- lesson visibility does not change when the column is added. Existing page
-- rows and worked_example JSON are not rewritten.
-- =============================================================================

alter table public.lessons
  add column publication_status text not null default 'published';

alter table public.lessons
  add constraint lessons_publication_status_check
  check (publication_status in ('draft', 'published'));

comment on column public.lessons.publication_status is
  'Teacher authoring state. Existing and built-in lessons default to published. Draft teacher lessons remain visible to their owner but are excluded from Student RLS.';

-- Draft lessons must not be returned to Student clients, even if section
-- assignments have already been chosen in the composer.
drop policy if exists lessons_student_select on public.lessons;

create policy lessons_student_select on public.lessons for select
  using (
    publication_status = 'published'
    and app.current_student_id() is not null
    and (
      (source_type = 'built_in' and lessons.grade_level = app.student_current_grade())
      or exists (
        select 1 from public.lesson_sections ls
        where ls.lesson_id = lessons.id
          and app.student_has_section(ls.section_id)
      )
    )
  );

-- lesson_pages originally shipped read-only because authoring did not exist.
-- These policies mirror the parent lesson ownership rules without weakening
-- visibility for built-in content.
create policy lesson_pages_teacher_insert on public.lesson_pages for insert
  with check (
    app.is_admin()
    or exists (
      select 1 from public.lessons l
      where l.id = lesson_pages.lesson_id
        and l.source_type = 'teacher'
        and l.created_by = auth.uid()
    )
  );

create policy lesson_pages_teacher_update on public.lesson_pages for update
  using (
    app.is_admin()
    or exists (
      select 1 from public.lessons l
      where l.id = lesson_pages.lesson_id
        and l.source_type = 'teacher'
        and l.created_by = auth.uid()
    )
  )
  with check (
    app.is_admin()
    or exists (
      select 1 from public.lessons l
      where l.id = lesson_pages.lesson_id
        and l.source_type = 'teacher'
        and l.created_by = auth.uid()
    )
  );

create policy lesson_pages_teacher_delete on public.lesson_pages for delete
  using (
    app.is_admin()
    or exists (
      select 1 from public.lessons l
      where l.id = lesson_pages.lesson_id
        and l.source_type = 'teacher'
        and l.created_by = auth.uid()
    )
  );

-- The original relationship-delete policy also requires the caller to still
-- teach the assigned section. A lesson owner must be able to remove a stale
-- audience row after being unassigned from that section; this adds delete-only
-- authority over relationships belonging to the teacher's own lesson.
create policy lesson_sections_teacher_owned_lesson_delete
  on public.lesson_sections for delete
  using (
    app.is_approved_teacher()
    and exists (
      select 1 from public.lessons l
      where l.id = lesson_sections.lesson_id
        and l.source_type = 'teacher'
        and l.created_by = auth.uid()
    )
  );

create or replace function public.save_teacher_lesson(
  p_lesson_id uuid,
  p_title text,
  p_summary text,
  p_publication_status text,
  p_section_ids uuid[],
  p_blocks jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_lesson_id uuid;
begin
  if not app.is_approved_teacher() then
    raise exception 'Only an approved teacher can save a lesson.';
  end if;

  if nullif(trim(p_title), '') is null then
    raise exception 'Lesson title is required.';
  end if;

  if nullif(trim(p_summary), '') is null then
    raise exception 'Lesson summary is required.';
  end if;

  if coalesce(p_publication_status, '') not in ('draft', 'published') then
    raise exception 'Invalid lesson publication status.';
  end if;

  if jsonb_typeof(p_blocks) is distinct from 'array' then
    raise exception 'Lesson content blocks must be an array.';
  end if;

  if jsonb_array_length(p_blocks) = 0 then
    raise exception 'A lesson must contain at least one content block.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_blocks) block
    where jsonb_typeof(block) is distinct from 'object'
      or coalesce(block->>'section_type', '') not in (
      'composer_heading',
      'composer_paragraph',
      'composer_image',
      'composer_key_idea',
      'composer_worked_example',
      'composer_link'
    )
      or (
        block->>'section_type' = 'composer_heading'
        and nullif(trim(block->>'title'), '') is null
      )
      or (
        coalesce(block->>'section_type', '') <> 'composer_heading'
        and nullif(trim(block->>'body'), '') is null
      )
  ) then
    raise exception 'One or more lesson blocks are incomplete.';
  end if;

  if p_publication_status = 'published'
     and coalesce(cardinality(p_section_ids), 0) = 0 then
    raise exception 'A published lesson must be assigned to a section.';
  end if;

  if exists (
    select 1
    from unnest(coalesce(p_section_ids, array[]::uuid[])) section_id
    where not app.teacher_has_section(section_id)
  ) then
    raise exception 'A lesson can only be assigned to your own sections.';
  end if;

  if p_lesson_id is null then
    insert into public.lessons (
      title,
      body,
      source_type,
      created_by,
      publication_status
    )
    values (
      trim(p_title),
      trim(p_summary),
      'teacher',
      auth.uid(),
      p_publication_status
    )
    returning id into v_lesson_id;
  else
    update public.lessons
    set title = trim(p_title),
        body = trim(p_summary),
        publication_status = p_publication_status
    where id = p_lesson_id
      and source_type = 'teacher'
      and created_by = auth.uid()
    returning id into v_lesson_id;

    if v_lesson_id is null then
      raise exception 'Lesson not found or not editable by this teacher.';
    end if;
  end if;

  delete from public.lesson_pages
  where lesson_id = v_lesson_id;

  insert into public.lesson_pages (
    lesson_id,
    display_order,
    section_type,
    title,
    body
  )
  select
    v_lesson_id,
    block_order::smallint,
    block->>'section_type',
    coalesce(block->>'title', ''),
    coalesce(block->>'body', '')
  from jsonb_array_elements(p_blocks) with ordinality as blocks(block, block_order);

  delete from public.lesson_sections
  where lesson_id = v_lesson_id;

  insert into public.lesson_sections (lesson_id, section_id, assigned_by)
  select v_lesson_id, section_id, auth.uid()
  from (
    select distinct unnest(coalesce(p_section_ids, array[]::uuid[])) as section_id
  ) selected_sections;

  return v_lesson_id;
end;
$$;

comment on function public.save_teacher_lesson(uuid, text, text, text, uuid[], jsonb) is
  'Atomically creates or updates one teacher-owned lesson, its ordered composer blocks, publication state, and section audience. Existing IDs are preserved when p_lesson_id is supplied.';

revoke all on function public.save_teacher_lesson(
  uuid,
  text,
  text,
  text,
  uuid[],
  jsonb
) from public, anon;

grant execute on function public.save_teacher_lesson(
  uuid,
  text,
  text,
  text,
  uuid[],
  jsonb
) to authenticated;

-- Public educational images contain no student data. Object writes remain
-- restricted to an approved teacher's own top-level folder.
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'lesson-images',
  'lesson-images',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy lesson_images_public_select on storage.objects for select
  using (bucket_id = 'lesson-images');

create policy lesson_images_teacher_insert on storage.objects for insert
  with check (
    bucket_id = 'lesson-images'
    and app.is_approved_teacher()
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy lesson_images_teacher_update on storage.objects for update
  using (
    bucket_id = 'lesson-images'
    and app.is_approved_teacher()
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'lesson-images'
    and app.is_approved_teacher()
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy lesson_images_teacher_delete on storage.objects for delete
  using (
    bucket_id = 'lesson-images'
    and app.is_approved_teacher()
    and (storage.foldername(name))[1] = auth.uid()::text
  );
