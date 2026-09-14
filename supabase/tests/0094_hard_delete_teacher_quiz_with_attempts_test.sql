begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(21);

insert into auth.users (id, email)
values
  ('93000000-0000-0000-0000-000000000001', 'delete-owner@baymath.test'),
  ('93000000-0000-0000-0000-000000000002', 'delete-other@baymath.test'),
  ('93000000-0000-0000-0000-000000000003', 'delete-pending@baymath.test');

insert into public.profiles (id, role, status, full_name, email)
values
  (
    '93000000-0000-0000-0000-000000000001',
    'teacher',
    'approved',
    'Delete Owner',
    'delete-owner@baymath.test'
  ),
  (
    '93000000-0000-0000-0000-000000000002',
    'teacher',
    'approved',
    'Delete Other',
    'delete-other@baymath.test'
  ),
  (
    '93000000-0000-0000-0000-000000000003',
    'teacher',
    'pending',
    'Delete Pending',
    'delete-pending@baymath.test'
  );

insert into public.schools (id, name)
values ('93000000-0000-0000-0000-000000001000', 'Delete Test School');

insert into public.school_years (
  id,
  school_id,
  label,
  start_date,
  end_date,
  is_current
)
values (
  '93000000-0000-0000-0000-000000001001',
  '93000000-0000-0000-0000-000000001000',
  '2093-2094',
  '2093-06-01',
  '2094-04-01',
  false
);

insert into public.sections (id, school_year_id, grade_level, name)
values (
  '93000000-0000-0000-0000-000000004001',
  '93000000-0000-0000-0000-000000001001',
  'grade_4',
  'Delete Test Section'
);

insert into public.teacher_sections (
  teacher_id,
  section_id,
  is_primary,
  assigned_by
)
values (
  '93000000-0000-0000-0000-000000000001',
  '93000000-0000-0000-0000-000000004001',
  true,
  '93000000-0000-0000-0000-000000000001'
);

insert into public.students (
  id,
  username,
  password_encrypted,
  full_name,
  created_by
)
values (
  '93000000-0000-0000-0000-000000003001',
  'delete_test_student',
  decode('00', 'hex'),
  'Delete Test Student',
  '93000000-0000-0000-0000-000000000001'
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
    '93000000-0000-0000-0000-000000002001',
    'delete_test_setup_only',
    'internal',
    'teacher',
    '93000000-0000-0000-0000-000000000001',
    null,
    null
  ),
  (
    '93000000-0000-0000-0000-000000002002',
    'delete_test_with_attempt',
    'internal',
    'teacher',
    '93000000-0000-0000-0000-000000000001',
    null,
    null
  ),
  (
    '93000000-0000-0000-0000-000000002003',
    'delete_test_other_teacher',
    'internal',
    'teacher',
    '93000000-0000-0000-0000-000000000002',
    null,
    null
  ),
  (
    '93000000-0000-0000-0000-000000002004',
    'delete_test_built_in',
    'internal',
    'built_in',
    null,
    'grade_4',
    null
  ),
  (
    '93000000-0000-0000-0000-000000002005',
    'delete_test_unrelated_with_attempt',
    'internal',
    'teacher',
    '93000000-0000-0000-0000-000000000001',
    null,
    null
  ),
  (
    '93000000-0000-0000-0000-000000002006',
    'delete_test_pending_teacher',
    'internal',
    'teacher',
    '93000000-0000-0000-0000-000000000003',
    null,
    null
  );

insert into public.question_bank (
  id,
  source_type,
  created_by,
  topic,
  prompt_text
)
values (
  '93000000-0000-0000-0000-000000005001',
  'teacher',
  '93000000-0000-0000-0000-000000000001',
  'Fractions',
  'Which fraction is one half?'
);

insert into public.question_choices (
  id,
  question_id,
  choice_text,
  is_correct,
  display_order
)
values
  (
    '93000000-0000-0000-0000-000000006001',
    '93000000-0000-0000-0000-000000005001',
    '1/2',
    true,
    1
  ),
  (
    '93000000-0000-0000-0000-000000006002',
    '93000000-0000-0000-0000-000000005001',
    '1/3',
    false,
    2
  );

