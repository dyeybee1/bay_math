-- =============================================================================
-- Migration: 0058_seed_grade4_lesson6_quiz6_fractions.sql
-- Content-seeding migration for the next Grade 4 (MELC-level) built-in
-- lesson/quiz pair, following the same overall shape as 0027 (seed) +
-- 0029 (lesson_pages) + 0033 (link lesson -> quiz), combined into one
-- migration here since this is new content rather than a schema-driven
-- restructuring of already-seeded rows.
--
-- Seeds:
--   Lesson 6 — Converting and Plotting Fractions   (grade_4, built_in)
--   Quiz 6: Converting and Plotting Fractions      (grade_4, built_in,
--                                                    internal, 10 questions)
--
-- Follows Lessons 1-5's numbering: this project's Grade 4 sequence is
--   1 Addition and Subtraction, 2 Comparing Numbers, 3 Place Value of
--   Whole Numbers, 4 Multiplication/Division and MDAS, 5 Types of
--   Fractions -- so this is Lesson 6, continuing directly from Lesson 5's
--   fraction-type coverage into converting/plotting fractions.
--
-- CONVENTIONS FOLLOWED (verified against 0007/0008/0009/0027/0028/0029/
-- 0032/0033 before writing this):
--   - lessons/quizzes: source_type = 'built_in', created_by = null,
--     grade_level = 'grade_4' (0027 pattern).
--   - lessons.body is the short 1-2 sentence list-screen description,
--     matching the shape 0029 left lessons 1-2 in (NOT the full lesson
--     text) -- the full text lives in lesson_pages rows from the start,
--     since lesson_pages already exists as of this migration (unlike
--     0027, which predates 0028 and had to be migrated after the fact).
--   - lesson_pages: one row per slide, display_order starting at 1,
--     section_type drawn only from values already used elsewhere
--     ('introduction' | 'vocabulary' | 'explanation' | 'examples' |
--     'summary') -- no new section_type invented.
--   - worked_example (0030) is intentionally left null on every page:
--     that column's shape is fixed to the 6-place-value addition/
--     subtraction POC (0030's column comment) and does not model
--     fraction conversion or number-line content, so plain-text `body`
--     is used throughout, per the task's Step 5 instruction not to
--     invent a new visualization/content type. Number lines are
--     represented as plain-text ASCII, the same technique already used
--     for place-value columns in 0027/0029's addition/subtraction
--     worked examples (e.g. the borrow-chain ASCII in Lesson 1, Example 4).
--   - question_bank/question_choices/quiz_questions: same shape as
--     0027 (4 choices per question, exactly one is_correct = true,
--     inserted in a single statement per question so the deferred
--     enforce_at_least_one_correct trigger never sees a zero-correct
--     question mid-transaction; topic tagged to the lesson title, per
--     the 0008 column comment).
--   - quizzes.shuffle_questions / shuffle_choices = true, matching
--     0027's quizzes.
--   - lessons.linked_quiz_id (0032) is set to Quiz 6 at the end, the
--     same way 0033 linked Lessons 1-2 to Quizzes 1-2.
--
-- MATH VERIFIED (independently recomputed, not copied from a template)
-- before writing the content below:
--   Mixed -> improper (multiply whole by denominator, add numerator,
--   keep denominator):
--     2 1/3 = (2*3+1)/3 = 7/3
--     3 1/4 = (3*4+1)/4 = 13/4
--     1 2/5 = (1*5+2)/5 = 7/5
--     4 3/4 = (4*4+3)/4 = 19/4
--     3 2/5 = (3*5+2)/5 = 17/5   (quiz Q2)
--     2 3/8 = (2*8+3)/8 = 19/8   (quiz Q3)
--   Improper -> mixed (divide numerator by denominator; quotient = whole,
--   remainder = new numerator, denominator unchanged):
--     7/3  = 2 r1 -> 2 1/3
--     9/4  = 2 r1 -> 2 1/4
--     11/5 = 2 r1 -> 2 1/5
--     13/6 = 2 r1 -> 2 1/6
--     5/4  = 1 r1 -> 1 1/4
--     23/6 = 3 r5 -> 3 5/6      (quiz Q4)
--     22/7 = 3 r1 -> 3 1/7      (quiz Q5)
--   Number lines: every interval below is confirmed to have equal-sized
--   parts equal to the stated denominator, and every marked point
--   corresponds to exactly one fraction (no ambiguous placement).
-- =============================================================================

do $$
declare
  v_lesson6_id uuid;
  v_quiz6_id   uuid;

  v_q1  uuid; v_q2  uuid; v_q3  uuid; v_q4  uuid; v_q5  uuid;
  v_q6  uuid; v_q7  uuid; v_q8  uuid; v_q9  uuid; v_q10 uuid;
begin

  -- ===========================================================================
  -- Lesson 6 — Converting and Plotting Fractions
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Converting and Plotting Fractions',
    'Learn to change mixed numbers into improper fractions and back again, and how to find and name fractions on a number line.',
    'built_in',
    null,
    'grade_4'
  )
  returning id into v_lesson6_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson6_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn how to change fractions from one form to another, and how to find and name fractions on a number line.'
  ),
  (
    v_lesson6_id, 2, 'vocabulary', 'Review of Fraction Parts',
    E'Every fraction has two parts:\n' ||
    E'  numerator -- the top number, telling how many parts we have\n' ||
    E'  denominator -- the bottom number, telling how many equal parts make one whole\n\n' ||
    E'A fraction like 3/4 means 3 out of 4 equal parts.'
  ),
  (
    v_lesson6_id, 3, 'explanation', 'Kinds of Fraction Representations',
    E'A proper fraction has a numerator smaller than its denominator, like 3/4.\n\n' ||
    E'An improper fraction has a numerator equal to or greater than its denominator, like 7/3.\n\n' ||
    E'A mixed number has a whole number part and a fraction part together, like 2 1/3. The whole number tells how many complete wholes there are, and the fraction part tells what is left over.'
  ),
  (
    v_lesson6_id, 4, 'explanation', 'Converting a Mixed Number to an Improper Fraction',
    E'To change a mixed number into an improper fraction:\n' ||
    E'  1. Multiply the whole number by the denominator.\n' ||
    E'  2. Add the numerator to that result.\n' ||
    E'  3. Keep the same denominator.'
  ),
  (
    v_lesson6_id, 5, 'examples', 'Mixed Number to Improper Fraction Examples',
    E'Worked Example 1:\n' ||
    E'  2 1/3 = ?\n' ||
    E'  Multiply the whole number by the denominator: 2 x 3 = 6.\n' ||
    E'  Add the numerator: 6 + 1 = 7.\n' ||
    E'  Keep the same denominator: 3.\n' ||
    E'  Answer: 2 1/3 = 7/3.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  3 1/4 = ?\n' ||
    E'  Multiply: 3 x 4 = 12.\n' ||
    E'  Add the numerator: 12 + 1 = 13.\n' ||
    E'  Keep the same denominator: 4.\n' ||
    E'  Answer: 3 1/4 = 13/4.\n\n' ||
    E'Worked Example 3:\n' ||
    E'  1 2/5 = ?\n' ||
    E'  Multiply: 1 x 5 = 5.\n' ||
    E'  Add the numerator: 5 + 2 = 7.\n' ||
    E'  Keep the same denominator: 5.\n' ||
    E'  Answer: 1 2/5 = 7/5.'
  ),
  (
    v_lesson6_id, 6, 'explanation', 'Converting an Improper Fraction to a Mixed Number',
    E'To change an improper fraction into a mixed number:\n' ||
    E'  1. Divide the numerator by the denominator.\n' ||
    E'  2. The quotient (the number of times it divides evenly) becomes the whole number.\n' ||
    E'  3. The remainder becomes the new numerator.\n' ||
    E'  4. The denominator stays the same.'
  ),
  (
    v_lesson6_id, 7, 'examples', 'Improper Fraction to Mixed Number Examples',
    E'Worked Example 4:\n' ||
    E'  7/3 = ?\n' ||
    E'  Divide: 7 / 3 = 2, remainder 1.\n' ||
    E'  Whole number: 2. New numerator: 1. Denominator stays 3.\n' ||
    E'  Answer: 7/3 = 2 1/3.\n\n' ||
    E'Worked Example 5:\n' ||
    E'  9/4 = ?\n' ||
    E'  Divide: 9 / 4 = 2, remainder 1.\n' ||
    E'  Answer: 9/4 = 2 1/4.\n\n' ||
    E'Worked Example 6:\n' ||
    E'  11/5 = ?\n' ||
    E'  Divide: 11 / 5 = 2, remainder 1.\n' ||
    E'  Answer: 11/5 = 2 1/5.'
  ),
  (
    v_lesson6_id, 8, 'explanation', 'Fractions on a Number Line',
    E'A number line can show fractions between whole numbers. The denominator tells how many equal parts the space between 0 and 1 (or between any two whole numbers) is divided into.\n\n' ||
    E'For example, 3/4 means the space from 0 to 1 is split into 4 equal parts, and we count 3 parts from 0.'
  ),
  (
    v_lesson6_id, 9, 'examples', 'Plotting Fractions on a Number Line',
    E'Worked Example 7:\n' ||
    E'  Plot 3/4 on a number line from 0 to 1.\n' ||
    E'  Divide the space from 0 to 1 into 4 equal parts:\n' ||
    E'    0    1/4   2/4   3/4    1\n' ||
    E'    |-----|-----|-----|-----|\n' ||
    E'  Count 3 parts from 0. The point lands at 3/4.\n\n' ||
    E'Worked Example 8:\n' ||
    E'  Plot 1/2 on a number line from 0 to 1.\n' ||
    E'  Divide the space from 0 to 1 into 2 equal parts:\n' ||
    E'    0          1/2          1\n' ||
    E'    |-----------|-----------|\n' ||
    E'  Count 1 part from 0. The point lands at 1/2, exactly in the middle.\n\n' ||
    E'Worked Example 9 (an improper fraction):\n' ||
    E'  Plot 5/4 on a number line from 0 to 2.\n' ||
    E'  Each whole (0 to 1, and 1 to 2) is divided into 4 equal parts:\n' ||
    E'    0    1/4   2/4   3/4    1    5/4   6/4   7/4    2\n' ||
    E'    |-----|-----|-----|-----|-----|-----|-----|-----|\n' ||
    E'  Count 5 parts from 0. The point lands just past 1, at 5/4, which is the same as 1 1/4.'
  ),
  (
    v_lesson6_id, 10, 'examples', 'Identifying Fractions from Marked Points',
    E'Worked Example 10:\n' ||
    E'  A number line from 0 to 1 is divided into 3 equal parts. A point is marked 2 parts from 0.\n' ||
    E'    0         1/3         2/3          1\n' ||
    E'    |----------|-----------|-----------|\n' ||
    E'                            ^\n' ||
    E'                          point\n' ||
    E'  Since the point is 2 parts from 0 out of 3 equal parts, the point names the fraction 2/3.'
  ),
  (
    v_lesson6_id, 11, 'summary', 'Remember',
    E'  - Mixed number to improper fraction: multiply the whole number by the denominator, add the numerator, then keep the same denominator.\n' ||
    E'  - Improper fraction to mixed number: divide the numerator by the denominator; the quotient is the whole number, the remainder is the new numerator, and the denominator stays the same.\n' ||
    E'  - The denominator tells how many equal parts the space between whole numbers is divided into.\n' ||
    E'  - To plot a fraction, count that many equal parts from 0 (or from the starting whole number).\n' ||
    E'  - To name a marked point, count how many equal parts it is from 0 and write that count over the total number of equal parts.'
  );

  -- ===========================================================================
  -- Quiz 6 — built-in Internal Quiz for Lesson 6
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 6: Converting and Plotting Fractions',
    'internal', 'built_in', null, 'grade_4', true, true
  )
  returning id into v_quiz6_id;

  -- --- Q1 (identifying fraction representations) --------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Converting and Plotting Fractions',
    'Which of the following is written as a mixed number?',
    'A mixed number has a whole number together with a fraction, like 2 3/5. "3/5" is a proper fraction, "23/5" is an improper fraction, and "5" is just a whole number -- none of those are mixed numbers.'
  )
  returning id into v_q1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1, '2 3/5', true,  1),
    (v_q1, '3/5',   false, 2),
    (v_q1, '23/5',  false, 3),
    (v_q1, '5',     false, 4);

  -- --- Q2 (mixed number -> improper fraction) ------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Converting and Plotting Fractions',
    'What is 3 2/5 written as an improper fraction?',
    'Multiply the whole number by the denominator: 3 x 5 = 15. Add the numerator: 15 + 2 = 17. Keep the same denominator: 5. So 3 2/5 = 17/5.'
  )
  returning id into v_q2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2, '17/5', true,  1),
    (v_q2, '15/5', false, 2),
    (v_q2, '11/5', false, 3),
    (v_q2, '16/5', false, 4);

  -- --- Q3 (mixed number -> improper fraction) ------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Converting and Plotting Fractions',
    'What is 2 3/8 written as an improper fraction?',
    'Multiply the whole number by the denominator: 2 x 8 = 16. Add the numerator: 16 + 3 = 19. Keep the same denominator: 8. So 2 3/8 = 19/8.'
  )
  returning id into v_q3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q3, '19/8', true,  1),
    (v_q3, '16/8', false, 2),
    (v_q3, '14/8', false, 3),
    (v_q3, '19/9', false, 4);

  -- --- Q4 (improper fraction -> mixed number) ------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Converting and Plotting Fractions',
    'What is 23/6 written as a mixed number?',
    'Divide the numerator by the denominator: 23 / 6 = 3, remainder 5. The whole number is 3, the new numerator is 5, and the denominator stays 6. So 23/6 = 3 5/6.'
  )
  returning id into v_q4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q4, '3 5/6', true,  1),
    (v_q4, '5 3/6', false, 2),
    (v_q4, '3 4/6', false, 3),
    (v_q4, '4 5/6', false, 4);

  -- --- Q5 (improper fraction -> mixed number) ------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Converting and Plotting Fractions',
    'What is 22/7 written as a mixed number?',
    'Divide the numerator by the denominator: 22 / 7 = 3, remainder 1. The whole number is 3, the new numerator is 1, and the denominator stays 7. So 22/7 = 3 1/7.'
  )
  returning id into v_q5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5, '3 1/7', true,  1),
    (v_q5, '1 3/7', false, 2),
    (v_q5, '3 2/7', false, 3),
    (v_q5, '4 1/7', false, 4);

  -- --- Q6 (understanding the whole number / fraction relationship) --------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Converting and Plotting Fractions',
    'In the mixed number 5 2/7, what does the 5 represent?',
    'In a mixed number, the whole number tells how many complete wholes there are, separate from the leftover fraction part. In 5 2/7, the 5 tells how many complete wholes there are, and the 2/7 tells the leftover part of the next whole.'
  )
  returning id into v_q6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6, 'The number of complete wholes', true,  1),
    (v_q6, 'The numerator of the fraction part', false, 2),
    (v_q6, 'The denominator of the fraction part', false, 3),
    (v_q6, 'The number of equal parts in one whole', false, 4);

  -- --- Q7 (role of the denominator on a number line) -----------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Converting and Plotting Fractions',
    'A number line from 0 to 1 is divided into equal parts to show sixths. How many equal parts are there between 0 and 1?',
    'The denominator tells how many equal parts the space between 0 and 1 is divided into. To show sixths, the denominator is 6, so there are 6 equal parts.'
  )
  returning id into v_q7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q7, '6', true,  1),
    (v_q7, '5', false, 2),
    (v_q7, '7', false, 3),
    (v_q7, '3', false, 4);

  -- --- Q8 (locating a given fraction on a number line) ---------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Converting and Plotting Fractions',
    'You want to plot 5/6 on a number line from 0 to 1 that is divided into 6 equal parts. How many parts away from 0 should the point be?',
    'The numerator tells how many equal parts to count from 0. For 5/6, count 5 parts away from 0 out of the 6 equal parts.'
  )
  returning id into v_q8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q8, '5', true,  1),
    (v_q8, '6', false, 2),
    (v_q8, '4', false, 3),
    (v_q8, '1', false, 4);

  -- --- Q9 (identifying the fraction represented by a marked point) --------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Converting and Plotting Fractions',
    'A number line from 0 to 1 is divided into 8 equal parts. A point is marked 3 parts away from 0. Which fraction names that point?',
    'The point is 3 parts from 0 out of 8 equal parts, so the fraction is written as (parts counted)/(total equal parts) = 3/8.'
  )
  returning id into v_q9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9, '3/8', true,  1),
    (v_q9, '8/8', false, 2),
    (v_q9, '5/8', false, 3),
    (v_q9, '3/3', false, 4);

  -- --- Q10 (application: plotting + mixed number, spanning past 1) --------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Converting and Plotting Fractions',
    'On a number line, each whole-number interval (0 to 1, 1 to 2, and so on) is divided into 4 equal parts. Point P is 9 equal parts away from 0. Which mixed number names point P?',
    'Every 4 parts make one whole, so 9 parts is 2 whole groups of 4 (8 parts, reaching the whole number 2) with 1 part left over. That leftover 1 part out of 4 gives the fraction 1/4, so point P is at 2 1/4.'
  )
  returning id into v_q10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10, '2 1/4', true,  1),
    (v_q10, '2 3/4', false, 2),
    (v_q10, '1 1/4', false, 3),
    (v_q10, '3/4',   false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz6_id, v_q1,  1),
    (v_quiz6_id, v_q2,  2),
    (v_quiz6_id, v_q3,  3),
    (v_quiz6_id, v_q4,  4),
    (v_quiz6_id, v_q5,  5),
    (v_quiz6_id, v_q6,  6),
    (v_quiz6_id, v_q7,  7),
    (v_quiz6_id, v_q8,  8),
    (v_quiz6_id, v_q9,  9),
    (v_quiz6_id, v_q10, 10);

  -- ===========================================================================
  -- Link Lesson 6 -> Quiz 6, the same "Take Quiz" convenience shortcut
  -- 0033 used for Lessons 1-2 -> Quizzes 1-2 (0032's linked_quiz_id column).
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz6_id where id = v_lesson6_id;

end $$;
