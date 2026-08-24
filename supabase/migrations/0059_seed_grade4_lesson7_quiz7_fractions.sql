-- =============================================================================
-- Migration: 0059_seed_grade4_lesson7_quiz7_fractions.sql
-- Content-seeding migration for the next Grade 4 (MELC-level) built-in
-- lesson/quiz pair, following the same shape as 0027 (seed) + 0029
-- (lesson_pages) + 0033 (link lesson -> quiz), combined into one
-- migration since this is new content rather than a schema-driven
-- restructuring of already-seeded rows. Same pattern already used for
-- Lesson 6 / Quiz 6 (see the "Converting and Plotting Fractions"
-- migration immediately before this one).
--
-- Seeds:
--   Lesson 7 — Comparing, Adding, and Subtracting Fractions
--                                                   (grade_4, built_in)
--   Quiz 7: Comparing, Adding, and Subtracting Fractions
--                                                   (grade_4, built_in,
--                                                    internal, 10 questions)
--
-- Continues the project's Grade 4 sequence: 1 Addition and Subtraction,
-- 2 Comparing Numbers, 3 Place Value of Whole Numbers, 4 Multiplication/
-- Division and MDAS, 5 Types of Fractions, 6 Converting and Plotting
-- Fractions -- so this is Lesson 7, moving from converting/plotting a
-- single fraction into comparing and combining two fractions.
--
-- SCOPE DECISION: the reference material provided does not show any
-- existing Grade 4 lesson/quiz teaching addition, subtraction, or
-- comparison of fractions with DIFFERENT denominators (no common-
-- denominator or LCD procedure appears anywhere in the supplied lesson
-- content). Per the task's explicit instruction to only teach what is
-- "explicitly supported by the existing curriculum/reference files,"
-- this lesson and quiz are scoped to same-denominator comparison,
-- addition, and subtraction only. No simplification or mixed-number
-- reduction of results is introduced either, for the same reason --
-- every addition/subtraction result below is left as a plain fraction
-- with numerator less than or equal to the denominator's supported
-- range, never requiring a reduction step that isn't shown elsewhere in
-- the reference material.
--
-- CONVENTIONS FOLLOWED (same as 0044/0058's Lesson 6 migration, itself
-- verified against 0007/0008/0009/0027/0028/0029/0032/0033):
--   - lessons/quizzes: source_type = 'built_in', created_by = null,
--     grade_level = 'grade_4'.
--   - lessons.body is the short 1-2 sentence list-screen description;
--     the full text lives in lesson_pages rows.
--   - lesson_pages: one row per slide, display_order starting at 1,
--     section_type drawn only from values already used elsewhere
--     ('introduction' | 'vocabulary' | 'explanation' | 'examples' |
--     'summary') -- no new section_type invented.
--   - worked_example (0030) left null on every page: that column's shape
--     is fixed to the 6-place-value addition/subtraction POC and does
--     not model fraction arithmetic, so plain-text `body` is used
--     throughout, consistent with Lesson 6's approach.
--   - question_bank/question_choices/quiz_questions: 4 choices per
--     question, exactly one is_correct = true, inserted in a single
--     statement per question so the deferred
--     enforce_at_least_one_correct trigger never sees a zero-correct
--     question mid-transaction; topic tagged to the lesson title.
--   - quizzes.shuffle_questions / shuffle_choices = true.
--   - lessons.linked_quiz_id (0032) set to Quiz 7 at the end, the same
--     way 0033/0044 linked earlier lessons to their quizzes.
--
-- MATH VERIFIED (independently recomputed before writing the content
-- below; every result checked as numerator arithmetic only, denominator
-- unchanged, since all fractions here share a denominator):
--   Comparisons:
--     3/8  vs 5/8  -> 3 < 5  -> 3/8 < 5/8
--     7/10 vs 4/10 -> 7 > 4  -> 7/10 > 4/10
--     5/6  vs 5/6  -> equal -> 5/6 = 5/6
--     4/9  vs 7/9  -> 4 < 7  -> 4/9 < 7/9   (quiz)
--     5/8  vs 3/8  -> 5 > 3  -> 5/8 > 3/8   (quiz)
--     6/11 vs 6/11 -> equal -> 6/11 = 6/11  (quiz)
--     2/9, 5/9, 4/9 ascending -> 2/9, 4/9, 5/9 (quiz)
--   Addition (add numerators, keep denominator):
--     2/7 + 3/7   = 5/7        (lesson)
--     3/10 + 4/10 = 7/10       (lesson)
--     2/8 + 3/8   = 5/8        (lesson word problem)
--     4/9 + 3/9   = 7/9        (quiz)
--     4/11 + 5/11 = 9/11       (quiz)
--     2/6 + 3/6   = 5/6        (quiz word problem)
--   Subtraction (subtract numerators, keep denominator):
--     6/9 - 2/9   = 4/9        (lesson)
--     8/11 - 3/11 = 5/11       (lesson)
--     9/10 - 3/10 = 6/10       (lesson word problem)
--     7/10 - 3/10 = 4/10       (quiz)
--     9/12 - 4/12 = 5/12       (quiz)
--     7/12 - 3/12 = 4/12       (quiz word problem)
--   No fraction pair or result above is reused verbatim between the
--   lesson and the quiz (Step 13's "don't copy the exact examples").
-- =============================================================================

do $$
declare
  v_lesson7_id uuid;
  v_quiz7_id   uuid;

  v_q1  uuid; v_q2  uuid; v_q3  uuid; v_q4  uuid; v_q5  uuid;
  v_q6  uuid; v_q7  uuid; v_q8  uuid; v_q9  uuid; v_q10 uuid;
begin

  -- ===========================================================================
  -- Lesson 7 — Comparing, Adding, and Subtracting Fractions
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Comparing, Adding, and Subtracting Fractions',
    'Learn how to compare fractions with the same denominator using <, >, and =, and how to add and subtract fractions with the same denominator.',
    'built_in',
    null,
    'grade_4'
  )
  returning id into v_lesson7_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson7_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will compare fractions to see which is greater, less, or equal, and learn how to add and subtract fractions that have the same denominator.'
  ),
  (
    v_lesson7_id, 2, 'vocabulary', 'Review of Fraction Parts',
    E'Remember the two parts of a fraction:\n' ||
    E'  numerator -- the top number, telling how many parts we have\n' ||
    E'  denominator -- the bottom number, telling how many equal parts make one whole\n\n' ||
    E'When two fractions have the same denominator, the whole is divided into the same number of equal parts, so we can compare or combine them just by looking at the numerators.'
  ),
  (
    v_lesson7_id, 3, 'explanation', 'Comparing Fractions with the Same Denominator',
    E'When two fractions have the same denominator, the one with the greater numerator is the greater fraction, because more equal-sized parts are being counted.\n\n' ||
    E'We use these symbols to compare fractions:\n' ||
    E'  < means "less than"\n' ||
    E'  > means "greater than"\n' ||
    E'  = means "equal to"'
  ),
  (
    v_lesson7_id, 4, 'examples', 'Comparison Examples',
    E'Worked Example 1:\n' ||
    E'  Compare 3/8 and 5/8.\n' ||
    E'  Both fractions have the same denominator, 8, so compare the numerators: 3 and 5.\n' ||
    E'  Since 3 is less than 5,\n' ||
    E'  3/8 < 5/8.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  Compare 7/10 and 4/10.\n' ||
    E'  Both fractions have the same denominator, 10, so compare the numerators: 7 and 4.\n' ||
    E'  Since 7 is greater than 4,\n' ||
    E'  7/10 > 4/10.\n\n' ||
    E'Worked Example 3:\n' ||
    E'  Compare 5/6 and 5/6.\n' ||
    E'  Both the numerators and denominators are exactly the same, so\n' ||
    E'  5/6 = 5/6.'
  ),
  (
    v_lesson7_id, 5, 'explanation', 'Adding Fractions with the Same Denominator',
    E'To add fractions that have the same denominator:\n' ||
    E'  1. Add the numerators.\n' ||
    E'  2. Keep the denominator the same.\n\n' ||
    E'Do NOT add the denominators -- the denominator only tells the size of the equal parts, and that size does not change when we add.'
  ),
  (
    v_lesson7_id, 6, 'examples', 'Addition Examples',
    E'Worked Example 4:\n' ||
    E'  2/7 + 3/7 = ?\n' ||
    E'  Add the numerators: 2 + 3 = 5.\n' ||
    E'  Keep the denominator: 7.\n' ||
    E'  Answer: 2/7 + 3/7 = 5/7.\n\n' ||
    E'Worked Example 5:\n' ||
    E'  3/10 + 4/10 = ?\n' ||
    E'  Add the numerators: 3 + 4 = 7.\n' ||
    E'  Keep the denominator: 10.\n' ||
    E'  Answer: 3/10 + 4/10 = 7/10.'
  ),
  (
    v_lesson7_id, 7, 'explanation', 'Subtracting Fractions with the Same Denominator',
    E'To subtract fractions that have the same denominator:\n' ||
    E'  1. Subtract the numerators.\n' ||
    E'  2. Keep the denominator the same.\n\n' ||
    E'Do NOT subtract the denominators -- just like in addition, the denominator stays the same because the size of the equal parts has not changed.'
  ),
  (
    v_lesson7_id, 8, 'examples', 'Subtraction Examples',
    E'Worked Example 6:\n' ||
    E'  6/9 - 2/9 = ?\n' ||
    E'  Subtract the numerators: 6 - 2 = 4.\n' ||
    E'  Keep the denominator: 9.\n' ||
    E'  Answer: 6/9 - 2/9 = 4/9.\n\n' ||
    E'Worked Example 7:\n' ||
    E'  8/11 - 3/11 = ?\n' ||
    E'  Subtract the numerators: 8 - 3 = 5.\n' ||
    E'  Keep the denominator: 11.\n' ||
    E'  Answer: 8/11 - 3/11 = 5/11.'
  ),
  (
    v_lesson7_id, 9, 'examples', 'Applying Fraction Addition and Subtraction',
    E'Worked Example 8 (addition):\n' ||
    E'  Liza ate 2/8 of a cake in the morning and 3/8 of the cake in the afternoon. How much of the cake did she eat in all?\n' ||
    E'  Add the numerators: 2 + 3 = 5. Keep the denominator: 8.\n' ||
    E'  Answer: Liza ate 5/8 of the cake in all.\n\n' ||
    E'Worked Example 9 (subtraction):\n' ||
    E'  A rope was 9/10 meter long. Pedro cut off 3/10 meter to use for a project. How much rope is left?\n' ||
    E'  Subtract the numerators: 9 - 3 = 6. Keep the denominator: 10.\n' ||
    E'  Answer: 6/10 meter of rope is left.'
  ),
  (
    v_lesson7_id, 10, 'summary', 'Remember',
    E'  - To compare fractions with the same denominator, the fraction with the greater numerator is the greater fraction.\n' ||
    E'  - Use < for less than, > for greater than, and = for equal to.\n' ||
    E'  - To add fractions with the same denominator, add the numerators and keep the denominator.\n' ||
    E'  - To subtract fractions with the same denominator, subtract the numerators and keep the denominator.\n' ||
    E'  - Never add or subtract the denominators.'
  );

  -- ===========================================================================
  -- Quiz 7 — built-in Internal Quiz for Lesson 7
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 7: Comparing, Adding, and Subtracting Fractions',
    'internal', 'built_in', null, 'grade_4', true, true
  )
  returning id into v_quiz7_id;

  -- --- Q1 (comparing, same denominator) ------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing, Adding, and Subtracting Fractions',
    'Which statement correctly compares 4/9 and 7/9?',
    'Both fractions have the same denominator, 9, so compare the numerators: 4 and 7. Since 4 is less than 7, 4/9 < 7/9.'
  )
  returning id into v_q1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1, '4/9 < 7/9', true,  1),
    (v_q1, '4/9 > 7/9', false, 2),
    (v_q1, '4/9 = 7/9', false, 3),
    (v_q1, 'Cannot be compared', false, 4);

  -- --- Q2 (comparing, same denominator) ------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing, Adding, and Subtracting Fractions',
    'Which statement correctly compares 5/8 and 3/8?',
    'Both fractions have the same denominator, 8, so compare the numerators: 5 and 3. Since 5 is greater than 3, 5/8 > 3/8.'
  )
  returning id into v_q2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2, '5/8 < 3/8', false, 1),
    (v_q2, '5/8 > 3/8', true,  2),
    (v_q2, '5/8 = 3/8', false, 3),
    (v_q2, 'Cannot be compared', false, 4);

  -- --- Q3 (comparing, equal fractions) --------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing, Adding, and Subtracting Fractions',
    'Which statement correctly compares 6/11 and 6/11?',
    'Both the numerators and denominators are exactly the same, so 6/11 = 6/11.'
  )
  returning id into v_q3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q3, '6/11 < 6/11', false, 1),
    (v_q3, '6/11 > 6/11', false, 2),
    (v_q3, '6/11 = 6/11', true,  3),
    (v_q3, 'Cannot be compared', false, 4);

  -- --- Q4 (addition, same denominator) --------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing, Adding, and Subtracting Fractions',
    'What is 4/9 + 3/9?',
    'Add the numerators: 4 + 3 = 7. Keep the denominator the same: 9. So 4/9 + 3/9 = 7/9.'
  )
  returning id into v_q4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q4, '7/9',  true,  1),
    (v_q4, '7/18', false, 2),
    (v_q4, '8/9',  false, 3),
    (v_q4, '7/10', false, 4);

  -- --- Q5 (addition, same denominator) --------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing, Adding, and Subtracting Fractions',
    'What is 4/11 + 5/11?',
    'Add the numerators: 4 + 5 = 9. Keep the denominator the same: 11. So 4/11 + 5/11 = 9/11.'
  )
  returning id into v_q5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5, '9/11',  true,  1),
    (v_q5, '9/22',  false, 2),
    (v_q5, '10/11', false, 3),
    (v_q5, '9/12',  false, 4);

  -- --- Q6 (subtraction, same denominator) -----------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing, Adding, and Subtracting Fractions',
    'What is 7/10 - 3/10?',
    'Subtract the numerators: 7 - 3 = 4. Keep the denominator the same: 10. So 7/10 - 3/10 = 4/10.'
  )
  returning id into v_q6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6, '4/10', true,  1),
    (v_q6, '5/10', false, 2),
    (v_q6, '3/10', false, 3),
    (v_q6, '4/9',  false, 4);

  -- --- Q7 (subtraction, same denominator) -----------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing, Adding, and Subtracting Fractions',
    'What is 9/12 - 4/12?',
    'Subtract the numerators: 9 - 4 = 5. Keep the denominator the same: 12. So 9/12 - 4/12 = 5/12.'
  )
  returning id into v_q7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q7, '5/12', true,  1),
    (v_q7, '5/24', false, 2),
    (v_q7, '6/12', false, 3),
    (v_q7, '5/13', false, 4);

  -- --- Q8 (word problem, addition) -------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing, Adding, and Subtracting Fractions',
    'Ben drank 2/6 of a bottle of juice in the morning and 3/6 of the bottle in the afternoon. What fraction of the bottle did he drink in all?',
    'This is an addition problem: 2/6 + 3/6. Add the numerators: 2 + 3 = 5. Keep the denominator: 6. So Ben drank 5/6 of the bottle in all.'
  )
  returning id into v_q8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q8, '5/6 of the bottle',  true,  1),
    (v_q8, '5/12 of the bottle', false, 2),
    (v_q8, '6/6 of the bottle',  false, 3),
    (v_q8, '5/7 of the bottle',  false, 4);

  -- --- Q9 (word problem, subtraction) -----------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing, Adding, and Subtracting Fractions',
    'A ribbon was 7/12 meter long. Ana cut off 3/12 meter to use for a project. How much ribbon is left?',
    'This is a subtraction problem: 7/12 - 3/12. Subtract the numerators: 7 - 3 = 4. Keep the denominator: 12. So 4/12 meter of ribbon is left.'
  )
  returning id into v_q9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9, '4/12 meter',  true,  1),
    (v_q9, '10/12 meter', false, 2),
    (v_q9, '5/12 meter',  false, 3),
    (v_q9, '4/13 meter',  false, 4);

  -- --- Q10 (slightly more challenging: ordering three fractions) -------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing, Adding, and Subtracting Fractions',
    'Which list correctly orders these fractions from least to greatest: 2/9, 5/9, 4/9?',
    'All three fractions share the denominator 9, so order them by their numerators from smallest to largest: 2, then 4, then 5. That gives 2/9, 4/9, 5/9.'
  )
  returning id into v_q10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10, '2/9, 4/9, 5/9', true,  1),
    (v_q10, '5/9, 4/9, 2/9', false, 2),
    (v_q10, '4/9, 2/9, 5/9', false, 3),
    (v_q10, '2/9, 5/9, 4/9', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz7_id, v_q1,  1),
    (v_quiz7_id, v_q2,  2),
    (v_quiz7_id, v_q3,  3),
    (v_quiz7_id, v_q4,  4),
    (v_quiz7_id, v_q5,  5),
    (v_quiz7_id, v_q6,  6),
    (v_quiz7_id, v_q7,  7),
    (v_quiz7_id, v_q8,  8),
    (v_quiz7_id, v_q9,  9),
    (v_quiz7_id, v_q10, 10);

  -- ===========================================================================
  -- Link Lesson 7 -> Quiz 7, the same "Take Quiz" convenience shortcut
  -- 0033/0044 used for earlier lessons (0032's linked_quiz_id column).
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz7_id where id = v_lesson7_id;

end $$;
