-- =============================================================================
-- Migration: 0066_seed_grade5_solving_operations_using_gmdas.sql
-- Content-seeding migration, following the same "schema already in place,
-- content only" pattern used by 0027 (Grade 4 seed) and 0029/0031/0033
-- (Grade 4 lesson_pages/worked_example/linked_quiz follow-ups) — except
-- consolidated into a single migration, since lesson_pages, question_bank,
-- quiz_questions, and lessons.linked_quiz_id are all already-existing
-- schema by this point (0028/0008-0009/0032) and there is no separate
-- "schema first" step needed here.
--
-- Seeds Grade 5 (MELC-level) built-in content:
--   Lesson 2 — Solving Operations Using GMDAS
--   Quiz 2   — Internal Quiz for Lesson 2 (10 questions)
--
-- This is the SECOND Grade 5 lesson in the sequence (Lesson 1 is assumed
-- to already exist in the live project; it is not part of this reference
-- package, so it is neither read from nor written by this migration).
--
-- Conventions matched against 0027/0029/0031/0033 (all re-read in full
-- before writing this):
--   - lessons: source_type = 'built_in', created_by = null,
--     grade_level = 'grade_5' (lessons_source_created_by_pairing, 0007;
--     grade_level values confirmed against lib/core/models/section.dart's
--     GradeLevel enum: 'grade_4' | 'grade_5' | 'grade_6').
--   - lessons.body is the SHORT 1-2 sentence list-screen description (the
--     full content lives in lesson_pages), matching the post-0029 shape
--     of the Grade 4 lessons, not 0027's original full-text blob.
--   - lesson_pages: one row per slide, display_order starting at 1,
--     section_type drawn only from values already seen in 0029
--     ('introduction' | 'explanation' | 'examples' | 'summary') — no new
--     section_type invented, per the "do not invent new structure"
--     instruction. worked_example (0030) is deliberately left null on
--     every page: that column is explicitly scoped in its own migration
--     comment as a fixed-6-column place-value addition/subtraction POC,
--     not built to generalize to order-of-operations content, so forcing
--     it here would misuse a field outside its documented shape.
--   - question_bank: source_type = 'built_in', created_by = null,
--     topic = the lesson title (matches 0027's topic-tagging convention
--     for the Highest/Lowest Performing Topics dashboard metric).
--   - question_choices: exactly 4 choices per question, exactly one
--     is_correct = true, display_order 1-4, all inserted in a single
--     statement per question (same reasoning as 0027: the deferred
--     enforce_at_least_one_correct trigger, 0014, must never observe a
--     zero-correct-choice question mid-transaction).
--   - quizzes: title 'Quiz 2: Solving Operations Using GMDAS',
--     quiz_type = 'internal', source_type = 'built_in', created_by = null,
--     grade_level = 'grade_5', shuffle_questions = true,
--     shuffle_choices = true (matches 0027 exactly; assessment_type, 0043,
--     is left null — this is an ordinary practice/graded quiz, not a
--     pre/post intervention measure).
--   - quiz_questions: display_order 1-10, one row per question, matching
--     0027's insert-all-at-once style.
--   - lessons.linked_quiz_id: set via UPDATE after both the lesson and
--     quiz exist, same as 0033 — done in the same DO block here rather
--     than a separate follow-up migration, since (unlike the historical
--     0027->0032->0033 sequence) linked_quiz_id already exists as a
--     column by this point and there's no schema-change reason to split
--     it into its own file.
--
-- All ids are database-generated (gen_random_uuid(), the default on every
-- affected table's id column) and captured via `returning ... into`, never
-- hardcoded.
--
-- MATH INDEPENDENTLY VERIFIED for every lesson example and every quiz
-- question/distractor before writing (see inline comments below). GMDAS
-- is applied correctly throughout: grouping symbols first; multiplication
-- and division are equal-priority, left to right; addition and
-- subtraction are equal-priority, left to right. Nothing in this
-- migration teaches "multiplication always before division" or "addition
-- always before subtraction".
-- =============================================================================

do $$
declare
  v_lesson2_id uuid;
  v_quiz2_id   uuid;

  -- Quiz 2 — Solving Operations Using GMDAS
  v_q_1  uuid; v_q_2  uuid; v_q_3  uuid; v_q_4  uuid; v_q_5  uuid;
  v_q_6  uuid; v_q_7  uuid; v_q_8  uuid; v_q_9  uuid; v_q_10 uuid;
begin

  -- ===========================================================================
  -- Lesson 2 — Solving Operations Using GMDAS
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Solving Operations Using GMDAS',
    'Learn to solve numerical expressions with more than one operation by following GMDAS: grouping symbols first, then multiplication and division (left to right), then addition and subtraction (left to right).',
    'built_in',
    null,
    'grade_5'
  )
  returning id into v_lesson2_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson2_id, 1, 'introduction', 'Introduction',
    E'Sometimes a math problem has more than one operation, like addition and multiplication together. If everyone solved the operations in a different order, they could get different answers! GMDAS is the set of rules that tells us exactly which operation to solve first, so that everyone gets the same, correct answer.'
  ),
  (
    v_lesson2_id, 2, 'explanation', 'What Does GMDAS Mean?',
    E'GMDAS stands for the order in which we solve operations:\n' ||
    E'  G - Grouping Symbols\n' ||
    E'  M - Multiplication\n' ||
    E'  D - Division\n' ||
    E'  A - Addition\n' ||
    E'  S - Subtraction\n\n' ||
    E'This order tells us which operations to perform first when an expression has more than one operation.'
  ),
  (
    v_lesson2_id, 3, 'explanation', 'Grouping Symbols First',
    E'When an expression has grouping symbols, like ( ), the operation inside them must always be solved first - before anything outside the grouping symbols.\n\n' ||
    E'Worked Example:\n' ||
    E'  8 + (6 x 2) = ?\n' ||
    E'  First, solve inside the grouping symbols: 6 x 2 = 12.\n' ||
    E'  Then add: 8 + 12 = 20.\n' ||
    E'  Answer: 8 + (6 x 2) = 20.'
  ),
  (
    v_lesson2_id, 4, 'explanation', 'Multiplication and Division: Left to Right',
    E'Multiplication and division have EQUAL priority. Neither one always comes first - whichever one appears FIRST (on the left) in the expression is solved first.\n\n' ||
    E'Worked Example:\n' ||
    E'  24 / 6 x 3 = ?\n' ||
    E'  Division appears first (on the left), so solve it first: 24 / 6 = 4.\n' ||
    E'  Then multiply: 4 x 3 = 12.\n' ||
    E'  Answer: 24 / 6 x 3 = 12.'
  ),
  (
    v_lesson2_id, 5, 'explanation', 'Addition and Subtraction: Left to Right',
    E'Addition and subtraction also have EQUAL priority. Whichever one appears FIRST (on the left) in the expression is solved first.\n\n' ||
    E'Worked Example:\n' ||
    E'  18 - 5 + 2 = ?\n' ||
    E'  Subtraction appears first (on the left), so solve it first: 18 - 5 = 13.\n' ||
    E'  Then add: 13 + 2 = 15.\n' ||
    E'  Answer: 18 - 5 + 2 = 15.'
  ),
  (
    v_lesson2_id, 6, 'examples', 'Solving Complete GMDAS Expressions',
    E'Worked Example 1:\n' ||
    E'  6 + 4 x 3 = ?\n' ||
    E'  Multiplication before addition: 4 x 3 = 12.\n' ||
    E'  Then add: 6 + 12 = 18.\n' ||
    E'  Answer: 6 + 4 x 3 = 18.\n\n' ||
    E'Worked Example 2 (step by step):\n' ||
    E'  20 - 3 x 4 + 2 = ?\n' ||
    E'  Step 1 - Multiplication: 3 x 4 = 12. The expression becomes 20 - 12 + 2.\n' ||
    E'  Step 2 - Subtraction and addition, left to right: 20 - 12 = 8, then 8 + 2 = 10.\n' ||
    E'  Answer: 20 - 3 x 4 + 2 = 10.\n\n' ||
    E'Worked Example 3 (multiplication and division together):\n' ||
    E'  18 + 12 / 3 x 2 = ?\n' ||
    E'  Division and multiplication first, left to right: 12 / 3 = 4, then 4 x 2 = 8.\n' ||
    E'  Then add: 18 + 8 = 26.\n' ||
    E'  Answer: 18 + 12 / 3 x 2 = 26.'
  ),
  (
    v_lesson2_id, 7, 'examples', 'Expressions with Grouping Symbols',
    E'Worked Example 1:\n' ||
    E'  (8 + 4) x 2 = ?\n' ||
    E'  Solve inside the grouping symbols first: 8 + 4 = 12.\n' ||
    E'  Then multiply: 12 x 2 = 24.\n' ||
    E'  Answer: (8 + 4) x 2 = 24.\n\n' ||
    E'Worked Example 2 (grouping symbols with multiplication inside):\n' ||
    E'  30 / (2 x 3) = ?\n' ||
    E'  Solve inside the grouping symbols first: 2 x 3 = 6.\n' ||
    E'  Then divide: 30 / 6 = 5.\n' ||
    E'  Answer: 30 / (2 x 3) = 5.'
  ),
  (
    v_lesson2_id, 8, 'explanation', 'Common Mistakes to Avoid',
    E'Here are mistakes learners often make with GMDAS:\n\n' ||
    E'Mistake 1: Solving strictly from left to right and ignoring GMDAS.\n' ||
    E'  Always check for grouping symbols and multiplication/division first.\n\n' ||
    E'Mistake 2: Adding before multiplying.\n' ||
    E'  In 5 + 3 x 4, multiply first (3 x 4 = 12), then add (5 + 12 = 17).\n\n' ||
    E'Mistake 3: Thinking multiplication always comes before division.\n' ||
    E'  Multiplication and division have equal priority - solve whichever comes first, left to right.\n\n' ||
    E'Mistake 4: Thinking addition always comes before subtraction.\n' ||
    E'  Addition and subtraction have equal priority - solve whichever comes first, left to right.'
  ),
  (
    v_lesson2_id, 9, 'examples', 'Applying GMDAS to Word Problems',
    E'Worked Example 1:\n' ||
    E'  Aling Rosa has 4 baskets of mangoes with 9 mangoes in each basket. She also has 6 extra mangoes on the table. How many mangoes does she have in all?\n' ||
    E'  Expression: 4 x 9 + 6\n' ||
    E'  Multiply first: 4 x 9 = 36.\n' ||
    E'  Then add: 36 + 6 = 42.\n' ||
    E'  Answer: Aling Rosa has 42 mangoes in all.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  The school canteen prepared 15 ham sandwiches and 9 egg sandwiches for recess, then sold 12 sandwiches. How many sandwiches are left?\n' ||
    E'  Expression: (15 + 9) - 12\n' ||
    E'  Solve inside the grouping symbols first: 15 + 9 = 24.\n' ||
    E'  Then subtract: 24 - 12 = 12.\n' ||
    E'  Answer: 12 sandwiches are left.'
  ),
  (
    v_lesson2_id, 10, 'summary', 'Remember',
    E'  - G first: solve inside grouping symbols before anything else.\n' ||
    E'  - Multiplication and Division have equal priority - solve left to right.\n' ||
    E'  - Addition and Subtraction have equal priority - solve left to right.\n' ||
    E'  - Solve one step at a time, and rewrite the expression after each step.\n' ||
    E'  - Always check your answer by reviewing each step.'
  );

  -- ===========================================================================
  -- Quiz 2 — built-in Internal Quiz for Lesson 2
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 2: Solving Operations Using GMDAS',
    'internal', 'built_in', null, 'grade_5', true, true
  )
  returning id into v_quiz2_id;

  -- --- Q1 (identify: grouping symbols first) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Solving Operations Using GMDAS',
    'In the expression 7 + (5 x 3), which part must be solved first?',
    'GMDAS says grouping symbols are always solved first, no matter what operation is inside them. So (5 x 3) must be solved before the addition.'
  )
  returning id into v_q_1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_1, '(5 x 3)', true,  1),
    (v_q_1, '7 + 5', false, 2),
    (v_q_1, '3 alone', false, 3),
    (v_q_1, 'It does not matter which part you solve first', false, 4);

  -- --- Q2 (multiplication before addition) -----------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Solving Operations Using GMDAS',
    'What is 5 + 3 x 4?',
    'Multiplication comes before addition in GMDAS: 3 x 4 = 12. Then add: 5 + 12 = 17.'
  )
  returning id into v_q_2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_2, '17', true,  1),
    (v_q_2, '32', false, 2),
    (v_q_2, '12', false, 3),
    (v_q_2, '19', false, 4);

  -- --- Q3 (division and subtraction) ------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Solving Operations Using GMDAS',
    'What is 30 / 5 - 2?',
    'Division comes before subtraction: 30 / 5 = 6. Then subtract: 6 - 2 = 4.'
  )
  returning id into v_q_3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_3, '4', true,  1),
    (v_q_3, '10', false, 2),
    (v_q_3, '3', false, 3),
    (v_q_3, '25', false, 4);

  -- --- Q4 (multiplication and division, left to right) ------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Solving Operations Using GMDAS',
    'What is 60 / 3 x 2?',
    'Multiplication and division have equal priority, so solve left to right: division appears first, 60 / 3 = 20. Then multiply: 20 x 2 = 40. Multiplication does not always come before division.'
  )
  returning id into v_q_4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_4, '40', true,  1),
    (v_q_4, '10', false, 2),
    (v_q_4, '20', false, 3),
    (v_q_4, '90', false, 4);

  -- --- Q5 (addition and subtraction, left to right) ----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Solving Operations Using GMDAS',
    'What is 20 - 7 + 3?',
    'Addition and subtraction have equal priority, so solve left to right: subtraction appears first, 20 - 7 = 13. Then add: 13 + 3 = 16. Addition does not always come before subtraction.'
  )
  returning id into v_q_5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_5, '16', true,  1),
    (v_q_5, '10', false, 2),
    (v_q_5, '30', false, 3),
    (v_q_5, '13', false, 4);

  -- --- Q6 (grouping symbols) -----------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Solving Operations Using GMDAS',
    'What is (9 + 6) x 3?',
    'Solve inside the grouping symbols first: 9 + 6 = 15. Then multiply: 15 x 3 = 45.'
  )
  returning id into v_q_6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_6, '45', true,  1),
    (v_q_6, '27', false, 2),
    (v_q_6, '33', false, 3),
    (v_q_6, '18', false, 4);

  -- --- Q7 (grouping symbols containing multiplication) --------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Solving Operations Using GMDAS',
    'What is 40 / (5 x 2)?',
    'Solve inside the grouping symbols first: 5 x 2 = 10. Then divide: 40 / 10 = 4.'
  )
  returning id into v_q_7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_7, '4', true,  1),
    (v_q_7, '16', false, 2),
    (v_q_7, '8', false, 3),
    (v_q_7, '20', false, 4);

  -- --- Q8 (complete multi-operation expression) ----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Solving Operations Using GMDAS',
    'What is 25 - 4 x 3 + 6?',
    'Multiplication first: 4 x 3 = 12, so the expression becomes 25 - 12 + 6. Then subtraction and addition, left to right: 25 - 12 = 13, then 13 + 6 = 19.'
  )
  returning id into v_q_8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_8, '19', true,  1),
    (v_q_8, '7', false, 2),
    (v_q_8, '13', false, 3),
    (v_q_8, '69', false, 4);

  -- --- Q9 (identify a common GMDAS mistake) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Solving Operations Using GMDAS',
    'Jay solved 6 + 2 x 5 by adding first (6 + 2 = 8), then multiplying (8 x 5 = 40). What did Jay do wrong?',
    'Jay should have multiplied first (2 x 5 = 10), then added (6 + 10 = 16). GMDAS requires multiplication before addition, not left-to-right when the operations have different priority.'
  )
  returning id into v_q_9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_9, 'He should have multiplied first, then added', true,  1),
    (v_q_9, 'He should have added last too, so 40 is correct', false, 2),
    (v_q_9, 'He should have divided instead of multiplied', false, 3),
    (v_q_9, 'There is no mistake', false, 4);

  -- --- Q10 (word problem application) --------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Solving Operations Using GMDAS',
    'Michael bought 3 bags of rice at ₱45 each, plus a bag of sugar for ₱20. How much did he spend in all?',
    'This is 3 x 45 + 20. Multiply first: 3 x 45 = 135. Then add: 135 + 20 = 155. Michael spent ₱155 in all.'
  )
  returning id into v_q_10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_10, '₱155', true,  1),
    (v_q_10, '₱195', false, 2),
    (v_q_10, '₱65', false, 3),
    (v_q_10, '₱150', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz2_id, v_q_1,  1),
    (v_quiz2_id, v_q_2,  2),
    (v_quiz2_id, v_q_3,  3),
    (v_quiz2_id, v_q_4,  4),
    (v_quiz2_id, v_q_5,  5),
    (v_quiz2_id, v_q_6,  6),
    (v_quiz2_id, v_q_7,  7),
    (v_quiz2_id, v_q_8,  8),
    (v_quiz2_id, v_q_9,  9),
    (v_quiz2_id, v_q_10, 10);

  -- ===========================================================================
  -- Link Lesson 2 -> Quiz 2 (0032's linked_quiz_id, same pattern as 0033)
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz2_id where id = v_lesson2_id;

end $$;
