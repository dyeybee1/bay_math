-- =============================================================================
-- Migration: 0055_seed_grade4_place_value.sql
-- Content-seeding migration, following the same pattern already used for
-- Grade 4 content: 0027 (lessons.body seed) + 0029 (lesson_pages
-- restructuring) + 0032/0033 (lessons.linked_quiz_id column + linking).
-- Because `lesson_pages` (0028) and `lessons.linked_quiz_id` (0032) already
-- exist as schema by this point, this single migration seeds the lesson
-- directly into paginated `lesson_pages` form and links it to its quiz in
-- one pass, instead of the historical two-step split those columns
-- themselves required back when they were first introduced.
--
-- Seeds Grade 4 (MELC-level) built-in content:
--   Lesson — Place Value of Whole Numbers (9 pages)
--   Quiz   — Quiz 3: Place Value of Whole Numbers (10 questions), linked to
--            the lesson via `lessons.linked_quiz_id` (0032/0033 pattern).
--
-- Numbered "Quiz 3" continuing the sequence after the existing built-in
-- Grade 4 quizzes seeded in 0027 ("Quiz 1: Addition and Subtraction...",
-- "Quiz 2: Comparing Numbers..."). If additional built-in Grade 4 quizzes
-- were added between 0033 and this migration, this title should be
-- renumbered accordingly before applying.
--
-- Scope matches the existing Grade 4 lessons (place values from ones
-- through hundred thousands, i.e. numbers up to 999,999) rather than
-- introducing a millions place, so this lesson stays consistent with the
-- "up to 1,000,000" ceiling already established by the two lessons seeded
-- in 0027.
--
-- All ids are database-generated (gen_random_uuid()) and captured via
-- `returning ... into`, never hardcoded — same approach as 0027.
--
-- Each question's 4 choices are inserted in a single statement, so the
-- deferred `enforce_at_least_one_correct` constraint trigger (0014) never
-- observes a question with zero correct choices mid-transaction — same
-- approach as 0027.
--
-- ARITHMETIC VERIFIED (place/value pairs for every number used below,
-- computed digit-by-digit, not just restated from prose) before writing
-- the lesson pages and quiz questions:
--   528,946: 5=HTh(500,000) 2=TTh(20,000) 8=Th(8,000) 9=H(900) 4=T(40) 6=O(6)
--   673,148: 6=HTh(600,000) 7=TTh(70,000) 3=Th(3,000) 1=H(100) 4=T(40) 8=O(8)
--   304,952: 3=HTh(300,000) 0=TTh(0) 4=Th(4,000) 9=H(900) 5=T(50) 2=O(2)
--   618,392: 6=HTh(600,000) 1=TTh(10,000) 8=Th(8,000) 3=H(300) 9=T(90) 2=O(2)
--   741,265: 7=HTh(700,000) 4=TTh(40,000) 1=Th(1,000) 2=H(200) 6=T(60) 5=O(5)
--   365,479: 3=HTh(300,000) 6=TTh(60,000) 5=Th(5,000) 4=H(400) 7=T(70) 9=O(9)
--   442,187: 4=HTh(400,000) 4=TTh(40,000) 2=Th(2,000) 1=H(100) 8=T(80) 7=O(7)
--   356,819: 3=HTh(300,000) 5=TTh(50,000) 6=Th(6,000) 8=H(800) 1=T(10) 9=O(9)
--   782,145: 7=HTh(700,000) 8=TTh(80,000) 2=Th(2,000) 1=H(100) 4=T(40) 5=O(5)
--   913,462: 9=HTh(900,000) 1=TTh(10,000) 3=Th(3,000) 4=H(400) 6=T(60) 2=O(2)
--   271,584: 2=HTh(200,000) 7=TTh(70,000) 1=Th(1,000) 5=H(500) 8=T(80) 4=O(4)
--   543,267: 5=HTh(500,000) 4=TTh(40,000) 3=Th(3,000) 2=H(200) 6=T(60) 7=O(7)
--   407,089: 4=HTh(400,000) 0=TTh(0) 7=Th(7,000) 0=H(0) 8=T(80) 9=O(9)
--   852,613: 8=HTh(800,000) 5=TTh(50,000) 2=Th(2,000) 6=H(600) 1=T(10) 3=O(3)
--   634,178: 6=HTh(600,000) 3=TTh(30,000) 4=Th(4,000) 1=H(100) 7=T(70) 8=O(8)
--   456,203: 4=HTh(400,000) 5=TTh(50,000) 6=Th(6,000) 2=H(200) 0=T(0) 3=O(3)
-- =============================================================================

