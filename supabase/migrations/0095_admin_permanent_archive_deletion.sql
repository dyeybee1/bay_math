-- =============================================================================
-- Admin permanent deletion for archived Sections, Students, and Teachers.
--
-- Safety rules:
--   * every entry point verifies app.is_admin();
--   * active records are never eligible;
--   * Sections with enrollment or quiz-attempt history are preserved;
--   * Student deletion removes only that Student's dependent rows, atomically;
--   * Teacher Auth deletion remains in the delete-teacher-account Edge
--     Function. This migration only performs an eligibility preflight and
--     changes the pure teacher_sections assignment FK to a narrow cascade.
-- =============================================================================

-- A Teacher-to-Section assignment has no meaning after the Teacher identity is
-- permanently deleted. Cascading this one relationship lets GoTrue's supported
-- Auth Admin deletion remove an otherwise-eligible profile atomically. Durable
-- authored content and created Students keep their existing RESTRICT FKs.
alter table public.teacher_sections
  drop constraint teacher_sections_teacher_id_fkey;

alter table public.teacher_sections
  add constraint teacher_sections_teacher_id_fkey
  foreign key (teacher_id)
  references public.profiles (id)
  on delete cascade
  on update cascade;

create or replace function app.delete_archived_section(p_section_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status section_status;
begin
  if not app.is_admin() then
    return 'not_authorized';
  end if;

  select status into v_status
  from public.sections
  where id = p_section_id
  for update;

  if not found then
    return 'not_found';
  end if;
  if v_status <> 'archived' then
    return 'not_archived';
  end if;

  if exists (
    select 1 from public.student_enrollments
    where section_id = p_section_id
  ) then
    return 'has_student_history';
  end if;

  if exists (
    select 1 from public.quiz_attempts
    where section_id = p_section_id
  ) then
    return 'has_quiz_history';
  end if;

  -- These are reversible assignment/visibility rows, not learning history.
  delete from public.teacher_sections where section_id = p_section_id;
  delete from public.lesson_sections where section_id = p_section_id;
  delete from public.quiz_sections where section_id = p_section_id;
  delete from public.sections where id = p_section_id;

  perform app.log_audit_event(
    'section_permanently_deleted',
    'sections',
    p_section_id,
    jsonb_build_object('previous_status', 'archived')
  );
  return 'deleted';
end;
$$;

create or replace function public.delete_archived_section(p_section_id uuid)
returns text
language sql
as $$
  select app.delete_archived_section(p_section_id);
$$;

revoke all on function app.delete_archived_section(uuid) from public, anon;
revoke all on function public.delete_archived_section(uuid) from public, anon;
grant execute on function app.delete_archived_section(uuid) to authenticated;
grant execute on function public.delete_archived_section(uuid) to authenticated;

comment on function public.delete_archived_section(uuid) is
  'Admin-only permanent delete for an archived section. Blocks when enrollment or quiz-attempt history exists; otherwise removes assignment rows and the section atomically.';

create or replace function app.delete_archived_student(p_student_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status student_status;
begin
  if not app.is_admin() then
    return 'not_authorized';
  end if;

  select status into v_status
  from public.students
  where id = p_student_id
  for update;

  if not found then
    return 'not_found';
  end if;
  if v_status <> 'archived' then
    return 'not_archived';
  end if;

  -- Attempts cascade to answers and answer-choice snapshots through the
  -- existing purpose-built child FKs. Every other dependency is explicit.
  delete from public.lesson_progress where student_id = p_student_id;
  delete from public.endless_quiz_sessions where student_id = p_student_id;
  delete from public.quiz_attempts where student_id = p_student_id;
  delete from public.student_enrollments where student_id = p_student_id;
  delete from public.students where id = p_student_id;

  perform app.log_audit_event(
    'student_account_permanently_deleted',
    'students',
    p_student_id,
    jsonb_build_object('previous_status', 'archived')
  );
  return 'deleted';
end;
$$;

create or replace function public.delete_archived_student(p_student_id uuid)
returns text
language sql
as $$
  select app.delete_archived_student(p_student_id);
$$;

revoke all on function app.delete_archived_student(uuid) from public, anon;
revoke all on function public.delete_archived_student(uuid) from public, anon;
grant execute on function app.delete_archived_student(uuid) to authenticated;
grant execute on function public.delete_archived_student(uuid) to authenticated;

comment on function public.delete_archived_student(uuid) is
  'Admin-only atomic permanent deletion of an archived custom Student identity and its enrollments, lesson progress, quiz attempts/results, and endless-quiz sessions.';

create or replace function app.teacher_account_delete_eligibility(
  p_teacher_id uuid
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role profile_role;
  v_status profile_status;
begin
  if not app.is_admin() then
    return 'not_authorized';
  end if;

  select role, status into v_role, v_status
  from public.profiles
  where id = p_teacher_id;

  if not found then
    return 'not_found';
  end if;
  if v_role <> 'teacher' then
    return 'not_teacher';
  end if;
  if v_status <> 'archived' then
    return 'not_archived';
  end if;
  if exists (select 1 from public.students where created_by = p_teacher_id) then
    return 'has_students';
  end if;
  if exists (select 1 from public.lessons where created_by = p_teacher_id) then
    return 'has_lessons';
  end if;
  if exists (select 1 from public.quizzes where created_by = p_teacher_id) then
    return 'has_quizzes';
  end if;
  if exists (
    select 1 from public.question_bank where created_by = p_teacher_id
  ) then
    return 'has_questions';
  end if;

  return 'eligible';
end;
$$;

create or replace function public.teacher_account_delete_eligibility(
  p_teacher_id uuid
)
returns text
language sql
as $$
  select app.teacher_account_delete_eligibility(p_teacher_id);
$$;

revoke all on function app.teacher_account_delete_eligibility(uuid)
  from public, anon;
revoke all on function public.teacher_account_delete_eligibility(uuid)
  from public, anon;
grant execute on function app.teacher_account_delete_eligibility(uuid)
  to authenticated;
grant execute on function public.teacher_account_delete_eligibility(uuid)
  to authenticated;

comment on function public.teacher_account_delete_eligibility(uuid) is
  'Admin-only preflight used by delete-teacher-account before invoking the Supabase Auth Admin API. Only archived Teacher profiles with no authored content, question-bank content, or created Students are eligible.';

create or replace function app.record_teacher_account_permanent_delete(
  p_teacher_id uuid
)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if not app.is_admin() then
    return 'not_authorized';
  end if;

  perform app.log_audit_event(
    'teacher_account_permanently_deleted',
    'profiles',
    p_teacher_id,
    jsonb_build_object('auth_identity_deleted', true)
  );
  return 'recorded';
end;
$$;

create or replace function public.record_teacher_account_permanent_delete(
  p_teacher_id uuid
)
returns text
language sql
as $$
  select app.record_teacher_account_permanent_delete(p_teacher_id);
$$;

revoke all on function app.record_teacher_account_permanent_delete(uuid)
  from public, anon;
revoke all on function public.record_teacher_account_permanent_delete(uuid)
  from public, anon;
grant execute on function app.record_teacher_account_permanent_delete(uuid)
  to authenticated;
grant execute on function public.record_teacher_account_permanent_delete(uuid)
  to authenticated;
