-- =============================================================================
-- Migration: 0047_admin_account_archiving.sql
-- Part 1 of 4 (Admin Account Management + Archive). Adds archive/restore
-- support for both account types Admin manages directly:
--   - Teachers (public.profiles, role='teacher') via a new profile_status
--     enum value. Full audit coverage already exists for this table (see
--     app.audit_profile_status_change, 0014) — no new trigger needed.
--   - Students (public.students) via a brand-new status column, since
--     students have never had one. New enum, new column, new audit trigger
--     mirroring the profiles one, and new admin-only RPCs.
--
-- ENROLLMENT_STATUS FINDING (reported prior to this migration, repeated here
-- for anyone reading the SQL later): 0002_enums.sql defines
-- `enrollment_status` as ('active', 'transferred', 'completed'). This does
-- NOT match lib/core/models/student_enrollment.dart's EnrollmentStatus enum
-- (active/closed) — that Dart enum will need to change in a later part, or
-- app.archive_student's enrollment-ending value below will crash the client
-- on deserialization.
--
-- ENROLLMENT_STATUS 'archived' VALUE (revised from the original draft of
-- this migration, which reused 'completed'): 'completed' is reserved for a
-- likely future end-of-year grade completion/advancement feature — a
-- distinct, legitimate lifecycle event. Reusing it for admin-initiated
-- archival would conflate two different reasons an enrollment ended and
-- pollute any future reporting that counts "completed" enrollments as
-- grade advancement. A dedicated 'archived' value is added below instead,
-- and used only by app.archive_student.
--
-- SAME-TRANSACTION ENUM USE: `alter type ... add value` cannot have its new
-- value USED until the adding transaction commits — but that restriction
-- applies to values resolved at statement-execution time. app.archive_student
-- (below) is PL/pgSQL: its body's SQL is parsed and planned lazily, on first
-- call, not at CREATE FUNCTION time — so referencing 'archived' inside it in
-- this same migration is safe. Nothing in this file executes an UPDATE/
-- INSERT/comparison against either new enum value directly (only inside
-- function bodies that run later), so no "unsafe use of new value" error is
-- expected from either ALTER TYPE below.
--
-- RLS/GRANTS: no RLS policy changes in this migration. profiles already has
-- unrestricted table-level grants and admin-covering RLS (0015/0016), so the
-- new profile_status value needs nothing further. students' column-level
-- UPDATE grant (0016) intentionally excludes the new status column — status
-- changes are only reachable through the admin-only, audit-logged RPCs
-- below, never a raw table PATCH. A SELECT grant on the new column IS added
-- below (see item 2a) — 0016's existing column-level SELECT list predates
-- this column and does not cover it automatically.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Teachers: add 'archived' to profile_status.
-- Not used anywhere else in this migration.
-- ---------------------------------------------------------------------------
alter type profile_status add value 'archived';

-- ---------------------------------------------------------------------------
-- 2. Students: brand-new status column (students have never had one).
-- Mirrors section_status's shape (0002: active/archived) since the same
-- "still exists historically, just not current" semantics apply.
-- ---------------------------------------------------------------------------
create type student_status as enum ('active', 'archived');

alter table public.students
  add column status student_status not null default 'active';

comment on column public.students.status is
  'Admin-controlled archive state. Changed only via app.archive_student / app.restore_student (this migration) — never granted for direct table UPDATE (see 0016), so every transition is guaranteed to go through app.log_audit_event via the trigger below.';

-- ---------------------------------------------------------------------------
-- 2a. SELECT grant for the new column. 0016_grants.sql's column-level SELECT
-- list for students predates this column and does not include it; without
-- this, any query selecting students.status fails with "permission denied
-- for column status", Admin included.
-- ---------------------------------------------------------------------------
grant select (status) on public.students to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Audit trigger for students.status changes — mirrors
-- app.audit_profile_status_change() (0014) exactly, one table over.
-- ---------------------------------------------------------------------------
create or replace function app.audit_student_status_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.status is distinct from new.status then
    perform app.log_audit_event(
      'student_status_changed',
      'students',
      new.id,
      jsonb_build_object('from_status', old.status, 'to_status', new.status)
    );
  end if;
  return new;
end;
$$;

create trigger audit_status_change after update on public.students
  for each row execute function app.audit_student_status_change();

-- ---------------------------------------------------------------------------
-- 4. Students: add 'archived' to enrollment_status, reserved exclusively for
-- app.archive_student's enrollment-ending logic below. See header comment
-- for why this is a dedicated value rather than a reuse of 'completed'.
-- ---------------------------------------------------------------------------
alter type enrollment_status add value 'archived';

