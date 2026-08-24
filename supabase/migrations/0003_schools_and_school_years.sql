-- =============================================================================
-- Migration: 0003_schools_and_school_years.sql
-- Source: Phase 2 schema §3.1 (schools), §3.2 (school_years).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- schools
-- One row today; no constraint forces exactly one — multi-school later
-- requires zero migration (schema §3.1).
-- ---------------------------------------------------------------------------
create table public.schools (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.schools is
  'Top-level tenant. Phase 2 schema §3.1.';

-- ---------------------------------------------------------------------------
-- school_years
-- ---------------------------------------------------------------------------
create table public.school_years (
  id          uuid primary key default gen_random_uuid(),
  school_id   uuid not null references public.schools (id) on delete restrict on update cascade,
  label       text not null,
  start_date  date not null,
  end_date    date not null,
  is_current  boolean not null default false,
  status      school_year_status not null default 'active',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint school_years_end_after_start check (end_date > start_date),
  constraint school_years_school_label_unique unique (school_id, label)
);

comment on table public.school_years is
  'A bounded academic period everything time-bound is scoped to. Phase 2 schema §3.2.';

-- At most one current year per school.
create unique index school_years_one_current_per_school
  on public.school_years (school_id)
  where is_current = true;

create index school_years_school_id_idx on public.school_years (school_id);
