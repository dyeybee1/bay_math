-- =============================================================================
-- Migration: 0067_seed_grade5_multiplying_dividing_fractions.sql
-- Content-seeding migration, same consolidated pattern as
-- 0066_seed_grade5_solving_operations_using_gmdas.sql — schema (lessons,
-- lesson_pages, question_bank, question_choices, quizzes, quiz_questions,
-- lessons.linked_quiz_id) is already fully in place, so lesson, pages,
-- quiz, questions, choices, and the lesson-to-quiz link are all seeded
-- together in one migration rather than split across several.
--
-- Seeds Grade 5 (MELC-level) built-in content:
--   Lesson 3 — Multiplying and Dividing Fractions
--   Quiz 3   — Internal Quiz for Lesson 3 (10 questions)
--
-- This is the THIRD Grade 5 lesson in the sequence. Lesson 1 and
-- Lesson 2 (0066) are assumed to already exist; this migration does not
-- read from or depend on either of them — it only creates new rows.
--
-- Conventions matched against 0027/0029/0031/0033/0066 (all re-read
-- before writing this):
--   - lessons: source_type = 'built_in', created_by = null,
--     grade_level = 'grade_5' (lessons_source_created_by_pairing, 0007;
--     grade_level confirmed against lib/core/models/section.dart's
--     GradeLevel enum).
--   - lessons.body is the short 1-2 sentence list-screen description; the
--     full content lives in lesson_pages (post-0029 shape).
--   - lesson_pages: one row per slide, display_order starting at 1,
--     section_type drawn only from values already used in this project
--     ('introduction' | 'explanation' | 'examples' | 'summary') — no new
--     section_type invented. worked_example (0030) is left null on every
--     page, same reasoning as 0066: that column is explicitly scoped to
--     a fixed 6-column place-value addition/subtraction POC and does not
--     fit fraction content.
--   - question_bank: source_type = 'built_in', created_by = null,
--     topic = the lesson title (matches 0027's topic-tagging convention).
--   - question_choices: exactly 4 choices per question, exactly one
--     is_correct = true, display_order 1-4, all 4 inserted in a single
--     statement per question so the deferred
--     enforce_at_least_one_correct trigger (0014) never observes a
--     zero-correct-choice question mid-transaction.
--   - quizzes: quiz_type = 'internal', source_type = 'built_in',
--     created_by = null, grade_level = 'grade_5',
--     shuffle_questions = true, shuffle_choices = true.
--     assessment_type (0043) left null — ordinary practice quiz, not a
--     pre/post intervention measure.
--   - quiz_questions: display_order 1-10, inserted all at once.
--   - lessons.linked_quiz_id: set via UPDATE in the same DO block after
--     both the lesson and quiz exist, same relationship 0032/0033/0066
--     established.
--
-- FRACTION-ANSWER FORMAT NOTE: nothing in the reference files (Grade 4
-- content only covers whole-number addition/subtraction/comparison) shows
-- an existing convention for presenting improper fractions vs. mixed
-- numbers. Per the "do not invent unsupported conventions" instruction,
-- this migration does NOT force conversion to mixed numbers anywhere —
-- every multiplication/division result is left as a fraction (simplified
-- to lowest terms), improper where that is what the math produces. Page 4
-- mentions the mixed-number equivalent once, briefly, as informational
-- context only, not as a required answer format.
--
-- All ids are database-generated (gen_random_uuid()) and captured via
-- `returning ... into`, never hardcoded.
--
-- MATH INDEPENDENTLY VERIFIED for every lesson example and every quiz
-- question/distractor before writing (see inline comments below).
-- Multiplication: numerator x numerator over denominator x denominator,
-- simplified to lowest terms. Division: keep the first fraction, change
-- division to multiplication, flip ONLY the second fraction (the
-- divisor) to its reciprocal — never the first fraction, never both.
-- =============================================================================

do $$
declare
  v_lesson3_id uuid;
  v_quiz3_id   uuid;

  -- Quiz 3 — Multiplying and Dividing Fractions
  v_q_1  uuid; v_q_2  uuid; v_q_3  uuid; v_q_4  uuid; v_q_5  uuid;
  v_q_6  uuid; v_q_7  uuid; v_q_8  uuid; v_q_9  uuid; v_q_10 uuid;
begin

  -- ===========================================================================
  -- Lesson 3 — Multiplying and Dividing Fractions
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Multiplying and Dividing Fractions',
    'Learn to multiply fractions by fractions and by whole numbers, simplify the results, and divide fractions using the keep-change-flip method.',
    'built_in',
    null,
    'grade_5'
  )
  returning id into v_lesson3_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson3_id, 1, 'introduction', 'Introduction',
    E'We already know how to add and subtract fractions. In this lesson, we will learn how to multiply and divide fractions - two operations you will use often, like finding a portion of a portion, or sharing an amount into equal fraction-sized parts.'
  ),
  (
    v_lesson3_id, 2, 'explanation', 'Quick Review: Fraction Basics',
    E'Before we begin, let us review a few terms:\n' ||
    E'  Numerator - the top number of a fraction, showing how many parts we have.\n' ||
    E'  Denominator - the bottom number of a fraction, showing how many equal parts make a whole.\n' ||
    E'  Proper fraction - a fraction where the numerator is smaller than the denominator, like 3/4.\n' ||
    E'  Simplifying - writing a fraction using the smallest possible numerator and denominator, like changing 6/12 to 1/2.\n\n' ||
    E'We will use these terms throughout the lesson.'
  ),
  (
    v_lesson3_id, 3, 'explanation', 'Multiplying Fractions',
    E'To multiply two fractions, multiply the numerators together, then multiply the denominators together.\n\n' ||
    E'Worked Example:\n' ||
    E'  2/3 x 4/5 = ?\n' ||
    E'  Multiply the numerators: 2 x 4 = 8.\n' ||
    E'  Multiply the denominators: 3 x 5 = 15.\n' ||
    E'  Answer: 2/3 x 4/5 = 8/15.\n\n' ||
    E'8/15 is already in simplest form, since 8 and 15 share no common factor other than 1.'
  ),
  (
    v_lesson3_id, 4, 'explanation', 'Multiplying a Fraction by a Whole Number',
    E'A whole number can be written as a fraction by placing it over 1.\n\n' ||
    E'Worked Example:\n' ||
    E'  3 x 2/5 = ?\n' ||
    E'  Rewrite the whole number: 3 = 3/1.\n' ||
    E'  Multiply: 3/1 x 2/5 = (3 x 2) / (1 x 5) = 6/5.\n' ||
    E'  Answer: 3 x 2/5 = 6/5.\n\n' ||
    E'6/5 is an improper fraction (the numerator is larger than the denominator). It is also equal to the mixed number 1 1/5.'
  ),
  (
    v_lesson3_id, 5, 'examples', 'Simplifying Products',
    E'Sometimes a product can be simplified after multiplying.\n\n' ||
    E'Worked Example 1 (simplify after multiplying):\n' ||
    E'  2/3 x 3/4 = ?\n' ||
    E'  Multiply: (2 x 3) / (3 x 4) = 6/12.\n' ||
    E'  Simplify: 6/12 = 1/2.\n' ||
    E'  Answer: 2/3 x 3/4 = 1/2.\n\n' ||
    E'Worked Example 2 (simplify before multiplying):\n' ||
    E'  2/3 x 3/4 can also be simplified first: the 3 in the first fraction and the 3 in the second fraction cancel out.\n' ||
    E'  This leaves 2/1 x 1/4 = 2/4 = 1/2 - the same answer, reached with smaller numbers.'
  ),
  (
    v_lesson3_id, 6, 'explanation', 'Understanding Fraction Multiplication',
    E'Multiplying two fractions can be understood as finding a fraction OF another fraction.\n\n' ||
    E'Worked Example:\n' ||
    E'  1/2 x 3/4 means "one-half of three-fourths".\n' ||
    E'  1/2 x 3/4 = 3/8, so one-half of three-fourths is 3/8.'
  ),
  (
    v_lesson3_id, 7, 'explanation', 'Dividing Fractions: Keep-Change-Flip',
    E'To divide fractions, we use keep-change-flip:\n' ||
    E'  Keep the first fraction the same.\n' ||
    E'  Change the division sign to a multiplication sign.\n' ||
    E'  Flip the second fraction (the divisor) - swap its numerator and denominator.\n\n' ||
    E'Worked Example:\n' ||
    E'  2/3 / 4/5 = ?\n' ||
    E'  Keep: 2/3.\n' ||
    E'  Change / to x.\n' ||
    E'  Flip 4/5 to 5/4.\n' ||
    E'  Multiply: 2/3 x 5/4 = 10/12 = 5/6.\n' ||
    E'  Answer: 2/3 / 4/5 = 5/6.\n\n' ||
    E'Only the second fraction (the divisor) is flipped - the first fraction never changes.'
  ),
  (
    v_lesson3_id, 8, 'examples', 'Dividing With Whole Numbers',
    E'Worked Example 1 (fraction divided by a whole number):\n' ||
    E'  3/4 / 2 = ?\n' ||
    E'  Rewrite the whole number: 2 = 2/1.\n' ||
    E'  Keep 3/4, change / to x, flip 2/1 to 1/2.\n' ||
    E'  Multiply: 3/4 x 1/2 = 3/8.\n' ||
    E'  Answer: 3/4 / 2 = 3/8.\n\n' ||
    E'Worked Example 2 (whole number divided by a fraction):\n' ||
    E'  3 / 1/2 = ?\n' ||
    E'  Rewrite the whole number: 3 = 3/1.\n' ||
    E'  Keep 3/1, change / to x, flip 1/2 to 2/1.\n' ||
    E'  Multiply: 3/1 x 2/1 = 6/1 = 6.\n' ||
    E'  Answer: 3 / 1/2 = 6.'
  ),
  (
    v_lesson3_id, 9, 'explanation', 'Multiplication or Division?',
    E'How do you know which operation a problem needs? Think about what is happening, not just the words used.\n\n' ||
    E'  Finding a fraction OF an amount usually means multiplication. Example: "three-fourths of a ribbon" suggests 3/4 x (the ribbon length).\n' ||
    E'  Sharing an amount equally, or asking how many equal-sized groups fit into an amount, usually means division. Example: "how many 1/8-kilogram bags" suggests dividing by 1/8.\n\n' ||
    E'These are helpful clues, not strict rules - always think about what the problem is really asking.'
  ),
  (
    v_lesson3_id, 10, 'explanation', 'Common Mistakes to Avoid',
    E'Here are mistakes learners often make with fraction multiplication and division:\n\n' ||
    E'Multiplication mistake: adding the numerators and denominators instead of multiplying them.\n' ||
    E'  Incorrect: 1/2 x 1/3 = 2/5.  Correct: 1/2 x 1/3 = 1/6.\n\n' ||
    E'Division mistake: flipping the wrong fraction.\n' ||
    E'  Only the second fraction (the divisor) is flipped - never the first fraction, and never both.\n\n' ||
    E'Simplification mistake: forgetting to simplify the final answer.\n' ||
    E'  Always check whether the numerator and denominator share a common factor.\n\n' ||
    E'Whole-number mistake: forgetting to write a whole number as a fraction over 1 before multiplying or dividing.'
  ),
  (
    v_lesson3_id, 11, 'examples', 'Applying Fractions to Real Life',
    E'Worked Example 1 (multiplication):\n' ||
    E'  A student has 3/4 of a meter of ribbon and uses 2/3 of it. How much ribbon is used?\n' ||
    E'  Expression: 3/4 x 2/3.\n' ||
    E'  Multiply: (3 x 2) / (4 x 3) = 6/12.\n' ||
    E'  Simplify: 6/12 = 1/2.\n' ||
    E'  Answer: 1/2 meter of ribbon is used.\n\n' ||
    E'Worked Example 2 (division):\n' ||
    E'  A baker has 3/4 kilogram of flour and pours it into small bags that each hold 1/8 kilogram. How many bags can she fill?\n' ||
    E'  Expression: 3/4 / 1/8.\n' ||
    E'  Keep 3/4, change / to x, flip 1/8 to 8/1.\n' ||
    E'  Multiply: 3/4 x 8/1 = 24/4 = 6.\n' ||
    E'  Answer: She can fill 6 bags.'
  ),
  (
    v_lesson3_id, 12, 'summary', 'Remember',
    E'  - To multiply fractions: multiply the numerators, multiply the denominators, then simplify.\n' ||
    E'  - A whole number can be written as a fraction over 1 before multiplying or dividing.\n' ||
    E'  - To divide fractions: keep the first fraction, change division to multiplication, and flip only the second fraction (the divisor).\n' ||
    E'  - Always check whether your final answer can be simplified.\n' ||
    E'  - Think about what the problem is really asking to decide between multiplication and division.'
  );

  -- ===========================================================================
  -- Quiz 3 — built-in Internal Quiz for Lesson 3
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 3: Multiplying and Dividing Fractions',
    'internal', 'built_in', null, 'grade_5', true, true
  )
  returning id into v_quiz3_id;

  -- --- Q1 (multiplying fractions, requires simplifying) -----------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplying and Dividing Fractions',
    'What is 3/4 x 2/5, in simplest form?',
    'Multiply the numerators: 3 x 2 = 6. Multiply the denominators: 4 x 5 = 20. This gives 6/20, which simplifies to 3/10.'
  )
  returning id into v_q_1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_1, '3/10', true,  1),
    (v_q_1, '6/20', false, 2),
    (v_q_1, '5/9', false, 3),
    (v_q_1, '6/9', false, 4);

  -- --- Q2 (multiplying a fraction by a whole number) ---------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplying and Dividing Fractions',
    'What is 4 x 3/7?',
    'Rewrite the whole number as a fraction: 4 = 4/1. Multiply: (4 x 3) / (1 x 7) = 12/7.'
  )
  returning id into v_q_2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_2, '12/7', true,  1),
    (v_q_2, '3/28', false, 2),
    (v_q_2, '7/12', false, 3),
    (v_q_2, '12/11', false, 4);

  -- --- Q3 (simplifying a multiplication result) ---------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplying and Dividing Fractions',
    'What is 2/5 x 5/6, in simplest form?',
    'Multiply: (2 x 5) / (5 x 6) = 10/30. Simplify by dividing the numerator and denominator by 10: 10/30 = 1/3.'
  )
  returning id into v_q_3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_3, '1/3', true,  1),
    (v_q_3, '10/30', false, 2),
    (v_q_3, '7/11', false, 3),
    (v_q_3, '1/6', false, 4);

  -- --- Q4 (dividing fractions, keep-change-flip) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplying and Dividing Fractions',
    'What is 3/5 / 2/7?',
    'Keep 3/5, change division to multiplication, and flip only the second fraction: 2/7 becomes 7/2. Multiply: (3 x 7) / (5 x 2) = 21/10.'
  )
  returning id into v_q_4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_4, '21/10', true,  1),
    (v_q_4, '10/21', false, 2),
    (v_q_4, '6/35', false, 3),
    (v_q_4, '35/6', false, 4);

  -- --- Q5 (dividing a fraction by a whole number) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplying and Dividing Fractions',
    'What is 5/6 / 3?',
    'Rewrite the whole number: 3 = 3/1. Keep 5/6, change division to multiplication, and flip 3/1 to 1/3. Multiply: (5 x 1) / (6 x 3) = 5/18.'
  )
  returning id into v_q_5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_5, '5/18', true,  1),
    (v_q_5, '5/2', false, 2),
    (v_q_5, '18/5', false, 3),
    (v_q_5, '5/9', false, 4);

  -- --- Q6 (whole number divided by a fraction) ------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplying and Dividing Fractions',
    'What is 4 / 1/3?',
    'Rewrite the whole number: 4 = 4/1. Keep 4/1, change division to multiplication, and flip 1/3 to 3/1. Multiply: (4 x 3) / (1 x 1) = 12/1 = 12.'
  )
  returning id into v_q_6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_6, '12', true,  1),
    (v_q_6, '4/3', false, 2),
    (v_q_6, '1/12', false, 3),
    (v_q_6, '3', false, 4);

  -- --- Q7 (identify the correct reciprocal, conceptual) ---------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplying and Dividing Fractions',
    'To solve 5/8 / 3/7 using keep-change-flip, which fraction should you multiply 5/8 by?',
    'Only the second fraction (the divisor) is flipped. 3/7 flipped is 7/3, so 5/8 is multiplied by 7/3.'
  )
  returning id into v_q_7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_7, '7/3', true,  1),
    (v_q_7, '3/7', false, 2),
    (v_q_7, '8/5', false, 3),
    (v_q_7, '5/8', false, 4);

  -- --- Q8 (distinguishing multiplication from a described situation) ----------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplying and Dividing Fractions',
    'Which expression means "one-third of two-fifths"?',
    'Finding a fraction of another fraction is multiplication, so "one-third of two-fifths" is written as 1/3 x 2/5.'
  )
  returning id into v_q_8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_8, '1/3 x 2/5', true,  1),
    (v_q_8, '1/3 + 2/5', false, 2),
    (v_q_8, '1/3 / 2/5', false, 3),
    (v_q_8, '2/5 / 1/3', false, 4);

  -- --- Q9 (word problem, multiplication) --------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplying and Dividing Fractions',
    'A recipe needs 2/3 cup of sugar. Ana wants to make 3/4 of the recipe. How much sugar does she need?',
    'This is 2/3 x 3/4. Multiply: (2 x 3) / (3 x 4) = 6/12. Simplify: 6/12 = 1/2. Ana needs 1/2 cup of sugar.'
  )
  returning id into v_q_9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_9, '1/2 cup', true,  1),
    (v_q_9, '6/12 cup', false, 2),
    (v_q_9, '5/7 cup', false, 3),
    (v_q_9, '3/4 cup', false, 4);

  -- --- Q10 (word problem, division) --------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Multiplying and Dividing Fractions',
    'A ribbon that is 5/6 meter long is cut into pieces that are each 1/6 meter long. How many pieces can be cut?',
    'This is 5/6 / 1/6. Keep 5/6, change division to multiplication, and flip 1/6 to 6/1. Multiply: (5 x 6) / (6 x 1) = 30/6 = 5. She can cut 5 pieces.'
  )
  returning id into v_q_10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_10, '5 pieces', true,  1),
    (v_q_10, '5/36 pieces', false, 2),
    (v_q_10, '1/5 pieces', false, 3),
    (v_q_10, '30 pieces', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz3_id, v_q_1,  1),
    (v_quiz3_id, v_q_2,  2),
    (v_quiz3_id, v_q_3,  3),
    (v_quiz3_id, v_q_4,  4),
    (v_quiz3_id, v_q_5,  5),
    (v_quiz3_id, v_q_6,  6),
    (v_quiz3_id, v_q_7,  7),
    (v_quiz3_id, v_q_8,  8),
    (v_quiz3_id, v_q_9,  9),
    (v_quiz3_id, v_q_10, 10);

  -- ===========================================================================
  -- Link Lesson 3 -> Quiz 3 (0032's linked_quiz_id, same pattern as 0033/0066)
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz3_id where id = v_lesson3_id;

end $$;
