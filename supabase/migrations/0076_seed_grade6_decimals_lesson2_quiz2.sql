-- =============================================================================
-- Migration: 0076_seed_grade6_decimals_lesson2_quiz2.sql
-- Content-seeding migration only — no schema changes. `grade_level =
-- 'grade_6'` already exists on the GradeLevel enum (lib/core/models/
-- section.dart), and `lesson_pages` / `lessons.linked_quiz_id` (0028/0032)
-- are already in place, so this seeds directly into `lesson_pages` rather
-- than the old "single lessons.body blob, split later" two-step
-- (0027 -> 0029) that predates 0028.
--
-- Adds:
--   Grade 6 Lesson 2 — Operations with Decimals (13 lesson_pages)
--   Grade 6 Quiz 2   — Operations with Decimals (10 questions)
-- Links the new lesson to the new quiz via `lessons.linked_quiz_id`
-- (convenience shortcut only, per 0032 — never a hard dependency).
--
-- SEQUENCE NOTE: this is Grade 6 Lesson 2 / Quiz 2 in the intended
-- Grade 6 sequence (Lesson 1: Operations with Fractions, Whole Numbers,
-- and Mixed Numbers — not created by this migration; Lesson 2: this
-- migration; Lesson 3: Understanding Ratio and Proportion, seeded
-- separately in 0077). Deliberately does NOT create or modify Lesson 1
-- or any Lesson 3 records.
--
-- Deliberately does NOT use the `worked_example` jsonb POC shape (0030):
-- that shape is fixed to exactly 6 place-value columns for whole-number
-- addition/subtraction and is explicitly scoped as a non-generalizing
-- POC (0030's column comment). Decimal worked examples don't fit that
-- shape, so every worked example here is plain `body` text, matching the
-- standard (non-interactive) lesson_pages format used everywhere outside
-- the two POC pages from 0031.
--
-- DUPLICATE GUARD: the whole seed is wrapped in
-- `if not exists (select 1 from public.lessons where title = ... and
-- grade_level = 'grade_6')`, so re-running this migration is a no-op
-- instead of creating duplicate Lesson 2 / Quiz 2 rows.
--
-- MATH VERIFICATION: every worked example and every quiz question below
-- was independently computed and re-checked before being written into
-- this migration. See the inline comments on each quiz question.
-- All ids are database-generated (gen_random_uuid()) and captured via
-- `returning ... into`, never hardcoded, matching 0027/0029/0031/0033.
-- =============================================================================

do $$
declare
  v_lesson_id uuid;
  v_quiz_id   uuid;

  -- Quiz 2 question ids
  v_q1  uuid; v_q2  uuid; v_q3  uuid; v_q4  uuid; v_q5  uuid;
  v_q6  uuid; v_q7  uuid; v_q8  uuid; v_q9  uuid; v_q10 uuid;
begin

  if exists (
    select 1 from public.lessons
    where title = 'Operations with Decimals'
      and source_type = 'built_in'
      and grade_level = 'grade_6'
  ) then
    raise notice '0076: Grade 6 Lesson 2 (Operations with Decimals) already exists — skipping seed entirely.';
    return;
  end if;

  -- ===========================================================================
  -- Grade 6 Lesson 2 — Operations with Decimals
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Operations with Decimals',
    'Learn how to add, subtract, multiply, and divide decimals, with step-by-step worked examples and real-world word problems involving money and measurement.',
    'built_in',
    null,
    'grade_6'
  )
  returning id into v_lesson_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn how to add, subtract, multiply, and divide decimals, and how to use these operations to solve real-world word problems.'
  ),
  (
    v_lesson_id, 2, 'vocabulary', 'Decimal Place Value Review',
    E'Before we operate on decimals, let''s review decimal place value. In the number 3.256:\n' ||
    E'  3 is in the ones place\n' ||
    E'  2 is in the tenths place\n' ||
    E'  5 is in the hundredths place\n' ||
    E'  6 is in the thousandths place\n\n' ||
    E'Each place to the right of the decimal point is worth one-tenth of the place before it.'
  ),
  (
    v_lesson_id, 3, 'explanation', 'Adding Decimals',
    E'To add decimals, line up the decimal points so that each place value matches (ones under ones, tenths under tenths, and so on). Add zeros as placeholders if one number has fewer decimal places, then add as you would with whole numbers.\n\n' ||
    E'Worked Example:\n' ||
    E'  12.5 + 3.75 = ?\n' ||
    E'  Line up the decimal points, writing 12.5 as 12.50 so both numbers have two decimal places:\n' ||
    E'      12.50\n' ||
    E'    +  3.75\n' ||
    E'  Add each column from right to left: hundredths 0+5=5, tenths 5+7=12 (write 2, carry 1), ones 2+3+1(carried)=6, tens 1+0=1.\n' ||
    E'  Answer: 12.5 + 3.75 = 16.25.'
  ),
  (
    v_lesson_id, 4, 'examples', 'Addition Examples',
    E'Worked Example 1:\n' ||
    E'  8.4 + 2.65 = ?\n' ||
    E'      8.40\n' ||
    E'    + 2.65\n' ||
    E'  Answer: 8.4 + 2.65 = 11.05.\n\n' ||
    E'Worked Example 2 (money):\n' ||
    E'  Maria bought a notebook for ₱45.50 and a pen for ₱12.75. How much did she spend in total?\n' ||
    E'  45.50 + 12.75 = 58.25.\n' ||
    E'  Maria spent a total of ₱58.25.\n\n' ||
    E'Worked Example 3 (three addends):\n' ||
    E'  3.2 + 5.75 + 1.05 = ?\n' ||
    E'  3.20 + 5.75 = 8.95, then 8.95 + 1.05 = 10.00.\n' ||
    E'  Answer: 3.2 + 5.75 + 1.05 = 10.'
  ),
  (
    v_lesson_id, 5, 'explanation', 'Subtracting Decimals',
    E'To subtract decimals, line up the decimal points the same way as with addition, adding zeros as placeholders if needed. Subtract each column from right to left, regrouping (borrowing) whenever the top digit is smaller than the bottom digit.\n\n' ||
    E'Worked Example:\n' ||
    E'  15.6 - 8.25 = ?\n' ||
    E'  Write 15.6 as 15.60 so both numbers have two decimal places:\n' ||
    E'      15.60\n' ||
    E'    -  8.25\n' ||
    E'  Hundredths: 0 - 5, borrow -> 10 - 5 = 5. Tenths: 5(after borrowing) - 2 = 3. Ones: 5 - 8, borrow -> 15 - 8 = 7. Tens: 0 (after borrowing) - 0 = 0.\n' ||
    E'  Answer: 15.6 - 8.25 = 7.35.'
  ),
  (
    v_lesson_id, 6, 'examples', 'Subtraction Examples',
    E'Worked Example 1:\n' ||
    E'  20 - 4.35 = ?\n' ||
    E'      20.00\n' ||
    E'    -  4.35\n' ||
    E'  Answer: 20 - 4.35 = 15.65.\n\n' ||
    E'Worked Example 2 (money):\n' ||
    E'  Jenna had ₱100. She bought a snack for ₱37.25. How much money does she have left?\n' ||
    E'  100.00 - 37.25 = 62.75.\n' ||
    E'  Jenna has ₱62.75 left.\n\n' ||
    E'Worked Example 3 (two-step):\n' ||
    E'  9.5 - 3.75 - 2.1 = ?\n' ||
    E'  9.5 - 3.75 = 5.75, then 5.75 - 2.1 = 3.65.\n' ||
    E'  Answer: 9.5 - 3.75 - 2.1 = 3.65.'
  ),
  (
    v_lesson_id, 7, 'explanation', 'Multiplying Decimals',
    E'To multiply decimals, multiply the numbers as if there were no decimal points at all. Then count the total number of decimal places in both factors combined, and place the decimal point that many places from the right in the product.\n\n' ||
    E'Worked Example:\n' ||
    E'  2.5 x 1.2 = ?\n' ||
    E'  Multiply ignoring the decimal points: 25 x 12 = 300.\n' ||
    E'  Count the decimal places: 2.5 has 1 decimal place, 1.2 has 1 decimal place, for a total of 2.\n' ||
    E'  Place the decimal point 2 places from the right in 300: 3.00.\n' ||
    E'  Answer: 2.5 x 1.2 = 3.'
  ),
  (
    v_lesson_id, 8, 'examples', 'Multiplication Examples',
    E'Worked Example 1:\n' ||
    E'  0.6 x 0.4 = ?\n' ||
    E'  Multiply ignoring decimals: 6 x 4 = 24. Total decimal places: 1 + 1 = 2.\n' ||
    E'  Answer: 0.6 x 0.4 = 0.24.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  3.2 x 2.5 = ?\n' ||
    E'  Multiply ignoring decimals: 32 x 25 = 800. Total decimal places: 1 + 1 = 2.\n' ||
    E'  Answer: 3.2 x 2.5 = 8.\n\n' ||
    E'Worked Example 3 (money):\n' ||
    E'  A pencil costs ₱8.50. How much would 6 pencils cost?\n' ||
    E'  8.50 x 6 = 51.00.\n' ||
    E'  Six pencils would cost ₱51.00.'
  ),
  (
    v_lesson_id, 9, 'explanation', 'Dividing Decimals',
    E'To divide a decimal by a whole number, divide normally and keep the decimal point in the quotient directly above the decimal point in the dividend.\n\n' ||
    E'To divide by a decimal divisor, first move the decimal point in the divisor to the right until it becomes a whole number, then move the decimal point in the dividend the same number of places to the right. Then divide as usual.\n\n' ||
    E'Worked Example 1 (dividing by a whole number):\n' ||
    E'  8.4 / 4 = ?\n' ||
    E'  Answer: 8.4 / 4 = 2.1.\n\n' ||
    E'Worked Example 2 (dividing by a decimal):\n' ||
    E'  6.4 / 0.8 = ?\n' ||
    E'  Move the decimal point 1 place to the right in both numbers: 6.4 becomes 64, and 0.8 becomes 8.\n' ||
    E'  Now divide: 64 / 8 = 8.\n' ||
    E'  Answer: 6.4 / 0.8 = 8.'
  ),
  (
    v_lesson_id, 10, 'examples', 'Division Examples',
    E'Worked Example 1:\n' ||
    E'  12.6 / 3 = ?\n' ||
    E'  Answer: 12.6 / 3 = 4.2.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  4.5 / 0.5 = ?\n' ||
    E'  Move the decimal point 1 place to the right in both numbers: 4.5 becomes 45, and 0.5 becomes 5.\n' ||
    E'  Now divide: 45 / 5 = 9.\n' ||
    E'  Answer: 4.5 / 0.5 = 9.\n\n' ||
    E'Worked Example 3 (money):\n' ||
    E'  ₱37.50 is shared equally among 5 students. How much does each student get?\n' ||
    E'  37.50 / 5 = 7.50.\n' ||
    E'  Each student gets ₱7.50.'
  ),
  (
    v_lesson_id, 11, 'examples', 'Decimal Word Problems',
    E'Worked Example 1 (multiplication + addition):\n' ||
    E'  Ron bought 3 notebooks at ₱25.75 each and a ruler for ₱15.50. How much did he spend in total?\n' ||
    E'  Cost of notebooks: 25.75 x 3 = 77.25.\n' ||
    E'  Total cost: 77.25 + 15.50 = 92.75.\n' ||
    E'  Ron spent a total of ₱92.75.\n\n' ||
    E'Worked Example 2 (division):\n' ||
    E'  A ribbon that is 12.6 meters long is cut into 6 equal pieces. How long is each piece?\n' ||
    E'  12.6 / 6 = 2.1.\n' ||
    E'  Each piece is 2.1 meters long.\n\n' ||
    E'Worked Example 3 (two-step subtraction):\n' ||
    E'  Mrs. Cruz bought 4.5 kg of rice. She used 1.8 kg for lunch and 1.2 kg for dinner. How many kilograms of rice are left?\n' ||
    E'  4.5 - 1.8 = 2.7, then 2.7 - 1.2 = 1.5.\n' ||
    E'  There are 1.5 kg of rice left.'
  ),
  (
    v_lesson_id, 12, 'examples', 'Real-World Applications',
    E'Worked Example 1 (distance):\n' ||
    E'  A runner ran 5.75 km in the morning and 3.4 km in the afternoon. What is the total distance run?\n' ||
    E'  5.75 + 3.4 = 9.15.\n' ||
    E'  The runner covered a total of 9.15 km.\n\n' ||
    E'Worked Example 2 (weight):\n' ||
    E'  A box of apples weighs 12.4 kg. If it is divided equally among 4 baskets, how much does each basket weigh?\n' ||
    E'  12.4 / 4 = 3.1.\n' ||
    E'  Each basket weighs 3.1 kg.\n\n' ||
    E'Worked Example 3 (capacity):\n' ||
    E'  A bottle holds 1.5 liters of juice. How many liters are there in 8 bottles?\n' ||
    E'  1.5 x 8 = 12.\n' ||
    E'  Eight bottles hold 12 liters of juice in total.'
  ),
  (
    v_lesson_id, 13, 'summary', 'Remember',
    E'  - To add or subtract decimals, line up the decimal points and add zeros as placeholders if needed.\n' ||
    E'  - To multiply decimals, multiply as if there were no decimal points, then count the total decimal places in both factors to place the decimal point in the product.\n' ||
    E'  - To divide by a decimal, move the decimal point in the divisor to make it a whole number, and move the decimal point in the dividend the same number of places.\n' ||
    E'  - Always check that your answer makes sense for the situation.\n' ||
    E'  - Decimal operations are used often in real life — money, measurements, distances, weight, and capacity.'
  );

  -- ===========================================================================
  -- Grade 6 Quiz 2 — built-in Internal Quiz for Lesson 2
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 2: Operations with Decimals',
    'internal', 'built_in', null, 'grade_6', true, true
  )
  returning id into v_quiz_id;

  -- --- Q1 (addition, basic computation) --------------------------------------
  -- 6.35 + 2.80 = 9.15.
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Decimals',
    'What is 6.35 + 2.8?',
    'Line up the decimal points, writing 2.8 as 2.80: 6.35 + 2.80. Adding column by column gives 9.15.'
  )
  returning id into v_q1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1, '9.15', true, 1),
    (v_q1, '6.63', false, 2),
    (v_q1, '9.05', false, 3),
    (v_q1, '8.15', false, 4);

  -- --- Q2 (subtraction, basic computation) ------------------------------------
  -- 14.20 - 5.75 = 8.45.
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Decimals',
    'What is 14.2 - 5.75?',
    'Line up the decimal points, writing 14.2 as 14.20: 14.20 - 5.75. Subtracting with regrouping gives 8.45.'
  )
  returning id into v_q2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2, '8.45', true, 1),
    (v_q2, '9.55', false, 2),
    (v_q2, '8.55', false, 3),
    (v_q2, '9.45', false, 4);

  -- --- Q3 (multiplication, basic computation) ---------------------------------
  -- 7 x 5 = 35, decimal places = 1+1 = 2 -> 0.35.
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Decimals',
    'What is 0.7 x 0.5?',
    'Multiply ignoring the decimal points: 7 x 5 = 35. Both factors have 1 decimal place, for a total of 2 decimal places, so the product is 0.35.'
  )
  returning id into v_q3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q3, '0.35', true, 1),
    (v_q3, '3.5', false, 2),
    (v_q3, '0.035', false, 3),
    (v_q3, '0.12', false, 4);

  -- --- Q4 (division, basic computation) ---------------------------------------
  -- 9.6 / 3 = 3.2.
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Decimals',
    'What is 9.6 / 3?',
    'Dividing a decimal by a whole number, keep the decimal point aligned in the quotient: 9.6 / 3 = 3.2.'
  )
  returning id into v_q4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q4, '3.2', true, 1),
    (v_q4, '3.02', false, 2),
    (v_q4, '32', false, 3),
    (v_q4, '2.9', false, 4);

  -- --- Q5 (interpreting/setup: decimal alignment) -----------------------------
  -- Tests understanding of alignment, not computation.
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Decimals',
    'Which addition problem below is set up correctly, with the decimal points aligned, to add 4.6 and 12.35?',
    '4.6 can be written as 4.60 without changing its value. Lining up "4.60 + 12.35" keeps ones under ones, tenths under tenths, and hundredths under hundredths — the correct setup.'
  )
  returning id into v_q5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5, '4.60 + 12.35', true, 1),
    (v_q5, '4.6 + 1.235', false, 2),
    (v_q5, '46.0 + 12.35', false, 3),
    (v_q5, '4.6 + 123.5', false, 4);

  -- --- Q6 (multiplication: decimal-place reasoning, not full computation) ------
  -- 3.25 (2 dp) x 4.2 (1 dp) -> 3 decimal places in the product.
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Decimals',
    'When multiplying 3.25 x 4.2, how many decimal places should the product have?',
    '3.25 has 2 decimal places and 4.2 has 1 decimal place. Adding the decimal places of both factors gives 2 + 1 = 3 decimal places in the product.'
  )
  returning id into v_q6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6, '3', true, 1),
    (v_q6, '2', false, 2),
    (v_q6, '1', false, 3),
    (v_q6, '4', false, 4);

  -- --- Q7 (unit rate / division word problem) ----------------------------------
  -- 97.50 / 5 = 19.50.
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Decimals',
    '5 notebooks cost ₱97.50. What is the cost per notebook?',
    'To find the cost per notebook, divide the total cost by the number of notebooks: 97.50 / 5 = 19.50. Each notebook costs ₱19.50.'
  )
  returning id into v_q7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q7, '₱19.50', true, 1),
    (v_q7, '₱19.05', false, 2),
    (v_q7, '₱195.00', false, 3),
    (v_q7, '₱9.75', false, 4);

  -- --- Q8 (multiplying by a power of 10 / decimal-shift reasoning) -------------
  -- 2.4 x 10 = 24.
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Decimals',
    'What is 2.4 x 10?',
    'Multiplying by 10 moves the decimal point one place to the right: 2.4 x 10 = 24.'
  )
  returning id into v_q8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q8, '24', true, 1),
    (v_q8, '2.40', false, 2),
    (v_q8, '0.24', false, 3),
    (v_q8, '240', false, 4);

  -- --- Q9 (multi-step word problem: multiplication + subtraction) --------------
  -- 2 x 52.75 = 105.50; 200 - 105.50 = 94.50.
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Decimals',
    'Liza bought 2 kg of rice at ₱52.75 per kilogram. She paid with a ₱200 bill. How much change did she receive?',
    'First find the total cost: 52.75 x 2 = 105.50. Then subtract from the amount paid: 200 - 105.50 = 94.50. Liza received ₱94.50 in change.'
  )
  returning id into v_q9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9, '₱94.50', true, 1),
    (v_q9, '₱147.25', false, 2),
    (v_q9, '₱94.05', false, 3),
    (v_q9, '₱105.50', false, 4);

  -- --- Q10 (real-world application: area, multiplication) ------------------------
  -- 8.5 x 3.2 = 27.2.
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Decimals',
    'A rectangular garden has a length of 8.5 meters and a width of 3.2 meters. What is its area in square meters? (Area = length x width)',
    'Multiply the length and width: 8.5 x 3.2. Ignoring decimals, 85 x 32 = 2,720. Both factors have 1 decimal place each, for a total of 2 decimal places, so the area is 27.2 square meters.'
  )
  returning id into v_q10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10, '27.2 m²', true, 1),
    (v_q10, '11.7 m²', false, 2),
    (v_q10, '2.72 m²', false, 3),
    (v_q10, '272 m²', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz_id, v_q1,  1),
    (v_quiz_id, v_q2,  2),
    (v_quiz_id, v_q3,  3),
    (v_quiz_id, v_q4,  4),
    (v_quiz_id, v_q5,  5),
    (v_quiz_id, v_q6,  6),
    (v_quiz_id, v_q7,  7),
    (v_quiz_id, v_q8,  8),
    (v_quiz_id, v_q9,  9),
    (v_quiz_id, v_q10, 10);

  -- ===========================================================================
  -- Link Lesson 2 -> Quiz 2 (0032 convenience shortcut, never a dependency)
  -- ===========================================================================
  update public.lessons
  set linked_quiz_id = v_quiz_id
  where id = v_lesson_id;

end $$;
