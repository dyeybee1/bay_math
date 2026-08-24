-- =============================================================================
-- Migration: 0013_helper_functions.sql
-- Supports: Phase 2 schema §7 (RLS Responsibility Mapping), §10/§3.20 (audit
-- logging: "written server-side... never via a direct client insert grant").
--
-- All functions live in the `app` schema (not exposed via the Supabase API —
-- see 0001). They are STABLE/SECURITY DEFINER as appropriate so RLS policies
-- can call them without re-querying the same lookups per row.
--
-- Revision (post-Phase-3 hardening audit): app.current_student_id() now has
-- a real implementation (JWT custom claim), and app.student_has_section()
-- was added to fix a critical recursive-RLS gap. See both functions' own
-- comments below and 0017_student_authentication.sql for the full mechanism.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Role lookups
-- ---------------------------------------------------------------------------
create or replace function app.current_profile_role()
returns profile_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function app.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and status = 'approved'
  );
$$;

create or replace function app.is_approved_teacher()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'teacher' and status = 'approved'
  );
$$;

comment on function app.is_admin() is
  'True iff the calling auth user is an approved Admin. Used by RLS policies across every table (schema §7: Admin = Full access).';
comment on function app.is_approved_teacher() is
  'True iff the calling auth user is an approved (non-pending, non-suspended) Teacher. Approval gating matches blueprint: "Cannot use the system until approved."';

-- ---------------------------------------------------------------------------
-- Section-scoping lookups (Teacher isolation — schema §7, §11.2)
-- ---------------------------------------------------------------------------
create or replace function app.teacher_has_section(p_section_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.teacher_sections
    where teacher_id = auth.uid() and section_id = p_section_id
  );
$$;

comment on function app.teacher_has_section(uuid) is
  'True iff the calling teacher is assigned to the given section (any row in teacher_sections, not just primary). Core building block for every Teacher RLS policy in this schema.';

create or replace function app.teacher_has_student(p_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.student_enrollments se
    join public.teacher_sections ts on ts.section_id = se.section_id
    where se.student_id = p_student_id
      and se.status = 'active'
      and ts.teacher_id = auth.uid()
  );
$$;

comment on function app.teacher_has_student(uuid) is
  'True iff the given student''s CURRENT active enrollment section is one the calling teacher is assigned to. Used to scope student/attempt/progress visibility to a teacher''s own sections only.';

-- ---------------------------------------------------------------------------
-- STUDENT AUTHENTICATION LINKAGE — RESOLVED.
--
-- Students are deliberately NOT rows in auth.users (no duplicate Auth
-- identities, no synthetic emails — see 0017_student_authentication.sql for
-- the full mechanism and rationale). Instead, a successful username/password
-- login (verified by app.verify_student_credentials in 0017, called only
-- from a trusted server-side context) results in a custom-signed JWT
-- containing a `student_id` claim and `role: authenticated`. That JWT is
-- used as the student's session token for all subsequent requests, exactly
-- like a normal Supabase Auth token, except Postgres never sees a matching
-- auth.users/profiles row for it.
--
-- This function reads that custom claim directly from the request's JWT
-- claims (the same mechanism auth.uid() uses internally to read `sub`).
-- For a Teacher/Admin session (a real Supabase Auth token), this claim is
-- simply absent, so the function correctly returns NULL — there is no risk
-- of a Teacher/Admin token being misread as a student session.
-- ---------------------------------------------------------------------------
create or replace function app.current_student_id()
returns uuid
language sql
stable
as $$
  select nullif(
    current_setting('request.jwt.claims', true)::jsonb ->> 'student_id',
    ''
  )::uuid;
$$;

comment on function app.current_student_id() is
  'Reads the student_id custom claim from the request JWT, minted at login by app.verify_student_credentials (0017). Returns NULL for any non-student session (Teacher/Admin tokens never carry this claim).';


-- ---------------------------------------------------------------------------
-- Section-scoping lookup for Students, mirroring app.teacher_has_section().
--
-- AUDIT FINDING (Severity: CRITICAL, fixed here): several student-facing RLS
-- policies in 0015 originally embedded a RAW subquery on student_enrollments
-- directly, instead of going through a SECURITY DEFINER helper. Because
-- student_enrollments had no student-visible SELECT policy, that raw
-- subquery silently returned zero rows for every student caller — meaning
-- students would never have been able to see ANY lesson or quiz content at
-- all, even with a fully working authentication mechanism. Postgres RLS
-- applies a table's own policies recursively to every subquery that touches
-- it, regardless of which other policy embeds the subquery; SECURITY
-- DEFINER functions are the standard way to intentionally break that
-- recursion for a narrow, trusted lookup — exactly the pattern already used
-- for the Teacher-side equivalents. This function, plus the corresponding
-- policy rewrites in 0015, close that gap.
-- ---------------------------------------------------------------------------
create or replace function app.student_has_section(p_section_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.student_enrollments
    where student_id = app.current_student_id()
      and section_id = p_section_id
      and status = 'active'
  );
$$;

comment on function app.student_has_section(uuid) is
  'True iff the currently authenticated student''s CURRENT active enrollment is the given section. SECURITY DEFINER to avoid recursive RLS on student_enrollments (see audit finding above).';

-- ---------------------------------------------------------------------------
-- Audit logging — the only sanctioned write path into audit_logs.
-- SECURITY DEFINER: runs with the privileges of the function owner, so it can
-- insert into audit_logs even though no role is granted direct INSERT there
-- (schema §3.20 / §10: "written server-side... never via a direct client
-- insert grant"). Callable by any authenticated role; the actor is always
-- taken from auth.uid()/the resolved profile role, never a caller-supplied
-- value, so a caller cannot forge another user's audit entry.
-- ---------------------------------------------------------------------------
create or replace function app.log_audit_event(
  p_action       text,
  p_target_table text,
  p_target_id    uuid,
  p_metadata     jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_role audit_actor_role;
  v_log_id uuid;
begin
  select case role
           when 'admin' then 'admin'::audit_actor_role
           when 'teacher' then 'teacher'::audit_actor_role
         end
    into v_actor_role
    from public.profiles
    where id = auth.uid();

  if v_actor_role is null then
    v_actor_role := 'system';
  end if;

  insert into public.audit_logs (actor_profile_id, actor_role, action, target_table, target_id, metadata)
  values (auth.uid(), v_actor_role, p_action, p_target_table, p_target_id, p_metadata)
  returning id into v_log_id;

  return v_log_id;
end;
$$;

comment on function app.log_audit_event(text, text, uuid, jsonb) is
  'The sole write path into audit_logs. Records: teacher approval/rejection, section/teacher (re)assignment, student account creation, credential view/change/print/export, quiz attempt reset, lesson/quiz edits or removals after student attempts exist, and any Admin action affecting another user''s access (schema §10).';

