-- =============================================================================
-- Migration: 0062_seed_grade4_decimal_place_value.sql
--
-- Seeds Grade 4 (MELC-level) built-in content, following directly after
-- Lesson 9 (0061):
--   Lesson 10 — Place Value and Value of Decimal Digits
--   Quiz 10   — Internal Quiz for Lesson 10 (10 questions, place vs. value,
--               tenths + hundredths, mixed)
--
-- CONFIRMED AGAINST ACTUAL SCHEMA before writing this (same tables/columns
-- 0061 already used, re-checked, nothing changed since):
--   - `public.lessons` (0007) + `linked_quiz_id` (0032): Quiz 10 is created
--     first, same as 0061, so its id is set directly on the lesson's own
--     insert — no separate linking migration needed.
--   - `public.lesson_pages` (0028): `section_type` reuses the same free-text
--     values already in use — 'introduction', 'vocabulary', 'explanation',
--     'examples', 'summary' — no new type invented.
--   - `worked_example` (0030) stays null on every page — it is fixed to
--     whole-number addition/subtraction (0030's column comment) and does
--     not model decimal place value, so every page here is plain `body`
--     text, same approach 0061 used for Lesson 9.
--   - `public.quizzes` (0009) + `assessment_type` (0043): ordinary practice
--     quiz, `assessment_type` left null, same as every other non-assessment
--     quiz including Quiz 9.
--   - `public.question_bank` (0008): `topic` tagged to the owning lesson's
--     title, matching 0027's original convention.
--   - Each question's 4 choices inserted in a single statement, so the
--     deferred `enforce_at_least_one_correct` trigger (0014) never observes
--     a question with zero correct choices mid-transaction.
--   - All ids are database-generated (gen_random_uuid()), captured via
--     `returning ... into`, never hardcoded.
--
-- MATH INDEPENDENTLY VERIFIED for every lesson-page example and every quiz
-- question below (digit -> place -> value, worked separately from the
-- task brief's own sample numbers, since two of that brief's illustrative
-- examples — "7 in 5.72" and "digit with value 0.06 in 4.63" — do not
-- hold up under direct calculation: in 5.72, 7 is the tenths digit, not
-- hundredths; in 4.63, the hundredths digit is 3 (value 0.03), not 6.
-- Every number used below was picked and checked independently instead):
--   4.56: 5 -> tenths -> 0.5     6 -> hundredths -> 0.06
--   7.38: 3 -> tenths -> 0.3     8 -> hundredths -> 0.08
--   9.24: 2 -> tenths -> 0.2     4 -> hundredths -> 0.04
--   3.61: 6 -> tenths -> 0.6     1 -> hundredths -> 0.01
--   5.18: 1 -> tenths            8 -> hundredths
--   2.94: 9 -> tenths            4 -> hundredths
--   6.47: 4 -> tenths            7 -> hundredths
--   8.35: 3 -> tenths            5 -> hundredths -> 0.05
--   4.72: 7 -> tenths -> 0.7     2 -> hundredths
--   1.59: 5 -> tenths            9 -> hundredths -> 0.09
--   6.45: 4 -> tenths -> 0.4     5 -> hundredths
--   8.73: 7 -> tenths            3 -> hundredths -> 0.03
--   3.29: 2 -> tenths            9 -> hundredths
--   9.16: 1 -> tenths            6 -> hundredths
--   5.84: 8 -> tenths -> 0.8     4 -> hundredths
--   2.67: 6 -> tenths            7 -> hundredths -> 0.07
--   7.53: 5 -> tenths            3 -> hundredths -> 0.03
--   4.98: read as "four and ninety-eight hundredths"
-- Every distractor was checked to NOT be numerically or textually equal to
-- the correct choice.
-- =============================================================================

do $$
declare
  v_lesson10_id uuid;
  v_quiz10_id   uuid;

  -- Quiz 10 — Place Value and Value of Decimal Digits
  v_q10_1  uuid; v_q10_2  uuid; v_q10_3  uuid; v_q10_4  uuid; v_q10_5  uuid;
  v_q10_6  uuid; v_q10_7  uuid; v_q10_8  uuid; v_q10_9  uuid; v_q10_10 uuid;
begin

  -- ===========================================================================
  -- Quiz 10 — built-in Internal Quiz for Lesson 10
  -- (created first so its id can be set directly on the lesson insert below)
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 10: Place Value and Value of Decimal Digits',
    'internal', 'built_in', null, 'grade_4', true, true
  )
  returning id into v_quiz10_id;

  -- --- Q1 -------------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value and Value of Decimal Digits',
    'What is the place of 4 in 6.45?',
    '4 is the first digit after the decimal point in 6.45, so 4 is in the tenths place.'
  )
  returning id into v_q10_1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10_1, 'Tenths place',    true,  1),
    (v_q10_1, 'Hundredths place', false, 2),
    (v_q10_1, 'Ones place',      false, 3),
    (v_q10_1, 'Hundreds place',  false, 4);

  -- --- Q2 -------------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value and Value of Decimal Digits',
    'What is the value of 4 in 6.45?',
    '4 is in the tenths place in 6.45, so its value is 4 tenths, or 0.4.'
  )
  returning id into v_q10_2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10_2, '0.4',   true,  1),
    (v_q10_2, '0.04',  false, 2),
    (v_q10_2, '4.0',   false, 3),
    (v_q10_2, '0.004', false, 4);

  -- --- Q3 -------------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value and Value of Decimal Digits',
    'What is the place of 3 in 8.73?',
    '3 is the second digit after the decimal point in 8.73, so 3 is in the hundredths place.'
  )
  returning id into v_q10_3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10_3, 'Hundredths place', true,  1),
    (v_q10_3, 'Tenths place',     false, 2),
    (v_q10_3, 'Ones place',       false, 3),
    (v_q10_3, 'Tens place',       false, 4);

  -- --- Q4 -------------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value and Value of Decimal Digits',
    'What is the value of 3 in 8.73?',
    '3 is in the hundredths place in 8.73, so its value is 3 hundredths, or 0.03.'
  )
  returning id into v_q10_4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10_4, '0.03',  true,  1),
    (v_q10_4, '0.3',   false, 2),
    (v_q10_4, '3.0',   false, 3),
    (v_q10_4, '0.003', false, 4);

  -- --- Q5 -------------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value and Value of Decimal Digits',
    'Which digit is in the tenths place in 3.29?',
    'The first digit after the decimal point in 3.29 is 2, so 2 is in the tenths place.'
  )
  returning id into v_q10_5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10_5, '2', true,  1),
    (v_q10_5, '9', false, 2),
    (v_q10_5, '3', false, 3),
    (v_q10_5, '0', false, 4);

  -- --- Q6 -------------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value and Value of Decimal Digits',
    'Which digit is in the hundredths place in 9.16?',
    'The second digit after the decimal point in 9.16 is 6, so 6 is in the hundredths place.'
  )
  returning id into v_q10_6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10_6, '6', true,  1),
    (v_q10_6, '1', false, 2),
    (v_q10_6, '9', false, 3),
    (v_q10_6, '0', false, 4);

  -- --- Q7 -------------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value and Value of Decimal Digits',
    'In 5.84, what is the value of the digit in the tenths place?',
    'The digit in the tenths place in 5.84 is 8, so its value is 8 tenths, or 0.8.'
  )
  returning id into v_q10_7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10_7, '0.8',   true,  1),
    (v_q10_7, '0.08',  false, 2),
    (v_q10_7, '8.0',   false, 3),
    (v_q10_7, '0.008', false, 4);

  -- --- Q8 -------------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value and Value of Decimal Digits',
    'In 2.67, what is the value of the digit in the hundredths place?',
    'The digit in the hundredths place in 2.67 is 7, so its value is 7 hundredths, or 0.07.'
  )
  returning id into v_q10_8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10_8, '0.07',  true,  1),
    (v_q10_8, '0.7',   false, 2),
    (v_q10_8, '7.0',   false, 3),
    (v_q10_8, '0.007', false, 4);

  -- --- Q9 -------------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value and Value of Decimal Digits',
    'Which digit has a value of 0.03 in 7.53?',
    'A value of 0.03 means 3 hundredths. In 7.53, the digit in the hundredths place is 3.'
  )
  returning id into v_q10_9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10_9, '3', true,  1),
    (v_q10_9, '5', false, 2),
    (v_q10_9, '7', false, 3),
    (v_q10_9, '0', false, 4);

  -- --- Q10 (reading decimals) -------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value and Value of Decimal Digits',
    'How do you read 4.98?',
    '4.98 has a whole number part of 4 and a decimal part of 98 hundredths, so it is read as four and ninety-eight hundredths.'
  )
  returning id into v_q10_10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10_10, 'Four and ninety-eight hundredths', true,  1),
    (v_q10_10, 'Four and ninety-eight tenths',      false, 2),
    (v_q10_10, 'Forty-nine and eight hundredths',   false, 3),
    (v_q10_10, 'Four and eighty-nine hundredths',   false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz10_id, v_q10_1,  1),
    (v_quiz10_id, v_q10_2,  2),
    (v_quiz10_id, v_q10_3,  3),
    (v_quiz10_id, v_q10_4,  4),
    (v_quiz10_id, v_q10_5,  5),
    (v_quiz10_id, v_q10_6,  6),
    (v_quiz10_id, v_q10_7,  7),
    (v_quiz10_id, v_q10_8,  8),
    (v_quiz10_id, v_q10_9,  9),
    (v_quiz10_id, v_q10_10, 10);

  -- ===========================================================================
  -- Lesson 10 — Place Value and Value of Decimal Digits
  -- `body` is the short 1-2 sentence description the lesson list screen
  -- shows (current convention post-0029); full content lives in
  -- `lesson_pages` below. `linked_quiz_id` is set directly to Quiz 10's id.
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level, linked_quiz_id)
  values (
    'Place Value and Value of Decimal Digits',
    'Learn the difference between the place of a decimal digit and its value, covering the tenths and hundredths places, reading decimals, and finding a digit from its place or value.',
    'built_in',
    null,
    'grade_4',
    v_quiz10_id
  )
  returning id into v_lesson10_id;

  -- ===========================================================================
  -- Lesson 10 pages (10 pages)
  -- ===========================================================================
  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson10_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn about decimal place value — especially the difference between the place of a digit and the value of a digit in a decimal number.'
  ),
  (
    v_lesson10_id, 2, 'vocabulary', 'Decimal Place Value',
    E'In a decimal number, each digit has its own place:\n' ||
    E'  the digit before the decimal point is in the ones place\n' ||
    E'  the first digit after the decimal point is in the tenths place\n' ||
    E'  the second digit after the decimal point is in the hundredths place\n\n' ||
    E'For example, in the decimal 4.56:\n' ||
    E'  4 is in the ones place\n' ||
    E'  5 is in the tenths place\n' ||
    E'  6 is in the hundredths place'
  ),
  (
    v_lesson10_id, 3, 'explanation', 'Place vs. Value',
    E'The place of a digit tells us where the digit is located in the number. The value of a digit tells us how much that digit is actually worth.\n\n' ||
    E'For example, in 7.38:\n' ||
    E'  the digit 3 is in the tenths place; its value is 3 tenths, or 0.3\n' ||
    E'  the digit 8 is in the hundredths place; its value is 8 hundredths, or 0.08\n\n' ||
    E'Place tells us where. Value tells us how much.'
  ),
  (
    v_lesson10_id, 4, 'examples', 'Place vs. Value Examples',
    E'Worked Example 1:\n' ||
    E'  In 9.24, the digit 2 is in the tenths place.\n' ||
    E'  Its value is 2 tenths, or 0.2.\n' ||
    E'  The digit 4 is in the hundredths place.\n' ||
    E'  Its value is 4 hundredths, or 0.04.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  In 3.61, the digit 6 is in the tenths place.\n' ||
    E'  Its value is 6 tenths, or 0.6.\n' ||
    E'  The digit 1 is in the hundredths place.\n' ||
    E'  Its value is 1 hundredth, or 0.01.'
  ),
  (
    v_lesson10_id, 5, 'explanation', 'Identifying the Place of a Digit',
    E'To find the place of a digit:\n' ||
    E'  1. Find the decimal point.\n' ||
    E'  2. The first digit to the right of the decimal point is in the tenths place.\n' ||
    E'  3. The second digit to the right of the decimal point is in the hundredths place.\n\n' ||
    E'Example: What is the place of 8 in 5.18?\n' ||
    E'  8 is the second digit after the decimal point, so 8 is in the hundredths place.'
  ),
  (
    v_lesson10_id, 6, 'examples', 'Finding the Place',
    E'Worked Example 3:\n' ||
    E'  In 2.94, what is the place of 9?\n' ||
    E'  9 is the first digit after the decimal point, so 9 is in the tenths place.\n\n' ||
    E'Worked Example 4:\n' ||
    E'  In 6.47, what is the place of 7?\n' ||
    E'  7 is the second digit after the decimal point, so 7 is in the hundredths place.'
  ),
  (
    v_lesson10_id, 7, 'explanation', 'Identifying the Value of a Digit',
    E'To find the value of a digit:\n' ||
    E'  1. Find the digit''s place (tenths or hundredths).\n' ||
    E'  2. If it is in the tenths place, its value is that many tenths, written 0._.\n' ||
    E'  3. If it is in the hundredths place, its value is that many hundredths, written 0.0_.\n\n' ||
    E'Example: What is the value of 5 in 8.35?\n' ||
    E'  5 is in the hundredths place, so its value is 5 hundredths, or 0.05.'
  ),
  (
    v_lesson10_id, 8, 'examples', 'Finding the Value',
    E'Worked Example 5:\n' ||
    E'  In 4.72, what is the value of 7?\n' ||
    E'  7 is in the tenths place, so its value is 7 tenths, or 0.7.\n\n' ||
    E'Worked Example 6:\n' ||
    E'  In 1.59, what is the value of 9?\n' ||
    E'  9 is in the hundredths place, so its value is 9 hundredths, or 0.09.'
  ),
  (
    v_lesson10_id, 9, 'explanation', 'Reading Decimal Numbers',
    E'We read decimals by naming the whole number part, then the digits after the decimal point together with their place.\n\n' ||
    E'For example:\n' ||
    E'  0.4 is read as four tenths\n' ||
    E'  0.25 is read as twenty-five hundredths\n' ||
    E'  6.3 is read as six and three tenths\n' ||
    E'  2.08 is read as two and eight hundredths'
  ),
  (
    v_lesson10_id, 10, 'summary', 'Remember',
    E'  - The place of a digit tells us where it is located in the number.\n' ||
    E'  - The value of a digit tells us how much it represents.\n' ||
    E'  - The first digit after the decimal point is in the tenths place.\n' ||
    E'  - The second digit after the decimal point is in the hundredths place.\n' ||
    E'  - A tenths digit has a value written as 0._; a hundredths digit has a value written as 0.0_.'
  );

end $$;
