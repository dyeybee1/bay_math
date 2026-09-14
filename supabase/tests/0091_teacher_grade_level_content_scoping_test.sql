begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(28);

-- Stable, transaction-local fixtures. Every catalog assertion is restricted
-- to the rls_test_ prefix so normal seed content cannot affect the results.
insert into auth.users (id, email)
values
  ('91000000-0000-0000-0000-000000000001', 'rls-admin@baymath.test'),
  ('91000000-0000-0000-0000-000000000004', 'rls-grade4@baymath.test'),
  ('91000000-0000-0000-0000-000000000005', 'rls-grade5@baymath.test'),
  ('91000000-0000-0000-0000-000000000006', 'rls-grade6@baymath.test'),
  ('91000000-0000-0000-0000-000000000045', 'rls-multigrade@baymath.test'),
  ('91000000-0000-0000-0000-000000000099', 'rls-no-sections@baymath.test'),
  ('91000000-0000-0000-0000-000000000777', 'rls-other-teacher@baymath.test');

insert into public.profiles (id, role, status, full_name, email)
values
  (
    '91000000-0000-0000-0000-000000000001',
    'admin',
    'approved',
    'RLS Admin',
    'rls-admin@baymath.test'
  ),
  (
    '91000000-0000-0000-0000-000000000004',
    'teacher',
    'approved',
    'Grade Four Teacher',
    'rls-grade4@baymath.test'
  ),
  (
    '91000000-0000-0000-0000-000000000005',
    'teacher',
    'approved',
    'Grade Five Teacher',
    'rls-grade5@baymath.test'
  ),
  (
    '91000000-0000-0000-0000-000000000006',
    'teacher',
    'approved',
    'Grade Six Teacher',
    'rls-grade6@baymath.test'
  ),
  (
    '91000000-0000-0000-0000-000000000045',
    'teacher',
    'approved',
    'Multi Grade Teacher',
    'rls-multigrade@baymath.test'
  ),
  (
    '91000000-0000-0000-0000-000000000099',
    'teacher',
    'approved',
    'No Sections Teacher',
    'rls-no-sections@baymath.test'
  ),
  (
    '91000000-0000-0000-0000-000000000777',
    'teacher',
    'approved',
    'Other Teacher',
    'rls-other-teacher@baymath.test'
  );

insert into public.schools (id, name)
values ('91000000-0000-0000-0000-000000001000', 'RLS Test School');

insert into public.school_years (
  id,
  school_id,
  label,
  start_date,
  end_date,
  is_current
)
values (
  '91000000-0000-0000-0000-000000001001',
  '91000000-0000-0000-0000-000000001000',
  'RLS Test Year',
  '2090-06-01',
  '2091-04-01',
  false
);

insert into public.sections (id, school_year_id, grade_level, name)
values
  (
    '91000000-0000-0000-0000-000000004001',
    '91000000-0000-0000-0000-000000001001',
    'grade_4',
    'RLS Grade 4 A'
  ),
  (
    '91000000-0000-0000-0000-000000004002',
    '91000000-0000-0000-0000-000000001001',
    'grade_4',
    'RLS Grade 4 B'
  ),
  (
    '91000000-0000-0000-0000-000000005001',
    '91000000-0000-0000-0000-000000001001',
    'grade_5',
    'RLS Grade 5 A'
  ),
  (
    '91000000-0000-0000-0000-000000006001',
    '91000000-0000-0000-0000-000000001001',
    'grade_6',
    'RLS Grade 6 A'
  );

