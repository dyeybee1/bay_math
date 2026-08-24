-- =============================================================================
-- Migration: 0027_seed_grade4_addition_subtraction_comparison.sql
-- Content-seeding migration, separate from the schema change in 0026 by
-- design (schema first, content second).
--
-- Seeds Grade 4 (MELC-level) built-in content:
--   Lesson 1 — Addition and Subtraction of Numbers up to 1,000,000
--   Lesson 2 — Comparing Numbers up to 1,000,000
--   Quiz 1   — Internal Quiz for Lesson 1 (10 questions, addition + subtraction, mixed)
--   Quiz 2   — Internal Quiz for Lesson 2 (10 questions, comparison using =, <, >)
--
-- All ids are database-generated (gen_random_uuid(), the default on every
-- affected table's id column) and captured via `returning ... into`, never
-- hardcoded. lessons/quizzes/question_bank rows use source_type = 'built_in',
-- created_by = null, grade_level = 'grade_4' (lessons/quizzes only —
-- question_bank has no grade_level column, per the 0026 design discussion).
-- question_bank.topic is tagged to match the owning lesson's title, for the
-- Highest/Lowest Performing Topics dashboard metric (schema comment, 0008).
--
-- Each question's 4 choices are inserted in a single statement, so the
-- deferred `enforce_at_least_one_correct` constraint trigger (0014) never
-- observes a question with zero correct choices mid-transaction.
-- =============================================================================

do $$
declare
  v_lesson1_id uuid;
  v_lesson2_id uuid;
  v_quiz1_id   uuid;
  v_quiz2_id   uuid;

  -- Quiz 1 — Addition and Subtraction
  v_q1_1  uuid; v_q1_2  uuid; v_q1_3  uuid; v_q1_4  uuid; v_q1_5  uuid;
  v_q1_6  uuid; v_q1_7  uuid; v_q1_8  uuid; v_q1_9  uuid; v_q1_10 uuid;

  -- Quiz 2 — Comparing Numbers
  v_q2_1  uuid; v_q2_2  uuid; v_q2_3  uuid; v_q2_4  uuid; v_q2_5  uuid;
  v_q2_6  uuid; v_q2_7  uuid; v_q2_8  uuid; v_q2_9  uuid; v_q2_10 uuid;
begin

  -- ===========================================================================
  -- Lesson 1 — Addition and Subtraction of Numbers up to 1,000,000
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Addition and Subtraction of Numbers up to 1,000,000',
    E'In this lesson, we will add and subtract whole numbers with up to 7 digits — numbers up to 1,000,000 (one million).\n\n'
    'PLACE VALUE REVIEW\n'
    'Before adding or subtracting large numbers, it helps to see each digit''s place value. In the number 456,789:\n'
    '  4 is in the hundred thousands place\n'
    '  5 is in the ten thousands place\n'
    '  6 is in the thousands place\n'
    '  7 is in the hundreds place\n'
    '  8 is in the tens place\n'
    '  9 is in the ones place\n\n'
    'ADDING NUMBERS WITH SUMS UP TO 1,000,000\n'
    'To add large numbers, line up the digits by place value (ones under ones, tens under tens, and so on), then add each column from right to left, regrouping (carrying) whenever a column adds up to 10 or more.\n\n'
    'Worked Example 1:\n'
    '  245,000 + 132,500 = ?\n'
    '  Line up the numbers:\n'
    '      245,000\n'
    '    + 132,500\n'
    '  Add the ones, tens, and hundreds first: 000 + 500 = 500.\n'
    '  Add the thousands: 245 (thousands) + 132 (thousands) = 377 (thousands).\n'
    '  Answer: 245,000 + 132,500 = 377,500.\n\n'
    'Worked Example 2 (with regrouping):\n'
    '  512,340 + 87,660 = ?\n'
    '      512,340\n'
    '    +  87,660\n'
    '  Ones: 0 + 0 = 0.\n'
    '  Tens: 4 + 6 = 10 -> write 0, carry 1 to the hundreds.\n'
    '  Hundreds: 3 + 6 + 1(carried) = 10 -> write 0, carry 1 to the thousands.\n'
    '  Thousands: 2 + 7 + 1(carried) = 10 -> write 0, carry 1 to the ten thousands.\n'
    '  Ten thousands: 1 + 8 + 1(carried) = 10 -> write 0, carry 1 to the hundred thousands.\n'
    '  Hundred thousands: 5 + 0 + 1(carried) = 6.\n'
    '  Answer: 512,340 + 87,660 = 600,000.\n\n'
    'SUBTRACTING NUMBERS (BOTH NUMBERS LESS THAN 1,000,000)\n'
    'To subtract, line up the digits the same way, then subtract each column from right to left. Whenever the top digit in a column is smaller than the bottom digit, regroup (borrow) 1 from the column to its left.\n\n'
    'Worked Example 3:\n'
    '  875,432 - 432,432 = ?\n'
    '      875,432\n'
    '    - 432,432\n'
    '  Ones: 2 - 2 = 0.  Tens: 3 - 3 = 0.  Hundreds: 4 - 4 = 0.\n'
    '  Thousands: 5 - 2 = 3.  Ten thousands: 7 - 3 = 4.  Hundred thousands: 8 - 4 = 4.\n'
    '  Answer: 875,432 - 432,432 = 443,000.\n\n'
    'Worked Example 4 (with regrouping across zeros):\n'
    '  700,000 - 256,789 = ?\n'
    '  Since 700,000 has zeros in every place except the hundred thousands, we must regroup across several columns at once: borrow from the 7 (hundred thousands), which turns the number into 6 hundred-thousands, 9 ten-thousands, 9 thousands, 9 hundreds, 9 tens, and 10 ones — then subtract normally.\n'
    '      6 9 9 9 9 10\n'
    '      7 0 0 0 0 0\n'
    '    - 2 5 6 7 8 9\n'
    '    -----------\n'
    '      4 4 3 2 1 1\n'
    '  Answer: 700,000 - 256,789 = 443,211.\n\n'
    'REMEMBER\n'
    '  - Always line up the digits by place value before adding or subtracting.\n'
    '  - Work from right to left (ones, then tens, then hundreds, and so on).\n'
    '  - Regroup (carry) when a column in addition totals 10 or more.\n'
    '  - Regroup (borrow) when the top digit in subtraction is smaller than the bottom digit.'
    ,
    'built_in',
    null,
    'grade_4'
  )
  returning id into v_lesson1_id;

  -- ===========================================================================
  -- Lesson 2 — Comparing Numbers up to 1,000,000
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Comparing Numbers up to 1,000,000',
    E'In this lesson, we will compare whole numbers up to 1,000,000 using the symbols = (equal to), < (less than), and > (greater than).\n\n'
    'HOW TO COMPARE LARGE NUMBERS\n'
    'To compare two numbers:\n'
    '  1. First compare the number of digits. A number with more digits is always greater (for example, a 7-digit number is always greater than a 6-digit number).\n'
    '  2. If both numbers have the same number of digits, compare digit by digit starting from the leftmost (highest) place value.\n'
    '  3. Move one place to the right only when the digits in the current place are the same.\n'
    '  4. The first place value where the digits differ decides which number is greater.\n'
    '  5. If every digit is exactly the same, the numbers are equal.\n\n'
    'Worked Example 1 (using >):\n'
    '  Compare 723,450 and 723,405.\n'
    '      7 2 3 4 5 0\n'
    '      7 2 3 4 0 5\n'
    '  Hundred thousands, ten thousands, thousands, and hundreds are the same (7, 2, 3, 4).\n'
    '  At the tens place: 5 versus 0. Since 5 is greater than 0,\n'
    '  723,450 > 723,405.\n\n'
    'Worked Example 2 (using <):\n'
    '  Compare 305,678 and 350,678.\n'
    '      3 0 5 6 7 8\n'
    '      3 5 0 6 7 8\n'
    '  The hundred thousands digit is the same (3).\n'
    '  At the ten thousands place: 0 versus 5. Since 0 is less than 5,\n'
    '  305,678 < 350,678.\n\n'
    'Worked Example 3 (using =):\n'
    '  Compare 640,000 and 640,000.\n'
    '  Every digit matches exactly, so\n'
    '  640,000 = 640,000.\n\n'
    'Worked Example 4 (different number of digits):\n'
    '  Compare 999,999 and 1,000,000.\n'
    '  999,999 has 6 digits. 1,000,000 has 7 digits.\n'
    '  A number with more digits is always greater, so\n'
    '  999,999 < 1,000,000.\n\n'
    'REMEMBER\n'
    '  - Compare the number of digits first.\n'
    '  - If the digit count is the same, compare from the leftmost place value going right.\n'
    '  - Stop as soon as you find a place value where the digits are different — that place decides the answer.\n'
    '  - Use > for greater than, < for less than, and = for equal to.'
    ,
    'built_in',
    null,
    'grade_4'
  )
  returning id into v_lesson2_id;

  -- ===========================================================================
  -- Quiz 1 — built-in Internal Quiz for Lesson 1
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 1: Addition and Subtraction of Numbers up to 1,000,000',
    'internal', 'built_in', null, 'grade_4', true, true
  )
  returning id into v_quiz1_id;

  -- --- Q1 ---------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Addition and Subtraction of Numbers up to 1,000,000',
    'What is 245,000 + 132,500?',
    'Line up the numbers by place value. The ones, tens, and hundreds add to 000 + 500 = 500. The thousands add to 245 + 132 = 377 (thousands). So 245,000 + 132,500 = 377,500.'
  )
  returning id into v_q1_1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_1, '377,500', true,  1),
    (v_q1_1, '367,500', false, 2),
    (v_q1_1, '377,000', false, 3),
    (v_q1_1, '387,500', false, 4);

  -- --- Q2 ---------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Addition and Subtraction of Numbers up to 1,000,000',
    'What is 512,340 + 87,660?',
    'Adding column by column with carrying: ones 0+0=0; tens 4+6=10, write 0 carry 1; hundreds 3+6+1=10, write 0 carry 1; thousands 2+7+1=10, write 0 carry 1; ten thousands 1+8+1=10, write 0 carry 1; hundred thousands 5+0+1=6. Result: 512,340 + 87,660 = 600,000.'
  )
  returning id into v_q1_2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_2, '600,000', true,  1),
    (v_q1_2, '599,000', false, 2),
    (v_q1_2, '610,000', false, 3),
    (v_q1_2, '590,000', false, 4);

  -- --- Q3 ---------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Addition and Subtraction of Numbers up to 1,000,000',
    'What is 999,999 + 1?',
    'Adding 1 to 999,999 causes every place to regroup in a chain: the ones 9+1=10 carries into the tens, which carries into the hundreds, and so on all the way to the hundred thousands place. The result is 1,000,000.'
  )
  returning id into v_q1_3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_3, '1,000,000', true,  1),
    (v_q1_3, '999,999',   false, 2),
    (v_q1_3, '1,000,999', false, 3),
    (v_q1_3, '1,900,000', false, 4);

  -- --- Q4 ---------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Addition and Subtraction of Numbers up to 1,000,000',
    'What is 875,432 - 432,432?',
    'Subtracting column by column: ones 2-2=0; tens 3-3=0; hundreds 4-4=0; thousands 5-2=3; ten thousands 7-3=4; hundred thousands 8-4=4. Result: 875,432 - 432,432 = 443,000.'
  )
  returning id into v_q1_4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_4, '443,000', true,  1),
    (v_q1_4, '433,000', false, 2),
    (v_q1_4, '443,432', false, 3),
    (v_q1_4, '453,000', false, 4);

  -- --- Q5 ---------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Addition and Subtraction of Numbers up to 1,000,000',
    'What is 700,000 - 256,789?',
    'Since 700,000 has zeros in every place except the hundred thousands, borrow from the 7 to turn it into 6 hundred-thousands, 9 ten-thousands, 9 thousands, 9 hundreds, 9 tens, and 10 ones, then subtract normally: 699,9(10) - 256,789 = 443,211. So 700,000 - 256,789 = 443,211.'
  )
  returning id into v_q1_5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_5, '443,211', true,  1),
    (v_q1_5, '444,211', false, 2),
    (v_q1_5, '453,211', false, 3),
    (v_q1_5, '443,311', false, 4);

  -- --- Q6 ---------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Addition and Subtraction of Numbers up to 1,000,000',
    'What is 500,000 - 123,456?',
    'Borrowing across the zeros in 500,000: it becomes 4 hundred-thousands, 9 ten-thousands, 9 thousands, 9 hundreds, 9 tens, and 10 ones. Subtracting: 499,9(10) - 123,456 = 376,544. So 500,000 - 123,456 = 376,544.'
  )
  returning id into v_q1_6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_6, '376,544', true,  1),
    (v_q1_6, '376,554', false, 2),
    (v_q1_6, '386,544', false, 3),
    (v_q1_6, '376,444', false, 4);

  -- --- Q7 ---------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Addition and Subtraction of Numbers up to 1,000,000',
    'What is 456,789 + 234,211?',
    'Adding column by column with carrying: ones 9+1=10, carry 1; tens 8+1+1=10, carry 1; hundreds 7+2+1=10, carry 1; thousands 6+4+1=11, carry 1; ten thousands 5+3+1=9; hundred thousands 4+2=6. Result: 456,789 + 234,211 = 691,000.'
  )
  returning id into v_q1_7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_7, '691,000', true,  1),
    (v_q1_7, '691,900', false, 2),
    (v_q1_7, '681,000', false, 3),
    (v_q1_7, '690,000', false, 4);

  -- --- Q8 ---------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Addition and Subtraction of Numbers up to 1,000,000',
    'What is 999,998 - 888,887?',
    'Subtracting column by column, no borrowing needed since every top digit is at least as large as the bottom digit: ones 8-7=1; tens 9-8=1; hundreds 9-8=1; thousands 9-8=1; ten thousands 9-8=1; hundred thousands 9-8=1. Result: 999,998 - 888,887 = 111,111.'
  )
  returning id into v_q1_8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_8, '111,111', true,  1),
    (v_q1_8, '111,011', false, 2),
    (v_q1_8, '101,111', false, 3),
    (v_q1_8, '110,111', false, 4);

  -- --- Q9 (word problem, addition) ---------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Addition and Subtraction of Numbers up to 1,000,000',
    'Barangay Masagana had 350,275 registered voters. After a voter registration drive, 128,725 new voters were added. What is the total number of registered voters now?',
    'This is an addition problem: 350,275 + 128,725. Adding column by column with carrying gives 350,275 + 128,725 = 479,000. So the barangay now has 479,000 registered voters.'
  )
  returning id into v_q1_9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_9, '479,000 voters', true,  1),
    (v_q1_9, '478,000 voters', false, 2),
    (v_q1_9, '480,000 voters', false, 3),
    (v_q1_9, '469,000 voters', false, 4);

  -- --- Q10 (word problem, subtraction) -------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Addition and Subtraction of Numbers up to 1,000,000',
    'A school cooperative had a budget of ₱850,000 for the school year. So far, they have spent ₱375,600 on books and supplies. How much of the budget remains?',
    'This is a subtraction problem: 850,000 - 375,600. Subtracting with regrouping gives 850,000 - 375,600 = 474,400. So ₱474,400 of the budget remains.'
  )
  returning id into v_q1_10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_10, '₱474,400', true,  1),
    (v_q1_10, '₱475,400', false, 2),
    (v_q1_10, '₱464,400', false, 3),
    (v_q1_10, '₱474,600', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz1_id, v_q1_1,  1),
    (v_quiz1_id, v_q1_2,  2),
    (v_quiz1_id, v_q1_3,  3),
    (v_quiz1_id, v_q1_4,  4),
    (v_quiz1_id, v_q1_5,  5),
    (v_quiz1_id, v_q1_6,  6),
    (v_quiz1_id, v_q1_7,  7),
    (v_quiz1_id, v_q1_8,  8),
    (v_quiz1_id, v_q1_9,  9),
    (v_quiz1_id, v_q1_10, 10);

  -- ===========================================================================
  -- Quiz 2 — built-in Internal Quiz for Lesson 2
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 2: Comparing Numbers up to 1,000,000',
    'internal', 'built_in', null, 'grade_4', true, true
  )
  returning id into v_quiz2_id;

  -- --- Q1 -----------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing Numbers up to 1,000,000',
    'Which statement correctly compares 456,789 and 456,798?',
    'The digits match through the hundreds place (4,5,6,7). At the tens place, 8 is less than 9, so 456,789 < 456,798.'
  )
  returning id into v_q2_1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2_1, '456,789 < 456,798', true,  1),
    (v_q2_1, '456,789 > 456,798', false, 2),
    (v_q2_1, '456,789 = 456,798', false, 3),
    (v_q2_1, 'Cannot be compared', false, 4);

  -- --- Q2 -----------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing Numbers up to 1,000,000',
    'Which statement correctly compares 723,450 and 723,405?',
    'The digits match through the hundreds place (7,2,3,4). At the tens place, 5 is greater than 0, so 723,450 > 723,405.'
  )
  returning id into v_q2_2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2_2, '723,450 < 723,405', false, 1),
    (v_q2_2, '723,450 > 723,405', true,  2),
    (v_q2_2, '723,450 = 723,405', false, 3),
    (v_q2_2, 'Cannot be compared', false, 4);

  -- --- Q3 -----------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing Numbers up to 1,000,000',
    'Which statement correctly compares 999,000 and 999,000?',
    'Every digit in both numbers is identical, so 999,000 = 999,000.'
  )
  returning id into v_q2_3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2_3, '999,000 < 999,000', false, 1),
    (v_q2_3, '999,000 > 999,000', false, 2),
    (v_q2_3, '999,000 = 999,000', true,  3),
    (v_q2_3, 'Cannot be compared', false, 4);

  -- --- Q4 -----------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing Numbers up to 1,000,000',
    'Which statement correctly compares 305,678 and 350,678?',
    'The hundred thousands digit matches (3). At the ten thousands place, 0 is less than 5, so 305,678 < 350,678.'
  )
  returning id into v_q2_4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2_4, '305,678 < 350,678', true,  1),
    (v_q2_4, '305,678 > 350,678', false, 2),
    (v_q2_4, '305,678 = 350,678', false, 3),
    (v_q2_4, 'Cannot be compared', false, 4);

  -- --- Q5 -----------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing Numbers up to 1,000,000',
    'Which statement correctly compares 640,000 and 640,000?',
    'Every digit in both numbers is identical, so 640,000 = 640,000.'
  )
  returning id into v_q2_5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2_5, '640,000 < 640,000', false, 1),
    (v_q2_5, '640,000 > 640,000', false, 2),
    (v_q2_5, '640,000 = 640,000', true,  3),
    (v_q2_5, 'Cannot be compared', false, 4);

  -- --- Q6 -----------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing Numbers up to 1,000,000',
    'Which statement correctly compares 458,900 and 458,090?',
    'The digits match through the thousands place (4,5,8). At the hundreds place, 9 is greater than 0, so 458,900 > 458,090.'
  )
  returning id into v_q2_6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2_6, '458,900 < 458,090', false, 1),
    (v_q2_6, '458,900 > 458,090', true,  2),
    (v_q2_6, '458,900 = 458,090', false, 3),
    (v_q2_6, 'Cannot be compared', false, 4);

  -- --- Q7 -----------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing Numbers up to 1,000,000',
    'Which statement correctly compares 100,001 and 100,010?',
    'The digits match through the hundreds place (1,0,0,0). At the tens place, 0 is less than 1, so 100,001 < 100,010.'
  )
  returning id into v_q2_7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2_7, '100,001 < 100,010', true,  1),
    (v_q2_7, '100,001 > 100,010', false, 2),
    (v_q2_7, '100,001 = 100,010', false, 3),
    (v_q2_7, 'Cannot be compared', false, 4);

  -- --- Q8 -----------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing Numbers up to 1,000,000',
    'Which statement correctly compares 999,999 and 1,000,000?',
    '999,999 has 6 digits while 1,000,000 has 7 digits. A number with more digits is always greater, so 999,999 < 1,000,000.'
  )
  returning id into v_q2_8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2_8, '999,999 < 1,000,000', true,  1),
    (v_q2_8, '999,999 > 1,000,000', false, 2),
    (v_q2_8, '999,999 = 1,000,000', false, 3),
    (v_q2_8, 'Cannot be compared', false, 4);

  -- --- Q9 (word problem) ---------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing Numbers up to 1,000,000',
    'Town A has 512,430 residents. Town B has 512,340 residents. Which statement is correct?',
    'The digits match through the thousands place (5,1,2). At the hundreds place, 4 is greater than 3, so 512,430 > 512,340 — Town A has more residents.'
  )
  returning id into v_q2_9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2_9, 'Town A > Town B', true,  1),
    (v_q2_9, 'Town A < Town B', false, 2),
    (v_q2_9, 'Town A = Town B', false, 3),
    (v_q2_9, 'Cannot be compared', false, 4);

  -- --- Q10 (word problem) --------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Comparing Numbers up to 1,000,000',
    'A factory produced 675,000 toys in Year 1 and 675,000 toys in Year 2. Which statement is correct?',
    'Every digit in both production totals is identical, so Year 1 = Year 2 (675,000 = 675,000).'
  )
  returning id into v_q2_10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2_10, 'Year 1 < Year 2', false, 1),
    (v_q2_10, 'Year 1 > Year 2', false, 2),
    (v_q2_10, 'Year 1 = Year 2', true,  3),
    (v_q2_10, 'Cannot be compared', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz2_id, v_q2_1,  1),
    (v_quiz2_id, v_q2_2,  2),
    (v_quiz2_id, v_q2_3,  3),
    (v_quiz2_id, v_q2_4,  4),
    (v_quiz2_id, v_q2_5,  5),
    (v_quiz2_id, v_q2_6,  6),
    (v_quiz2_id, v_q2_7,  7),
    (v_quiz2_id, v_q2_8,  8),
    (v_quiz2_id, v_q2_9,  9),
    (v_quiz2_id, v_q2_10, 10);

end $$;
