-- =============================================================================
-- Migration: 0020_public_rpc_wrappers_for_student_functions.sql
--
-- WHY THIS FILE EXISTS (read before assuming this duplicates 0017):
-- 0001_extensions_and_schema.sql creates the `app` schema explicitly so it
-- is NOT in PostgREST's exposed-schema list ("Supabase's PostgREST layer
-- only exposes schemas explicitly configured for API access (by default:
-- public, graphql_public) — `app` is intentionally left out of that list").
-- That means `app.create_student`, `app.set_student_password`,
-- `app.view_student_password`, and `app.verify_student_credentials` (all
-- defined in 0017_student_authentication.sql) are NOT reachable via
-- `POST /rest/v1/rpc/...` at all — not from the Flutter client (which is
-- correctly never supposed to call them directly, per 0017's own comment),
-- and not from a Supabase Edge Function either, since an Edge Function
-- using the standard supabase-js/supabase-dart client also talks to
-- PostgREST over that same HTTP API. 0016_grants.sql already anticipated
-- exactly this gap: "Helper functions in `app` (not API-exposed — see
-- 0001 — but still callable from within Postgres, e.g. a future
-- public-schema wrapper RPC in Phase 4)." This migration is that wrapper.
--
-- These wrappers add NO new logic and change NOTHING about 0017's
-- functions — each one is a single `select app.<same_function>(...)` call.
-- All authorization checks, encryption, and audit logging still happen
-- entirely inside the `app`-schema functions, unchanged. `security invoker`
-- (the default omitted below) is correct, not `security definer`: `auth.uid()`
-- resolves from the request's JWT claims (a per-request Postgres setting),
-- not from the definer/invoker mode of whichever function reads it, so a
-- plain pass-through wrapper preserves the caller's real identity exactly
-- as if the Edge Function had called `app.create_student` directly.
--
-- Grants mirror 0017 exactly: the three teacher/admin-initiated functions
-- are granted to `authenticated`; `verify_student_credentials` remains
-- revoked from every role except `service_role`.
-- =============================================================================

create or replace function public.create_student(
  p_username        text,
  p_full_name       text,
  p_password        text,
  p_section_id      uuid,
  p_encryption_key  text,
  p_student_number  text default null
)
returns uuid
language sql
as $$
  select app.create_student(p_username, p_full_name, p_password, p_section_id, p_encryption_key, p_student_number);
$$;

comment on function public.create_student(text, text, text, uuid, text, text) is
  'Public-schema pass-through to app.create_student (0017) so it is reachable via PostgREST/Edge Functions — see 0020 header comment. No additional logic.';

grant execute on function public.create_student(text, text, text, uuid, text, text) to authenticated;

create or replace function public.set_student_password(
  p_student_id      uuid,
  p_new_password    text,
  p_encryption_key  text
)
returns void
language sql
as $$
  select app.set_student_password(p_student_id, p_new_password, p_encryption_key);
$$;

comment on function public.set_student_password(uuid, text, text) is
  'Public-schema pass-through to app.set_student_password (0017) so it is reachable via PostgREST/Edge Functions — see 0020 header comment. No additional logic.';

grant execute on function public.set_student_password(uuid, text, text) to authenticated;

create or replace function public.view_student_password(
  p_student_id      uuid,
  p_encryption_key  text
)
returns text
language sql
as $$
  select app.view_student_password(p_student_id, p_encryption_key);
$$;

comment on function public.view_student_password(uuid, text) is
  'Public-schema pass-through to app.view_student_password (0017) so it is reachable via PostgREST/Edge Functions — see 0020 header comment. No additional logic.';

grant execute on function public.view_student_password(uuid, text) to authenticated;

create or replace function public.verify_student_credentials(
  p_username        text,
  p_password        text,
  p_encryption_key  text
)
returns uuid
language sql
as $$
  select app.verify_student_credentials(p_username, p_password, p_encryption_key);
$$;

comment on function public.verify_student_credentials(text, text, text) is
  'Public-schema pass-through to app.verify_student_credentials (0017) so it is reachable via PostgREST from the student-login Edge Function only — see 0020 header comment. Revoked from every role except service_role, exactly like the app-schema original.';

revoke all on function public.verify_student_credentials(text, text, text) from public, anon, authenticated;
grant execute on function public.verify_student_credentials(text, text, text) to service_role;