-- ---------------------------------------------------------------------------
-- 5a. app.archive_student — admin-only. Atomically archives the student and
-- ends their currently-active enrollment (there is at most one, per the
-- unique partial index in 0006). Mirrors the admin-only-check + SECURITY
-- DEFINER + audit-via-trigger shape already used by app.set_student_password
-- etc. (0017), except the audit here comes from the trigger above rather
-- than an explicit app.log_audit_event call, since it's a plain column
-- update the trigger already observes.
-- ---------------------------------------------------------------------------
create or replace function app.archive_student(p_student_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not app.is_admin() then
    raise exception 'not authorized to archive student %', p_student_id;
  end if;

  update public.students
  set status = 'archived'
  where id = p_student_id;

  if not found then
    raise exception 'student % not found', p_student_id;
  end if;

  -- End the currently-active enrollment, if any. Uses the dedicated
  -- 'archived' enrollment_status value (item 4 above), not 'completed' —
  -- see header comment.
  update public.student_enrollments
  set status = 'archived', ended_at = now()
  where student_id = p_student_id and status = 'active';
end;
$$;

comment on function app.archive_student(uuid) is
  'Admin-only. Sets students.status = archived and ends the student''s currently-active enrollment (student_enrollments.status = archived, ended_at = now()). The status change is audit-logged via the audit_status_change trigger on students, action = student_status_changed.';

grant execute on function app.archive_student(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5b. app.restore_student — admin-only. Status only; deliberately does NOT
-- create a new enrollment. A restored student has no active section until
-- explicitly re-enrolled (a later part's concern).
-- ---------------------------------------------------------------------------
create or replace function app.restore_student(p_student_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not app.is_admin() then
    raise exception 'not authorized to restore student %', p_student_id;
  end if;

  update public.students
  set status = 'active'
  where id = p_student_id;

  if not found then
    raise exception 'student % not found', p_student_id;
  end if;
end;
$$;

comment on function app.restore_student(uuid) is
  'Admin-only. Sets students.status = active. Does NOT re-create an enrollment — a restored student has no active section until re-enrolled separately. Audit-logged via the audit_status_change trigger on students, action = student_status_changed.';

grant execute on function app.restore_student(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Public-schema wrapper functions, matching the exact pass-through
-- pattern established in 0020_public_rpc_wrappers_for_student_functions.sql
-- (plain security invoker calls into the app-schema functions above; the
-- `app` schema is not in PostgREST's exposed-schema list, see 0001, so these
-- are what makes the functions reachable via POST /rest/v1/rpc/...).
-- ---------------------------------------------------------------------------
create or replace function public.archive_student(p_student_id uuid)
returns void
language sql
as $$
  select app.archive_student(p_student_id);
$$;

comment on function public.archive_student(uuid) is
  'Public-schema pass-through to app.archive_student (this migration) so it is reachable via PostgREST — see 0020 header comment for why this pattern exists. No additional logic.';

grant execute on function public.archive_student(uuid) to authenticated;

create or replace function public.restore_student(p_student_id uuid)
returns void
language sql
as $$
  select app.restore_student(p_student_id);
$$;

comment on function public.restore_student(uuid) is
  'Public-schema pass-through to app.restore_student (this migration) so it is reachable via PostgREST — see 0020 header comment for why this pattern exists. No additional logic.';

grant execute on function public.restore_student(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. app.verify_student_credentials — archived students may not log in.
-- Same "don't leak which part failed" shape as the existing wrong-username
-- path: an archived username is treated exactly like a nonexistent one
-- (same pg_sleep, same bare `return null`, no distinguishable error).
--
-- Redefined in full (not ALTERed) because the WHERE/select needs to pull
-- status too. CREATE OR REPLACE does not touch grants/ownership (the
-- service_role-only revoke/grant from 0017 stays intact), but it DOES
-- require the search_path fix from 0021 to be restated explicitly here, or
-- pgp_sym_decrypt would fail again (pgcrypto lives in `extensions`, not
-- `public`).
-- ---------------------------------------------------------------------------
create or replace function app.verify_student_credentials(
  p_username text,
  p_password text,
  p_encryption_key text
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_student_id uuid;
  v_encrypted bytea;
  v_status student_status;
  v_decrypted text;
begin
  select id, password_encrypted, status into v_student_id, v_encrypted, v_status
  from public.students
  where username = p_username;

  if v_student_id is null or v_status = 'archived' then
    -- Do roughly the same amount of work whether the username didn't exist
    -- or belongs to an archived student, as a mild (not complete) mitigation
    -- against enumerating which case applies via response timing.
    perform pg_sleep(0.1);
    return null;
  end if;

  begin
    v_decrypted := pgp_sym_decrypt(v_encrypted, p_encryption_key);
  exception when others then
    -- Never leak decryption error detail to the caller (also covers a
    -- misconfigured/stale key being passed in).
    return null;
  end;

  if v_decrypted = p_password then
    return v_student_id;
  else
    return null;
  end if;
end;
$$;

comment on function app.verify_student_credentials(text, text, text) is
  'Login verification only. Returns the student id on success, NULL otherwise (unknown username, wrong password, and archived status are all indistinguishable to the caller). Callable only by service_role, from the login Edge Function, which supplies the encryption key from its own environment secret.';
