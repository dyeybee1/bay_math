-- =============================================================================
-- Migration: 0060_seed_grade4_lesson8_quiz8_factors.sql
-- Content-seeding migration for the next Grade 4 (MELC-level) built-in
-- lesson/quiz pair, following the same shape as 0027 (seed) + 0029
-- (lesson_pages) + 0033 (link lesson -> quiz), combined into one
-- migration since this is new content rather than a schema-driven
-- restructuring of already-seeded rows. Same pattern already used for
-- Lesson 6 / Quiz 6 and Lesson 7 / Quiz 7 (the two fraction migrations
-- immediately before this one).
--
-- Seeds:
--   Lesson 8 — Factors of Numbers up to 100          (grade_4, built_in)
--   Quiz 8: Factors of Numbers up to 100              (grade_4, built_in,
--                                                       internal, 10 questions)
--
-- Continues the project's Grade 4 sequence: 1 Addition and Subtraction,
-- 2 Comparing Numbers, 3 Place Value of Whole Numbers, 4 Multiplication/
-- Division and MDAS, 5 Types of Fractions, 6 Converting and Plotting
-- Fractions, 7 Comparing, Adding, and Subtracting Fractions -- so this
-- is Lesson 8, moving from fractions back to whole-number relationships
-- (factors), building on Lesson 4's multiplication/division foundation.
--
-- SCOPE DECISION: the reference material provided does not show any
-- existing Grade 4 lesson/quiz teaching prime or composite numbers (no
-- such classification appears anywhere in the supplied lesson content).
-- Per the task's explicit instruction to only include this "if the
-- existing Grade 4 curriculum/reference files clearly support this
-- concept," prime/composite classification is NOT introduced here. The
-- lesson stays scoped exactly to its stated topic: identifying,
-- listing, and checking factors of numbers up to 100. A brief
-- factors-vs-multiples distinction is included (Step 15 allows this "if
-- supported... keep the explanation brief and focused") since it
-- directly prevents a common Grade 4 confusion without introducing a
-- new unsupported topic of its own.
--
-- CONVENTIONS FOLLOWED (same as 0044/0058 and 0059's fraction
-- migrations, themselves verified against 0007/0008/0009/0027/0028/
-- 0029/0032/0033):
--   - lessons/quizzes: source_type = 'built_in', created_by = null,
--     grade_level = 'grade_4'.
--   - lessons.body is the short 1-2 sentence list-screen description;
--     the full text lives in lesson_pages rows.
--   - lesson_pages: one row per slide, display_order starting at 1,
--     section_type drawn only from values already used elsewhere
--     ('introduction' | 'vocabulary' | 'explanation' | 'examples' |
--     'summary') -- no new section_type invented.
--   - worked_example (0030) left null on every page: that column's
--     shape is fixed to the 6-place-value addition/subtraction POC and
--     does not model factor-finding, so plain-text `body` is used
--     throughout, consistent with Lessons 6-7.
--   - question_bank/question_choices/quiz_questions: 4 choices per
--     question, exactly one is_correct = true, inserted in a single
--     statement per question so the deferred
--     enforce_at_least_one_correct trigger never sees a zero-correct
--     question mid-transaction; topic tagged to the lesson title.
--   - quizzes.shuffle_questions / shuffle_choices = true.
--   - lessons.linked_quiz_id (0032) set to Quiz 8 at the end, the same
--     way 0033/0044/0059 linked earlier lessons to their quizzes.
--
-- MATH VERIFIED (every factor list below independently recomputed by
-- checking divisibility for every whole number from 1 up to the target
-- number, not just restated from a template, before writing the content):
--   Lesson:
--     12 = {1,2,3,4,6,12}              (pairs 1x12, 2x6, 3x4)
--     24 = {1,2,3,4,6,8,12,24}         (pairs 1x24, 2x12, 3x8, 4x6)
--     30 = {1,2,3,5,6,10,15,30}        (used for "is 5 a factor of 30?" -> yes, 30/5=6)
--     18 = {1,2,3,6,9,18}              (used for "is 4 a factor of 18?" -> no, 18/4 = 4.5)
--     42 = {1,2,3,6,7,14,21,42}        (used for 6 x 7 = 42, missing-factor example)
--     6  = {1,2,3,6}, multiples 6,12,18,24,... (factors-vs-multiples contrast)
--     20 = {1,2,4,5,10,20}             (pairs 1x20, 2x10, 4x5)
--     48 = {1,2,3,4,6,8,12,16,24,48}   (pairs 1x48,2x24,3x16,4x12,6x8)
--   Quiz (all different numbers from the lesson, per Step 16):
--     36 = {1,2,3,4,6,9,12,18,36}      -> Q1: 9 is a factor, 5/8/10 are not
--     28 = {1,2,4,7,14,28}             -> Q7: complete factor list
--     40 = {1,2,4,5,8,10,20,40}        -> Q2: 5x8=40 is a valid factor pair;
--                                           4x9=36, 5x9=45, 6x7=42 are not 40
--     63 = {1,3,7,9,21,63}             -> Q4/Q5: 7x9=63, 63/9=7
--     32 = {1,2,4,8,16,32}             -> Q3: 8x4=32; 8x3=24, 8x5=40, 8x6=48 are not 32
--     50 = {1,2,5,10,25,50}            -> Q6: 6 is NOT a factor of 50 (50/6 = 8.33)
--     45 = {1,3,5,9,15,45}             -> Q9/Q10: 6 is NOT a factor of 45 (45/6=7.5);
--                                           full factor list {1,3,5,9,15,45}
--     60 = {1,2,3,4,5,6,10,12,15,20,30,60} -> Q8: 6x10=60 is a valid factor pair;
--                                           7x9=63, 8x7=56, 5x11=55 are not 60
--   No target number or factor pair above is reused verbatim between the
--   lesson and the quiz.
-- =============================================================================

do $$
declare
  v_lesson8_id uuid;
  v_quiz8_id   uuid;

  v_q1  uuid; v_q2  uuid; v_q3  uuid; v_q4  uuid; v_q5  uuid;
  v_q6  uuid; v_q7  uuid; v_q8  uuid; v_q9  uuid; v_q10 uuid;
begin

  -- ===========================================================================
  -- Lesson 8 — Factors of Numbers up to 100
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Factors of Numbers up to 100',
    'Learn what a factor is, how to find factor pairs using multiplication and division, and how to list all the factors of a number up to 100.',
    'built_in',
    null,
    'grade_4'
  )
  returning id into v_lesson8_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson8_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn what factors are, how to find the factors of a number using multiplication and division, and how to list all the factors of numbers up to 100.'
  ),
  (
    v_lesson8_id, 2, 'vocabulary', 'What Is a Factor?',
    E'A factor is a whole number that multiplies with another whole number to make a given number.\n\n' ||
    E'If 3 x 4 = 12, then:\n' ||
    E'  3 is a factor of 12\n' ||
    E'  4 is a factor of 12\n' ||
    E'  12 is the product\n\n' ||
    E'Multiplication and division are connected: if 24 / 6 = 4, then 6 and 4 are both factors of 24.'
  ),
  (
    v_lesson8_id, 3, 'explanation', 'Factor Pairs',
    E'A factor pair is two factors that multiply together to make the target number.\n\n' ||
    E'For example, the factor pairs of 12 are:\n' ||
    E'  1 x 12\n' ||
    E'  2 x 6\n' ||
    E'  3 x 4\n\n' ||
    E'Putting all these factors together, the factors of 12 are: 1, 2, 3, 4, 6, 12.'
  ),
  (
    v_lesson8_id, 4, 'explanation', 'Finding All the Factors of a Number',
    E'To find all the factors of a number, start at 1 and test each whole number in order, checking whether it divides the target number evenly. Stop once the factor pairs start to repeat.\n\n' ||
    E'Worked Example 1:\n' ||
    E'  Find all the factors of 24.\n' ||
    E'  1 x 24\n' ||
    E'  2 x 12\n' ||
    E'  3 x 8\n' ||
    E'  4 x 6\n' ||
    E'  Testing 5 next: 24 / 5 is not a whole number, so 5 is not a factor.\n' ||
    E'  The next number, 6, has already appeared (paired with 4), so we have found them all.\n' ||
    E'  Answer: the factors of 24 are 1, 2, 3, 4, 6, 8, 12, 24.'
  ),
  (
    v_lesson8_id, 5, 'explanation', 'Checking Whether a Number Is a Factor',
    E'To check whether one number is a factor of another, divide. If the answer is a whole number with nothing left over, it is a factor. If not, it is not a factor.'
  ),
  (
    v_lesson8_id, 6, 'examples', 'Checking Factors with Division',
    E'Worked Example 2:\n' ||
    E'  Is 5 a factor of 30?\n' ||
    E'  30 / 5 = 6, which is a whole number.\n' ||
    E'  Answer: Yes, 5 is a factor of 30.\n\n' ||
    E'Worked Example 3:\n' ||
    E'  Is 4 a factor of 18?\n' ||
    E'  18 / 4 = 4.5, which is not a whole number.\n' ||
    E'  Answer: No, 4 is not a factor of 18.'
  ),
  (
    v_lesson8_id, 7, 'examples', 'Completing a Factor Pair',
    E'Sometimes we know one factor and the product, and need to find the missing factor.\n\n' ||
    E'Worked Example 4:\n' ||
    E'  6 x ___ = 42\n' ||
    E'  Think: what number times 6 gives 42? Or divide: 42 / 6 = 7.\n' ||
    E'  Answer: the missing factor is 7, since 6 x 7 = 42.'
  ),
  (
    v_lesson8_id, 8, 'vocabulary', 'Factors vs. Multiples',
    E'Do not confuse factors with multiples -- they are opposite ideas.\n\n' ||
    E'For the number 6:\n' ||
    E'  Factors of 6 (numbers that divide evenly into 6): 1, 2, 3, 6\n' ||
    E'  Multiples of 6 (6 multiplied by 1, 2, 3, and so on): 6, 12, 18, 24, ...\n\n' ||
    E'A factor is always less than or equal to the number. A multiple is always greater than or equal to the number.'
  ),
  (
    v_lesson8_id, 9, 'examples', 'More Practice with Numbers up to 100',
    E'Worked Example 5:\n' ||
    E'  Find all the factors of 20.\n' ||
    E'  1 x 20\n' ||
    E'  2 x 10\n' ||
    E'  4 x 5\n' ||
    E'  Testing 3 next: 20 / 3 is not a whole number, so 3 is not a factor.\n' ||
    E'  Answer: the factors of 20 are 1, 2, 4, 5, 10, 20.\n\n' ||
    E'Worked Example 6:\n' ||
    E'  Find all the factors of 48.\n' ||
    E'  1 x 48\n' ||
    E'  2 x 24\n' ||
    E'  3 x 16\n' ||
    E'  4 x 12\n' ||
    E'  6 x 8\n' ||
    E'  Testing 5 next: 48 / 5 is not a whole number, so 5 is not a factor.\n' ||
    E'  The next number, 6, we already found, so we have found them all.\n' ||
    E'  Answer: the factors of 48 are 1, 2, 3, 4, 6, 8, 12, 16, 24, 48.'
  ),
  (
    v_lesson8_id, 10, 'summary', 'Remember',
    E'  - A factor is a whole number that multiplies with another whole number to make a given number.\n' ||
    E'  - A factor pair is two factors whose product is the target number.\n' ||
    E'  - To find all factors, test whole numbers in order starting at 1 until the pairs start to repeat.\n' ||
    E'  - To check whether a number is a factor, divide -- if the result is a whole number with nothing left over, it is a factor.\n' ||
    E'  - Factors divide evenly into a number; multiples are what you get when you multiply that number. Do not mix them up.'
  );

  -- ===========================================================================
  -- Quiz 8 — built-in Internal Quiz for Lesson 8
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 8: Factors of Numbers up to 100',
    'internal', 'built_in', null, 'grade_4', true, true
  )
  returning id into v_quiz8_id;

  -- --- Q1 (identifying a factor) --------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Factors of Numbers up to 100',
    'Which number is a factor of 36?',
    'A factor of 36 divides evenly into 36. 36 / 9 = 4, a whole number, so 9 is a factor of 36. 36 / 5, 36 / 8, and 36 / 10 all leave a remainder, so 5, 8, and 10 are not factors of 36.'
  )
  returning id into v_q1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1, '9',  true,  1),
    (v_q1, '5',  false, 2),
    (v_q1, '8',  false, 3),
    (v_q1, '10', false, 4);

  -- --- Q2 (identifying a factor pair) ----------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Factors of Numbers up to 100',
    'Which pair is a factor pair of 40?',
    'A factor pair multiplies together to make the target number. 5 x 8 = 40, so 5 and 8 are a factor pair of 40. 4 x 9 = 36, 5 x 9 = 45, and 6 x 7 = 42 -- none of these equal 40.'
  )
  returning id into v_q2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2, '5 x 8', true,  1),
    (v_q2, '4 x 9', false, 2),
    (v_q2, '5 x 9', false, 3),
    (v_q2, '6 x 7', false, 4);

  -- --- Q3 (using multiplication to identify factors) -------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Factors of Numbers up to 100',
    'Which multiplication sentence shows that 8 is a factor of 32?',
    '8 is a factor of 32 if some whole number times 8 equals 32. 8 x 4 = 32, so this is the correct sentence. 8 x 3 = 24, 8 x 5 = 40, and 8 x 6 = 48 do not equal 32.'
  )
  returning id into v_q3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q3, '8 x 4 = 32', true,  1),
    (v_q3, '8 x 3 = 32', false, 2),
    (v_q3, '8 x 5 = 32', false, 3),
    (v_q3, '8 x 6 = 32', false, 4);

  -- --- Q4 (completing a factor pair) ------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Factors of Numbers up to 100',
    '7 x ___ = 63. What is the missing factor?',
    'Divide the product by the known factor: 63 / 7 = 9. Check: 7 x 9 = 63. So the missing factor is 9.'
  )
  returning id into v_q4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q4, '9',  true,  1),
    (v_q4, '8',  false, 2),
    (v_q4, '10', false, 3),
    (v_q4, '56', false, 4);

  -- --- Q5 (using division to check factors) -----------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Factors of Numbers up to 100',
    'Which division sentence shows that 9 is a factor of 63?',
    'To check that 9 is a factor of 63, divide 63 by 9. 63 / 9 = 7, a whole number with nothing left over, so 9 is a factor of 63.'
  )
  returning id into v_q5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5, '63 / 9 = 7', true,  1),
    (v_q5, '63 / 9 = 6', false, 2),
    (v_q5, '63 / 9 = 8', false, 3),
    (v_q5, '63 / 9 = 9', false, 4);

  -- --- Q6 (identifying a number that is NOT a factor) --------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Factors of Numbers up to 100',
    'Which number is NOT a factor of 50?',
    '50 / 2 = 25, 50 / 5 = 10, and 50 / 10 = 5 are all whole numbers, so 2, 5, and 10 are factors of 50. But 50 / 6 = 8.33, which is not a whole number, so 6 is not a factor of 50.'
  )
  returning id into v_q6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6, '6',  true,  1),
    (v_q6, '2',  false, 2),
    (v_q6, '5',  false, 3),
    (v_q6, '10', false, 4);

  -- --- Q7 (finding all factors) --------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Factors of Numbers up to 100',
    'What are all the factors of 28?',
    'Testing whole numbers in order: 1 x 28, 2 x 14, 4 x 7. Testing 3, 5, and 6 shows none of them divide 28 evenly. So the complete list of factors of 28 is 1, 2, 4, 7, 14, 28.'
  )
  returning id into v_q7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q7, '1, 2, 4, 7, 14, 28',    true,  1),
    (v_q7, '1, 2, 4, 14, 28',       false, 2),
    (v_q7, '1, 2, 4, 7, 8, 14, 28', false, 3),
    (v_q7, '28, 56, 84, 112',       false, 4);

  -- --- Q8 (application: factor pair) ---------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Factors of Numbers up to 100',
    'A gardener wants to plant 60 seeds in equal rows, with the same number of seeds in each row and no seeds left over. Which pair of numbers could be the number of rows and the number of seeds per row?',
    'The number of rows and the number of seeds per row must be a factor pair of 60. 6 x 10 = 60, so 6 rows of 10 seeds works. 7 x 9 = 63, 8 x 7 = 56, and 5 x 11 = 55 -- none of these equal 60.'
  )
  returning id into v_q8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q8, '6 rows of 10 seeds', true,  1),
    (v_q8, '7 rows of 9 seeds',  false, 2),
    (v_q8, '8 rows of 7 seeds',  false, 3),
    (v_q8, '5 rows of 11 seeds', false, 4);

  -- --- Q9 (application: identifying a non-factor group size) ---------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Factors of Numbers up to 100',
    'A teacher has 45 pencils and wants to put them into equal groups with none left over. Which group size will NOT work?',
    'The group size must be a factor of 45. 45 / 5 = 9, 45 / 9 = 5, and 45 / 15 = 3 all come out even, so 5, 9, and 15 all work as group sizes. But 45 / 6 = 7.5, which is not a whole number, so a group size of 6 will NOT work.'
  )
  returning id into v_q9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9, '6 pencils per group',  true,  1),
    (v_q9, '5 pencils per group',  false, 2),
    (v_q9, '9 pencils per group',  false, 3),
    (v_q9, '15 pencils per group', false, 4);

  -- --- Q10 (finding all factors, larger number) -----------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Factors of Numbers up to 100',
    'What are all the factors of 45?',
    'Testing whole numbers in order: 1 x 45, 3 x 15, 5 x 9. Testing 2, 4, 6, 7, and 8 shows none of them divide 45 evenly. So the complete list of factors of 45 is 1, 3, 5, 9, 15, 45.'
  )
  returning id into v_q10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10, '1, 3, 5, 9, 15, 45',    true,  1),
    (v_q10, '1, 3, 5, 15, 45',       false, 2),
    (v_q10, '1, 3, 5, 9, 10, 15, 45', false, 3),
    (v_q10, '45, 90, 135, 180',      false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz8_id, v_q1,  1),
    (v_quiz8_id, v_q2,  2),
    (v_quiz8_id, v_q3,  3),
    (v_quiz8_id, v_q4,  4),
    (v_quiz8_id, v_q5,  5),
    (v_quiz8_id, v_q6,  6),
    (v_quiz8_id, v_q7,  7),
    (v_quiz8_id, v_q8,  8),
    (v_quiz8_id, v_q9,  9),
    (v_quiz8_id, v_q10, 10);

  -- ===========================================================================
  -- Link Lesson 8 -> Quiz 8, the same "Take Quiz" convenience shortcut
  -- 0033/0044/0059 used for earlier lessons (0032's linked_quiz_id column).
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz8_id where id = v_lesson8_id;

end $$;
