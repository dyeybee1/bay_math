begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(18);

select is(
  (
    select count(*)
    from public.quizzes
    where source_type = 'built_in'
      and created_by is null
      and quiz_type = 'internal'
      and grade_level in ('grade_4', 'grade_5', 'grade_6')
      and assessment_type in ('pre_test', 'post_test')
      and title in (
        'Grade 4 Pre-Test', 'Grade 4 Post-Test',
        'Grade 5 Pre-Test', 'Grade 5 Post-Test',
        'Grade 6 Pre-Test', 'Grade 6 Post-Test'
      )
  ),
  6::bigint,
  'Exactly six target built-in assessments exist'
);

select is(
  (
    select count(*)
    from (
      select q.id
      from public.quizzes q
      left join public.quiz_questions qq on qq.quiz_id = q.id
      where q.source_type = 'built_in'
        and q.created_by is null
        and q.quiz_type = 'internal'
        and q.grade_level in ('grade_4', 'grade_5', 'grade_6')
        and q.assessment_type in ('pre_test', 'post_test')
      group by q.id
      having count(qq.id) = 30
    ) complete_assessments
  ),
  6::bigint,
  'Every target assessment has 30 questions'
);

select ok(
  not exists (
    select pre.display_order, pre.question_id
    from public.quiz_questions pre
    join public.quizzes quiz on quiz.id = pre.quiz_id
    where quiz.title = 'Grade 4 Pre-Test'
      and quiz.source_type = 'built_in'
      and quiz.grade_level = 'grade_4'
      and quiz.assessment_type = 'pre_test'
    except
    select post.display_order, post.question_id
    from public.quiz_questions post
    join public.quizzes quiz on quiz.id = post.quiz_id
    where quiz.title = 'Grade 4 Post-Test'
      and quiz.source_type = 'built_in'
      and quiz.grade_level = 'grade_4'
      and quiz.assessment_type = 'post_test'
  ),
  'Grade 4 Pre-Test IDs and order are contained in the Post-Test'
);

select ok(
  not exists (
    select post.display_order, post.question_id
    from public.quiz_questions post
    join public.quizzes quiz on quiz.id = post.quiz_id
    where quiz.title = 'Grade 4 Post-Test'
      and quiz.source_type = 'built_in'
      and quiz.grade_level = 'grade_4'
      and quiz.assessment_type = 'post_test'
    except
    select pre.display_order, pre.question_id
    from public.quiz_questions pre
    join public.quizzes quiz on quiz.id = pre.quiz_id
    where quiz.title = 'Grade 4 Pre-Test'
      and quiz.source_type = 'built_in'
      and quiz.grade_level = 'grade_4'
      and quiz.assessment_type = 'pre_test'
  ),
  'Grade 4 Post-Test IDs and order are contained in the Pre-Test'
);

select ok(
  not exists (
    select pre.display_order, pre.question_id
    from public.quiz_questions pre
    join public.quizzes quiz on quiz.id = pre.quiz_id
    where quiz.title = 'Grade 5 Pre-Test'
      and quiz.source_type = 'built_in'
      and quiz.grade_level = 'grade_5'
      and quiz.assessment_type = 'pre_test'
    except
    select post.display_order, post.question_id
    from public.quiz_questions post
    join public.quizzes quiz on quiz.id = post.quiz_id
    where quiz.title = 'Grade 5 Post-Test'
      and quiz.source_type = 'built_in'
      and quiz.grade_level = 'grade_5'
      and quiz.assessment_type = 'post_test'
  ),
  'Grade 5 Pre-Test IDs and order are contained in the Post-Test'
);

select ok(
  not exists (
    select post.display_order, post.question_id
    from public.quiz_questions post
    join public.quizzes quiz on quiz.id = post.quiz_id
    where quiz.title = 'Grade 5 Post-Test'
      and quiz.source_type = 'built_in'
      and quiz.grade_level = 'grade_5'
      and quiz.assessment_type = 'post_test'
    except
    select pre.display_order, pre.question_id
    from public.quiz_questions pre
    join public.quizzes quiz on quiz.id = pre.quiz_id
    where quiz.title = 'Grade 5 Pre-Test'
      and quiz.source_type = 'built_in'
      and quiz.grade_level = 'grade_5'
      and quiz.assessment_type = 'pre_test'
  ),
  'Grade 5 Post-Test IDs and order are contained in the Pre-Test'
);

select ok(
  not exists (
    select pre.display_order, pre.question_id
    from public.quiz_questions pre
    join public.quizzes quiz on quiz.id = pre.quiz_id
    where quiz.title = 'Grade 6 Pre-Test'
      and quiz.source_type = 'built_in'
      and quiz.grade_level = 'grade_6'
      and quiz.assessment_type = 'pre_test'
    except
    select post.display_order, post.question_id
    from public.quiz_questions post
    join public.quizzes quiz on quiz.id = post.quiz_id
    where quiz.title = 'Grade 6 Post-Test'
      and quiz.source_type = 'built_in'
      and quiz.grade_level = 'grade_6'
      and quiz.assessment_type = 'post_test'
  ),
  'Grade 6 Pre-Test IDs and order are contained in the Post-Test'
);

