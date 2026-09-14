begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(28);

insert into auth.users (id, email)
values
  ('95000000-0000-0000-0000-000000000001', 'archive-admin@baymath.test'),
  ('95000000-0000-0000-0000-000000000002', 'eligible-teacher@baymath.test'),
  ('95000000-0000-0000-0000-000000000003', 'owner-teacher@baymath.test'),
  ('95000000-0000-0000-0000-000000000004', 'active-teacher@baymath.test');

insert into public.profiles (id, role, status, full_name, email)
values
  (
    '95000000-0000-0000-0000-000000000001',
    'admin',
    'approved',
    'Archive Admin',
    'archive-admin@baymath.test'
  ),
  (
    '95000000-0000-0000-0000-000000000002',
    'teacher',
    'archived',
    'Eligible Teacher',
    'eligible-teacher@baymath.test'
  ),
  (
    '95000000-0000-0000-0000-000000000003',
    'teacher',
    'archived',
    'Owner Teacher',
    'owner-teacher@baymath.test'
  ),
  (
    '95000000-0000-0000-0000-000000000004',
    'teacher',
    'approved',
    'Active Teacher',
    'active-teacher@baymath.test'
  );

insert into public.schools (id, name)
values ('95000000-0000-0000-0000-000000001000', 'Archive Test School');

insert into public.school_years (
  id,
  school_id,
  label,
  start_date,
  end_date,
  is_current
)
values (
  '95000000-0000-0000-0000-000000001001',
  '95000000-0000-0000-0000-000000001000',
  '2095-2096',
  '2095-06-01',
  '2096-04-01',
  false
);

insert into public.sections (id, school_year_id, grade_level, name, status)
values
  (
    '95000000-0000-0000-0000-000000002001',
    '95000000-0000-0000-0000-000000001001',
    'grade_4',
    'Active Safety',
    'active'
  ),
  (
    '95000000-0000-0000-0000-000000002002',
    '95000000-0000-0000-0000-000000001001',
    'grade_5',
    'Archived Clear',
    'archived'
  ),
  (
    '95000000-0000-0000-0000-000000002003',
    '95000000-0000-0000-0000-000000001001',
    'grade_6',
    'Archived Enrollment History',
    'archived'
  ),
  (
    '95000000-0000-0000-0000-000000002004',
    '95000000-0000-0000-0000-000000001001',
    'grade_6',
    'Archived Quiz History',
    'archived'
  ),
  (
    '95000000-0000-0000-0000-000000002005',
    '95000000-0000-0000-0000-000000001001',
    'grade_4',
    'Unrelated Section',
    'active'
  );

insert into public.teacher_sections (
  teacher_id,
  section_id,
  is_primary,
  assigned_by
)
values
  (
    '95000000-0000-0000-0000-000000000002',
    '95000000-0000-0000-0000-000000002002',
    true,
    '95000000-0000-0000-0000-000000000001'
  ),
  (
    '95000000-0000-0000-0000-000000000002',
    '95000000-0000-0000-0000-000000002005',
    true,
    '95000000-0000-0000-0000-000000000001'
  );

insert into public.students (
  id,
  username,
  password_encrypted,
  full_name,
  created_by,
  status
)
values
  (
    '95000000-0000-0000-0000-000000003001',
    'archive_history_student',
    decode('00', 'hex'),
    'History Student',
    '95000000-0000-0000-0000-000000000003',
    'active'
  ),
  (
    '95000000-0000-0000-0000-000000003002',
    'archive_delete_student',
    decode('00', 'hex'),
    'Delete Student',
    '95000000-0000-0000-0000-000000000001',
    'archived'
  ),
  (
    '95000000-0000-0000-0000-000000003003',
    'archive_active_student',
    decode('00', 'hex'),
    'Active Student',
    '95000000-0000-0000-0000-000000000001',
    'active'
  );

insert into public.student_enrollments (student_id, section_id, status, ended_at)
values
  (
    '95000000-0000-0000-0000-000000003001',
    '95000000-0000-0000-0000-000000002003',
    'active',
    null
  ),
  (
    '95000000-0000-0000-0000-000000003002',
    '95000000-0000-0000-0000-000000002005',
    'archived',
    now()
  ),
  (
    '95000000-0000-0000-0000-000000003003',
    '95000000-0000-0000-0000-000000002005',
    'active',
    null
  );

