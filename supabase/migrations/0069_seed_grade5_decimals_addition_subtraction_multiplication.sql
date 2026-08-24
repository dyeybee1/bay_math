-- =============================================================================
-- Migration: 0069_seed_grade5_decimals_addition_subtraction_multiplication.sql
--
-- Content-seeding migration (schema-only changes are NOT needed here — this
-- reuses `lessons` / `lesson_pages` (0028) / `quizzes` / `question_bank` /
-- `question_choices` / `quiz_questions` / `lessons.linked_quiz_id` (0032)
-- exactly as they already exist).
--
-- Seeds Grade 5 built-in content:
--   Lesson 5 — Adding, Subtracting, and Multiplying Decimals (14 pages)
--   Quiz 5   — Internal Quiz for Lesson 5 (10 questions, mixed
--               addition/subtraction/multiplication of decimals)
--
-- Follows the same pattern as 0027 (seed) + 0029 (pages) + 0033 (link),
-- collapsed into a single migration since — unlike those three, which
-- retrofitted an already-existing lesson/quiz pair created before
-- `lesson_pages` (0028) and `linked_quiz_id` (0032) existed — this lesson
-- and quiz are being created for the first time, together, so there is no
-- need to split "schema first, content second" or to look the ids back up
-- by title in a follow-up migration: both ids are already in scope as
-- local variables in the same DO block.
--
-- All ids are database-generated (gen_random_uuid(), the default on every
-- affected table's id column) and captured via `returning ... into`, never
-- hardcoded. lessons/quizzes/question_bank rows use source_type =
-- 'built_in', created_by = null, grade_level = 'grade_5' (lessons/quizzes
-- only — question_bank has no grade_level column, matching 0027/0008).
-- question_bank.topic is tagged to match the owning lesson's title, for
-- the Highest/Lowest Performing Topics dashboard metric (schema comment,
-- 0008) — same convention 0027 used.
--
-- quizzes.assessment_type (0043) is left null — this is an ordinary
-- practice/graded quiz, not a Pre-Test/Post-Test.
--
-- No `worked_example` (0030) is used on any page here: that column is an
-- explicitly-scoped proof of concept "fixed to exactly 6 place-value
-- columns (Hundred Thousands..Ones)" for whole-number addition/
-- subtraction (see 0030's column comment) and was never built to
-- generalize to decimal place values — every page below uses plain
-- `body` text instead, exactly like every existing page outside that POC
-- (e.g. all of 0029's Grade 4 Lesson 2 pages).
--
-- Each question's 4 choices are inserted in a single statement, so the
-- deferred `enforce_at_least_one_correct` constraint trigger (0014) never
-- observes a question with zero correct choices mid-transaction — same
-- approach 0027 used.
--
-- MATH VERIFIED INDEPENDENTLY (via Decimal arithmetic, not by hand) before
-- writing this migration:
--   12.50 + 3.75 = 16.25        4.50 + 2.35 = 6.85
--   15.80 - 6.45 = 9.35         8.20 - 3.75 = 4.45
--   2.4 × 3 = 7.2                3.15 × 4 = 12.60 (= 12.6)
--   1.2 × 0.3 = 0.36              2.5 × 1.2 = 3.00 (= 3)
--   0.4 × 0.5 = 0.20 (= 0.2)     24.50 + 35.75 = 60.25
--   50.00 - 18.75 = 31.25        15.25 × 4 = 61.00 (= 61)
--   19.8 + 10.2 = 30.0
--   -- quiz (deliberately different numbers from the lesson, same skills) --
--   8.40 + 2.65 = 11.05          9.6 - 3.25 = 6.35
--   3.6 × 4 = 14.4                1.5 × 0.4 = 0.60 (= 0.6)
--   18.25 + 6.50 = 24.75          45.00 - 27.35 = 17.65
--   2.3 × 1.4 = 3.22              0.85 × 5 = 4.25
--   14.9 + 5.3 = 20.2
-- =============================================================================

do $$
declare
  v_lesson5_id uuid;
  v_quiz5_id   uuid;

  v_q_1  uuid; v_q_2  uuid; v_q_3  uuid; v_q_4  uuid; v_q_5  uuid;
  v_q_6  uuid; v_q_7  uuid; v_q_8  uuid; v_q_9  uuid; v_q_10 uuid;
begin

  -- ===========================================================================
  -- Lesson 5 — Adding, Subtracting, and Multiplying Decimals
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Adding, Subtracting, and Multiplying Decimals',
    'Learn to add, subtract, and multiply decimal numbers, with a decimal place-value review and step-by-step worked examples for each operation, including real-life money and measurement problems.',
    'built_in',
    null,
    'grade_5'
  )
  returning id into v_lesson5_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson5_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn how to add, subtract, and multiply decimal numbers. We will review decimal place value, practice lining up decimal points, and use decimals to solve simple real-life problems.'
  ),
  (
    v_lesson5_id, 2, 'vocabulary', 'Decimal Place Value Review',
    E'Before we operate with decimals, let''s review decimal place value. In the number 4.275:\n' ||
    E'  4 is the ones digit\n' ||
    E'  2 is the tenths digit\n' ||
    E'  7 is the hundredths digit\n' ||
    E'  5 is the thousandths digit\n\n' ||
    E'Each place to the right of the decimal point is 10 times smaller than the place before it.'
  ),
  (
    v_lesson5_id, 3, 'explanation', 'Adding Decimals',
    E'To add decimals, line up the decimal points so that ones are under ones, tenths are under tenths, and hundredths are under hundredths. Add zeros as placeholders when the numbers have a different number of decimal places, then add from right to left just like with whole numbers. Bring the decimal point straight down into the answer.\n\n' ||
    E'Steps:\n' ||
    E'  1. Write the numbers so the decimal points line up.\n' ||
    E'  2. Add zeros when needed.\n' ||
    E'  3. Add from right to left.\n' ||
    E'  4. Bring the decimal point straight down.\n' ||
    E'  5. Check whether the answer is reasonable.'
  ),
  (
    v_lesson5_id, 4, 'examples', 'Addition Examples',
    E'Worked Example 1:\n' ||
    E'  12.50 + 3.75 = ?\n' ||
    E'  Line up the decimal points:\n' ||
    E'      12.50\n' ||
    E'    +  3.75\n' ||
    E'    -------\n' ||
    E'      16.25\n' ||
    E'  Answer: 12.50 + 3.75 = 16.25.\n\n' ||
    E'Worked Example 2 (using a placeholder zero):\n' ||
    E'  4.5 + 2.35 = ?\n' ||
    E'  4.5 has only one decimal place, so write it as 4.50.\n' ||
    E'      4.50\n' ||
    E'    + 2.35\n' ||
    E'    -------\n' ||
    E'       6.85\n' ||
    E'  Answer: 4.5 + 2.35 = 6.85.'
  ),
  (
    v_lesson5_id, 5, 'explanation', 'Subtracting Decimals',
    E'To subtract decimals, line up the decimal points the same way you would for addition. Add zeros as placeholders when needed, then subtract from right to left, regrouping (borrowing) whenever the top digit in a column is smaller than the bottom digit.\n\n' ||
    E'Steps:\n' ||
    E'  1. Align the decimal points.\n' ||
    E'  2. Add zeros when needed.\n' ||
    E'  3. Subtract from right to left.\n' ||
    E'  4. Regroup when necessary.\n' ||
    E'  5. Place the decimal point correctly in the answer.\n' ||
    E'  6. Check the answer.'
  ),
  (
    v_lesson5_id, 6, 'examples', 'Subtraction Examples',
    E'Worked Example 1:\n' ||
    E'  15.80 - 6.45 = ?\n' ||
    E'      15.80\n' ||
    E'    -  6.45\n' ||
    E'    -------\n' ||
    E'       9.35\n' ||
    E'  Answer: 15.80 - 6.45 = 9.35.\n\n' ||
    E'Worked Example 2 (using a placeholder zero, with regrouping):\n' ||
    E'  8.2 - 3.75 = ?\n' ||
    E'  8.2 has only one decimal place, so write it as 8.20.\n' ||
    E'      8.20\n' ||
    E'    - 3.75\n' ||
    E'    -------\n' ||
    E'       4.45\n' ||
    E'  The hundredths digit (0) is smaller than 5, so we regroup from the tenths. The tenths digit (2) is then smaller than 7, so we regroup from the ones.\n' ||
    E'  Answer: 8.2 - 3.75 = 4.45.'
  ),
  (
    v_lesson5_id, 7, 'explanation', 'Multiplying Decimals by a Whole Number',
    E'To multiply a decimal by a whole number, first multiply the digits as if there were no decimal point at all. Then count the number of decimal places in the decimal factor, and place the decimal point that many places from the right in the product.'
  ),
  (
    v_lesson5_id, 8, 'examples', 'Multiplying by a Whole Number — Examples',
    E'Worked Example 1:\n' ||
    E'  2.4 × 3 = ?\n' ||
    E'  Multiply as whole numbers: 24 × 3 = 72.\n' ||
    E'  2.4 has 1 decimal place, so the product needs 1 decimal place.\n' ||
    E'  Answer: 2.4 × 3 = 7.2.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  3.15 × 4 = ?\n' ||
    E'  Multiply as whole numbers: 315 × 4 = 1,260.\n' ||
    E'  3.15 has 2 decimal places, so the product needs 2 decimal places.\n' ||
    E'  1,260 with 2 decimal places is 12.60, which is the same as 12.6.\n' ||
    E'  Answer: 3.15 × 4 = 12.6.'
  ),
  (
    v_lesson5_id, 9, 'explanation', 'Multiplying Two Decimals',
    E'When multiplying two decimals, multiply the digits as if there were no decimal points. Then add together the number of decimal places in both factors — that total tells you how many decimal places belong in the product, counting from the right.\n\n' ||
    E'Be extra careful when a factor is less than 1. For example, 0.4 × 0.5 = 0.20, which is the same as 0.2 — not 2 and not 0.02. Always count the decimal places in both factors before placing the decimal point.'
  ),
  (
    v_lesson5_id, 10, 'examples', 'Multiplying Two Decimals — Examples',
    E'Worked Example 1:\n' ||
    E'  1.2 × 0.3 = ?\n' ||
    E'  Multiply as whole numbers: 12 × 3 = 36.\n' ||
    E'  1.2 has 1 decimal place and 0.3 has 1 decimal place, for a total of 2 decimal places.\n' ||
    E'  Answer: 1.2 × 0.3 = 0.36.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  2.5 × 1.2 = ?\n' ||
    E'  Multiply as whole numbers: 25 × 12 = 300.\n' ||
    E'  2.5 has 1 decimal place and 1.2 has 1 decimal place, for a total of 2 decimal places.\n' ||
    E'  300 with 2 decimal places is 3.00, which is the same as 3.\n' ||
    E'  Answer: 2.5 × 1.2 = 3.'
  ),
  (
    v_lesson5_id, 11, 'examples', 'Real-Life Applications',
    E'Addition: A notebook costs ₱24.50 and a pencil case costs ₱35.75. How much do they cost altogether?\n' ||
    E'  24.50 + 35.75 = 60.25\n' ||
    E'  Together they cost ₱60.25.\n\n' ||
    E'Subtraction: Mika has ₱50.00. She buys a storybook for ₱18.75. How much change does she get?\n' ||
    E'  50.00 - 18.75 = 31.25\n' ||
    E'  Mika gets ₱31.25 in change.\n\n' ||
    E'Multiplication: A teacher buys 4 notebooks that cost ₱15.25 each. What is the total cost?\n' ||
    E'  15.25 × 4 = 61.00, which is the same as ₱61.00.\n' ||
    E'  The total cost is ₱61.'
  ),
  (
    v_lesson5_id, 12, 'explanation', 'Checking Whether an Answer Is Reasonable',
    E'Estimating before or after you calculate helps you check whether your exact answer makes sense. Round each decimal to the nearest whole number, then add, subtract, or multiply the rounded numbers.\n\n' ||
    E'For example:\n' ||
    E'  19.8 + 10.2 is close to 20 + 10 = 30.\n' ||
    E'  Since 30 is close to the exact answer (30.0), the exact answer is reasonable.\n\n' ||
    E'If your exact answer is very different from your estimate, check your work for a mistake.'
  ),
  (
    v_lesson5_id, 13, 'explanation', 'Common Mistakes to Avoid',
    E'Addition/Subtraction mistake: Forgetting to line up the decimal points before adding or subtracting.\n\n' ||
    E'Placeholder mistake: Not writing in zero placeholders — for example, thinking 4.5 is smaller than 4.50, when they are actually the same number.\n\n' ||
    E'Multiplication mistake: Placing the decimal point in the wrong spot in the product.\n\n' ||
    E'Decimal-place mistake: Forgetting to count the decimal places in both factors when multiplying two decimals.\n\n' ||
    E'Operation mistake: Using subtraction when a problem calls for addition, or the other way around. Always think about what is happening in the problem before choosing an operation.'
  ),
  (
    v_lesson5_id, 14, 'summary', 'Remember',
    E'  - Always line up the decimal points before adding or subtracting.\n' ||
    E'  - Add zero placeholders when the numbers have different numbers of decimal places.\n' ||
    E'  - To multiply a decimal by a whole number, multiply normally, then place the decimal point using the decimal factor''s number of decimal places.\n' ||
    E'  - To multiply two decimals, add together the number of decimal places in both factors to place the decimal point in the product.\n' ||
    E'  - Estimate to check whether your answer is reasonable.'
  );

  -- ===========================================================================
  -- Quiz 5 — built-in Internal Quiz for Lesson 5
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 5: Adding, Subtracting, and Multiplying Decimals',
    'internal', 'built_in', null, 'grade_5', true, true
  )
  returning id into v_quiz5_id;

  -- --- Q1 (basic addition) --------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Adding, Subtracting, and Multiplying Decimals',
    'What is 8.40 + 2.65?',
    'Line up the decimal points and add from right to left: hundredths 0+5=5, tenths 4+6=10 (write 0, carry 1), ones 8+2+1(carried)=11. So 8.40 + 2.65 = 11.05.'
  )
  returning id into v_q_1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_1, '11.05', true,  1),
    (v_q_1, '10.95', false, 2),
    (v_q_1, '11.15', false, 3),
    (v_q_1, '1.105', false, 4);

  -- --- Q2 (basic/intermediate subtraction, different decimal places) -------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Adding, Subtracting, and Multiplying Decimals',
    'What is 9.6 - 3.25?',
    'Write 9.6 as 9.60 so both numbers have 2 decimal places, then subtract: 9.60 - 3.25 = 6.35.'
  )
  returning id into v_q_2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_2, '6.35', true,  1),
    (v_q_2, '6.25', false, 2),
    (v_q_2, '6.45', false, 3),
    (v_q_2, '7.35', false, 4);

  -- --- Q3 (intermediate: decimal x whole number) ----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Adding, Subtracting, and Multiplying Decimals',
    'What is 3.6 × 4?',
    'Multiply as whole numbers: 36 × 4 = 144. Since 3.6 has 1 decimal place, the product needs 1 decimal place: 3.6 × 4 = 14.4.'
  )
  returning id into v_q_3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_3, '14.4', true,  1),
    (v_q_3, '1.44', false, 2),
    (v_q_3, '144',  false, 3),
    (v_q_3, '14.04', false, 4);

  -- --- Q4 (intermediate: decimal x decimal) ---------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Adding, Subtracting, and Multiplying Decimals',
    'What is 1.5 × 0.4?',
    'Multiply as whole numbers: 15 × 4 = 60. 1.5 has 1 decimal place and 0.4 has 1 decimal place, for a total of 2 decimal places: 60 becomes 0.60, which is the same as 0.6.'
  )
  returning id into v_q_4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_4, '0.6',  true,  1),
    (v_q_4, '6',    false, 2),
    (v_q_4, '0.06', false, 3),
    (v_q_4, '0.15', false, 4);

  -- --- Q5 (application, addition) -------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Adding, Subtracting, and Multiplying Decimals',
    'Ana buys a ruler for ₱18.25 and an eraser for ₱6.50. How much does she spend in all?',
    'This is an addition problem: 18.25 + 6.50 = 24.75. Ana spends ₱24.75 in all.'
  )
  returning id into v_q_5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_5, '₱24.75', true,  1),
    (v_q_5, '₱24.25', false, 2),
    (v_q_5, '₱25.75', false, 3),
    (v_q_5, '₱24.85', false, 4);

  -- --- Q6 (application, subtraction / change) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Adding, Subtracting, and Multiplying Decimals',
    'Jun has ₱45.00. He spends ₱27.35 on school supplies. How much money does he have left?',
    'This is a subtraction problem: 45.00 - 27.35 = 17.65. Jun has ₱17.65 left.'
  )
  returning id into v_q_6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_6, '₱17.65', true,  1),
    (v_q_6, '₱18.65', false, 2),
    (v_q_6, '₱17.75', false, 3),
    (v_q_6, '₱22.65', false, 4);

  -- --- Q7 (reasoning: alignment) ---------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Adding, Subtracting, and Multiplying Decimals',
    'What should you do first before adding 6.4 and 12.75?',
    'Before adding (or subtracting) decimals, you must line up the decimal points so that ones are under ones, tenths are under tenths, and so on. Only after the decimal points are aligned should you add from right to left.'
  )
  returning id into v_q_7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_7, 'Line up the decimal points', true,  1),
    (v_q_7, 'Line up the last digits on the right', false, 2),
    (v_q_7, 'Round both numbers first', false, 3),
    (v_q_7, 'Add only the whole-number parts', false, 4);

  -- --- Q8 (reasoning: decimal placement in a product) -------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Adding, Subtracting, and Multiplying Decimals',
    'A student multiplied 2.3 × 1.4 and wrote the answer as 32.2. What mistake did the student most likely make?',
    '2.3 has 1 decimal place and 1.4 has 1 decimal place, so the product needs 2 decimal places: 23 × 14 = 322, so 2.3 × 1.4 = 3.22. Writing 32.2 instead means the decimal point was placed one place too far to the right.'
  )
  returning id into v_q_8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_8, 'Placed the decimal point one place too far to the right', true,  1),
    (v_q_8, 'Placed the decimal point one place too far to the left', false, 2),
    (v_q_8, 'Forgot to multiply the ones digit', false, 3),
    (v_q_8, 'Added instead of multiplying', false, 4);

  -- --- Q9 (application, multiplication / equal groups) ------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Adding, Subtracting, and Multiplying Decimals',
    'A tailor cuts 5 pieces of ribbon that are each 0.85 meter long. What is the total length of ribbon used?',
    'This is a multiplication problem: 0.85 × 5. Multiply as whole numbers: 85 × 5 = 425. Since 0.85 has 2 decimal places, the product needs 2 decimal places: 0.85 × 5 = 4.25. The total length is 4.25 meters.'
  )
  returning id into v_q_9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_9, '4.25 meters', true,  1),
    (v_q_9, '42.5 meters', false, 2),
    (v_q_9, '4.05 meters', false, 3),
    (v_q_9, '4.35 meters', false, 4);

  -- --- Q10 (reasoning: estimation / reasonableness) ---------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Adding, Subtracting, and Multiplying Decimals',
    'Which is the best estimate for 14.9 + 5.3?',
    'Round each number to the nearest whole number: 14.9 rounds to 15, and 5.3 rounds to 5. 15 + 5 = 20, so about 20 is the best estimate (the exact answer, 20.2, is close to 20).'
  )
  returning id into v_q_10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_10, 'About 20', true,  1),
    (v_q_10, 'About 10', false, 2),
    (v_q_10, 'About 30', false, 3),
    (v_q_10, 'About 15', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz5_id, v_q_1,  1),
    (v_quiz5_id, v_q_2,  2),
    (v_quiz5_id, v_q_3,  3),
    (v_quiz5_id, v_q_4,  4),
    (v_quiz5_id, v_q_5,  5),
    (v_quiz5_id, v_q_6,  6),
    (v_quiz5_id, v_q_7,  7),
    (v_quiz5_id, v_q_8,  8),
    (v_quiz5_id, v_q_9,  9),
    (v_quiz5_id, v_q_10, 10);

  -- ===========================================================================
  -- Link Lesson 5 -> Quiz 5 (0032's linked_quiz_id) — both ids are already
  -- local variables from this same DO block, so no by-title lookup (like
  -- 0033 needed for the pre-existing Grade 4 pair) is necessary here.
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz5_id where id = v_lesson5_id;

end $$;