select ok(
  not exists (
    select post.display_order, post.question_id
    from public.quiz_questions post
    join public.quizzes quiz on quiz.id = post.quiz_id
    where quiz.title = 'Grade 6 Post-Test'
      and quiz.source_type = 'built_in'
      and quiz.grade_level = 'grade_6'
      and quiz.assessment_type = 'post_test'
    except
    select pre.display_order, pre.question_id
    from public.quiz_questions pre
    join public.quizzes quiz on quiz.id = pre.quiz_id
    where quiz.title = 'Grade 6 Pre-Test'
      and quiz.source_type = 'built_in'
      and quiz.grade_level = 'grade_6'
      and quiz.assessment_type = 'pre_test'
  ),
  'Grade 6 Post-Test IDs and order are contained in the Pre-Test'
);

select is(
  (
    select count(distinct qq.question_id)
    from public.quiz_questions qq
    join public.quizzes q on q.id = qq.quiz_id
    where q.source_type = 'built_in'
      and q.grade_level in ('grade_4', 'grade_5', 'grade_6')
      and q.assessment_type in ('pre_test', 'post_test')
  ),
  90::bigint,
  'The six assessments use only 90 active question rows'
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
        and q.grade_level in ('grade_4', 'grade_5', 'grade_6')
        and q.assessment_type = 'pre_test'
      group by qq.question_id
      having count(qc.id) <> 4
    ) invalid
  ),
  0::bigint,
  'Every shared question has four choices'
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
        and q.grade_level in ('grade_4', 'grade_5', 'grade_6')
        and q.assessment_type = 'pre_test'
      group by qq.question_id
      having count(qc.id) filter (where qc.is_correct) <> 1
    ) invalid
  ),
  0::bigint,
  'Every shared question has exactly one correct choice'
);

select is(
  (
    select count(*)
    from public.quiz_questions qq
    join public.quizzes q on q.id = qq.quiz_id
    join public.question_choices qc on qc.question_id = qq.question_id
    where q.source_type = 'built_in'
      and q.grade_level in ('grade_4', 'grade_5', 'grade_6')
      and q.assessment_type in ('pre_test', 'post_test')
  ),
  720::bigint,
  'Quiz loading returns 30 questions with four choices for all six assessments'
);

select is(
  (
    select count(*)
    from (
      select qq.question_id
      from public.quiz_questions qq
      join public.quizzes q on q.id = qq.quiz_id
      where q.source_type = 'built_in'
        and q.grade_level = 'grade_4'
        and q.assessment_type = 'pre_test'
      intersect
      select qq.question_id
      from public.quiz_questions qq
      join public.quizzes q on q.id = qq.quiz_id
      where q.source_type = 'built_in'
        and q.grade_level in ('grade_5', 'grade_6')
        and q.assessment_type = 'pre_test'
    ) mixed
  ),
  0::bigint,
  'Grade 4 questions are not mixed with Grade 5 or Grade 6'
);

select is(
  (
    select count(*)
    from (
      select qq.question_id
      from public.quiz_questions qq
      join public.quizzes q on q.id = qq.quiz_id
      where q.source_type = 'built_in'
        and q.grade_level = 'grade_5'
        and q.assessment_type = 'pre_test'
      intersect
      select qq.question_id
      from public.quiz_questions qq
      join public.quizzes q on q.id = qq.quiz_id
      where q.source_type = 'built_in'
        and q.grade_level = 'grade_6'
        and q.assessment_type = 'pre_test'
    ) mixed
  ),
  0::bigint,
  'Grade 5 questions are not mixed with Grade 6'
);

select is(
  (
    select count(*)
    from public.quiz_questions qq
    join public.quizzes assessment on assessment.id = qq.quiz_id
    join public.quiz_questions regular_link
      on regular_link.question_id = qq.question_id
    join public.quizzes regular_quiz on regular_quiz.id = regular_link.quiz_id
    where assessment.source_type = 'built_in'
      and assessment.grade_level in ('grade_4', 'grade_5', 'grade_6')
      and assessment.assessment_type = 'pre_test'
      and regular_quiz.source_type = 'built_in'
      and regular_quiz.grade_level = assessment.grade_level
      and regular_quiz.assessment_type is null
  ),
  90::bigint,
  'Every canonical assessment question reuses a regular built-in question row'
);

select ok(
  not exists (
    select 1
    from public.quiz_attempt_answers answer
    left join public.question_bank question on question.id = answer.question_id
    where question.id is null
  ),
  'Every historical answer still has its referenced question row'
);

select ok(
  not exists (
    select 1
    from public.quiz_attempt_answers answer
    where answer.selected_choice_id is not null
      and not exists (
        select 1
        from public.question_choices choice
        where choice.id = answer.selected_choice_id
      )
  ),
  'Every retained selected-choice backlink still resolves'
);

select ok(
  not exists (
    select 1
    from public.quiz_attempts attempt
    join public.quiz_attempt_answers answer
      on answer.quiz_attempt_id = attempt.id
    join public.quizzes quiz on quiz.id = attempt.quiz_id
    where attempt.attempt_status = 'active'
      and quiz.source_type = 'built_in'
      and quiz.grade_level in ('grade_4', 'grade_5', 'grade_6')
      and quiz.assessment_type in ('pre_test', 'post_test')
      and not exists (
        select 1
        from public.quiz_questions link
        where link.quiz_id = attempt.quiz_id
          and link.question_id = answer.question_id
      )
  ),
  'Every active saved answer belongs to its remapped assessment'
);

select * from finish();
rollback;
