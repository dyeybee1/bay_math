-- =============================================================================
-- Migration: 0017_student_authentication.sql
--
-- RESOLVES: the student authentication gap (app.current_student_id() is
-- implemented in 0013; this file adds the credential-handling functions it
-- depends on).
--
-- KEY STORAGE DECISION: an Edge Function environment secret, NOT Supabase
-- Vault. Justification (full comparison delivered alongside this migration):
-- Vault keeps the key inside Postgres, readable by any sufficiently
-- privileged DB session including the Dashboard SQL Editor, and entangles
-- it with database backups/clones. An Edge Function secret never enters
-- Postgres at all, is write-only from the Dashboard once set, is untouched
-- by DB backups/clones, and reuses the exact same secret-management
-- mechanism this login flow already requires for JWT signing. For this
-- project's scale and risk profile, Vault added a second secret-management
-- subsystem for no offsetting security benefit.
--
-- HOW THE KEY FLOWS: every function below that touches password_encrypted
-- takes the encryption key as a parameter (p_encryption_key) rather than
-- looking it up itself. The key is sourced from Deno.env.get(...) inside a
-- Phase 4 Edge Function and passed in on each call — it is never generated,
-- stored, or looked up by Postgres itself.
--
-- *** IMPORTANT FOR PHASE 4: these functions must be called ONLY from Edge
-- Functions, never directly from the Flutter client — including
-- set_student_password/view_student_password/create_student, even though
-- those are teacher-initiated. A teacher's device must never hold the
-- encryption key. The pattern is: Flutter -> Edge Function (holds the key,
-- forwards the caller's own JWT to Postgres so auth.uid()-based ownership
-- checks below still resolve to the real teacher) -> these functions. ***
--
-- KEY ROTATION NOTE (applies regardless of where the key lives): rotating
-- the key does not retroactively re-encrypt existing password_encrypted
-- values. A rotation requires a proper re-encryption pass (decrypt with the
-- old key, re-encrypt with the new one) — not just swapping the env var.
-- This is an inherent property of static-key symmetric encryption, not a
-- consequence of choosing env secrets over Vault.
--
-- STUDENT AUTH MECHANISM (unchanged from the original design): custom JWT
-- claims. Students are never inserted into auth.users — zero duplicate Auth
-- identities, zero synthetic emails. See app.current_student_id() (0013)
-- for how the resulting JWT's student_id claim is read back out.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- app.verify_student_credentials — the login path.
--
-- Callable only by service_role (see the revoke/grant below) — i.e. only
-- from the login Edge Function, which is the actual public, rate-limited
-- entry point. Never exposed to anon/authenticated directly.
-- ---------------------------------------------------------------------------
create or replace function app.verify_student_credentials(
  p_username text,
  p_password text,
  p_encryption_key text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_encrypted bytea;
  v_decrypted text;
begin
  select id, password_encrypted into v_student_id, v_encrypted
  from public.students
  where username = p_username;

  if v_student_id is null then
    -- Do roughly the same amount of work whether or not the username
    -- existed, as a mild (not complete) mitigation against username
    -- enumeration via response timing.
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
  'Login verification only. Returns the student id on success, NULL otherwise. Callable only by service_role, from the login Edge Function, which supplies the encryption key from its own environment secret.';

revoke all on function app.verify_student_credentials(text, text, text) from public, anon, authenticated;
grant execute on function app.verify_student_credentials(text, text, text) to service_role;

-- ---------------------------------------------------------------------------
-- app.set_student_password — teacher/admin-initiated set or reset.
-- Ownership-checked (mirrors students_teacher_update's RLS condition
-- exactly) and audit-logged. The only permitted write path for
-- password_encrypted (see the column-level grant in 0016).
-- ---------------------------------------------------------------------------
create or replace function app.set_student_password(
  p_student_id uuid,
  p_new_password text,
  p_encryption_key text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (app.is_admin() or app.teacher_has_student(p_student_id)) then
    raise exception 'not authorized to change credentials for student %', p_student_id;
  end if;

  if p_new_password is null or length(p_new_password) < 4 then
    raise exception 'password does not meet the minimum length requirement';
  end if;

  update public.students
  set password_encrypted = pgp_sym_encrypt(p_new_password, p_encryption_key)
  where id = p_student_id;

  if not found then
    raise exception 'student % not found', p_student_id;
  end if;

  perform app.log_audit_event('student_password_changed', 'students', p_student_id, null);
end;
$$;

comment on function app.set_student_password(uuid, text, text) is
  'Sets/resets a student''s password. Ownership-checked identically to the students table''s own UPDATE RLS policy. Audit-logged. MUST be called via an Edge Function that supplies the key from its environment secret — never directly from the Flutter client.';

grant execute on function app.set_student_password(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- app.view_student_password — teacher/admin-initiated plaintext reveal.
-- Ownership-checked and audit-logged on every VIEW, not just every change,
-- per the approved credential audit requirement.
-- ---------------------------------------------------------------------------
create or replace function app.view_student_password(
  p_student_id uuid,
  p_encryption_key text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_encrypted bytea;
  v_decrypted text;
begin
  if not (app.is_admin() or app.teacher_has_student(p_student_id)) then
    raise exception 'not authorized to view credentials for student %', p_student_id;
  end if;

  select password_encrypted into v_encrypted
  from public.students
  where id = p_student_id;

  if not found then
    raise exception 'student % not found', p_student_id;
  end if;

  v_decrypted := pgp_sym_decrypt(v_encrypted, p_encryption_key);

  perform app.log_audit_event('student_password_viewed', 'students', p_student_id, null);

  return v_decrypted;
end;
$$;

comment on function app.view_student_password(uuid, text) is
  'Reveals a student''s plaintext password to an authorized teacher/admin. Ownership-checked and audit-logged on every call. MUST be called via an Edge Function that supplies the key from its environment secret — never directly from the Flutter client.';

grant execute on function app.view_student_password(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- app.create_student — atomic student + enrollment creation.
--
-- Performs the students INSERT and the student_enrollments INSERT in one
-- transaction, so there is no window in which a student can exist without
-- an active enrollment (the approved "no unassigned student" rule) — fixing
-- the atomicity gap left by treating these as two independently-grantable
-- client inserts in the original Phase 3 delivery.
-- ---------------------------------------------------------------------------
create or replace function app.create_student(
  p_username        text,
  p_full_name       text,
  p_password        text,
  p_section_id      uuid,
  p_encryption_key  text,
  p_student_number  text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
begin
  if not (app.is_admin() or (app.is_approved_teacher() and app.teacher_has_section(p_section_id))) then
    raise exception 'not authorized to create a student in section %', p_section_id;
  end if;

  if p_password is null or length(p_password) < 4 then
    raise exception 'password does not meet the minimum length requirement';
  end if;

  insert into public.students (username, full_name, password_encrypted, student_number, created_by)
  values (p_username, p_full_name, pgp_sym_encrypt(p_password, p_encryption_key), p_student_number, auth.uid())
  returning id into v_student_id;

  insert into public.student_enrollments (student_id, section_id, status, enrolled_at)
  values (v_student_id, p_section_id, 'active', now());

  perform app.log_audit_event(
    'student_created',
    'students',
    v_student_id,
    jsonb_build_object('section_id', p_section_id)
  );

  return v_student_id;
end;
$$;

comment on function app.create_student(text, text, text, uuid, text, text) is
  'Atomically creates a student and their initial active enrollment in one transaction, inside the caller''s currently-assigned section only. Audit-logged. MUST be called via an Edge Function that supplies the key from its environment secret — never directly from the Flutter client.';

grant execute on function app.create_student(text, text, text, uuid, text, text) to authenticated;