insert into public.teacher_sections (
  teacher_id,
  section_id,
  is_primary,
  assigned_by
)
values
  (
    '91000000-0000-0000-0000-000000000004',
    '91000000-0000-0000-0000-000000004001',
    false,
    '91000000-0000-0000-0000-000000000001'
  ),
  (
    '91000000-0000-0000-0000-000000000004',
    '91000000-0000-0000-0000-000000004002',
    false,
    '91000000-0000-0000-0000-000000000001'
  ),
  (
    '91000000-0000-0000-0000-000000000005',
    '91000000-0000-0000-0000-000000005001',
    false,
    '91000000-0000-0000-0000-000000000001'
  ),
  (
    '91000000-0000-0000-0000-000000000006',
    '91000000-0000-0000-0000-000000006001',
    false,
    '91000000-0000-0000-0000-000000000001'
  ),
  (
    '91000000-0000-0000-0000-000000000045',
    '91000000-0000-0000-0000-000000004001',
    false,
    '91000000-0000-0000-0000-000000000001'
  ),
  (
    '91000000-0000-0000-0000-000000000045',
    '91000000-0000-0000-0000-000000005001',
    false,
    '91000000-0000-0000-0000-000000000001'
  ),
  (
    '91000000-0000-0000-0000-000000000777',
    '91000000-0000-0000-0000-000000006001',
    false,
    '91000000-0000-0000-0000-000000000001'
  );

