-- =============================================================================
-- Migration: 0061_seed_grade4_decimals_fractions.sql
--
-- Seeds Grade 4 (MELC-level) built-in content, following directly after
-- Lessons 1-8 already present in the project:
--   Lesson 9 — Decimals and Their Relationship to Fractions
--   Quiz 9   — Internal Quiz for Lesson 9 (10 questions, tenths + hundredths,
--              decimal <-> fraction conversion, mixed)
--
-- CONFIRMED AGAINST ACTUAL SCHEMA before writing this:
--   - `public.lessons` (0007) + `linked_quiz_id` (0032): unlike the original
--     Lesson 1/2 seed (0027), which predates 0032 and therefore had to link
--     its lesson to its quiz in a separate follow-up migration (0033), the
--     `linked_quiz_id` column already exists as of this migration. The quiz
--     is created FIRST here so its id can be set directly on the lesson's
--     own insert — no separate linking migration needed this time.
--   - `public.lesson_pages` (0028) + `worked_example` (0030): the
--     interactive worked_example jsonb panel is fixed to exactly 6
--     place-value columns (Hundred Thousands..Ones) for whole-number
--     addition/subtraction only (0030's column comment) — it does not
--     model decimals, so every page below is deliberately left as plain
--     `body` text (`worked_example` stays null), the same as every page
--     in Lesson 2 and every non-POC page in Lesson 1.
--   - `section_type` (0028) is free text, presentation-only, used only to
--     pick a client-side icon (`lesson_viewer_screen.dart`). This seed
--     reuses the same values already in use — 'introduction', 'vocabulary',
--     'explanation', 'examples', 'summary' — rather than inventing new
--     ones. 'summary' isn't in `_sectionTypeIcons`'s map (confirmed by
--     reading the file) and already falls back to the default icon for
--     Lessons 1/2's own "Remember" pages, so this is existing, not new,
--     behavior.
--   - `public.quizzes` (0009) + `assessment_type` (0043): this is an
--     ordinary practice quiz, not a Pre-/Post-Test, so `assessment_type`
--     is left unset (null), matching every other non-assessment quiz.
--   - `public.question_bank` (0008): `topic` is tagged to match the owning
--     lesson's title, exactly as 0027's header comment specifies, to
--     support the Highest/Lowest Performing Topics dashboard metric.
--   - Each question's 4 choices are inserted in a single statement, so the
--     deferred `enforce_at_least_one_correct` constraint trigger (0014)
--     never observes a question with zero correct choices mid-transaction
--     (same approach as 0027).
--   - All ids are database-generated (gen_random_uuid()) and captured via
--     `returning ... into`, never hardcoded.
--
-- MATH VERIFIED for every question and every lesson-page example below:
--   0.1 = 1/10   0.2 = 2/10   0.3 = 3/10   0.6 = 6/10   0.7 = 7/10
--   0.01 = 1/100   0.08 = 8/100   0.25 = 25/100   0.32 = 32/100
--   0.42 = 42/100   0.45 = 45/100   0.50 = 50/100
--   3/10 = 0.3   27/100 = 0.27   45/100 = 0.45
-- Every distractor was checked to NOT be numerically equal to the correct
-- value (e.g. 0.30 and 5.00 were deliberately avoided as distractors for
-- 0.3 and 0.50, since 0.30 = 0.3 and 5.00 = 5, which would make a
-- "wrong" choice actually correct in value).
-- =============================================================================

do $$
declare
  v_lesson9_id uuid;
  v_quiz9_id   uuid;

  -- Quiz 9 — Decimals and Their Relationship to Fractions
  v_q9_1  uuid; v_q9_2  uuid; v_q9_3  uuid; v_q9_4  uuid; v_q9_5  uuid;
  v_q9_6  uuid; v_q9_7  uuid; v_q9_8  uuid; v_q9_9  uuid; v_q9_10 uuid;
begin

  -- ===========================================================================
  -- Quiz 9 — built-in Internal Quiz for Lesson 9
  -- (created first so its id can be set directly on the lesson insert below)
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 9: Decimals and Their Relationship to Fractions',
    'internal', 'built_in', null, 'grade_4', true, true
  )
  returning id into v_quiz9_id;

  -- --- Q1 -------------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Decimals and Their Relationship to Fractions',
    'In the decimal 0.6, which place is the digit 6 in?',
    '0.6 has one digit after the decimal point, so that digit (6) is in the tenths place.'
  )
  returning id into v_q9_1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9_1, 'Tenths place',    true,  1),
    (v_q9_1, 'Hundredths place', false, 2),
    (v_q9_1, 'Ones place',      false, 3),
    (v_q9_1, 'Hundreds place',  false, 4);

  -- --- Q2 -------------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Decimals and Their Relationship to Fractions',
    'In the decimal 0.58, what is the value of the digit 8?',
    '0.58 has two digits after the decimal point. The second digit, 8, is in the hundredths place, so its value is 8 hundredths.'
  )
  returning id into v_q9_2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9_2, '8 hundredths',  true,  1),
    (v_q9_2, '8 tenths',      false, 2),
    (v_q9_2, '8 ones',        false, 3),
    (v_q9_2, '8 thousandths', false, 4);

  -- --- Q3 -------------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Decimals and Their Relationship to Fractions',
    'Which fraction is equal to 0.7?',
    '0.7 has one digit after the decimal point, so it means seven tenths. As a fraction, this is written 7/10.'
  )
  returning id into v_q9_3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9_3, '7/10',  true,  1),
    (v_q9_3, '7/100', false, 2),
    (v_q9_3, '10/7',  false, 3),
    (v_q9_3, '7/1',   false, 4);

  -- --- Q4 -------------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Decimals and Their Relationship to Fractions',
    'Which fraction is equal to 0.32?',
    '0.32 has two digits after the decimal point, so it means thirty-two hundredths. As a fraction, this is written 32/100.'
  )
  returning id into v_q9_4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9_4, '32/100', true,  1),
    (v_q9_4, '32/10',  false, 2),
    (v_q9_4, '100/32', false, 3),
    (v_q9_4, '3/100',  false, 4);

  -- --- Q5 -------------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Decimals and Their Relationship to Fractions',
    'What decimal is equal to 3/10?',
    '3/10 has a denominator of 10, so the numerator (3) is written as one digit after the decimal point: 3/10 = 0.3.'
  )
  returning id into v_q9_5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9_5, '0.3',  true,  1),
    (v_q9_5, '0.03', false, 2),
    (v_q9_5, '3.0',  false, 3),
    (v_q9_5, '30.0', false, 4);

  -- --- Q6 -------------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Decimals and Their Relationship to Fractions',
    'What decimal is equal to 45/100?',
    '45/100 has a denominator of 100, so the numerator (45) is written as two digits after the decimal point: 45/100 = 0.45.'
  )
  returning id into v_q9_6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9_6, '0.45',  true,  1),
    (v_q9_6, '4.5',   false, 2),
    (v_q9_6, '0.045', false, 3),
    (v_q9_6, '45.0',  false, 4);

  -- --- Q7 -------------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Decimals and Their Relationship to Fractions',
    'Which decimal is equal to 50/100?',
    '50/100 has a denominator of 100, so the numerator (50) is written as two digits after the decimal point: 50/100 = 0.50.'
  )
  returning id into v_q9_7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9_7, '0.50',  true,  1),
    (v_q9_7, '0.05',  false, 2),
    (v_q9_7, '5.00',  false, 3),
    (v_q9_7, '0.005', false, 4);

  -- --- Q8 (word problem) ------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Decimals and Their Relationship to Fractions',
    'Ana colored 0.4 of a rectangle. Which fraction shows the part she colored?',
    '0.4 has one digit after the decimal point, so it means four tenths. As a fraction, this is written 4/10.'
  )
  returning id into v_q9_8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9_8, '4/10',  true,  1),
    (v_q9_8, '4/100', false, 2),
    (v_q9_8, '10/4',  false, 3),
    (v_q9_8, '4/1',   false, 4);

  -- --- Q9 (word problem) ------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Decimals and Their Relationship to Fractions',
    'A recipe uses 27/100 of a cup of sugar. Which decimal represents this amount?',
    '27/100 has a denominator of 100, so the numerator (27) is written as two digits after the decimal point: 27/100 = 0.27.'
  )
  returning id into v_q9_9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9_9, '0.27',  true,  1),
    (v_q9_9, '2.7',   false, 2),
    (v_q9_9, '0.027', false, 3),
    (v_q9_9, '0.72',  false, 4);

  -- --- Q10 (equivalent representations) ----------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Decimals and Their Relationship to Fractions',
    'Which pair shows the same value?',
    '0.6 has one digit after the decimal point, meaning six tenths, so 0.6 = 6/10. The digit 6 stays in the tenths place, matching a denominator of 10, not 100 or 1,000.'
  )
  returning id into v_q9_10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9_10, '0.6 and 6/10',    true,  1),
    (v_q9_10, '0.6 and 6/100',   false, 2),
    (v_q9_10, '0.06 and 6/10',   false, 3),
    (v_q9_10, '0.6 and 60/1000', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz9_id, v_q9_1,  1),
    (v_quiz9_id, v_q9_2,  2),
    (v_quiz9_id, v_q9_3,  3),
    (v_quiz9_id, v_q9_4,  4),
    (v_quiz9_id, v_q9_5,  5),
    (v_quiz9_id, v_q9_6,  6),
    (v_quiz9_id, v_q9_7,  7),
    (v_quiz9_id, v_q9_8,  8),
    (v_quiz9_id, v_q9_9,  9),
    (v_quiz9_id, v_q9_10, 10);

  -- ===========================================================================
  -- Lesson 9 — Decimals and Their Relationship to Fractions
  -- `body` is the short 1-2 sentence description the lesson list screen
  -- shows (current convention post-0029); full content lives in
  -- `lesson_pages` below. `linked_quiz_id` is set directly to Quiz 9's id
  -- since that column (0032) already exists as of this migration.
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level, linked_quiz_id)
  values (
    'Decimals and Their Relationship to Fractions',
    'Learn how decimals and fractions can represent the same amount, using tenths and hundredths, decimal place value, and examples converting between decimal and fraction forms.',
    'built_in',
    null,
    'grade_4',
    v_quiz9_id
  )
  returning id into v_lesson9_id;

  -- ===========================================================================
  -- Lesson 9 pages (9 pages)
  -- ===========================================================================
  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson9_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn about decimals and how they relate to fractions. A decimal and a fraction can be two different ways of writing the exact same amount.'
  ),
  (
    v_lesson9_id, 2, 'vocabulary', 'Decimal Place Value',
    E'A decimal point separates the whole number part of a number from its fractional part. The digits right after the decimal point have their own place values:\n' ||
    E'  the first digit after the decimal point is in the tenths place\n' ||
    E'  the second digit after the decimal point is in the hundredths place\n\n' ||
    E'For example, in the decimal 0.47:\n' ||
    E'  4 is in the tenths place\n' ||
    E'  7 is in the hundredths place'
  ),
  (
    v_lesson9_id, 3, 'explanation', 'Tenths as Fractions',
    E'When a decimal has only one digit after the decimal point, it shows a number of tenths. The denominator (bottom number) of the matching fraction is always 10.\n\n' ||
    E'For example:\n' ||
    E'  0.1 means one tenth, written as the fraction 1/10\n' ||
    E'  0.2 means two tenths, written as the fraction 2/10\n\n' ||
    E'The decimal and the fraction stand for the same amount — they are just written in different ways.'
  ),
  (
    v_lesson9_id, 4, 'examples', 'Tenths Examples',
    E'Worked Example 1:\n' ||
    E'  0.3 means three tenths.\n' ||
    E'  As a fraction, this is written 3/10.\n' ||
    E'  So 0.3 = 3/10.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  0.7 means seven tenths.\n' ||
    E'  As a fraction, this is written 7/10.\n' ||
    E'  So 0.7 = 7/10.'
  ),
  (
    v_lesson9_id, 5, 'explanation', 'Hundredths as Fractions',
    E'When a decimal has two digits after the decimal point, it shows a number of hundredths. The denominator of the matching fraction is always 100.\n\n' ||
    E'For example:\n' ||
    E'  0.01 means one hundredth, written as the fraction 1/100\n' ||
    E'  0.25 means twenty-five hundredths, written as the fraction 25/100\n\n' ||
    E'Both digits after the decimal point together become the numerator (top number) of the fraction.'
  ),
  (
    v_lesson9_id, 6, 'examples', 'Hundredths Examples',
    E'Worked Example 3:\n' ||
    E'  0.42 means forty-two hundredths.\n' ||
    E'  As a fraction, this is written 42/100.\n' ||
    E'  So 0.42 = 42/100.\n\n' ||
    E'Worked Example 4:\n' ||
    E'  0.08 means eight hundredths.\n' ||
    E'  As a fraction, this is written 8/100.\n' ||
    E'  So 0.08 = 8/100.'
  ),
  (
    v_lesson9_id, 7, 'explanation', 'Converting Between Decimals and Fractions',
    E'You can change a decimal into a fraction, and a fraction into a decimal.\n\n' ||
    E'To change a decimal into a fraction:\n' ||
    E'  1. Count how many digits are after the decimal point.\n' ||
    E'  2. One digit means tenths, so use 10 as the denominator.\n' ||
    E'  3. Two digits means hundredths, so use 100 as the denominator.\n' ||
    E'  4. Write the digits after the decimal point as the numerator.\n\n' ||
    E'To change a fraction into a decimal:\n' ||
    E'  1. Look at the denominator.\n' ||
    E'  2. If the denominator is 10, write the numerator as one digit after the decimal point.\n' ||
    E'  3. If the denominator is 100, write the numerator as two digits after the decimal point.'
  ),
  (
    v_lesson9_id, 8, 'examples', 'Conversion Examples',
    E'Worked Example 5 (decimal to fraction):\n' ||
    E'  0.6 has one digit after the decimal point, so it means six tenths.\n' ||
    E'  As a fraction, this is written 6/10.\n' ||
    E'  So 0.6 = 6/10.\n\n' ||
    E'Worked Example 6 (fraction to decimal):\n' ||
    E'  45/100 has a denominator of 100, so the numerator becomes two digits after the decimal point.\n' ||
    E'  So 45/100 = 0.45.\n\n' ||
    E'Worked Example 7 (fraction to decimal):\n' ||
    E'  3/10 has a denominator of 10, so the numerator becomes one digit after the decimal point.\n' ||
    E'  So 3/10 = 0.3.'
  ),
  (
    v_lesson9_id, 9, 'summary', 'Remember',
    E'  - A decimal and a fraction can represent the same amount.\n' ||
    E'  - One digit after the decimal point means tenths (denominator 10).\n' ||
    E'  - Two digits after the decimal point means hundredths (denominator 100).\n' ||
    E'  - To write a decimal as a fraction, use the digits after the decimal point as the numerator.\n' ||
    E'  - To write a fraction as a decimal, match the denominator (10 or 100) to the number of decimal places.'
  );

end $$;