insert into public.quiz_questions (id, quiz_id, question_id, display_order)
values
  (
    '93000000-0000-0000-0000-000000007001',
    '93000000-0000-0000-0000-000000002001',
    '93000000-0000-0000-0000-000000005001',
    1
  ),
  (
    '93000000-0000-0000-0000-000000007002',
    '93000000-0000-0000-0000-000000002002',
    '93000000-0000-0000-0000-000000005001',
    1
  ),
  (
    '93000000-0000-0000-0000-000000007003',
    '93000000-0000-0000-0000-000000002005',
    '93000000-0000-0000-0000-000000005001',
    1
  );

insert into public.quiz_sections (id, quiz_id, section_id, assigned_by)
values
  (
    '93000000-0000-0000-0000-000000008001',
    '93000000-0000-0000-0000-000000002001',
    '93000000-0000-0000-0000-000000004001',
    '93000000-0000-0000-0000-000000000001'
  ),
  (
    '93000000-0000-0000-0000-000000008002',
    '93000000-0000-0000-0000-000000002002',
    '93000000-0000-0000-0000-000000004001',
    '93000000-0000-0000-0000-000000000001'
  ),
  (
    '93000000-0000-0000-0000-000000008003',
    '93000000-0000-0000-0000-000000002005',
    '93000000-0000-0000-0000-000000004001',
    '93000000-0000-0000-0000-000000000001'
  );

insert into public.lessons (
  id,
  title,
  body,
  source_type,
  created_by,
  grade_level,
  linked_quiz_id
)
values (
  '93000000-0000-0000-0000-000000009001',
  'delete_test_linked_lesson',
  'Linked lesson body',
  'teacher',
  '93000000-0000-0000-0000-000000000001',
  null,
  '93000000-0000-0000-0000-000000002001'
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
    '93000000-0000-0000-0000-000000010001',
    '93000000-0000-0000-0000-000000003001',
    '93000000-0000-0000-0000-000000002002',
    '93000000-0000-0000-0000-000000004001',
    '93000000-0000-0000-0000-000000001001',
    'superseded',
    1,
    1,
    now()
  ),
  (
    '93000000-0000-0000-0000-000000010002',
    '93000000-0000-0000-0000-000000003001',
    '93000000-0000-0000-0000-000000002005',
    '93000000-0000-0000-0000-000000004001',
    '93000000-0000-0000-0000-000000001001',
    'active',
    1,
    0,
    now()
  );

insert into public.quiz_attempt_answers (
  id,
  quiz_attempt_id,
  question_id,
  question_text_snapshot,
  selected_choice_id,
  is_correct
)
values
  (
    '93000000-0000-0000-0000-000000011001',
    '93000000-0000-0000-0000-000000010001',
    '93000000-0000-0000-0000-000000005001',
    'Which fraction is one half?',
    '93000000-0000-0000-0000-000000006001',
    true
  ),
  (
    '93000000-0000-0000-0000-000000011002',
    '93000000-0000-0000-0000-000000010002',
    '93000000-0000-0000-0000-000000005001',
    'Which fraction is one half?',
    '93000000-0000-0000-0000-000000006002',
    false
  );

insert into public.quiz_attempt_answer_choice_snapshots (
  id,
  quiz_attempt_answer_id,
  choice_text_snapshot,
  was_correct,
  was_selected,
  display_order
)
values
  (
    '93000000-0000-0000-0000-000000012001',
    '93000000-0000-0000-0000-000000011001',
    '1/2',
    true,
    true,
    1
  ),
  (
    '93000000-0000-0000-0000-000000012002',
    '93000000-0000-0000-0000-000000011002',
    '1/3',
    false,
    true,
    1
  );

