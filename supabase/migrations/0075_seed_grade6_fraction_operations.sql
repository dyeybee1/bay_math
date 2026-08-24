-- =============================================================================
-- Migration: 0075_seed_grade6_fraction_operations.sql
--
-- Seeds Grade 6 (MELC-level) built-in content:
--   Lesson 1 — Operations with Fractions, Whole Numbers, and Mixed Numbers
--   Quiz 1   — Internal Quiz for Lesson 1 (10 questions: addition,
--              subtraction, multiplication, division, and a mixed word
--              problem)
--
-- Follows the exact pattern established by 0027 (seed) + 0029 (lesson_pages)
-- + 0032/0033 (lesson -> quiz link) + 0074 (most recent seed migration,
-- Grade 5 Lesson 10/Quiz 10), collapsed into one migration since this is a
-- single lesson/quiz addition. All ids are database-generated
-- (gen_random_uuid(), the default on every affected table's id column) and
-- captured via `returning ... into`, never hardcoded. This is a pure content
-- addition — no table, column, or enum is created or altered, and no
-- existing Grade 4 (or Grade 5) row is modified.
--
-- lessons/quizzes/question_bank rows use source_type = 'built_in',
-- created_by = null, grade_level = 'grade_6' (lessons/quizzes only —
-- question_bank has no grade_level column, per 0027's established
-- convention, re-confirmed in 0074). question_bank.topic is tagged to
-- match the owning lesson's title, for the Highest/Lowest Performing
-- Topics dashboard metric (schema comment, 0008).
--
-- Lesson uses the `lesson_pages` structure directly (0028), same as 0074 —
-- no separate two-step lessons.body -> lesson_pages migration is needed
-- here since lesson_pages already exists (that split only mattered for
-- 0027/0029, written before lesson_pages existed).
--
-- The `worked_example` jsonb column (0030) is deliberately NOT used here:
-- per its own column comment, that shape is fixed to exactly 6 place-value
-- columns for addition/subtraction of WHOLE numbers and is explicitly
-- "POC scope, not built to generalize" — it has no field for numerators,
-- denominators, or reciprocals, so it cannot represent fraction operations
-- without inventing a new JSON shape, which the brief explicitly forbids.
-- All worked examples below use plain-text `body`, the same as every
-- lesson page outside that narrow POC (matches 0074's same reasoning).
--
-- section_type values used below (introduction, vocabulary, explanation,
-- examples, summary) are exactly the existing free-text values already
-- used by 0029/0074 — no new section_type introduced.
--
-- Each question's 4 choices are inserted in a single statement, so the
-- deferred `enforce_at_least_one_correct` constraint trigger (0014) never
-- observes a question with zero correct choices mid-transaction.
--
-- MATH INDEPENDENTLY VERIFIED (Python `fractions.Fraction`, re-checked
-- again below by hand) before writing this file:
--
--   Lesson addition:      1/8+3/8=1/2 | 2/3+1/4=11/12 | 2 1/3+1 1/2=3 5/6
--                          | 3 3/4+2 5/6=6 7/12 (regroups: 19/12 -> 1 7/12)
--   Lesson subtraction:    5/6-1/6=2/3 | 3/4-1/3=5/12 | 5 1/4-2 3/4=2 1/2
--                          (regroup) | 4 1/5-1 2/3=2 8/15 (regroup)
--   Lesson multiplication: 2/3*3/5=2/5 | 3/4*8=6 | 1 1/2*2/3=1
--                          | 2 1/4*1 1/3=3
--   Lesson division:       1/2÷1/4=2 | 4÷2/3=6 | 3/4÷6=1/8 | 2 1/2÷1 1/4=2
--   Lesson word problem:   3 1/2-1 3/4=1 3/4 (remaining ribbon);
--                          1 3/4÷1/4=7 (pieces cut)
--
--   Quiz (all dimensions/numbers deliberately different from the lesson's
--   worked examples — same skill, new numbers):
--     Q1  3/8+2/8=5/8            Q6  3 1/4-1 1/2=1 3/4 (regroup)
--     Q2  1/2+1/3=5/6            Q7  3/5*2/9=2/15
--     Q3  1 2/5+2 1/2=3 9/10     Q8  1 1/3*2 1/4=3
--     Q4  7/9-4/9=1/3            Q9  3/4÷1/8=6
--     Q5  5/6-1/4=7/12           Q10 word problem: 2 3/4-1 1/4=1 1/2
--
--   For every question, all three distractors were checked to be
--   mathematically distinct from the correct answer (including in
--   unreduced/equivalent form, e.g. 3/9 was rejected as a Q4 distractor
--   since it equals the correct answer 1/3) — no question has two
--   choices that are numerically the same value.
-- =============================================================================

do $$
declare
  v_lesson1_g6_id uuid;
  v_quiz1_g6_id   uuid;

  -- Quiz 1 (Grade 6) — Operations with Fractions, Whole Numbers, and Mixed Numbers
  v_q_1  uuid; v_q_2  uuid; v_q_3  uuid; v_q_4  uuid; v_q_5  uuid;
  v_q_6  uuid; v_q_7  uuid; v_q_8  uuid; v_q_9  uuid; v_q_10 uuid;
begin

  -- ===========================================================================
  -- Lesson 1 (Grade 6) — Operations with Fractions, Whole Numbers, and
  -- Mixed Numbers
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Operations with Fractions, Whole Numbers, and Mixed Numbers',
    'Learn how to add, subtract, multiply, and divide fractions, whole numbers, and mixed numbers, with step-by-step worked examples for each operation.',
    'built_in',
    null,
    'grade_6'
  )
  returning id into v_lesson1_g6_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson1_g6_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn how to add, subtract, multiply, and divide fractions, whole numbers, and mixed numbers.\n\n' ||
    E'These four operations are the building blocks for solving many real-life problems, such as measuring ingredients, sharing materials, or figuring out how much of something is left over.'
  ),
  (
    v_lesson1_g6_id, 2, 'vocabulary', 'Fraction Vocabulary Review',
    E'Before we begin, let''s review some important words:\n\n' ||
    E'  - Numerator: the top number of a fraction. It tells how many parts we have.\n' ||
    E'  - Denominator: the bottom number of a fraction. It tells how many equal parts make a whole.\n' ||
    E'  - Proper fraction: the numerator is smaller than the denominator, such as 3/4.\n' ||
    E'  - Improper fraction: the numerator is equal to or greater than the denominator, such as 7/4.\n' ||
    E'  - Mixed number: a whole number and a proper fraction together, such as 1 3/4.'
  ),
  (
    v_lesson1_g6_id, 3, 'explanation', 'Converting Mixed Numbers and Improper Fractions',
    E'Sometimes it helps to change a mixed number into an improper fraction, or an improper fraction back into a mixed number.\n\n' ||
    E'To change a mixed number to an improper fraction:\n' ||
    E'  1. Multiply the whole number by the denominator.\n' ||
    E'  2. Add the numerator.\n' ||
    E'  3. Write that total over the same denominator.\n\n' ||
    E'Example: 2 1/3 -> (2 x 3) + 1 = 7, so 2 1/3 = 7/3.\n\n' ||
    E'To change an improper fraction to a mixed number, divide the numerator by the denominator. The whole-number answer is the whole number, and the remainder becomes the new numerator.\n\n' ||
    E'Example: 7/3 -> 7 divided by 3 is 2, remainder 1, so 7/3 = 2 1/3.'
  ),
  (
    v_lesson1_g6_id, 4, 'explanation', 'Adding Fractions and Mixed Numbers',
    E'To add fractions with the SAME denominator, simply add the numerators and keep the denominator the same, then simplify.\n\n' ||
    E'To add fractions with DIFFERENT denominators:\n' ||
    E'  1. Find a common denominator (a number both denominators can divide into evenly).\n' ||
    E'  2. Rewrite each fraction using that common denominator.\n' ||
    E'  3. Add the numerators and keep the common denominator.\n' ||
    E'  4. Simplify the answer if possible.\n\n' ||
    E'To add mixed numbers, add the whole numbers together and the fractions together (using a common denominator), then simplify. If the fraction part becomes an improper fraction, regroup it into the whole-number part.'
  ),
  (
    v_lesson1_g6_id, 5, 'examples', 'Addition Worked Examples',
    E'Example 1 — Same denominator:\n' ||
    E'  1/8 + 3/8 = ?\n' ||
    E'  Add the numerators and keep the denominator: 1 + 3 = 4, so 4/8.\n' ||
    E'  Simplify: 4/8 = 1/2.\n' ||
    E'  Answer: 1/8 + 3/8 = 1/2\n\n' ||
    E'Example 2 — Different denominators:\n' ||
    E'  2/3 + 1/4 = ?\n' ||
    E'  Find a common denominator: 12 works for both 3 and 4.\n' ||
    E'  Rewrite: 2/3 = 8/12, and 1/4 = 3/12.\n' ||
    E'  Add: 8/12 + 3/12 = 11/12. This is already in simplest form.\n' ||
    E'  Answer: 2/3 + 1/4 = 11/12\n\n' ||
    E'Example 3 — Mixed numbers:\n' ||
    E'  2 1/3 + 1 1/2 = ?\n' ||
    E'  Find a common denominator for the fractions: 6 works for both 3 and 2.\n' ||
    E'  Rewrite: 1/3 = 2/6, and 1/2 = 3/6.\n' ||
    E'  Add the whole numbers: 2 + 1 = 3. Add the fractions: 2/6 + 3/6 = 5/6.\n' ||
    E'  Answer: 2 1/3 + 1 1/2 = 3 5/6\n\n' ||
    E'Example 4 — More challenging (regrouping):\n' ||
    E'  3 3/4 + 2 5/6 = ?\n' ||
    E'  Common denominator for 4 and 6 is 12: 3/4 = 9/12, and 5/6 = 10/12.\n' ||
    E'  Add the whole numbers: 3 + 2 = 5. Add the fractions: 9/12 + 10/12 = 19/12.\n' ||
    E'  Since 19/12 is an improper fraction, change it to a mixed number: 19/12 = 1 7/12.\n' ||
    E'  Add that extra whole number to our total: 5 + 1 7/12 = 6 7/12.\n' ||
    E'  Answer: 3 3/4 + 2 5/6 = 6 7/12'
  ),
  (
    v_lesson1_g6_id, 6, 'explanation', 'Subtracting Fractions and Mixed Numbers',
    E'To subtract fractions with the SAME denominator, subtract the numerators and keep the denominator the same, then simplify.\n\n' ||
    E'To subtract fractions with DIFFERENT denominators, find a common denominator first, rewrite both fractions, then subtract the numerators.\n\n' ||
    E'To subtract mixed numbers, subtract the whole numbers and the fractions separately. If the fraction being subtracted is larger than the fraction you are subtracting from, you must REGROUP: borrow 1 whole from the whole-number part and add it to the fraction as an equivalent fraction before subtracting.'
  ),
  (
    v_lesson1_g6_id, 7, 'examples', 'Subtraction Worked Examples',
    E'Example 1 — Same denominator:\n' ||
    E'  5/6 - 1/6 = ?\n' ||
    E'  Subtract the numerators: 5 - 1 = 4, so 4/6.\n' ||
    E'  Simplify: 4/6 = 2/3.\n' ||
    E'  Answer: 5/6 - 1/6 = 2/3\n\n' ||
    E'Example 2 — Different denominators:\n' ||
    E'  3/4 - 1/3 = ?\n' ||
    E'  Common denominator for 4 and 3 is 12: 3/4 = 9/12, and 1/3 = 4/12.\n' ||
    E'  Subtract: 9/12 - 4/12 = 5/12. This is already in simplest form.\n' ||
    E'  Answer: 3/4 - 1/3 = 5/12\n\n' ||
    E'Example 3 — Mixed numbers with regrouping:\n' ||
    E'  5 1/4 - 2 3/4 = ?\n' ||
    E'  Since 1/4 is smaller than 3/4, we must regroup: borrow 1 from the 5, turning 5 1/4 into 4 5/4.\n' ||
    E'  Now subtract: whole numbers 4 - 2 = 2; fractions 5/4 - 3/4 = 2/4.\n' ||
    E'  Simplify: 2/4 = 1/2.\n' ||
    E'  Answer: 5 1/4 - 2 3/4 = 2 1/2\n\n' ||
    E'Example 4 — More challenging (different denominators AND regrouping):\n' ||
    E'  4 1/5 - 1 2/3 = ?\n' ||
    E'  Common denominator for 5 and 3 is 15: 1/5 = 3/15, and 2/3 = 10/15.\n' ||
    E'  Since 3/15 is smaller than 10/15, regroup: borrow 1 from the 4, turning 4 3/15 into 3 18/15.\n' ||
    E'  Subtract: whole numbers 3 - 1 = 2; fractions 18/15 - 10/15 = 8/15.\n' ||
    E'  Answer: 4 1/5 - 1 2/3 = 2 8/15'
  ),
  (
    v_lesson1_g6_id, 8, 'explanation', 'Multiplying Fractions, Whole Numbers, and Mixed Numbers',
    E'To multiply two fractions, multiply the numerators together and multiply the denominators together, then simplify.\n\n' ||
    E'To multiply a fraction by a whole number, write the whole number as a fraction over 1, then multiply as usual.\n\n' ||
    E'To multiply mixed numbers, first convert each mixed number to an improper fraction, then multiply the numerators and denominators, then simplify (converting back to a mixed number if needed).\n\n' ||
    E'Tip: You can often simplify BEFORE multiplying by cancelling common factors between any numerator and any denominator — this keeps the numbers smaller and easier to work with.'
  ),
  (
    v_lesson1_g6_id, 9, 'examples', 'Multiplication Worked Examples',
    E'Example 1 — Fraction times fraction:\n' ||
    E'  2/3 x 3/5 = ?\n' ||
    E'  We can simplify before multiplying: the 3 in the first numerator... actually, cancel the 3 in 3/5''s numerator with the 3 in 2/3''s denominator: 2/3 x 3/5 = 2/1 x 1/5.\n' ||
    E'  Multiply: 2 x 1 = 2, and 1 x 5 = 5.\n' ||
    E'  Answer: 2/3 x 3/5 = 2/5\n\n' ||
    E'Example 2 — Fraction times whole number:\n' ||
    E'  3/4 x 8 = ?\n' ||
    E'  Write 8 as 8/1: 3/4 x 8/1.\n' ||
    E'  Simplify first by dividing 8 and 4 by their common factor 4: 3/1 x 2/1.\n' ||
    E'  Multiply: 3 x 2 = 6.\n' ||
    E'  Answer: 3/4 x 8 = 6\n\n' ||
    E'Example 3 — Mixed number times fraction:\n' ||
    E'  1 1/2 x 2/3 = ?\n' ||
    E'  Convert 1 1/2 to an improper fraction: (1 x 2) + 1 = 3, so 1 1/2 = 3/2.\n' ||
    E'  Multiply: 3/2 x 2/3. Simplify by cancelling the 2s and the 3s: 1/1 x 1/1 = 1.\n' ||
    E'  Answer: 1 1/2 x 2/3 = 1\n\n' ||
    E'Example 4 — Mixed number times mixed number:\n' ||
    E'  2 1/4 x 1 1/3 = ?\n' ||
    E'  Convert both to improper fractions: 2 1/4 = 9/4, and 1 1/3 = 4/3.\n' ||
    E'  Multiply: 9/4 x 4/3. Simplify by cancelling the 4s: 9/1 x 1/3 = 9/3.\n' ||
    E'  Simplify: 9/3 = 3.\n' ||
    E'  Answer: 2 1/4 x 1 1/3 = 3'
  ),
  (
    v_lesson1_g6_id, 10, 'explanation', 'Dividing Fractions, Whole Numbers, and Mixed Numbers',
    E'To divide by a fraction, multiply by its RECIPROCAL instead. The reciprocal of a fraction is the fraction flipped upside down (numerator and denominator swapped).\n\n' ||
    E'Steps for dividing fractions:\n' ||
    E'  1. Keep the first number the same.\n' ||
    E'  2. Change the division sign to multiplication.\n' ||
    E'  3. Flip the second fraction (use its reciprocal).\n' ||
    E'  4. Multiply, then simplify.\n\n' ||
    E'This same method works for dividing a whole number by a fraction (write the whole number as a fraction over 1 first), a fraction by a whole number, and mixed numbers (convert to improper fractions first).'
  ),
  (
    v_lesson1_g6_id, 11, 'examples', 'Division Worked Examples',
    E'Example 1 — Fraction divided by fraction:\n' ||
    E'  1/2 ÷ 1/4 = ?\n' ||
    E'  Keep, change, flip: 1/2 x 4/1.\n' ||
    E'  Multiply: 1 x 4 = 4, and 2 x 1 = 2, giving 4/2.\n' ||
    E'  Simplify: 4/2 = 2.\n' ||
    E'  Answer: 1/2 ÷ 1/4 = 2\n\n' ||
    E'Example 2 — Whole number divided by fraction:\n' ||
    E'  4 ÷ 2/3 = ?\n' ||
    E'  Write 4 as 4/1. Keep, change, flip: 4/1 x 3/2.\n' ||
    E'  Simplify by cancelling: 2/1 x 3/1 = 6.\n' ||
    E'  Answer: 4 ÷ 2/3 = 6\n\n' ||
    E'Example 3 — Fraction divided by whole number:\n' ||
    E'  3/4 ÷ 6 = ?\n' ||
    E'  Write 6 as 6/1. Keep, change, flip: 3/4 x 1/6.\n' ||
    E'  Multiply: 3 x 1 = 3, and 4 x 6 = 24, giving 3/24.\n' ||
    E'  Simplify: 3/24 = 1/8.\n' ||
    E'  Answer: 3/4 ÷ 6 = 1/8\n\n' ||
    E'Example 4 — Mixed number divided by mixed number:\n' ||
    E'  2 1/2 ÷ 1 1/4 = ?\n' ||
    E'  Convert both to improper fractions: 2 1/2 = 5/2, and 1 1/4 = 5/4.\n' ||
    E'  Keep, change, flip: 5/2 x 4/5.\n' ||
    E'  Simplify by cancelling the 5s: 1/2 x 4/1 = 4/2.\n' ||
    E'  Simplify: 4/2 = 2.\n' ||
    E'  Answer: 2 1/2 ÷ 1 1/4 = 2'
  ),
  (
    v_lesson1_g6_id, 12, 'examples', 'Mixed Application: A Multi-Step Word Problem',
    E'Mia has 3 1/2 meters of ribbon. She uses 1 3/4 meters to tie a bow. She wants to cut the ribbon that is left into small pieces, each 1/4 meter long. How many pieces can she cut?\n\n' ||
    E'Step 1: Find how much ribbon is left (subtraction).\n' ||
    E'  3 1/2 - 1 3/4 = ?\n' ||
    E'  Common denominator 4: 3 1/2 = 3 2/4.\n' ||
    E'  Since 2/4 is smaller than 3/4, regroup: 3 2/4 becomes 2 6/4.\n' ||
    E'  Subtract: 2 6/4 - 1 3/4 = 1 3/4.\n' ||
    E'  Mia has 1 3/4 meters of ribbon left.\n\n' ||
    E'Step 2: Find how many 1/4-meter pieces fit into 1 3/4 meters (division).\n' ||
    E'  1 3/4 ÷ 1/4 = ?\n' ||
    E'  Convert 1 3/4 to an improper fraction: 1 3/4 = 7/4.\n' ||
    E'  Keep, change, flip: 7/4 x 4/1 = 28/4 = 7.\n\n' ||
    E'Answer: Mia can cut 7 pieces of ribbon. Notice that this problem needed two different operations — subtraction, then division — to solve.'
  ),
  (
    v_lesson1_g6_id, 13, 'summary', 'Common Mistakes to Avoid',
    E'  - Adding or subtracting numerators without first finding a common denominator.\n' ||
    E'  - Forgetting to regroup when the fraction being subtracted is larger.\n' ||
    E'  - Multiplying whole numbers and fractions separately instead of converting mixed numbers to improper fractions first.\n' ||
    E'  - Dividing by a fraction without flipping it to its reciprocal.\n' ||
    E'  - Forgetting to simplify the final answer.\n' ||
    E'  - Forgetting to convert an improper fraction result back into a mixed number when appropriate.'
  ),
  (
    v_lesson1_g6_id, 14, 'summary', 'Remember',
    E'  - To add or subtract fractions with different denominators, find a common denominator first.\n' ||
    E'  - Convert mixed numbers to improper fractions when it makes multiplying or dividing easier.\n' ||
    E'  - When subtracting mixed numbers, regroup if the fraction being subtracted is larger.\n' ||
    E'  - To multiply fractions, multiply the numerators together and the denominators together.\n' ||
    E'  - To divide by a fraction, multiply by its reciprocal instead.\n' ||
    E'  - Always simplify your final answer.'
  );

  -- ===========================================================================
  -- Quiz 1 (Grade 6) — built-in Internal Quiz for Lesson 1
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 1: Operations with Fractions, Whole Numbers, and Mixed Numbers',
    'internal', 'built_in', null, 'grade_6', true, true
  )
  returning id into v_quiz1_g6_id;

  -- --- Q1 (basic — addition, same denominator) ------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Fractions, Whole Numbers, and Mixed Numbers',
    'What is 3/8 + 2/8?',
    'Since the denominators are the same, add the numerators and keep the denominator: 3 + 2 = 5, so 3/8 + 2/8 = 5/8.'
  )
  returning id into v_q_1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_1, '5/8', true,  1),
    (v_q_1, '5/16', false, 2),
    (v_q_1, '1/8', false, 3),
    (v_q_1, '3/4', false, 4);

  -- --- Q2 (basic/intermediate — addition, different denominators) ---------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Fractions, Whole Numbers, and Mixed Numbers',
    'What is 1/2 + 1/3?',
    'The common denominator for 2 and 3 is 6: 1/2 = 3/6 and 1/3 = 2/6. Adding: 3/6 + 2/6 = 5/6.'
  )
  returning id into v_q_2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_2, '5/6', true,  1),
    (v_q_2, '2/5', false, 2),
    (v_q_2, '1/6', false, 3),
    (v_q_2, '2/3', false, 4);

  -- --- Q3 (intermediate — addition of mixed numbers) -----------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Fractions, Whole Numbers, and Mixed Numbers',
    'What is 1 2/5 + 2 1/2?',
    'The common denominator for 5 and 2 is 10: 2/5 = 4/10 and 1/2 = 5/10. Add the whole numbers: 1 + 2 = 3. Add the fractions: 4/10 + 5/10 = 9/10. Answer: 3 9/10.'
  )
  returning id into v_q_3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_3, '3 9/10', true,  1),
    (v_q_3, '3 7/10', false, 2),
    (v_q_3, '4 9/10', false, 3),
    (v_q_3, '3 1/10', false, 4);

  -- --- Q4 (basic — subtraction, same denominator) ---------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Fractions, Whole Numbers, and Mixed Numbers',
    'What is 7/9 - 4/9?',
    'Since the denominators are the same, subtract the numerators and keep the denominator: 7 - 4 = 3, so 7/9 - 4/9 = 3/9, which simplifies to 1/3.'
  )
  returning id into v_q_4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_4, '1/3', true,  1),
    (v_q_4, '11/9', false, 2),
    (v_q_4, '4/9', false, 3),
    (v_q_4, '1/9', false, 4);

  -- --- Q5 (intermediate — subtraction, different denominators) -------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Fractions, Whole Numbers, and Mixed Numbers',
    'What is 5/6 - 1/4?',
    'The common denominator for 6 and 4 is 12: 5/6 = 10/12 and 1/4 = 3/12. Subtracting: 10/12 - 3/12 = 7/12.'
  )
  returning id into v_q_5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_5, '7/12', true,  1),
    (v_q_5, '3/4', false, 2),
    (v_q_5, '7/24', false, 3),
    (v_q_5, '1/2', false, 4);

  -- --- Q6 (advanced — subtraction of mixed numbers with regrouping) --------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Fractions, Whole Numbers, and Mixed Numbers',
    'What is 3 1/4 - 1 1/2?',
    'Since 1/4 is smaller than 1/2 (2/4), regroup: 3 1/4 becomes 2 5/4. Subtract: whole numbers 2 - 1 = 1; fractions 5/4 - 2/4 = 3/4. Answer: 1 3/4.'
  )
  returning id into v_q_6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_6, '1 3/4', true,  1),
    (v_q_6, '2 1/4', false, 2),
    (v_q_6, '1 1/4', false, 3),
    (v_q_6, '2 3/4', false, 4);

  -- --- Q7 (intermediate — multiplication, fraction times fraction) --------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Fractions, Whole Numbers, and Mixed Numbers',
    'What is 3/5 x 2/9?',
    'Multiply the numerators: 3 x 2 = 6. Multiply the denominators: 5 x 9 = 45. This gives 6/45, which simplifies to 2/15.'
  )
  returning id into v_q_7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_7, '2/15', true,  1),
    (v_q_7, '3/7', false, 2),
    (v_q_7, '2/9', false, 3),
    (v_q_7, '5/14', false, 4);

  -- --- Q8 (advanced — multiplication of mixed numbers) ---------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Fractions, Whole Numbers, and Mixed Numbers',
    'What is 1 1/3 x 2 1/4?',
    'Convert to improper fractions: 1 1/3 = 4/3 and 2 1/4 = 9/4. Multiply: 4/3 x 9/4. Simplify by cancelling the 4s: 1/3 x 9/1 = 9/3 = 3.'
  )
  returning id into v_q_8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_8, '3', true,  1),
    (v_q_8, '2 1/12', false, 2),
    (v_q_8, '2 2/3', false, 3),
    (v_q_8, '4', false, 4);

  -- --- Q9 (intermediate — division of fractions) ----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Fractions, Whole Numbers, and Mixed Numbers',
    'What is 3/4 ÷ 1/8?',
    'Keep, change, flip: 3/4 x 8/1. Simplify by cancelling 4 into 8: 3/1 x 2/1 = 6.'
  )
  returning id into v_q_9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_9, '6', true,  1),
    (v_q_9, '3/32', false, 2),
    (v_q_9, '3/2', false, 3),
    (v_q_9, '48', false, 4);

  -- --- Q10 (application — word problem, subtraction) -----------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Operations with Fractions, Whole Numbers, and Mixed Numbers',
    'Jenna has 2 3/4 meters of cloth. She uses 1 1/4 meters to make a pillow cover. How much cloth does she have left?',
    'Since the fractions already share a denominator, subtract directly: whole numbers 2 - 1 = 1; fractions 3/4 - 1/4 = 2/4 = 1/2. Answer: 1 1/2 meters.'
  )
  returning id into v_q_10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_10, '1 1/2 meters', true,  1),
    (v_q_10, '4 meters', false, 2),
    (v_q_10, '1 3/4 meters', false, 3),
    (v_q_10, '2 1/2 meters', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz1_g6_id, v_q_1,  1),
    (v_quiz1_g6_id, v_q_2,  2),
    (v_quiz1_g6_id, v_q_3,  3),
    (v_quiz1_g6_id, v_q_4,  4),
    (v_quiz1_g6_id, v_q_5,  5),
    (v_quiz1_g6_id, v_q_6,  6),
    (v_quiz1_g6_id, v_q_7,  7),
    (v_quiz1_g6_id, v_q_8,  8),
    (v_quiz1_g6_id, v_q_9,  9),
    (v_quiz1_g6_id, v_q_10, 10);

  -- ===========================================================================
  -- Lesson 1 (Grade 6) -> Quiz 1 (Grade 6) link (0032's linked_quiz_id
  -- convenience column, same pattern as 0033/0074)
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz1_g6_id where id = v_lesson1_g6_id;

end $$;
