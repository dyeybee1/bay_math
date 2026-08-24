-- =============================================================================
-- Migration: 0050_restore_student_auto_reenroll.sql
-- Redefines app.restore_student (originally 0048) so that restoring an
-- archived student automatically re-enrolls them into their most recent
-- section, instead of leaving the admin to re-enroll manually afterward.
--
-- NEW BUSINESS RULE:
-- Look at the student's single most recent student_enrollments row (by
-- enrolled_at desc, created_at desc as a tiebreaker — this is deliberately
-- the most recent row regardless of its own status, since archive_student
-- (0048) ends the active row rather than deleting it, so the "last" row is
-- normally the one archive_student itself just closed out):
--   - Last section still active  -> flip students.status back to 'active'
--     AND insert a brand-new student_enrollments row for that same section
--     (status = 'active', enrolled_at = now()). This satisfies the
--     "exactly one active enrollment per student" partial unique index from
--     0006 because the prior row for this student is not 'active' (either
--     archive_student already closed it, or it was never active to begin
--     with in the "no enrollment" case handled separately below).
--   - Last section archived, OR student has no enrollment row at all ->
--     restore is blocked outright with a human-readable exception, since
--     there is no sensible section to place them back into automatically.
--
-- This replaces 0048's version, whose comment on function explicitly said
-- restore does NOT create an enrollment — that is no longer accurate.
--
-- public.restore_student(uuid) (the PostgREST pass-through wrapper added in
-- 0048) is untouched: its signature and body just call app.restore_student,
-- so the new behavior below is picked up automatically with no wrapper
-- changes needed.
--
-- COLUMNS/CONSTRAINTS CONFIRMED FROM 0006_students_and_enrollments.sql:
--   - public.student_enrollments: id, student_id, section_id, status
--     (enrollment_status, default 'active'), enrolled_at (timestamptz,
--     default now()), ended_at (timestamptz, nullable), created_at,
--     updated_at (both timestamptz, default now()).
--   - Partial unique index student_enrollments_one_active_per_student on
--     (student_id) where status = 'active' — confirms at most one active
--     enrollment per student, which the insert below must not violate.
--   - public.sections.status uses the section_status enum with an 'active'
--     value, per lib/core/models/section.dart's SectionStatus mirror
--     (values: active, archived) — 0006 itself doesn't define `sections`
--     (created earlier, in 0005), so this Dart mirror is what confirms the
--     enum's naming/value here.
--
-- ASSUMPTIONS:
--   - "Most recent enrollment row" is taken as ORDER BY enrolled_at desc,
--     created_at desc LIMIT 1, with no additional filter on status, per the
--     task description ("regardless of its current status").
--   - Only section_id, status, and enrolled_at are set explicitly on the
--     new insert; id/created_at/updated_at all have defaults per 0006 and
--     are left to those defaults, consistent with how student_enrollments
--     is otherwise inserted into elsewhere in this codebase.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- app.restore_student — admin-only. See header comment above for the full
-- new rule. Redefined in full (CREATE OR REPLACE), not ALTERed, since the
-- body's control flow changes substantially from 0048's version.
-- ---------------------------------------------------------------------------
create or replace function app.restore_student(p_student_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_section_id     uuid;
  v_section_status section_status;
begin
  if not app.is_admin() then
    raise exception 'not authorized to restore student %', p_student_id;
  end if;

  if not exists (select 1 from public.students where id = p_student_id) then
    raise exception 'student % not found', p_student_id;
  end if;

  -- Most recent enrollment row for this student, regardless of its status —
  -- this is normally the row archive_student (0048) just closed out, but we
  -- deliberately don't filter on status here (see header comment).
  select section_id
  into v_section_id
  from public.student_enrollments
  where student_id = p_student_id
  order by enrolled_at desc, created_at desc
  limit 1;

  if v_section_id is null then
    raise exception
      'This student has no prior section on record and cannot be restored.';
  end if;

  select status
  into v_section_status
  from public.sections
  where id = v_section_id;

  if v_section_status is distinct from 'active' then
    raise exception
      'This student''s last section is no longer active. Restore is only allowed when the last section is still active.';
  end if;

  update public.students
  set status = 'active'
  where id = p_student_id;

  -- Re-enroll into the same section. Safe against
  -- student_enrollments_one_active_per_student (0006) because this
  -- student's prior rows are never 'active' at this point — archive_student
  -- always closed the last active one, and the no-enrollment case was
  -- already blocked above.
  insert into public.student_enrollments (student_id, section_id, status, enrolled_at)
  values (p_student_id, v_section_id, 'active', now());
end;
$$;

comment on function app.restore_student(uuid) is
  'Admin-only. Sets students.status = active and re-enrolls the student into their most recent section by creating a new student_enrollments row (status = active, enrolled_at = now()), provided that section is still active. Blocked with an exception if the student''s last section is archived or the student has no enrollment history at all. The status change is audit-logged via the audit_status_change trigger on students, action = student_status_changed.';