select set_config(
  'request.jwt.claim.sub',
  '93000000-0000-0000-0000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"93000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  public.delete_own_teacher_quiz(
    '93000000-0000-0000-0000-000000002001'
  ),
  'deleted',
  'Owner can delete an owned setup-only custom quiz'
);
select is(
  (select count(*) from public.quizzes where id = '93000000-0000-0000-0000-000000002001'),
  0::bigint,
  'Deleted quiz is no longer visible'
);
select is(
  (select count(*) from public.quiz_questions where id = '93000000-0000-0000-0000-000000007001'),
  0::bigint,
  'Owned quiz question links are removed'
);
select is(
  (select count(*) from public.quiz_sections where id = '93000000-0000-0000-0000-000000008001'),
  0::bigint,
  'Owned quiz section links are removed'
);
select is(
  (select linked_quiz_id from public.lessons where id = '93000000-0000-0000-0000-000000009001'),
  null::uuid,
  'Existing lesson link is safely cleared rather than deleting the lesson'
);
select is(
  (select count(*) from public.question_bank where id = '93000000-0000-0000-0000-000000005001'),
  1::bigint,
  'Reusable question-bank item remains'
);
select is(
  (select count(*) from public.question_choices where question_id = '93000000-0000-0000-0000-000000005001'),
  2::bigint,
  'Reusable question choices remain'
);
select is(
  public.delete_own_teacher_quiz(
    '93000000-0000-0000-0000-000000002004'
  ),
  'not_authorized',
  'Teacher cannot delete a built-in quiz'
);
select is(
  public.delete_own_teacher_quiz(
    '93000000-0000-0000-0000-000000002003'
  ),
  'not_authorized',
  'Teacher cannot delete another Teacher quiz'
);
select is(
  public.delete_own_teacher_quiz(
    '93000000-0000-0000-0000-000000002002'
  ),
  'deleted',
  'Owner can hard-delete an owned custom quiz with attempts and results'
);
select is(
  (select count(*) from public.quizzes where id = '93000000-0000-0000-0000-000000002002'),
  0::bigint,
  'Quiz with attempts is deleted'
);
select is(
  (select count(*) from public.quiz_attempt_answer_choice_snapshots where id = '93000000-0000-0000-0000-000000012001'),
  0::bigint,
  'Target answer-choice snapshots are deleted first'
);
select is(
  (select count(*) from public.quiz_attempt_answers where id = '93000000-0000-0000-0000-000000011001'),
  0::bigint,
  'Target attempt answers are deleted'
);
select is(
  (select count(*) from public.quiz_attempts where id = '93000000-0000-0000-0000-000000010001'),
  0::bigint,
  'Target attempts are deleted'
);
select is(
  (select count(*) from public.quiz_questions where id = '93000000-0000-0000-0000-000000007002'),
  0::bigint,
  'Target quiz-question links are deleted'
);
select is(
  (select count(*) from public.quiz_sections where id = '93000000-0000-0000-0000-000000008002'),
  0::bigint,
  'Target quiz-section assignments are deleted'
);
select is(
  (select count(*) from public.quizzes where id = '93000000-0000-0000-0000-000000002005'),
  1::bigint,
  'Unrelated quiz remains'
);
select is(
  (select count(*) from public.quiz_attempts where id = '93000000-0000-0000-0000-000000010002'),
  1::bigint,
  'Unrelated quiz attempt remains'
);
select is(
  (select count(*) from public.quiz_attempt_answers where id = '93000000-0000-0000-0000-000000011002'),
  1::bigint,
  'Unrelated attempt answer remains'
);
select is(
  (select count(*) from public.quiz_attempt_answer_choice_snapshots where id = '93000000-0000-0000-0000-000000012002'),
  1::bigint,
  'Unrelated answer-choice snapshot remains'
);

reset role;

select set_config(
  'request.jwt.claim.sub',
  '93000000-0000-0000-0000-000000000003',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"93000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  public.delete_own_teacher_quiz(
    '93000000-0000-0000-0000-000000002006'
  ),
  'not_authorized',
  'A non-approved Teacher cannot use the delete RPC'
);

reset role;

select * from finish();
rollback;
