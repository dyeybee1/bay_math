-- =============================================================================
-- Migration: 0019_fix_profiles_self_registration_check.sql
--
-- BLOCKER FOUND DURING PHASE 1 IMPLEMENTATION, NOT AN ARCHITECTURE CHANGE:
--
-- profiles_admin_insert (0015) reads:
--   with check (app.is_admin() or id = auth.uid());
--     -- self-registration creates own row (role='teacher', status='pending')
--
-- The comment states the intended constraint but the CHECK expression never
-- enforced it — a self-registering user could insert role='admin',
-- status='approved' for their own id and grant themselves Admin access
-- immediately, bypassing the entire approval workflow. This migration makes
-- the CHECK expression actually enforce what the original comment already
-- claimed it did — a correctness fix to already-approved SQL, the same
-- category as the SECURITY DEFINER fix applied during Phase 0's final
-- review, not a redesign of the approval workflow itself.
--
-- OPERATIONAL NOTE: because Admin is a predefined account with no
-- self-registration path (per the frozen Blueprint), and this policy's
-- app.is_admin() branch requires an existing approved Admin row to already
-- exist, the very first Admin profile cannot be created through the app at
-- all under this policy — by design. It must be inserted once, out-of-band,
-- via the Supabase SQL editor/CLI against a real auth.users row created for
-- that purpose. This is a one-time bootstrap step, not a gap: every
-- subsequent Teacher/Admin profile change goes through the app normally.
-- =============================================================================

drop policy if exists profiles_admin_insert on public.profiles;

create policy profiles_admin_insert on public.profiles for insert
  with check (
    app.is_admin()
    or (id = auth.uid() and role = 'teacher' and status = 'pending')
  );

comment on policy profiles_admin_insert on public.profiles is
  'Admin may insert any profile. A self-registering user may only insert their own row, and only as role=teacher, status=pending — never admin, never pre-approved. Fixed 0019 (the original 0015 version documented this constraint in a comment but never enforced it in the CHECK expression).';
