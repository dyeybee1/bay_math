-- =============================================================================
-- Migration: 0005_sections_and_teacher_sections.sql
-- Source: Phase 2 schema §3.4 (sections), §3.5 (teacher_sections).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- sections
-- ---------------------------------------------------------------------------
create table public.sections (
  id              uuid primary key default gen_random_uuid(),
  school_year_id  uuid not null references public.school_years (id) on delete restrict on update cascade,
  grade_level     grade_level not null,
  name            text not null,
  status          section_status not null default 'active',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint sections_year_grade_name_unique unique (school_year_id, grade_level, name)
);

comment on table public.sections is
  'A class/grade grouping within a school year — the unit the section-centric architecture revolves around. Phase 2 schema §3.4.';

create index sections_school_year_id_idx on public.sections (school_year_id);

-- ---------------------------------------------------------------------------
-- teacher_sections  ("My Sections")
-- ---------------------------------------------------------------------------
create table public.teacher_sections (
  id            uuid primary key default gen_random_uuid(),
  teacher_id    uuid not null references public.profiles (id) on delete restrict on update cascade,
  section_id    uuid not null references public.sections (id) on delete restrict on update cascade,
  is_primary    boolean not null default true,
  assigned_by   uuid references public.profiles (id) on delete set null on update cascade,
  assigned_at   timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint teacher_sections_teacher_section_unique unique (teacher_id, section_id)
);

comment on table public.teacher_sections is
  'Teacher <-> Section <-> School Year assignment, with a primary-teacher flag. Phase 2 schema §3.5.';

create index teacher_sections_teacher_id_idx on public.teacher_sections (teacher_id);
create index teacher_sections_section_id_idx on public.teacher_sections (section_id);

-- One primary teacher per section (V1 rule; schema §3.5).
create unique index teacher_sections_one_primary_per_section
  on public.teacher_sections (section_id)
  where is_primary = true;