insert into public.lessons (
  id,
  title,
  body,
  source_type,
  created_by,
  grade_level
)
values (
  '95000000-0000-0000-0000-000000004001',
  'Archive Test Lesson',
  'Archive test lesson body',
  'built_in',
  null,
  'grade_4'
);

insert into public.lessons (
  id,
  title,
  body,
  source_type,
  created_by,
  grade_level
)
values (
  '95000000-0000-0000-0000-000000004002',
  'Archive Test Assigned Lesson',
  'Assigned lesson body',
  'teacher',
  '95000000-0000-0000-0000-000000000003',
  null
);

insert into public.lesson_sections (lesson_id, section_id, assigned_by)
values (
  '95000000-0000-0000-0000-000000004002',
  '95000000-0000-0000-0000-000000002002',
  '95000000-0000-0000-0000-000000000001'
);

insert into public.lesson_progress (student_id, lesson_id, status)
values (
  '95000000-0000-0000-0000-000000003002',
  '95000000-0000-0000-0000-000000004001',
  'completed'
);

insert into public.quizzes (
  id,
  title,
  quiz_type,
  source_type,
  created_by,
  grade_level,
  assessment_type
)
values (
  '95000000-0000-0000-0000-000000005001',
  'Archive Test Quiz',
  'internal',
  'built_in',
  null,
  'grade_4',
  null
);

insert into public.quizzes (
  id,
  title,
  quiz_type,
  source_type,
  created_by,
  grade_level,
  assessment_type
)
values (
  '95000000-0000-0000-0000-000000005002',
  'Archive Test Assigned Quiz',
  'internal',
  'teacher',
  '95000000-0000-0000-0000-000000000003',
  null,
  null
);

insert into public.quiz_sections (quiz_id, section_id, assigned_by)
values (
  '95000000-0000-0000-0000-000000005002',
  '95000000-0000-0000-0000-000000002002',
  '95000000-0000-0000-0000-000000000001'
);

insert into public.quiz_attempts (
  id,
  student_id,
  quiz_id,
  section_id,
  school_year_id,
  attempt_status,
  total_questions,
  score,
  submitted_at
)
values
  (
    '95000000-0000-0000-0000-000000006001',
    '95000000-0000-0000-0000-000000003001',
    '95000000-0000-0000-0000-000000005001',
    '95000000-0000-0000-0000-000000002004',
    '95000000-0000-0000-0000-000000001001',
    'active',
    1,
    1,
    now()
  ),
  (
    '95000000-0000-0000-0000-000000006002',
    '95000000-0000-0000-0000-000000003002',
    '95000000-0000-0000-0000-000000005001',
    '95000000-0000-0000-0000-000000002005',
    '95000000-0000-0000-0000-000000001001',
    'active',
    1,
    0,
    now()
  );

insert into public.endless_quiz_sessions (
  student_id,
  started_at,
  ended_at,
  questions_answered,
  best_streak_session
)
values (
  '95000000-0000-0000-0000-000000003002',
  now() - interval '5 minutes',
  now(),
  4,
  2
);

select set_config(
  'request.jwt.claim.sub',
  '95000000-0000-0000-0000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"95000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  public.delete_archived_section('95000000-0000-0000-0000-000000002001'),
  'not_archived',
  'An active section cannot be permanently deleted'
);
select is(
  public.delete_archived_section('95000000-0000-0000-0000-000000002003'),
  'has_student_history',
  'An archived section with enrollment history is preserved'
);
select is(
  public.delete_archived_section('95000000-0000-0000-0000-000000002004'),
  'has_quiz_history',
  'An archived section with quiz-attempt history is preserved'
);
select is(
  public.delete_archived_section('95000000-0000-0000-0000-000000002002'),
  'deleted',
  'A clear archived section can be permanently deleted'
);
select is(
  (select count(*) from public.sections where id = '95000000-0000-0000-0000-000000002002'),
  0::bigint,
  'The eligible section is removed'
);
select is(
  (select count(*) from public.teacher_sections where section_id = '95000000-0000-0000-0000-000000002002'),
  0::bigint,
  'Pure Teacher assignment rows are removed with the section'
);
select is(
  (select count(*) from public.lesson_sections where section_id = '95000000-0000-0000-0000-000000002002'),
  0::bigint,
  'Lesson visibility mappings are removed with the section'
);
select is(
  (select count(*) from public.quiz_sections where section_id = '95000000-0000-0000-0000-000000002002'),
  0::bigint,
  'Quiz visibility mappings are removed with the section'
);
select is(
  (select count(*) from public.lessons where id = '95000000-0000-0000-0000-000000004002'),
  1::bigint,
  'Removing a Section mapping does not delete its learning content'
);
select is(
  (select count(*) from public.quizzes where id = '95000000-0000-0000-0000-000000005002'),
  1::bigint,
  'Removing a Section mapping does not delete its quiz content'
);
select is(
  (select count(*) from public.sections where id = '95000000-0000-0000-0000-000000002005'),
  1::bigint,
  'An unrelated section remains untouched'
);

