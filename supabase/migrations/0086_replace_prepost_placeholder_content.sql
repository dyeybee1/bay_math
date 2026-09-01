-- =============================================================================
-- Migration: 0086_replace_prepost_placeholder_content.sql
--
-- Replaces the 30 placeholder question bodies created by 0044 for every
-- Grade 4-6 Pre-Test and Post-Test with validated curriculum questions from
-- the corresponding built-in regular quizzes.
--
-- Coverage requested for both assessment forms:
--   Grade 4 (6 items per topic)
--     1. Addition and Subtraction of Numbers up to 1,000,000
--     2. Comparing Numbers up to 1,000,000
--     3. Place Value of Whole Numbers
--     4. Multiplication, Division, and MDAS
--     5. Types of Fractions
--   Grade 5 (10 items per topic)
--     1. Multiplying and Dividing Fractions
--     2. Finding the Area of Plane Figures
--     3. Adding, Subtracting, and Multiplying Decimals
--   Grade 6 (10 items per topic)
--     1. Operations with Decimals
--     2. Understanding Ratio and Proportion
--     3. Exponents and GEMDAS
--
-- IMPORTANT PRESERVATION RULES
--   * Each assessment keeps exactly its existing 30 quiz_questions rows.
--   * Existing question and choice ids are updated in place, never replaced.
--   * Quiz ids, assessment types, shuffle flags, attempts, answer snapshots,
--     score rules, and routing behavior are untouched.
--   * Submitted-attempt snapshots remain authoritative under 0010/0014.
--   * The migration is idempotent: rerunning it copies the same source data.
--
-- Grade 4 uses questions 1-6 of each source quiz for the Pre-Test and 5-10
-- for the Post-Test, producing parallel forms with only the unavoidable
-- two-item overlap per ten-question topic bank. Grade 5 and Grade 6 source
-- topic quizzes currently contain exactly ten validated items, so both forms
-- draw those ten items into their own independent question rows.
-- =============================================================================

create temporary table assessment_content_plan (
  grade_level       text not null,
  source_order      smallint not null,
  source_quiz_title text not null,
  take_count        smallint not null,
  primary key (grade_level, source_order)
) on commit drop;

insert into assessment_content_plan (
  grade_level,
  source_order,
  source_quiz_title,
  take_count
) values
  (
    'grade_4', 1,
    'Quiz 1: Addition and Subtraction of Numbers up to 1,000,000', 6
  ),
  (
    'grade_4', 2,
    'Quiz 2: Comparing Numbers up to 1,000,000', 6
  ),
  ('grade_4', 3, 'Quiz 3: Place Value of Whole Numbers', 6),
  ('grade_4', 4, 'Quiz 4: Multiplication, Division, and MDAS', 6),
  ('grade_4', 5, 'Quiz 5: Types of Fractions', 6),
  ('grade_5', 1, 'Quiz 3: Multiplying and Dividing Fractions', 10),
  ('grade_5', 2, 'Quiz 4: Finding the Area of Plane Figures', 10),
  (
    'grade_5', 3,
    'Quiz 5: Adding, Subtracting, and Multiplying Decimals', 10
  ),
  ('grade_6', 1, 'Quiz 2: Operations with Decimals', 10),
  ('grade_6', 2, 'Quiz 3: Understanding Ratio and Proportion', 10),
  ('grade_6', 3, 'Quiz 4: Exponents and GEMDAS', 10);

do $$
declare
  v_grade_levels          text[] := array['grade_4', 'grade_5', 'grade_6'];
  v_assessment_types      text[] := array['pre_test', 'post_test'];
  v_grade                 text;
  v_assessment_type       text;
  v_target_title          text;
  v_target_quiz           record;
  v_source_plan           record;
  v_source_question       record;
  v_source_quiz_id        uuid;
  v_target_question_id    uuid;
  v_target_question_count integer;
  v_source_question_count integer;
  v_source_choice_count   integer;
  v_source_correct_count  integer;
  v_target_choice_count   integer;
  v_source_offset         integer;
  v_target_position       integer;
  v_target_quiz_count     integer;
  v_rows_updated          integer;
