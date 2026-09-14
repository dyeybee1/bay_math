begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(15);

select is(
  (
    select count(*)
    from public.lessons
    where source_type = 'built_in'
      and grade_level = 'grade_4'
      and title = 'Types of Fractions'
  ),
  1::bigint,
  'Exactly one built-in Grade 4 Types of Fractions lesson remains'
);

select is(
  (
    select count(*)
    from public.quizzes
    where source_type = 'built_in'
      and grade_level = 'grade_4'
      and title = 'Quiz 5: Types of Fractions'
  ),
  1::bigint,
  'Exactly one built-in Grade 4 Types of Fractions quiz remains'
);

select is(
  (
    select count(*)
    from public.lessons l
    join public.quizzes q on q.id = l.linked_quiz_id
    where l.source_type = 'built_in'
      and l.grade_level = 'grade_4'
      and l.title = 'Types of Fractions'
      and q.source_type = 'built_in'
      and q.grade_level = 'grade_4'
      and q.title = 'Quiz 5: Types of Fractions'
  ),
  1::bigint,
  'The remaining lesson links to the remaining quiz'
);

select is(
  (
    select count(*)
    from public.lesson_pages lp
    join public.lessons l on l.id = lp.lesson_id
    where l.source_type = 'built_in'
      and l.grade_level = 'grade_4'
      and l.title = 'Types of Fractions'
  ),
  10::bigint,
  'The remaining lesson has ten pages'
);

select is(
  (
    select count(distinct lp.display_order)
    from public.lesson_pages lp
    join public.lessons l on l.id = lp.lesson_id
    where l.source_type = 'built_in'
      and l.grade_level = 'grade_4'
      and l.title = 'Types of Fractions'
  ),
  10::bigint,
  'The remaining lesson has ten distinct page positions'
);

select is(
  (
    select count(*)
    from public.quiz_questions qq
    join public.quizzes q on q.id = qq.quiz_id
    where q.source_type = 'built_in'
      and q.grade_level = 'grade_4'
      and q.title = 'Quiz 5: Types of Fractions'
  ),
  10::bigint,
  'The remaining quiz has ten question links'
);

select is(
  (
    select count(distinct qq.question_id)
    from public.quiz_questions qq
    join public.quizzes q on q.id = qq.quiz_id
    where q.source_type = 'built_in'
      and q.grade_level = 'grade_4'
      and q.title = 'Quiz 5: Types of Fractions'
  ),
  10::bigint,
  'The remaining quiz links ten distinct questions'
);

select is(
  (
    select count(distinct qq.display_order)
    from public.quiz_questions qq
    join public.quizzes q on q.id = qq.quiz_id
    where q.source_type = 'built_in'
      and q.grade_level = 'grade_4'
      and q.title = 'Quiz 5: Types of Fractions'
  ),
  10::bigint,
  'The remaining quiz has ten distinct question positions'
);

select is(
  (
    select count(*)
    from public.question_choices qc
    join public.quiz_questions qq on qq.question_id = qc.question_id
    join public.quizzes q on q.id = qq.quiz_id
    where q.source_type = 'built_in'
      and q.grade_level = 'grade_4'
      and q.title = 'Quiz 5: Types of Fractions'
  ),
  40::bigint,
  'The remaining quiz has forty choices'
);

select is(
  (
    select count(*)
    from (
      select qq.question_id
      from public.quiz_questions qq
      join public.quizzes q on q.id = qq.quiz_id
      left join public.question_choices qc on qc.question_id = qq.question_id
      where q.source_type = 'built_in'
        and q.grade_level = 'grade_4'
        and q.title = 'Quiz 5: Types of Fractions'
      group by qq.question_id
      having count(qc.id) <> 4
    ) invalid
  ),
  0::bigint,
  'Every remaining question has four choices'
);

select is(
  (
    select count(*)
    from (
      select qq.question_id
      from public.quiz_questions qq
      join public.quizzes q on q.id = qq.quiz_id
      left join public.question_choices qc on qc.question_id = qq.question_id
      where q.source_type = 'built_in'
        and q.grade_level = 'grade_4'
        and q.title = 'Quiz 5: Types of Fractions'
      group by qq.question_id
      having count(qc.id) filter (where qc.is_correct) <> 1
    ) invalid
  ),
  0::bigint,
  'Every remaining question has exactly one correct choice'
);

select is(
  (
    select count(*)
    from public.question_bank qb
    join public.quiz_questions qq on qq.question_id = qb.id
    join public.quizzes q on q.id = qq.quiz_id
    where q.source_type = 'built_in'
      and q.grade_level = 'grade_4'
      and q.title = 'Quiz 5: Types of Fractions'
      and qb.source_type = 'built_in'
      and qb.created_by is null
      and qb.topic = 'Types of Fractions'
  ),
  10::bigint,
  'All remaining questions retain the built-in Types classification'
);

select ok(
  not exists (
    select 1 from public.quizzes
    where id = '4e21bb8c-26b5-4487-8c2a-56732ca21ba5'::uuid
  ),
  'The audited later duplicate quiz is absent'
);

select ok(
  not exists (
    select 1 from public.lessons
    where id = '8f73371e-9c7b-4d3a-842a-e2da58741dd0'::uuid
  ),
  'The audited later duplicate lesson is absent'
);

select ok(
  not exists (
    select 1 from public.quiz_attempts
    where id = '26a9c5cf-f3fd-4e3e-9a23-89175c949405'::uuid
       or quiz_id = '4e21bb8c-26b5-4487-8c2a-56732ca21ba5'::uuid
  ),
  'The later duplicate quiz attempt is absent'
);

select * from finish();
rollback;

