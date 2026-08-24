-- =============================================================================
-- Migration: 0021_fix_pgcrypto_search_path.sql
--
-- BUG: app.create_student / app.set_student_password /
-- app.view_student_password / app.verify_student_credentials (0017) all
-- call pgp_sym_encrypt/pgp_sym_decrypt (from the pgcrypto extension)
-- unqualified, while each function's own `set search_path = public`
-- restricts name resolution to the public schema only. Supabase installs
-- pgcrypto into the `extensions` schema by default, not `public` — so
-- these functions fail at runtime with:
--   "function pgp_sym_encrypt(text, text) does not exist"
-- even though the extension is genuinely installed and 0001 ran
-- successfully (CREATE EXTENSION IF NOT EXISTS pgcrypto succeeds
-- regardless of which schema it lands in).
--
-- FIX: widen each function's search_path to include `extensions` as a
-- fallback after `public`. This does not change the "restrict search_path
-- for a SECURITY DEFINER function" security property these functions were
-- already going for — it only adds the one schema pgcrypto actually lives
-- in; `public` still resolves first for any name that exists in both.
-- Nothing else about these functions' logic, grants, or behavior changes.
-- =============================================================================

alter function app.verify_student_credentials(text, text, text)
  set search_path = public, extensions;

alter function app.create_student(text, text, text, uuid, text, text)
  set search_path = public, extensions;

alter function app.set_student_password(uuid, text, text)
  set search_path = public, extensions;

alter function app.view_student_password(uuid, text)
  set search_path = public, extensions;
