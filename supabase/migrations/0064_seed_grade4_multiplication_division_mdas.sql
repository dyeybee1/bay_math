-- =============================================================================
-- Migration: 0056_seed_grade4_multiplication_division_mdas.sql
-- Content-seeding migration, following the same pattern already used for
-- built-in Grade 4 content: 0027 (Lesson 1/2 + Quiz 1/2), 0055 (Lesson 3 +
-- Quiz 3). Like 0055, this seeds the lesson directly into paginated
-- `lesson_pages` form (0028) and links it to its quiz via
-- `lessons.linked_quiz_id` (0032) in a single pass, since both columns
-- already exist as schema by this point in the migration history.
--
-- Seeds Grade 4 (MELC-level) built-in content:
--   Lesson 4 — Multiplication, Division, and MDAS (10 pages)
--   Quiz 4   — Quiz 4: Multiplication, Division, and MDAS (10 questions),
--              linked to the lesson via `lessons.linked_quiz_id`.
--
-- This is the fourth built-in Grade 4 lesson/quiz pair, following:
--   Lesson 1 / Quiz 1 — Addition and Subtraction of Numbers up to 1,000,000 (0027)
--   Lesson 2 / Quiz 2 — Comparing Numbers up to 1,000,000 (0027)
--   Lesson 3 / Quiz 3 — Place Value of Whole Numbers (0055)
-- "Quiz 4" continues that same numbering, assuming no other built-in
-- Grade 4 quiz was added in migrations 0034-0054 (not included in the
-- reference ZIP this content was generated from). If one was, this title
-- should be renumbered accordingly before applying.
--
-- All ids are database-generated (gen_random_uuid()) and captured via
-- `returning ... into`, never hardcoded — same approach as 0027/0055.
--
-- Each question's 4 choices are inserted in a single statement, so the
-- deferred `enforce_at_least_one_correct` constraint trigger (0014) never
-- observes a question with zero correct choices mid-transaction — same
-- approach as 0027/0055.
--
-- MDAS RULE VERIFIED (every expression below solved independently,
-- multiplication/division strictly left-to-right, then addition/
-- subtraction strictly left-to-right, before writing any lesson page or
-- quiz question):
--   8 x 3 + 6                = 24 + 6            = 30
--   24 / 6 x 2                = 4 x 2             = 8
--   20 - 4 x 3                = 20 - 12           = 8
--   36 / 4 x 3                = 9 x 3             = 27   (NOT 36/(4x3)=3)
--   5 x 6 + 7                 = 30 + 7             = 37
--   40 - 15 / 5                = 40 - 3             = 37
--   9 + 12 / 3 x 2 - 4         = 9 + (4 x 2) - 4     = 9 + 8 - 4 = 13
--     (12/3=4 first since division appears before multiplication reading
--      left to right; then 4x2=8; then addition/subtraction left to
--      right: 9+8=17, 17-4=13)
--   3 x 8 + 5                 = 24 + 5             = 29
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
  -- linked_quiz_id (0032) without a separate follow-up update step.
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 4: Multiplication, Division, and MDAS',
    'internal', 'built_in', null, 'grade_4', true, true
  )
  returning id into v_quiz_id;

  -- ===========================================================================
  -- Lesson 4 — Multiplication, Division, and MDAS
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level, linked_quiz_id)
  values (
    'Multiplication, Division, and MDAS',
    'Learn to multiply and divide whole numbers, see how multiplication and division are related, and learn the MDAS rule for solving expressions with more than one operation.',
    'built_in',
    null,
    'grade_4',
    v_quiz_id
  )
  returning id into v_lesson_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will multiply and divide whole numbers, learn how multiplication and division are related, and learn the MDAS rule for solving expressions that have more than one operation.'
  ),
  (
    v_lesson_id, 2, 'explanation', 'Multiplication of Whole Numbers',
    E'Multiplication is a quick way to add the same number many times.\n\n' ||
    E'For example, 6 x 4 means adding 6 four times: 6 + 6 + 6 + 6 = 24.\n\n' ||
    E'So 6 x 4 = 24.'
  ),
  (
    v_lesson_id, 3, 'examples', 'Multiplication Examples',
    E'Worked Example 1:\n' ||
    E'  What is 7 x 8?\n' ||
    E'  7 x 8 means adding 7 eight times, or using the multiplication fact: 7 x 8 = 56.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  What is 9 x 6?\n' ||
    E'  Using the multiplication fact: 9 x 6 = 54.'
  ),
  (
    v_lesson_id, 4, 'explanation', 'Division of Whole Numbers',
    E'Division means splitting a number into equal groups.\n\n' ||
    E'For example, 24 divided by 6 asks: how many groups of 6 are in 24? Since 6 x 4 = 24, there are 4 groups.\n\n' ||
    E'So 24 / 6 = 4.'
  ),
  (
    v_lesson_id, 5, 'examples', 'Division Examples',
    E'Worked Example 3:\n' ||
    E'  What is 45 / 9?\n' ||
    E'  Since 9 x 5 = 45, 45 / 9 = 5.\n\n' ||
    E'Worked Example 4:\n' ||
    E'  What is 64 / 8?\n' ||
    E'  Since 8 x 8 = 64, 64 / 8 = 8.'
  ),
  (
    v_lesson_id, 6, 'explanation', 'How Multiplication and Division Are Related',
    E'Multiplication and division are opposite (inverse) operations.\n\n' ||
    E'If 6 x 4 = 24, then 24 / 4 = 6 and 24 / 6 = 4.\n\n' ||
    E'Knowing a multiplication fact can help you find a related division fact, and knowing a division fact can help you find a related multiplication fact.'
  ),
  (
    v_lesson_id, 7, 'explanation', 'Introducing MDAS',
    E'When a math expression has more than one operation, we follow a rule called MDAS so that everyone gets the same answer.\n\n' ||
    E'MDAS stands for:\n' ||
    E'  M - Multiplication\n' ||
    E'  D - Division\n' ||
    E'  A - Addition\n' ||
    E'  S - Subtraction\n\n' ||
    E'Follow these steps:\n' ||
    E'  1. Solve all multiplication and division first, working from LEFT TO RIGHT - whichever one comes first.\n' ||
    E'  2. Then solve all addition and subtraction, also working from LEFT TO RIGHT - whichever one comes first.\n\n' ||
    E'Multiplication is not always solved before division, and addition is not always solved before subtraction. Solve them in the order they appear, from left to right.'
  ),
  (
    v_lesson_id, 8, 'examples', 'MDAS Examples',
    E'Worked Example 5:\n' ||
    E'  Solve 8 x 3 + 6.\n' ||
    E'  First solve the multiplication: 8 x 3 = 24.\n' ||
    E'  Then add: 24 + 6 = 30.\n' ||
    E'  So 8 x 3 + 6 = 30.\n\n' ||
    E'Worked Example 6:\n' ||
    E'  Solve 24 / 6 x 2.\n' ||
    E'  Multiplication and division are solved from left to right. The division comes first: 24 / 6 = 4.\n' ||
    E'  Then multiply: 4 x 2 = 8.\n' ||
    E'  So 24 / 6 x 2 = 8.\n\n' ||
    E'Worked Example 7:\n' ||
    E'  Solve 20 - 4 x 3.\n' ||
    E'  First solve the multiplication: 4 x 3 = 12.\n' ||
    E'  Then subtract: 20 - 12 = 8.\n' ||
    E'  So 20 - 4 x 3 = 8.'
  ),
  (
    v_lesson_id, 9, 'examples', 'Application Problems',
    E'Worked Example 8:\n' ||
    E'  A vendor arranges 8 boxes of mangoes with 12 mangoes in each box. How many mangoes are there in all?\n' ||
    E'  This is a multiplication problem: 8 x 12 = 96.\n' ||
    E'  There are 96 mangoes in all.\n\n' ||
    E'Worked Example 9:\n' ||
    E'  A teacher has 56 pencils to share equally among 7 students. How many pencils will each student get?\n' ||
    E'  This is a division problem: 56 / 7 = 8.\n' ||
    E'  Each student will get 8 pencils.'
  ),
  (
    v_lesson_id, 10, 'summary', 'Remember',
    E'  - Multiplication is repeated addition of the same number.\n' ||
    E'  - Division splits a number into equal groups.\n' ||
    E'  - Multiplication and division are inverse (opposite) operations.\n' ||
    E'  - MDAS: solve multiplication and division from left to right, then solve addition and subtraction from left to right.\n' ||
    E'  - Multiplication is not always done before division, and addition is not always done before subtraction - follow the order the operations appear in, from left to right.'
  );

  -- ===========================================================================
  -- Quiz 4 questions — Multiplication, Division, and MDAS
  -- New numbers throughout (not reused from the lesson pages above), so
  -- the student has to apply the rules independently.
  -- ===========================================================================

  -- --- Q1 (multiplication computation) ------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplication, Division, and MDAS',
    'What is 9 x 7?',
    'Using the multiplication fact: 9 x 7 = 63.'
  )
  returning id into v_q1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1, '63', true,  1),
    (v_q1, '56', false, 2),
    (v_q1, '72', false, 3),
    (v_q1, '54', false, 4);

  -- --- Q2 (division computation) -------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplication, Division, and MDAS',
    'What is 72 / 8?',
    'Since 8 x 9 = 72, 72 / 8 = 9.'
  )
  returning id into v_q2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2, '9', true,  1),
    (v_q2, '8', false, 2),
    (v_q2, '7', false, 3),
    (v_q2, '6', false, 4);

  -- --- Q3 (multiplication/division relationship) ---------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplication, Division, and MDAS',
    'If 7 x 6 = 42, what is 42 / 6?',
    'Multiplication and division are inverse operations. Since 7 x 6 = 42, dividing 42 by 6 undoes the multiplication and gives back 7.'
  )
  returning id into v_q3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q3, '7',  true,  1),
    (v_q3, '6',  false, 2),
    (v_q3, '8',  false, 3),
    (v_q3, '36', false, 4);

  -- --- Q4 (multiplication and division together, left to right) -----------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplication, Division, and MDAS',
    'What is 36 / 4 x 3?',
    'Multiplication and division are solved from left to right. The division comes first: 36 / 4 = 9. Then multiply: 9 x 3 = 27. So 36 / 4 x 3 = 27.'
  )
  returning id into v_q4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q4, '27',  true,  1),
    (v_q4, '3',   false, 2),
    (v_q4, '108', false, 3),
    (v_q4, '12',  false, 4);

  -- --- Q5 (multiplication and addition) -------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplication, Division, and MDAS',
    'What is 5 x 6 + 7?',
    'Multiplication is solved before addition: 5 x 6 = 30. Then add: 30 + 7 = 37. So 5 x 6 + 7 = 37.'
  )
  returning id into v_q5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5, '37', true,  1),
    (v_q5, '65', false, 2),
    (v_q5, '42', false, 3),
    (v_q5, '36', false, 4);

  -- --- Q6 (division and subtraction) ----------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplication, Division, and MDAS',
    'What is 40 - 15 / 5?',
    'Division is solved before subtraction: 15 / 5 = 3. Then subtract: 40 - 3 = 37. So 40 - 15 / 5 = 37.'
  )
  returning id into v_q6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6, '37', true,  1),
    (v_q6, '5',  false, 2),
    (v_q6, '25', false, 3),
    (v_q6, '34', false, 4);

  -- --- Q7 (all four operations, full MDAS) -----------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplication, Division, and MDAS',
    'What is 9 + 12 / 3 x 2 - 4?',
    'First solve the division and multiplication from left to right: 12 / 3 = 4, then 4 x 2 = 8. The expression becomes 9 + 8 - 4. Then solve the addition and subtraction from left to right: 9 + 8 = 17, then 17 - 4 = 13. So 9 + 12 / 3 x 2 - 4 = 13.'
  )
  returning id into v_q7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q7, '13', true,  1),
    (v_q7, '10', false, 2),
    (v_q7, '17', false, 3),
    (v_q7, '20', false, 4);

  -- --- Q8 (identify correct order of operations, conceptual) -----------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplication, Division, and MDAS',
    'In the expression 18 / 3 x 2, which operation should be solved first?',
    'When multiplication and division appear together, solve them from left to right in the order they appear. Since the division comes first in 18 / 3 x 2, it is solved first: 18 / 3 = 6, then 6 x 2 = 12.'
  )
  returning id into v_q8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q8, '18 / 3, because division and multiplication are solved from left to right', true,  1),
    (v_q8, '3 x 2, because multiplication always comes before division',                 false, 2),
    (v_q8, '18 / (3 x 2), because the multiplication should be grouped first',           false, 3),
    (v_q8, 'It does not matter which one you solve first',                               false, 4);

  -- --- Q9 (application, multiplication) ---------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplication, Division, and MDAS',
    'A store has 6 shelves of storybooks with 15 books on each shelf. How many storybooks are there in all?',
    'This is a multiplication problem: 6 x 15 = 90. There are 90 storybooks in all.'
  )
  returning id into v_q9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9, '90',  true,  1),
    (v_q9, '21',  false, 2),
    (v_q9, '75',  false, 3),
    (v_q9, '105', false, 4);

  -- --- Q10 (application, MDAS word problem) ------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplication, Division, and MDAS',
    'Mrs. Santos bought 3 packs of pencils with 8 pencils in each pack. She also already had 5 pencils at home. How many pencils does she have now?',
    'First find the pencils she bought: 3 x 8 = 24. Then add the pencils she already had: 24 + 5 = 29. So Mrs. Santos now has 29 pencils.'
  )
  returning id into v_q10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10, '29', true,  1),
    (v_q10, '39', false, 2),
    (v_q10, '16', false, 3),
    (v_q10, '24', false, 4);

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