select is(
  public.delete_archived_student('95000000-0000-0000-0000-000000003003'),
  'not_archived',
  'An active Student cannot be permanently deleted'
);
select is(
  public.delete_archived_student('95000000-0000-0000-0000-000000003002'),
  'deleted',
  'An archived custom Student can be permanently deleted'
);
select is(
  (select count(*) from public.students where id = '95000000-0000-0000-0000-000000003002'),
  0::bigint,
  'The target Student identity is removed'
);
select is(
  (select count(*) from public.student_enrollments where student_id = '95000000-0000-0000-0000-000000003002'),
  0::bigint,
  'The target Student enrollments are removed'
);
select is(
  (select count(*) from public.lesson_progress where student_id = '95000000-0000-0000-0000-000000003002'),
  0::bigint,
  'The target Student lesson progress is removed'
);
select is(
  (select count(*) from public.quiz_attempts where student_id = '95000000-0000-0000-0000-000000003002'),
  0::bigint,
  'The target Student quiz results are removed'
);
select is(
  (select count(*) from public.endless_quiz_sessions where student_id = '95000000-0000-0000-0000-000000003002'),
  0::bigint,
  'The target Student endless-quiz sessions are removed'
);
select is(
  (select count(*) from public.students where id = '95000000-0000-0000-0000-000000003003'),
  1::bigint,
  'An unrelated Student remains untouched'
);

select is(
  public.teacher_account_delete_eligibility('95000000-0000-0000-0000-000000000001'),
  'not_teacher',
  'An Admin account is never eligible for the Teacher deletion path'
);
select is(
  public.teacher_account_delete_eligibility('95000000-0000-0000-0000-000000000004'),
  'not_archived',
  'An active Teacher cannot be permanently deleted'
);
select is(
  public.teacher_account_delete_eligibility('95000000-0000-0000-0000-000000000003'),
  'has_students',
  'A Teacher owning Student records is blocked'
);
select is(
  public.teacher_account_delete_eligibility('95000000-0000-0000-0000-000000000002'),
  'eligible',
  'An archived Teacher with only assignments is eligible'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '95000000-0000-0000-0000-000000000004',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"95000000-0000-0000-0000-000000000004","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  public.delete_archived_section('95000000-0000-0000-0000-000000002003'),
  'not_authorized',
  'A non-Admin cannot permanently delete a section'
);
select is(
  public.delete_archived_student('95000000-0000-0000-0000-000000003001'),
  'not_authorized',
  'A non-Admin cannot permanently delete a Student'
);
select is(
  public.teacher_account_delete_eligibility('95000000-0000-0000-0000-000000000002'),
  'not_authorized',
  'A non-Admin cannot authorize Teacher deletion'
);

reset role;

delete from auth.users
where id = '95000000-0000-0000-0000-000000000002';

select is(
  (select count(*) from public.profiles where id = '95000000-0000-0000-0000-000000000002'),
  0::bigint,
  'Supported Auth deletion cascades to the eligible Teacher profile'
);
select is(
  (select count(*) from public.teacher_sections where teacher_id = '95000000-0000-0000-0000-000000000002'),
  0::bigint,
  'The narrow Teacher assignment cascade does not block Auth deletion'
);

select * from finish();
rollback;