begin
  foreach v_grade in array v_grade_levels loop
    foreach v_assessment_type in array v_assessment_types loop
      v_target_title :=
        'Grade ' || replace(v_grade, 'grade_', '') || ' ' ||
        case v_assessment_type
          when 'pre_test' then 'Pre-Test'
          else 'Post-Test'
        end;
      v_target_quiz_count := 0;

      -- Update every exact built-in assessment match. This also repairs any
      -- duplicate assessment row created if the non-idempotent 0044 seed was
      -- accidentally applied more than once in an environment.
      for v_target_quiz in
        select q.id
        from public.quizzes q
        where q.title = v_target_title
          and q.quiz_type = 'internal'
          and q.source_type = 'built_in'
          and q.grade_level = v_grade::grade_level
          and q.assessment_type = v_assessment_type::assessment_type
        order by q.created_at, q.id
      loop
        v_target_quiz_count := v_target_quiz_count + 1;

        select count(*)
        into v_target_question_count
        from public.quiz_questions qq
        where qq.quiz_id = v_target_quiz.id;

        if v_target_question_count <> 30 then
          raise exception
            '0086: % must retain exactly 30 items; found % on quiz %',
            v_target_title,
            v_target_question_count,
            v_target_quiz.id;
        end if;

        v_target_position := 0;

        for v_source_plan in
          select p.source_quiz_title, p.take_count
          from assessment_content_plan p
          where p.grade_level = v_grade
          order by p.source_order
        loop
          v_source_quiz_id := null;

          -- If a seed was duplicated, the oldest regular quiz is the
          -- canonical source, matching Student catalog deduplication.
          select q.id
          into v_source_quiz_id
          from public.quizzes q
          where q.title = v_source_plan.source_quiz_title
            and q.quiz_type = 'internal'
            and q.source_type = 'built_in'
            and q.grade_level = v_grade::grade_level
            and q.assessment_type is null
          order by q.created_at, q.id
          limit 1;

          if v_source_quiz_id is null then
            raise exception
              '0086: source quiz not found for %: %',
              v_grade,
              v_source_plan.source_quiz_title;
          end if;

          select count(*)
          into v_source_question_count
          from public.quiz_questions qq
          where qq.quiz_id = v_source_quiz_id;

          -- Grade 4 uses separate six-question windows for its parallel
          -- forms. Grade 5/6 use all ten available validated topic items.
          v_source_offset :=
            case
              when v_grade = 'grade_4'
                and v_assessment_type = 'post_test' then 4
              else 0
            end;

          if v_source_question_count <
             v_source_offset + v_source_plan.take_count then
            raise exception
              '0086: source quiz % needs at least % questions for this form; found %',
              v_source_plan.source_quiz_title,
              v_source_offset + v_source_plan.take_count,
              v_source_question_count;
          end if;

          for v_source_question in
            select qq.question_id
            from public.quiz_questions qq
            where qq.quiz_id = v_source_quiz_id
            order by qq.display_order
            offset v_source_offset
            limit v_source_plan.take_count
          loop
            v_target_position := v_target_position + 1;
            v_target_question_id := null;

            select qq.question_id
            into v_target_question_id
            from public.quiz_questions qq
            where qq.quiz_id = v_target_quiz.id
              and qq.display_order = v_target_position;

            if v_target_question_id is null then
              raise exception
                '0086: target question % missing from quiz %',
                v_target_position,
                v_target_quiz.id;
            end if;

            select count(*), count(*) filter (where qc.is_correct)
            into v_source_choice_count, v_source_correct_count
            from public.question_choices qc
            where qc.question_id = v_source_question.question_id;

            select count(*)
            into v_target_choice_count
            from public.question_choices qc
            where qc.question_id = v_target_question_id;

            if v_source_choice_count <> 4 or v_source_correct_count <> 1 then
              raise exception
                '0086: source question % must have 4 choices and 1 correct answer; found % choices / % correct',
                v_source_question.question_id,
                v_source_choice_count,
                v_source_correct_count;
            end if;

            if v_target_choice_count <> 4 then
              raise exception
                '0086: target question % must retain exactly 4 choices; found %',
                v_target_question_id,
                v_target_choice_count;
            end if;

            update public.question_bank target_question
            set
              topic = source_question.topic,
              prompt_text = source_question.prompt_text,
              explanation_text = source_question.explanation_text
            from public.question_bank source_question
            where target_question.id = v_target_question_id
              and source_question.id = v_source_question.question_id;

            get diagnostics v_rows_updated = row_count;
            if v_rows_updated <> 1 then
              raise exception
                '0086: failed to update target question % from source %',
                v_target_question_id,
                v_source_question.question_id;
            end if;

            update public.question_choices target_choice
            set
              choice_text = source_choice.choice_text,
              is_correct = source_choice.is_correct
            from public.question_choices source_choice
            where target_choice.question_id = v_target_question_id
              and source_choice.question_id = v_source_question.question_id
              and target_choice.display_order = source_choice.display_order;

            get diagnostics v_rows_updated = row_count;
            if v_rows_updated <> 4 then
              raise exception
                '0086: expected to update 4 choices for target question %; updated %',
                v_target_question_id,
                v_rows_updated;
            end if;
          end loop;
        end loop;

        if v_target_position <> 30 then
          raise exception
            '0086: coverage plan produced % items for %; expected 30',
            v_target_position,
            v_target_title;
        end if;
      end loop;

      if v_target_quiz_count = 0 then
        raise exception '0086: target assessment not found: %', v_target_title;
      end if;
    end loop;
  end loop;