insert into public.lessons (
  id,
  title,
  body,
  source_type,
  created_by,
  grade_level
)
values
  (
    '91000000-0000-0000-0000-000000014001',
    'rls_test_lesson_grade_4',
    'Grade 4 lesson',
    'built_in',
    null,
    'grade_4'
  ),
  (
    '91000000-0000-0000-0000-000000015001',
    'rls_test_lesson_grade_5',
    'Grade 5 lesson',
    'built_in',
    null,
    'grade_5'
  ),
  (
    '91000000-0000-0000-0000-000000016001',
    'rls_test_lesson_grade_6',
    'Grade 6 lesson',
    'built_in',
    null,
    'grade_6'
  ),
  (
    '91000000-0000-0000-0000-000000014101',
    'rls_test_lesson_owned',
    'Owned custom lesson',
    'teacher',
    '91000000-0000-0000-0000-000000000004',
    null
  ),
  (
    '91000000-0000-0000-0000-000000016101',
    'rls_test_lesson_other_teacher',
    'Another Teacher custom lesson',
    'teacher',
    '91000000-0000-0000-0000-000000000777',
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
values
  (
    '91000000-0000-0000-0000-000000024001',
    'rls_test_quiz_grade_4_regular',
    'internal',
    'built_in',
    null,
    'grade_4',
    null
  ),
  (
    '91000000-0000-0000-0000-000000024002',
    'rls_test_quiz_grade_4_pre_test',
    'internal',
    'built_in',
    null,
    'grade_4',
    'pre_test'
  ),
  (
    '91000000-0000-0000-0000-000000024003',
    'rls_test_quiz_grade_4_post_test',
    'internal',
    'built_in',
    null,
    'grade_4',
    'post_test'
  ),
  (
    '91000000-0000-0000-0000-000000025001',
    'rls_test_quiz_grade_5',
    'internal',
    'built_in',
    null,
    'grade_5',
    null
  ),
  (
    '91000000-0000-0000-0000-000000026001',
    'rls_test_quiz_grade_6',
    'internal',
    'built_in',
    null,
    'grade_6',
    null
  ),
  (
    '91000000-0000-0000-0000-000000024101',
    'rls_test_quiz_owned',
    'internal',
    'teacher',
    '91000000-0000-0000-0000-000000000004',
    null,
    null
  ),
  (
    '91000000-0000-0000-0000-000000026101',
    'rls_test_quiz_other_teacher',
    'internal',
    'teacher',
    '91000000-0000-0000-0000-000000000777',
    null,
    null
  );

insert into public.lesson_sections (lesson_id, section_id, assigned_by)
values (
  '91000000-0000-0000-0000-000000014101',
  '91000000-0000-0000-0000-000000004001',
  '91000000-0000-0000-0000-000000000004'
);

insert into public.quiz_sections (quiz_id, section_id, assigned_by)
values (
  '91000000-0000-0000-0000-000000024101',
  '91000000-0000-0000-0000-000000004001',
  '91000000-0000-0000-0000-000000000004'
);

insert into public.students (
  id,
  username,
  password_encrypted,
  full_name,
  created_by
)
values (
  '91000000-0000-0000-0000-000000030001',
  'rls_test_student',
  decode('00', 'hex'),
  'RLS Test Student',
  '91000000-0000-0000-0000-000000000004'
);

insert into public.student_enrollments (student_id, section_id, status)
values (
  '91000000-0000-0000-0000-000000030001',
  '91000000-0000-0000-0000-000000004001',
  'active'
);

-- Grade 4-only Teacher (also assigned twice within Grade 4).
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000004',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"91000000-0000-0000-0000-000000000004","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (
    select string_agg(distinct grade_level::text, ',' order by grade_level::text)
    from public.lessons
    where title like 'rls_test_lesson_grade_%'
  ),
  'grade_4',
  'Grade 4 Teacher sees only Grade 4 built-in lessons'
);
select is(
  (
    select string_agg(distinct grade_level::text, ',' order by grade_level::text)
    from public.quizzes
    where title like 'rls_test_quiz_grade_%'
  ),
  'grade_4',
  'Grade 4 Teacher sees only Grade 4 built-in quizzes'
);
select is(
  (
    select count(*)
    from public.lessons
    where title = 'rls_test_lesson_grade_4'
  ),
  1::bigint,
  'Two Grade 4 section assignments do not duplicate one lesson'
);
select is(
  (
    select count(*)
    from public.quizzes
    where title like 'rls_test_quiz_grade_4_%'
  ),
  3::bigint,
  'Two Grade 4 section assignments do not duplicate quizzes'
);
select is(
  (
    select count(*)
    from public.lessons
    where title like 'rls_test_lesson_%'
  ),
  2::bigint,
  'All lessons contains allowed built-in content plus the Teacher own lesson'
);
select is(
  (
    select count(*)
    from public.lessons
    where title like 'rls_test_lesson_%'
      and source_type = 'built_in'
  ),
  1::bigint,
  'Built-in lesson filter operates on the scoped dataset'
);
select is(
  (
    select count(*)
    from public.lessons
    where title like 'rls_test_lesson_%'
      and source_type = 'teacher'
  ),
  1::bigint,
  'My lessons filter operates on the scoped owner-only dataset'
);
select is(
  (
    select count(*)
    from public.lessons
    where title = 'rls_test_lesson_owned'
  ),
  1::bigint,
  'Teacher can still read their own custom lesson'
);
select is(
  (
    select count(*)
    from public.lessons
    where title = 'rls_test_lesson_other_teacher'
  ),
  0::bigint,
  'Teacher cannot read another Teacher custom lesson'
);
select is(
  (
    select count(*)
    from public.quizzes
    where title = 'rls_test_quiz_owned'
  ),
  1::bigint,
  'Teacher can still read their own custom quiz'
);
select is(
  (
    select count(*)
    from public.quizzes
    where title = 'rls_test_quiz_other_teacher'
  ),
  0::bigint,
  'Teacher cannot read another Teacher custom quiz'
);
select is(
  (
    select string_agg(
      coalesce(assessment_type::text, 'regular'),
      ','
      order by coalesce(assessment_type::text, 'regular')
    )
    from public.quizzes
    where title like 'rls_test_quiz_grade_4_%'
  ),
  'post_test,pre_test,regular',
  'Grade scoping preserves regular, pre-test, and post-test quizzes'
);

reset role;

-- Grade 5-only Teacher.
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000005',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"91000000-0000-0000-0000-000000000005","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (
    select string_agg(distinct grade_level::text, ',' order by grade_level::text)
    from public.lessons
    where title like 'rls_test_lesson_grade_%'
  ),
  'grade_5',
  'Grade 5 Teacher sees only Grade 5 built-in lessons'
);
select is(
  (
    select string_agg(distinct grade_level::text, ',' order by grade_level::text)
    from public.quizzes
    where title like 'rls_test_quiz_grade_%'
  ),
  'grade_5',
  'Grade 5 Teacher sees only Grade 5 built-in quizzes'
);

