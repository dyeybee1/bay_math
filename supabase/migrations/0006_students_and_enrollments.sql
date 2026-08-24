-- =============================================================================
-- Migration: 0006_students_and_enrollments.sql
-- Source: Phase 2 schema §3.6 (students), §3.7 (student_enrollments).
--
-- NOTE ON password_encrypted: stored as bytea (pgcrypto's pgp_sym_encrypt
-- output type), reversibly encrypted per blueprint §11.3 / schema §3.6 — this
-- is the sole reason it is not one-way hashed like a normal credential. The
-- encryption key itself is an application-layer secret, never stored in this
-- database and never hardcoded in SQL; encrypt/decrypt calls are expected to
-- be made through a SECURITY DEFINER RPC supplied the key at call time
-- (a Phase 4 concern, not resolved by this migration).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- students
-- No section_id column — a student's section is always read through
-- student_enrollments (schema §3.6: "never owned by a section directly").
-- ---------------------------------------------------------------------------
create table public.students (
  id                   uuid primary key default gen_random_uuid(),
  student_number       text unique,
  username             text not null unique,
  password_encrypted   bytea not null,
  full_name            text not null,
  created_by           uuid not null references public.profiles (id) on delete restrict on update cascade,
  best_endless_streak  integer not null default 0,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),

  constraint students_best_streak_non_negative check (best_endless_streak >= 0)
);

comment on table public.students is
  'Permanent student identity. Login is username-based; students are not Supabase Auth identities. Phase 2 schema §3.6.';

comment on column public.students.student_number is
  'Optional permanent reporting identifier, never used for login. Nullable per blueprint §16 (left open); schema §9 Recommendation 8 confirms nullable.';

create index students_created_by_idx on public.students (created_by);

-- ---------------------------------------------------------------------------
-- student_enrollments
-- The only table that changes on transfer/advancement (schema §3.7).
-- ---------------------------------------------------------------------------
create table public.student_enrollments (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references public.students (id) on delete restrict on update cascade,
  section_id   uuid not null references public.sections (id) on delete restrict on update cascade,
  status       enrollment_status not null default 'active',
  enrolled_at  timestamptz not null default now(),
  ended_at     timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.student_enrollments is
  'Student <-> Section <-> School Year join. school_year_id is intentionally NOT duplicated here; derive via section_id -> sections.school_year_id (schema §9, Recommendation 1 — unchanged for this table). Phase 2 schema §3.7.';

create index student_enrollments_section_id_idx on public.student_enrollments (section_id);

-- Exactly one current section per student, enforced at the database level
-- (schema §3.7).
create unique index student_enrollments_one_active_per_student
  on public.student_enrollments (student_id)
  where status = 'active';