end $$;

-- Guard the postcondition explicitly: all six assessment identities, including
-- any duplicate seed rows for an identity, still contain exactly 30 items and
-- no placeholder prompt text remains attached to them.
do $$
declare
  v_invalid_count integer;
begin
  select count(*)
  into v_invalid_count
  from (
    select q.id
    from public.quizzes q
    left join public.quiz_questions qq on qq.quiz_id = q.id
    where q.quiz_type = 'internal'
      and q.source_type = 'built_in'
      and q.grade_level in ('grade_4', 'grade_5', 'grade_6')
      and q.assessment_type in ('pre_test', 'post_test')
      and q.title in (
        'Grade 4 Pre-Test', 'Grade 4 Post-Test',
        'Grade 5 Pre-Test', 'Grade 5 Post-Test',
        'Grade 6 Pre-Test', 'Grade 6 Post-Test'
      )
    group by q.id
    having count(qq.id) <> 30
  ) invalid_assessment;

  if v_invalid_count > 0 then
    raise exception
      '0086: % built-in Grade 4-6 assessments do not contain exactly 30 items',
      v_invalid_count;
  end if;

  select count(*)
  into v_invalid_count
  from public.quizzes q
  join public.quiz_questions qq on qq.quiz_id = q.id
  join public.question_bank qb on qb.id = qq.question_id
  where q.quiz_type = 'internal'
    and q.source_type = 'built_in'
    and q.grade_level in ('grade_4', 'grade_5', 'grade_6')
    and q.assessment_type in ('pre_test', 'post_test')
    and q.title in (
      'Grade 4 Pre-Test', 'Grade 4 Post-Test',
      'Grade 5 Pre-Test', 'Grade 5 Post-Test',
      'Grade 6 Pre-Test', 'Grade 6 Post-Test'
    )
    and qb.prompt_text like 'Placeholder question %';

  if v_invalid_count > 0 then
    raise exception
      '0086: % placeholder assessment questions remain after replacement',
      v_invalid_count;
  end if;
end $$;