reset role;

-- Grade 6-only Teacher.
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000006',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"91000000-0000-0000-0000-000000000006","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (
    select string_agg(distinct grade_level::text, ',' order by grade_level::text)
    from public.lessons
    where title like 'rls_test_lesson_grade_%'
  ),
  'grade_6',
  'Grade 6 Teacher sees only Grade 6 built-in lessons'
);
select is(
  (
    select string_agg(distinct grade_level::text, ',' order by grade_level::text)
    from public.quizzes
    where title like 'rls_test_quiz_grade_%'
  ),
  'grade_6',
  'Grade 6 Teacher sees only Grade 6 built-in quizzes'
);

reset role;

-- Multi-grade Teacher.
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000045',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"91000000-0000-0000-0000-000000000045","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (
    select string_agg(distinct grade_level::text, ',' order by grade_level::text)
    from public.lessons
    where title like 'rls_test_lesson_grade_%'
  ),
  'grade_4,grade_5',
  'Multi-grade Teacher sees Grade 4 and Grade 5 lessons'
);
select is(
  (
    select count(*)
    from public.lessons
    where title = 'rls_test_lesson_grade_6'
  ),
  0::bigint,
  'Multi-grade Teacher cannot see Grade 6 lessons'
);
select is(
  (
    select string_agg(distinct grade_level::text, ',' order by grade_level::text)
    from public.quizzes
    where title like 'rls_test_quiz_grade_%'
  ),
  'grade_4,grade_5',
  'Multi-grade Teacher sees Grade 4 and Grade 5 quizzes'
);
select is(
  (
    select count(*)
    from public.quizzes
    where title = 'rls_test_quiz_grade_6'
  ),
  0::bigint,
  'Multi-grade Teacher cannot see Grade 6 quizzes'
);

reset role;

-- Approved Teacher with no teacher_sections rows.
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000099',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"91000000-0000-0000-0000-000000000099","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (
    select count(*)
    from public.lessons
    where title like 'rls_test_lesson_grade_%'
  ),
  0::bigint,
  'Teacher with no sections receives no built-in lessons'
);
select is(
  (
    select count(*)
    from public.quizzes
    where title like 'rls_test_quiz_grade_%'
  ),
  0::bigint,
  'Teacher with no sections receives no built-in quizzes'
);

reset role;

-- Admin remains intentionally broad.
select set_config(
  'request.jwt.claim.sub',
  '91000000-0000-0000-0000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (
    select count(*)
    from public.lessons
    where title like 'rls_test_lesson_%'
  ),
  5::bigint,
  'Admin still sees all built-in and custom lessons'
);
select is(
  (
    select count(*)
    from public.quizzes
    where title like 'rls_test_quiz_%'
  ),
  7::bigint,
  'Admin still sees all built-in and custom quizzes'
);

reset role;

-- Student policy remains unchanged: current grade built-ins plus custom
-- content assigned to the Student active section.
select set_config('request.jwt.claim.sub', '', true);
select set_config(
  'request.jwt.claims',
  '{"student_id":"91000000-0000-0000-0000-000000030001","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (
    select count(*)
    from public.lessons
    where title like 'rls_test_lesson_%'
  ),
  2::bigint,
  'Student still sees current-grade built-in and section-assigned lessons'
);
select is(
  (
    select count(*)
    from public.lessons
    where title = 'rls_test_lesson_grade_5'
  ),
  0::bigint,
  'Student still cannot see another grade built-in lesson'
);
select is(
  (
    select count(*)
    from public.quizzes
    where title like 'rls_test_quiz_%'
  ),
  4::bigint,
  'Student still sees current-grade built-ins and section-assigned quizzes'
);
select is(
  (
    select count(*)
    from public.quizzes
    where title = 'rls_test_quiz_grade_5'
  ),
  0::bigint,
  'Student still cannot see another grade built-in quiz'
);

reset role;

select * from finish();
rollback;
