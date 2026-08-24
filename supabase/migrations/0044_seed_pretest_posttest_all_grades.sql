-- =============================================================================
-- Migration: 0044_seed_pretest_posttest_all_grades.sql
-- Content-seeding migration, separate from the schema change in 0043 by
-- design (schema first, content second) — same convention as 0026 -> 0027.
--
-- Seeds 6 built-in Internal Quizzes — one Pre-Test and one Post-Test for
-- EACH grade level (grade_4, grade_5, grade_6). Each pair is a distinct,
-- independent set of content; nothing is shared across grades:
--   Grade 4 Pre-Test / Grade 4 Post-Test
--   Grade 5 Pre-Test / Grade 5 Post-Test
--   Grade 6 Pre-Test / Grade 6 Post-Test
--
-- Every quiz: quiz_type = 'internal', source_type = 'built_in',
-- created_by = null, grade_level set to match, assessment_type =
-- 'pre_test' / 'post_test' accordingly (satisfies
-- quizzes_assessment_type_requires_internal, 0043). Every quiz gets 30
-- placeholder questions (question_bank.topic tagged to the quiz title, per
-- the 0027 convention for the Highest/Lowest Performing Topics dashboard
-- metric) — 180 questions / 720 choices in total. All content is
-- intentionally a placeholder; the admin replaces it with real Pre-Test /
-- Post-Test items later.
--
-- As in 0027, every id is database-generated and captured via
-- `returning ... into`, never hardcoded, and each question's 4 choices are
-- inserted in a single statement so the deferred
-- `enforce_at_least_one_correct` constraint trigger (0014) never observes a
-- question with zero correct choices mid-transaction.
--
-- Unlike 0027 (10 hand-written questions x 2 quizzes), this migration seeds
-- 30 questions x 6 quizzes of uniform placeholder content, so it is written
-- as nested loops over grade level / assessment type / question number
-- rather than 180 repeated blocks. Each choice's is_correct value is still
-- explicit and deterministic (choice 1 is always the correct one) — nothing
-- here is randomly generated.
-- =============================================================================

do $$
declare
  v_grade_levels      text[] := array['grade_4', 'grade_5', 'grade_6'];
  v_assessment_types  text[] := array['pre_test', 'post_test'];
  v_grade             text;
  v_atype             text;
  v_title             text;
  v_quiz_id           uuid;
  v_question_id       uuid;
  i                   int;
begin

  foreach v_grade in array v_grade_levels loop
    foreach v_atype in array v_assessment_types loop

      -- 'grade_4' -> '4', 'pre_test' -> 'Pre-Test' / 'post_test' -> 'Post-Test'
      v_title := 'Grade ' || replace(v_grade, 'grade_', '') || ' ' ||
                 case v_atype
                   when 'pre_test'  then 'Pre-Test'
                   else                  'Post-Test'
                 end;

      -- ---------------------------------------------------------------------
      -- Quiz — built-in Internal Quiz, Pre-Test or Post-Test for this grade
      -- ---------------------------------------------------------------------
      insert into public.quizzes (
        title, quiz_type, source_type, created_by, grade_level,
        assessment_type, shuffle_questions, shuffle_choices
      )
      values (
        v_title, 'internal', 'built_in', null, v_grade::grade_level,
        v_atype::assessment_type, true, true
      )
      returning id into v_quiz_id;

      -- ---------------------------------------------------------------------
      -- 30 placeholder questions, each with exactly 4 choices (1 correct,
      -- 3 incorrect), linked in order via quiz_questions.
      -- ---------------------------------------------------------------------
      for i in 1..30 loop
        insert into public.question_bank (
          source_type, created_by, topic, prompt_text, explanation_text
        )
        values (
          'built_in', null, v_title,
          'Placeholder question ' || i || ' for ' || v_title,
          'Placeholder explanation for question ' || i || ' of ' || v_title || '.'
        )
        returning id into v_question_id;

        insert into public.question_choices (
          question_id, choice_text, is_correct, display_order
        )
        select v_question_id, c.choice_text, c.is_correct, c.display_order
        from (values
          ('Placeholder correct answer for question ' || i,      true,  1),
          ('Placeholder incorrect option A for question ' || i,  false, 2),
          ('Placeholder incorrect option B for question ' || i,  false, 3),
          ('Placeholder incorrect option C for question ' || i,  false, 4)
        ) as c(choice_text, is_correct, display_order);

        insert into public.quiz_questions (quiz_id, question_id, display_order)
        values (v_quiz_id, v_question_id, i);
      end loop;

    end loop;
  end loop;

end $$;
