-- =============================================================================
-- Migration: 0007_lessons.sql
-- Source: Phase 2 schema §3.8 (lessons), §3.9 (lesson_sections),
--         §3.10 (lesson_progress).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- lessons
-- ---------------------------------------------------------------------------
create table public.lessons (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  body         text not null,
  source_type  content_source_type not null,
  created_by   uuid references public.profiles (id) on delete restrict on update cascade,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  constraint lessons_source_created_by_pairing check (
    (source_type = 'built_in' and created_by is null)
    or (source_type = 'teacher' and created_by is not null)
  )
);

comment on table public.lessons is
  'Built-in or teacher-created instructional content. Never a prerequisite for anything (schema §7.3). Phase 2 schema §3.8.';

create index lessons_created_by_idx on public.lessons (created_by);
create index lessons_source_type_idx on public.lessons (source_type);

-- ---------------------------------------------------------------------------
-- lesson_sections
-- Built-in lessons have ZERO rows here (universal visibility is a property
-- of source_type = 'built_in', not expressed through this join at all).
-- Teacher lessons get exactly one row by default (their home section); more
-- only via an explicit teacher action (schema §5, §3.9).
-- ---------------------------------------------------------------------------
create table public.lesson_sections (
  id           uuid primary key default gen_random_uuid(),
  lesson_id    uuid not null references public.lessons (id) on delete cascade on update cascade,
  section_id   uuid not null references public.sections (id) on delete cascade on update cascade,
  assigned_by  uuid references public.profiles (id) on delete set null on update cascade,
  assigned_at  timestamptz not null default now(),

  constraint lesson_sections_lesson_section_unique unique (lesson_id, section_id)
);

comment on table public.lesson_sections is
  'Section-visibility join for teacher-created lessons. Phase 2 schema §3.9.';

create index lesson_sections_section_id_idx on public.lesson_sections (section_id);

-- ---------------------------------------------------------------------------
-- lesson_progress
-- Analytics only — never an access gate (schema §7.3).
-- ---------------------------------------------------------------------------
create table public.lesson_progress (
  id            uuid primary key default gen_random_uuid(),
  student_id    uuid not null references public.students (id) on delete restrict on update cascade,
  lesson_id     uuid not null references public.lessons (id) on delete restrict on update cascade,
  status        lesson_progress_status not null default 'not_started',
  started_at    timestamptz,
  completed_at  timestamptz,
  updated_at    timestamptz not null default now(),

  constraint lesson_progress_student_lesson_unique unique (student_id, lesson_id)
);

comment on table public.lesson_progress is
  'A student''s status against a lesson: Not Started / In Progress / Completed. Analytics only. Phase 2 schema §3.10.';

create index lesson_progress_lesson_id_idx on public.lesson_progress (lesson_id);
