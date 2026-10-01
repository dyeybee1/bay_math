begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(21);

insert into auth.users (id, email)
values
  ('97000000-0000-0000-0000-000000000001', 'endless-admin@baymath.test'),
  ('97000000-0000-0000-0000-000000000002', 'endless-teacher@baymath.test');

insert into public.profiles (id, role, status, full_name, email)
values
  (
    '97000000-0000-0000-0000-000000000001',
    'admin',
    'approved',
    'Endless Test Admin',
    'endless-admin@baymath.test'
  ),
  (
    '97000000-0000-0000-0000-000000000002',
    'teacher',
    'approved',
    'Endless Test Teacher',
    'endless-teacher@baymath.test'
  );

insert into public.schools (id, name)
values ('97000000-0000-0000-0000-000000001000', 'Endless Test School');

insert into public.school_years (
  id,
  school_id,
  label,
  start_date,
  end_date,
  is_current
)
values (
  '97000000-0000-0000-0000-000000001001',
  '97000000-0000-0000-0000-000000001000',
  'Endless Test Year',
  '2097-06-01',
  '2098-04-01',
  false
);

insert into public.sections (
  id,
  school_year_id,
  grade_level,
  name,
  status
)
values
  (
    '97000000-0000-0000-0000-000000004001',
    '97000000-0000-0000-0000-000000001001',
    'grade_4',
    'Endless Grade 4 A',
    'active'
  ),
  (
    '97000000-0000-0000-0000-000000004002',
    '97000000-0000-0000-0000-000000001001',
    'grade_4',
    'Endless Grade 4 B',
    'active'
  ),
  (
    '97000000-0000-0000-0000-000000004003',
    '97000000-0000-0000-0000-000000001001',
    'grade_4',
    'Endless Grade 4 Archived',
    'archived'
  ),
  (
    '97000000-0000-0000-0000-000000005001',
    '97000000-0000-0000-0000-000000001001',
    'grade_5',
    'Endless Grade 5',
    'active'
  ),
  (
    '97000000-0000-0000-0000-000000006001',
    '97000000-0000-0000-0000-000000001001',
    'grade_6',
    'Endless Grade 6',
    'active'
  ),
  (
    '97000000-0000-0000-0000-000000004009',
    '97000000-0000-0000-0000-000000001001',
    'grade_6',
    'Endless Grade 6 Empty',
    'active'
  );

insert into public.students (
  id,
  username,
  password_encrypted,
  full_name,
  created_by
)
values
  (
    '97000000-0000-0000-0000-000000003004',
    'endless_grade4',
    decode('00', 'hex'),
    'Endless Grade 4 Student',
    '97000000-0000-0000-0000-000000000002'
  ),
  (
    '97000000-0000-0000-0000-000000003005',
    'endless_grade5',
    decode('00', 'hex'),
    'Endless Grade 5 Student',
    '97000000-0000-0000-0000-000000000002'
  ),
  (
    '97000000-0000-0000-0000-000000003006',
    'endless_grade6',
    decode('00', 'hex'),
    'Endless Grade 6 Student',
    '97000000-0000-0000-0000-000000000002'
  ),
  (
    '97000000-0000-0000-0000-000000003009',
    'endless_empty',
    decode('00', 'hex'),
    'Endless Empty Student',
    '97000000-0000-0000-0000-000000000002'
  );

