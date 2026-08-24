-- =============================================================================
-- Migration: 0049_admin_teacher_profile_edits.sql
-- Adds two admin-only RPCs so Admin can correct a Teacher's `public.profiles`
-- record after creation: app.update_teacher_full_name and
-- app.update_teacher_email, each with a public-schema pass-through wrapper
-- (pattern established in 0020_public_rpc_wrappers_for_student_functions.sql)
-- and full audit logging via app.log_audit_event (0013).
--
-- SCOPE — public.profiles ONLY, never auth.users. Postgres/PostgREST cannot
-- reach the Supabase Auth (GoTrue) Admin API from SQL, so this migration
-- cannot and does not change the teacher's actual sign-in email. A later
-- Edge Function will call public.update_teacher_email(...) first (to update
-- the profiles row + get a clean, classifiable unique-violation error if the
-- new email is already taken by some other profile) and then separately call
-- the Auth Admin API to update auth.users.email to match. Until that Edge
-- Function exists, calling update_teacher_email alone will leave
-- profiles.email and auth.users.email out of sync — that's expected and
-- intentional for this migration, not a bug.
--
-- SCOPE — Teacher targets only, and only while active. Both functions require
-- the target row to have role = 'teacher' and status = 'approved'. This is
-- deliberate, not an oversight:
--   - role <> 'teacher' (e.g. an Admin profile) is out of scope for what is
--     framed as "Admin edits a Teacher's info" — there is no product surface
--     for Admin-editing-Admin here, and silently allowing it would let this
--     RPC be repurposed for something it wasn't designed or reviewed for.
--   - status <> 'approved' covers both 'pending' (not yet an active account —
--     edit the signup request instead, not a live profile) and 'archived'
--     (0048: archived accounts are intentionally frozen; resurrecting one via
--     a rename/email-change RPC would bypass the restore_teacher flow that
--     presumably exists, or will exist, alongside app.restore_student).
-- A single lookup does all three checks (existence, role, status) in one
-- query and one error message, rather than three separate round-trips/
-- messages, mirroring how app.archive_student (0048) treats "not found" as
-- the single failure mode for an invalid target.
--
-- AUDIT METADATA — both functions capture the OLD value with a `select ...
-- into` BEFORE the UPDATE (not via `old.*`, since these aren't triggers), so
-- the audit_logs row for each change records both from_ and to_ values in one
-- place, consistent with how 0014's trigger-based audit entries for status
-- changes record from_status/to_status.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1a. app.update_teacher_full_name — admin-only.
-- ---------------------------------------------------------------------------
create or replace function app.update_teacher_full_name(
  p_teacher_id uuid,
  p_full_name  text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_full_name   text;
  v_clean_full_name text;
begin
  if not app.is_admin() then
    raise exception 'not authorized to update teacher %', p_teacher_id;
  end if;

  -- Single lookup covers existence + role + active-status in one go — see
  -- header comment for why all three collapse into one exception.
  select full_name into v_old_full_name
  from public.profiles
  where id = p_teacher_id and role = 'teacher' and status = 'approved';

  if not found then
    raise exception 'teacher % not found or not active', p_teacher_id;
  end if;

  -- Explicit NULL check alongside the blank check: trim(NULL) = '' is NULL,
  -- not true, so a NULL p_full_name would otherwise silently slip past this
  -- guard and hit profiles.full_name's NOT NULL constraint instead of
  -- raising this friendly exception.
  if p_full_name is null or trim(p_full_name) = '' then
    raise exception 'full name is required';
  end if;

  v_clean_full_name := trim(p_full_name);

  update public.profiles
  set full_name = v_clean_full_name
  where id = p_teacher_id;

  perform app.log_audit_event(
    'teacher_full_name_changed',
    'profiles',
    p_teacher_id,
    jsonb_build_object('from_full_name', v_old_full_name, 'to_full_name', v_clean_full_name)
  );
end;
$$;

comment on function app.update_teacher_full_name(uuid, text) is
  'Admin-only. Updates profiles.full_name for an active (role=teacher, status=approved) teacher and audit-logs the change (action = teacher_full_name_changed, metadata carries from_full_name/to_full_name). Rejects a blank name. Does not touch auth.users.';

grant execute on function app.update_teacher_full_name(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 1b. app.update_teacher_email — admin-only.
--
-- The '@' check is a deliberately shallow sanity check, not real email
-- validation — see header/task framing: this is defense-in-depth only,
-- catching obvious typos/blank input before they hit the database, not the
-- source of truth for "is this a valid email." A genuinely malformed-but-
-- containing-'@' value is allowed through unchanged.
--
-- The unique-violation on public.profiles.email (0004: `email text not null
-- unique`) is intentionally NOT caught here. Letting it propagate as a raw
-- Postgres error (rather than swallowing it or pre-checking for a duplicate
-- ourselves, which would just be a race-prone version of the same check) is
-- deliberate: the future Edge Function described in the header comment is
-- expected to classify that specific error code (23505) itself, and doing
-- the classification here would just mean duplicating that logic in two
-- places.
-- ---------------------------------------------------------------------------
create or replace function app.update_teacher_email(
  p_teacher_id uuid,
  p_new_email  text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_email  text;
  v_clean_email text;
begin
  if not app.is_admin() then
    raise exception 'not authorized to update teacher %', p_teacher_id;
  end if;

  select email into v_old_email
  from public.profiles
  where id = p_teacher_id and role = 'teacher' and status = 'approved';

  if not found then
    raise exception 'teacher % not found or not active', p_teacher_id;
  end if;

  -- Explicit NULL check alongside the blank/'@' checks: trim(NULL) = '' and
  -- position('@' in NULL) = 0 both evaluate to NULL (not true), and
  -- NULL or NULL is still NULL — so a NULL p_new_email would otherwise
  -- silently slip past this guard and hit profiles.email's NOT NULL
  -- constraint instead of raising this friendly exception.
  if p_new_email is null or trim(p_new_email) = '' or position('@' in p_new_email) = 0 then
    raise exception 'a valid email is required';
  end if;

  v_clean_email := lower(trim(p_new_email));

  -- Let a unique-violation on profiles.email propagate uncaught — see
  -- function-level comment above.
  update public.profiles
  set email = v_clean_email
  where id = p_teacher_id;

  perform app.log_audit_event(
    'teacher_email_changed',
    'profiles',
    p_teacher_id,
    jsonb_build_object('from_email', v_old_email, 'to_email', v_clean_email)
  );
end;
$$;

comment on function app.update_teacher_email(uuid, text) is
  'Admin-only. Updates profiles.email for an active (role=teacher, status=approved) teacher (stored lower/trimmed) and audit-logs the change (action = teacher_email_changed, metadata carries from_email/to_email). Rejects blank input or anything without an "@" (shallow sanity check only). Does NOT touch auth.users — the actual sign-in email is updated separately by a future Edge Function via the Auth Admin API, which should call this RPC first and classify any resulting unique-violation itself, since it is left uncaught here.';

grant execute on function app.update_teacher_email(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Public-schema wrappers, matching the exact pass-through pattern
-- established in 0020_public_rpc_wrappers_for_student_functions.sql (plain
-- security invoker calls into the app-schema functions above; `app` is not
-- in PostgREST's exposed-schema list — see 0001 — so these are what makes
-- the functions reachable via POST /rest/v1/rpc/...).
-- ---------------------------------------------------------------------------
create or replace function public.update_teacher_full_name(p_teacher_id uuid, p_full_name text)
returns void
language sql
as $$
  select app.update_teacher_full_name(p_teacher_id, p_full_name);
$$;

comment on function public.update_teacher_full_name(uuid, text) is
  'Public-schema pass-through to app.update_teacher_full_name (this migration) so it is reachable via PostgREST — see 0020 header comment for why this pattern exists. No additional logic.';

grant execute on function public.update_teacher_full_name(uuid, text) to authenticated;

create or replace function public.update_teacher_email(p_teacher_id uuid, p_new_email text)
returns void
language sql
as $$
  select app.update_teacher_email(p_teacher_id, p_new_email);
$$;

comment on function public.update_teacher_email(uuid, text) is
  'Public-schema pass-through to app.update_teacher_email (this migration) so it is reachable via PostgREST — see 0020 header comment for why this pattern exists. No additional logic. Does not touch auth.users — see app.update_teacher_email''s comment for the full sign-in-email-sync plan.';

grant execute on function public.update_teacher_email(uuid, text) to authenticated;