do $$
declare
  v_lesson_id uuid;
  v_quiz_id   uuid;

  v_q1  uuid; v_q2  uuid; v_q3  uuid; v_q4  uuid; v_q5  uuid;
  v_q6  uuid; v_q7  uuid; v_q8  uuid; v_q9  uuid; v_q10 uuid;
begin

  -- ===========================================================================
  -- Quiz — created first so its id is available for the lesson's
  -- linked_quiz_id (0032/0033) without a separate follow-up update step.
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 3: Place Value of Whole Numbers',
    'internal', 'built_in', null, 'grade_4', true, true
  )
  returning id into v_quiz_id;

  -- ===========================================================================
  -- Lesson — Place Value of Whole Numbers
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level, linked_quiz_id)
  values (
    'Place Value of Whole Numbers',
    'Learn how to identify the place and value of digits in whole numbers, and how to read and write numbers in standard and expanded form.',
    'built_in',
    null,
    'grade_4',
    v_quiz_id
  )
  returning id into v_lesson_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn about place value — how the position of a digit in a whole number tells us its value. Understanding place value helps us read, write, and compare whole numbers.'
  ),
  (
    v_lesson_id, 2, 'vocabulary', 'Understanding Place Value',
    E'Every digit in a number has a PLACE and a VALUE.\n\n' ||
    E'The PLACE of a digit is its position in the number (ones, tens, hundreds, and so on).\n' ||
    E'The VALUE of a digit is what that digit is worth because of its place.\n\n' ||
    E'Let''s look at the number 528,946:\n' ||
    E'  5 is in the hundred thousands place\n' ||
    E'  2 is in the ten thousands place\n' ||
    E'  8 is in the thousands place\n' ||
    E'  9 is in the hundreds place\n' ||
    E'  4 is in the tens place\n' ||
    E'  6 is in the ones place'
  ),
  (
    v_lesson_id, 3, 'explanation', 'Identifying the Place and Value of a Digit',
    E'To find the VALUE of a digit, multiply the digit by its place value.\n\n' ||
    E'In 528,946:\n' ||
    E'  5 (hundred thousands) has a value of 5 x 100,000 = 500,000\n' ||
    E'  2 (ten thousands) has a value of 2 x 10,000 = 20,000\n' ||
    E'  8 (thousands) has a value of 8 x 1,000 = 8,000\n' ||
    E'  9 (hundreds) has a value of 9 x 100 = 900\n' ||
    E'  4 (tens) has a value of 4 x 10 = 40\n' ||
    E'  6 (ones) has a value of 6 x 1 = 6'
  ),
  (
    v_lesson_id, 4, 'examples', 'Place and Value Examples',
    E'Worked Example 1:\n' ||
    E'  What is the place and value of the digit 7 in 673,148?\n' ||
    E'  The digits are 6 (hundred thousands), 7 (ten thousands), 3 (thousands), 1 (hundreds), 4 (tens), 8 (ones).\n' ||
    E'  The digit 7 is in the ten thousands place.\n' ||
    E'  Its value is 7 x 10,000 = 70,000.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  What is the place and value of the digit 9 in 304,952?\n' ||
    E'  The digits are 3 (hundred thousands), 0 (ten thousands), 4 (thousands), 9 (hundreds), 5 (tens), 2 (ones).\n' ||
    E'  The digit 9 is in the hundreds place.\n' ||
    E'  Its value is 9 x 100 = 900.'
  ),
  (
    v_lesson_id, 5, 'explanation', 'Reading and Writing Numbers in Standard Form',
    E'Standard form is the usual way we write a number, using digits grouped into 3s with commas: 618,392.\n\n' ||
    E'To read a number in standard form, read the digits before the comma first, say "thousand," then read the last three digits.\n\n' ||
    E'618,392 is read as: six hundred eighteen thousand, three hundred ninety-two.'
  ),
  (
    v_lesson_id, 6, 'explanation', 'Writing Numbers in Expanded Form',
    E'Expanded form shows a number as the sum of the values of each of its digits.\n\n' ||
    E'To write a number in expanded form, add together the value of every digit.\n\n' ||
    E'618,392 in expanded form is:\n' ||
    E'  600,000 + 10,000 + 8,000 + 300 + 90 + 2'
  ),
  (
    v_lesson_id, 7, 'examples', 'Expanded Form Examples',
    E'Worked Example 3:\n' ||
    E'  Write 741,265 in expanded form.\n' ||
    E'  7 (hundred thousands) = 700,000\n' ||
    E'  4 (ten thousands) = 40,000\n' ||
    E'  1 (thousands) = 1,000\n' ||
    E'  2 (hundreds) = 200\n' ||
    E'  6 (tens) = 60\n' ||
    E'  5 (ones) = 5\n' ||
    E'  Expanded form: 700,000 + 40,000 + 1,000 + 200 + 60 + 5\n\n' ||
    E'Worked Example 4:\n' ||
    E'  What number is written in expanded form as 300,000 + 60,000 + 5,000 + 400 + 70 + 9?\n' ||
    E'  Add the place values together: 300,000 + 60,000 + 5,000 + 400 + 70 + 9 = 365,479.\n' ||
    E'  Standard form: 365,479'
  ),
  (
    v_lesson_id, 8, 'explanation', 'Comparing the Value of Digits',
    E'Even when two digits in a number look the same, their VALUE depends on their place.\n\n' ||
    E'In 442,187, the digit 4 appears twice:\n' ||
    E'  The first 4 is in the hundred thousands place, so its value is 400,000.\n' ||
    E'  The second 4 is in the ten thousands place, so its value is 40,000.\n\n' ||
    E'Even though both digits are 4, the first 4 has a much greater value than the second 4, because it is in a higher place.'
  ),
  (
    v_lesson_id, 9, 'summary', 'Remember',
    E'  - The PLACE of a digit is its position in a number (ones, tens, hundreds, thousands, ten thousands, hundred thousands).\n' ||
    E'  - The VALUE of a digit is the digit multiplied by its place (for example, 5 in the hundred thousands place is worth 500,000).\n' ||
    E'  - Standard form is the usual way of writing a number with digits, like 618,392.\n' ||
    E'  - Expanded form shows a number as the sum of the values of its digits, like 600,000 + 10,000 + 8,000 + 300 + 90 + 2.\n' ||
    E'  - Two digits that look the same can have very different values depending on their place in the number.'
  );

  -- ===========================================================================
  -- Quiz 3 questions — Place Value of Whole Numbers
  -- New numbers throughout (not reused from the lesson pages above), so
  -- the student has to apply the concept rather than recall an example.
  -- ===========================================================================

  -- --- Q1 (identify the place of a digit) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value of Whole Numbers',
    'In the number 356,819, what is the place of the digit 6?',
    'Reading the digits from left to right — 3 (hundred thousands), 5 (ten thousands), 6 (thousands), 8 (hundreds), 1 (tens), 9 (ones) — the digit 6 is in the thousands place.'
  )
  returning id into v_q1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1, 'Thousands',        true,  1),
    (v_q1, 'Hundred Thousands', false, 2),
    (v_q1, 'Hundreds',          false, 3),
    (v_q1, 'Tens',              false, 4);

  -- --- Q2 (identify the place of a digit) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value of Whole Numbers',
    'In the number 782,145, what is the place of the digit 7?',
    'The digits are 7 (hundred thousands), 8 (ten thousands), 2 (thousands), 1 (hundreds), 4 (tens), 5 (ones), so the digit 7 is in the hundred thousands place.'
  )
  returning id into v_q2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2, 'Hundred Thousands', true,  1),
    (v_q2, 'Ten Thousands',     false, 2),
    (v_q2, 'Thousands',         false, 3),
    (v_q2, 'Ones',              false, 4);

  -- --- Q3 (identify the value of a digit) ---------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value of Whole Numbers',
    'What is the value of the digit 4 in 913,462?',
    'In 913,462, the digit 4 is in the hundreds place, so its value is 4 x 100 = 400.'
  )
  returning id into v_q3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q3, '400',   true,  1),
    (v_q3, '4',     false, 2),
    (v_q3, '40',    false, 3),
    (v_q3, '4,000', false, 4);

  -- --- Q4 (identify the value of a digit) ---------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value of Whole Numbers',
    'What is the value of the digit 7 in 271,584?',
    'In 271,584, the digit 7 is in the ten thousands place, so its value is 7 x 10,000 = 70,000.'
  )
  returning id into v_q4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q4, '70,000', true,  1),
    (v_q4, '7,000',  false, 2),
    (v_q4, '700',    false, 3),
    (v_q4, '7',      false, 4);

  -- --- Q5 (standard form from expanded form) ------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value of Whole Numbers',
    'Which number is written in expanded form as 500,000 + 40,000 + 3,000 + 200 + 60 + 7?',
    'Adding the place values together: 500,000 + 40,000 + 3,000 + 200 + 60 + 7 = 543,267.'
  )
  returning id into v_q5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5, '543,267', true,  1),
    (v_q5, '543,276', false, 2),
    (v_q5, '534,267', false, 3),
    (v_q5, '543,207', false, 4);

  -- --- Q6 (expanded form of a number) --------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value of Whole Numbers',
    'What is the expanded form of 618,392?',
    'Each digit''s place value is written out and added together: 6 (hundred thousands) = 600,000; 1 (ten thousands) = 10,000; 8 (thousands) = 8,000; 3 (hundreds) = 300; 9 (tens) = 90; 2 (ones) = 2. So 618,392 = 600,000 + 10,000 + 8,000 + 300 + 90 + 2.'
  )
  returning id into v_q6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6, '600,000 + 10,000 + 8,000 + 300 + 90 + 2', true,  1),
    (v_q6, '600,000 + 10,000 + 8,000 + 300 + 9 + 2',  false, 2),
    (v_q6, '600,000 + 1,000 + 8,000 + 300 + 90 + 2',  false, 3),
    (v_q6, '60,000 + 10,000 + 8,000 + 300 + 90 + 2',  false, 4);

  -- --- Q7 (reading numbers into standard form) ------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value of Whole Numbers',
    'Which number is "four hundred seven thousand, eighty-nine" written in standard form?',
    '"Four hundred seven thousand" is 407,000, and "eighty-nine" is 89. Together, 407,000 + 89 = 407,089.'
  )
  returning id into v_q7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q7, '407,089', true,  1),
    (v_q7, '470,089', false, 2),
    (v_q7, '407,890', false, 3),
    (v_q7, '417,089', false, 4);

  -- --- Q8 (determine which digit is in a given place) ------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value of Whole Numbers',
    'In 852,613, which digit is in the ten thousands place?',
    'The digits of 852,613 are 8 (hundred thousands), 5 (ten thousands), 2 (thousands), 6 (hundreds), 1 (tens), 3 (ones), so 5 is in the ten thousands place.'
  )
  returning id into v_q8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q8, '5', true,  1),
    (v_q8, '8', false, 2),
    (v_q8, '2', false, 3),
    (v_q8, '6', false, 4);

  -- --- Q9 (comparing place values) -----------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value of Whole Numbers',
    'In the number 634,178, which digit has the greater value: the 6 or the 7?',
    'In 634,178, the 6 is in the hundred thousands place, so it is worth 600,000. The 7 is in the tens place, so it is worth only 70. Even though 7 is a bigger digit than 6, its position gives it a much smaller value, so the 6 has the greater value.'
  )
  returning id into v_q9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9, '6, because it is in the hundred thousands place and is worth 600,000', true,  1),
    (v_q9, '7, because 7 is a greater digit than 6',                               false, 2),
    (v_q9, '6, because it is worth only 6',                                        false, 3),
    (v_q9, 'They have the same value',                                             false, 4);

  -- --- Q10 (application / simple problem-solving) ----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Place Value of Whole Numbers',
    'A school library recorded 456,203 books in its collection. What is the value of the digit 4 in this number?',
    'In 456,203, the digit 4 is in the hundred thousands place, so its value is 4 x 100,000 = 400,000.'
  )
  returning id into v_q10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10, '400,000', true,  1),
    (v_q10, '40,000',  false, 2),
    (v_q10, '4,000',   false, 3),
    (v_q10, '4',       false, 4);

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

end $$;