insert into public.student_enrollments (student_id, section_id, status)
values
  (
    '97000000-0000-0000-0000-000000003004',
    '97000000-0000-0000-0000-000000004001',
    'active'
  ),
  (
    '97000000-0000-0000-0000-000000003005',
    '97000000-0000-0000-0000-000000005001',
    'active'
  ),
  (
    '97000000-0000-0000-0000-000000003006',
    '97000000-0000-0000-0000-000000006001',
    'active'
  ),
  (
    '97000000-0000-0000-0000-000000003009',
    '97000000-0000-0000-0000-000000004009',
    'active'
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
  ('97000000-0000-0000-0000-000000014001', 'Endless G4 Built-in', 'internal', 'built_in', null, 'grade_4', null),
  ('97000000-0000-0000-0000-000000014002', 'Endless G4 Pre-Test', 'internal', 'built_in', null, 'grade_4', 'pre_test'),
  ('97000000-0000-0000-0000-000000014003', 'Endless G4 Post-Test', 'internal', 'built_in', null, 'grade_4', 'post_test'),
  ('97000000-0000-0000-0000-000000015001', 'Endless G5 Built-in', 'internal', 'built_in', null, 'grade_5', null),
  ('97000000-0000-0000-0000-000000016001', 'Endless G6 Built-in', 'internal', 'built_in', null, 'grade_6', null),
  ('97000000-0000-0000-0000-000000014101', 'Endless G4 Assigned Teacher', 'internal', 'teacher', '97000000-0000-0000-0000-000000000002', null, null),
  ('97000000-0000-0000-0000-000000014102', 'Endless G4 Unassigned Teacher', 'internal', 'teacher', '97000000-0000-0000-0000-000000000002', null, null),
  ('97000000-0000-0000-0000-000000014103', 'Endless G4 Other Section Teacher', 'internal', 'teacher', '97000000-0000-0000-0000-000000000002', null, null),
  ('97000000-0000-0000-0000-000000014104', 'Endless Archived Section Teacher', 'internal', 'teacher', '97000000-0000-0000-0000-000000000002', null, null),
  ('97000000-0000-0000-0000-000000015101', 'Endless G5 Assigned Teacher', 'internal', 'teacher', '97000000-0000-0000-0000-000000000002', null, null);

insert into public.quiz_sections (quiz_id, section_id, assigned_by)
values
  ('97000000-0000-0000-0000-000000014101', '97000000-0000-0000-0000-000000004001', '97000000-0000-0000-0000-000000000002'),
  ('97000000-0000-0000-0000-000000014103', '97000000-0000-0000-0000-000000004002', '97000000-0000-0000-0000-000000000002'),
  ('97000000-0000-0000-0000-000000014104', '97000000-0000-0000-0000-000000004003', '97000000-0000-0000-0000-000000000002'),
  ('97000000-0000-0000-0000-000000015101', '97000000-0000-0000-0000-000000005001', '97000000-0000-0000-0000-000000000002');

insert into public.question_bank (
  id,
  source_type,
  created_by,
  topic,
  prompt_text
)
values
  ('97000000-0000-0000-0000-000000024001', 'built_in', null, 'G4', 'G4 built-in question'),
  ('97000000-0000-0000-0000-000000024002', 'built_in', null, 'G4', 'G4 shared question'),
  ('97000000-0000-0000-0000-000000025001', 'built_in', null, 'G5', 'G5 built-in question'),
  ('97000000-0000-0000-0000-000000026001', 'built_in', null, 'G6', 'G6 built-in question'),
  ('97000000-0000-0000-0000-000000024101', 'teacher', '97000000-0000-0000-0000-000000000002', 'G4', 'G4 assigned teacher question'),
  ('97000000-0000-0000-0000-000000024102', 'teacher', '97000000-0000-0000-0000-000000000002', 'G4', 'G4 unassigned teacher question'),
  ('97000000-0000-0000-0000-000000024103', 'teacher', '97000000-0000-0000-0000-000000000002', 'G4', 'G4 other-section teacher question'),
  ('97000000-0000-0000-0000-000000024104', 'teacher', '97000000-0000-0000-0000-000000000002', 'G4', 'G4 archived-section teacher question'),
  ('97000000-0000-0000-0000-000000025101', 'teacher', '97000000-0000-0000-0000-000000000002', 'G5', 'G5 assigned teacher question');

insert into public.question_choices (
  id,
  question_id,
  choice_text,
  is_correct,
  display_order
)
select
  ('97000000-0000-0000-0000-' || right(question.id::text, 12))::uuid,
  question.id,
  'Correct',
  true,
  1
from public.question_bank question
where question.id::text like '97000000-0000-0000-0000-00000002%';

insert into public.quiz_questions (quiz_id, question_id, display_order)
values
  ('97000000-0000-0000-0000-000000014001', '97000000-0000-0000-0000-000000024001', 1),
  ('97000000-0000-0000-0000-000000014001', '97000000-0000-0000-0000-000000024002', 2),
  ('97000000-0000-0000-0000-000000014002', '97000000-0000-0000-0000-000000024002', 1),
  ('97000000-0000-0000-0000-000000014003', '97000000-0000-0000-0000-000000024002', 1),
  ('97000000-0000-0000-0000-000000015001', '97000000-0000-0000-0000-000000025001', 1),
  ('97000000-0000-0000-0000-000000016001', '97000000-0000-0000-0000-000000026001', 1),
  ('97000000-0000-0000-0000-000000014101', '97000000-0000-0000-0000-000000024101', 1),
  ('97000000-0000-0000-0000-000000014102', '97000000-0000-0000-0000-000000024102', 1),
  ('97000000-0000-0000-0000-000000014103', '97000000-0000-0000-0000-000000024103', 1),
  ('97000000-0000-0000-0000-000000014104', '97000000-0000-0000-0000-000000024104', 1),
  ('97000000-0000-0000-0000-000000015101', '97000000-0000-0000-0000-000000025101', 1);

select is(
  (
    select count(*)
    from app.endless_quiz_eligible_question_ids('97000000-0000-0000-0000-000000003004')
    where question_id::text like '97000000-%'
  ),
  3::bigint,
  'Grade 4 canonical pool has exactly its built-in, shared, and assigned teacher questions'
);

select ok(
  exists (
    select 1 from app.endless_quiz_eligible_question_ids('97000000-0000-0000-0000-000000003004')
    where question_id = '97000000-0000-0000-0000-000000024001'
  ),
  'Grade 4 includes a Grade 4 built-in question'
);

select ok(
  exists (
    select 1 from app.endless_quiz_eligible_question_ids('97000000-0000-0000-0000-000000003004')
    where question_id = '97000000-0000-0000-0000-000000024101'
  ),
  'Grade 4 includes a teacher question assigned to the Student section'
);

select ok(
  not exists (
    select 1 from app.endless_quiz_eligible_question_ids('97000000-0000-0000-0000-000000003004')
    where question_id in (
      '97000000-0000-0000-0000-000000025001',
      '97000000-0000-0000-0000-000000025101'
    )
  ),
  'Grade 4 excludes all Grade 5 questions'
);

select ok(
  not exists (
    select 1 from app.endless_quiz_eligible_question_ids('97000000-0000-0000-0000-000000003004')
    where question_id = '97000000-0000-0000-0000-000000026001'
  ),
  'Grade 4 excludes all Grade 6 questions'
);

select is(
  (
    select array_agg(question_id order by question_id)::text
    from app.endless_quiz_eligible_question_ids('97000000-0000-0000-0000-000000003005')
    where question_id::text like '97000000-%'
  ),
  '{97000000-0000-0000-0000-000000025001,97000000-0000-0000-0000-000000025101}',
  'Grade 5 receives only Grade 5 built-in and assigned teacher questions'
);

select is(
  (
    select array_agg(question_id order by question_id)::text
    from app.endless_quiz_eligible_question_ids('97000000-0000-0000-0000-000000003006')
    where question_id::text like '97000000-%'
  ),
  '{97000000-0000-0000-0000-000000026001}',
  'Grade 6 receives only Grade 6 questions'
);

select ok(
  not exists (
    select 1 from app.endless_quiz_eligible_question_ids('97000000-0000-0000-0000-000000003004')
    where question_id = '97000000-0000-0000-0000-000000024102'
  ),
  'An unassigned teacher quiz is excluded'
);

select ok(
  not exists (
    select 1 from app.endless_quiz_eligible_question_ids('97000000-0000-0000-0000-000000003004')
    where question_id = '97000000-0000-0000-0000-000000024103'
  ),
  'A teacher quiz assigned only to another same-grade section is excluded'
);

select is(
  (
    select count(*) from app.endless_quiz_eligible_question_ids('97000000-0000-0000-0000-000000003004')
    where question_id = '97000000-0000-0000-0000-000000024002'
  ),
  1::bigint,
  'One canonical question shared by Pre-Test and Post-Test appears once'
);

select is(
  (
    select count(*) from app.endless_quiz_eligible_question_ids('97000000-0000-0000-0000-000000003004')
    where question_id = '97000000-0000-0000-0000-000000024002'
  ),
  1::bigint,
  'One question linked to multiple same-grade quizzes appears once'
);

select ok(
  not exists (
    select 1 from app.endless_quiz_eligible_question_ids('97000000-0000-0000-0000-000000003004')
    where question_id = '97000000-0000-0000-0000-000000024104'
  ),
  'Content assigned only to an archived section is unavailable'
);

select ok(
  not exists (
    select 1
    from app.svc_fetch_endless_question('97000000-0000-0000-0000-000000003004') fetched
    where fetched.question_id not in (
      select eligible.question_id
      from app.endless_quiz_eligible_question_ids('97000000-0000-0000-0000-000000003004') eligible
    )
  ),
  'Fetch returns only an eligible question and its own choices'
);

select is(
  app.svc_check_endless_answer(
    '97000000-0000-0000-0000-000000003004',
    '97000000-0000-0000-0000-000000024001',
    '97000000-0000-0000-0000-000000024001'
  ),
  true,
  'Answer submission still works for an eligible question'
);

select throws_ok(
  $$
    select app.svc_check_endless_answer(
      '97000000-0000-0000-0000-000000003004',
      '97000000-0000-0000-0000-000000025001',
      '97000000-0000-0000-0000-000000025001'
    )
  $$,
  'P0001',
  'question 97000000-0000-0000-0000-000000025001 is not eligible for student 97000000-0000-0000-0000-000000003004',
  'A direct request to check another grade question is rejected'
);

select is(
  (
    select count(*)
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'app'
      and procedure.proname = 'svc_fetch_endless_question'
      and pg_get_function_identity_arguments(procedure.oid) = 'p_student_id uuid'
  ),
  1::bigint,
  'Fetch RPC accepts only verified student identity and no spoofable grade parameter'
);

-- The real seed catalog has built-ins for every supported grade. Remove only
-- Grade 6 built-in links transaction-locally, after its inclusion assertion,
-- to exercise a genuine empty pool without inventing a fallback grade.
delete from public.quiz_questions link
using public.quizzes quiz
where quiz.id = link.quiz_id
  and quiz.source_type = 'built_in'
  and quiz.grade_level = 'grade_6';

select is(
  (select count(*) from app.endless_quiz_eligible_question_ids('97000000-0000-0000-0000-000000003009')),
  0::bigint,
  'An empty eligible pool remains empty without cross-grade fallback'
);

select throws_ok(
  $$ select * from app.svc_fetch_endless_question('97000000-0000-0000-0000-000000003009') $$,
  'P0001',
  'no endless quiz questions available for student grade',
  'Fetching an empty pool returns the dedicated safe-empty condition'
);

insert into public.endless_quiz_sessions (
  id,
  student_id,
  started_at,
  ended_at,
  questions_answered,
  best_streak_session
)
values (
  '97000000-0000-0000-0000-000000030001',
  '97000000-0000-0000-0000-000000003004',
  '2097-07-01 09:00:00+00',
  '2097-07-01 09:05:00+00',
  5,
  3
);

select *
from app.svc_fetch_endless_question('97000000-0000-0000-0000-000000003004')
limit 0;

select is(
  (
    select count(*) from public.endless_quiz_sessions
    where student_id = '97000000-0000-0000-0000-000000003004'
  ),
  1::bigint,
  'Question pool reads leave existing Endless Quiz session history intact'
);

select is(
  (
    select count(*)
    from information_schema.role_routine_grants
    where routine_schema = 'app'
      and routine_name = 'endless_quiz_eligible_question_ids'
      and grantee in ('anon', 'authenticated')
  ),
  0::bigint,
  'Students cannot call the internal eligible-pool helper directly'
);

select is(
  (
    select count(distinct question_id)
    from app.endless_quiz_eligible_question_ids('97000000-0000-0000-0000-000000003004')
  ),
  (
    select count(*)
    from app.endless_quiz_eligible_question_ids('97000000-0000-0000-0000-000000003004')
  ),
  'The candidate pool contains no duplicate canonical question ids'
);

select * from finish();
rollback;
