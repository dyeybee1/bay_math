-- =============================================================================
-- Migration: 0053_student_avatar.sql
--
-- Adds a first-login avatar picker for students (Flutter home screen).
--
-- DESIGN DECISION: avatar_id is a short catalog key (e.g. 'fox', 'star'),
-- NOT an uploaded image. The Flutter client maps this key to a bundled
-- asset/icon (see lib/core/constants/avatar_catalog.dart) — nothing is
-- stored in Supabase Storage. This keeps the feature entirely inside the
-- free-tier Database quota (one small text column) with zero Storage/
-- bandwidth usage, and avoids all the moderation/validation concerns that
-- come with user-uploaded images.
--
-- NULL avatar_id is the "hasn't picked one yet" signal the Flutter router
-- uses to show the picker on first login — no separate boolean flag is
-- needed. This persists in the database (unlike StudentSession, which is
-- in-memory only per Phase 4 scope), so the picker only ever shows once,
-- regardless of device or app restarts.
--
-- WRITE PATH: deliberately NOT a plain RLS UPDATE policy on `students`.
-- That table has no student-facing RLS policy at all today (0015: "Student:
-- —") and its column-level grants (0016) only allow `authenticated` to
-- update student_number/username/full_name. Opening a blanket UPDATE policy
-- for students would need careful column-scoping to stop a student from
-- editing their own full_name/username, which RLS cannot restrict on its
-- own (RLS is row-scoped, not column-scoped). Instead this follows the same
-- SECURITY DEFINER pattern already used for narrow, trusted student writes
-- elsewhere in this schema (app.student_has_section, app.log_audit_event):
-- a single-purpose function that only ever touches avatar_id for the
-- caller's own row, callable directly from the student-scoped PostgREST
-- client (Connection A, same trust model as
-- EndlessQuizRepository.finalizeSession) — no Edge Function needed, since
-- no secret/encryption key is involved.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Column
-- ---------------------------------------------------------------------------
alter table public.students
  add column avatar_id text;

comment on column public.students.avatar_id is
  'Catalog key for the student''s chosen avatar (see Flutter avatar_catalog.dart), NOT an image. NULL means the student has not picked one yet — the Flutter router treats NULL as "show the first-login avatar picker". Set exclusively via app.set_student_avatar (this migration), never a direct client UPDATE.';

-- Keeps the catalog authoritative in one place: the Flutter asset catalog
-- and this constraint must be updated together whenever an avatar option
-- is added/removed. Deliberately a fixed list rather than free text — an
-- unrecognized key would silently fail to render on the home screen.
alter table public.students
  add constraint students_avatar_id_valid check (
    avatar_id is null or avatar_id in (
      'fox', 'owl', 'panda', 'robot', 'star', 'rocket',
      'turtle', 'whale', 'cat', 'lion', 'penguin', 'dino'
    )
  );

-- ---------------------------------------------------------------------------
-- RLS — let a student read their own row.
--
-- AUDIT NOTE: 0015 deliberately left `students` with no student-facing
-- policy at all ("Student: —"), because nothing student-facing needed it
-- yet. The avatar picker is the first student-side feature that needs to
-- read back its own row (avatar_id, full_name), so this adds exactly that
-- — own-row SELECT only, mirroring student_enrollments_select's own-row
-- shape (0015).
-- ---------------------------------------------------------------------------
create policy students_student_select_own on public.students for select
  using (id = app.current_student_id());

-- Column-level grants (0016) gate PostgREST access independently of RLS —
-- the existing `select` grant predates this column, so it must be reissued
-- to include it. Re-granting the full existing column list (not just
-- avatar_id) because `grant select (col) on ... to authenticated` is
-- additive per-call, but writing the complete list here keeps this
-- migration self-documenting about exactly what authenticated can select,
-- rather than relying on the reader to mentally merge it with 0016.
grant select (
  id, student_number, username, full_name, created_by,
  best_endless_streak, avatar_id, created_at, updated_at
) on public.students to authenticated;

-- ---------------------------------------------------------------------------
-- Controlled write: app.set_student_avatar
-- ---------------------------------------------------------------------------
create or replace function app.set_student_avatar(p_avatar_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid := app.current_student_id();
begin
  if v_student_id is null then
    raise exception 'Not authenticated as a student.' using errcode = '28000';
  end if;

  -- Constraint on the table itself is the source of truth for valid keys;
  -- this update will simply fail with a check-constraint violation for an
  -- unrecognized key rather than duplicating the allowed list here.
  update public.students
  set avatar_id = p_avatar_id,
      updated_at = now()
  where id = v_student_id;
end;
$$;

comment on function app.set_student_avatar(text) is
  'Sets the calling student''s own avatar_id, scoped by app.current_student_id() (never a caller-supplied student id). SECURITY DEFINER so it can write without a blanket student UPDATE policy/grant on `students` — mirrors the app.student_has_section/app.log_audit_event narrow-write pattern (0013).';

revoke all on function app.set_student_avatar(text) from public, anon;
grant execute on function app.set_student_avatar(text) to authenticated;

-- Public-schema pass-through wrapper so the Flutter client can call this
-- via PostgREST .rpc() — `app` is not an exposed schema (0001), same
-- reasoning as public.student_section_school_year (0023).
create or replace function public.set_student_avatar(p_avatar_id text)
returns void
language sql
as $$
  select app.set_student_avatar(p_avatar_id);
$$;

comment on function public.set_student_avatar(text) is
  'Public-schema pass-through to app.set_student_avatar (0053) so it is reachable via PostgREST .rpc() from the student-scoped Flutter client (studentScopedClientProvider). Same wrapper shape as public.student_section_school_year (0023) / public.archive_student (0047).';

grant execute on function public.set_student_avatar(text) to authenticated;
