-- =============================================================================
-- Migration: 0004_profiles.sql
-- Source: Phase 2 schema §3.3.
--
-- profiles.id = auth.users.id (1:1). Referencing auth.users directly with
-- ON DELETE CASCADE is standard Supabase practice: this FK is not one of the
-- "permanent-identity" internal relationships covered by the schema's general
-- RESTRICT policy (§0) — it is the identity link itself. If the underlying
-- Supabase Auth user is ever removed, the profile row has no remaining
-- purpose and should go with it.
-- =============================================================================

create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  role          profile_role not null,
  status        profile_status not null default 'pending',
  full_name     text not null,
  email         text not null unique,
  approved_by   uuid references public.profiles (id) on delete set null on update cascade,
  approved_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  -- An Admin profile is always approved — Admin is predefined, never a
  -- self-registration candidate (schema §3.3).
  constraint profiles_admin_always_approved
    check (role <> 'admin' or status = 'approved')
);

comment on table public.profiles is
  'Supabase Auth identity for Admin and Teacher, with role + approval status. Phase 2 schema §3.3.';

comment on column public.profiles.email is
  'Mirrors auth.users.email for query convenience (schema §9, Recommendation 7, confirmed as standard Supabase practice). Must be kept in sync at write time.';

create index profiles_role_idx on public.profiles (role);

-- Admin approval queue (schema §6 index strategy).
create index profiles_pending_teacher_approval_idx
  on public.profiles (status)
  where role = 'teacher' and status = 'pending';
