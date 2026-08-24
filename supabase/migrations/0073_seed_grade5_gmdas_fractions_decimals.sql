-- =============================================================================
-- Migration: 0073_seed_grade5_gmdas_fractions_decimals.sql
-- Content-seeding migration, following the same conventions established by
-- 0027 (Grade 4 seed) / 0029 (lesson_pages) / 0033 (lesson -> quiz link) /
-- 0071 (Grade 5 Lesson 7 / Quiz 7 seed) / 0072 (Grade 5 Lesson 8 / Quiz 8
-- seed — the most recent same-shape seeds).
--
-- Seeds Grade 5 built-in content:
--   Lesson 9 — GMDAS with Fractions and Decimals (11 lesson_pages)
--   Quiz 9   — Internal Quiz for Lesson 9 (10 questions, 4 choices each)
--
-- Single migration (no schema-then-content split) because every schema
-- piece this needs (lesson_pages from 0028/0030, lessons.linked_quiz_id
-- from 0032) already exists as of this project's current migration state
-- (through 0072) — only new rows are added here, matching 0071/0072's
-- approach.
--
-- All ids are database-generated (gen_random_uuid(), the default on every
-- affected table's id column) and captured via `returning ... into`, never
-- hardcoded. lessons/quizzes rows use source_type = 'built_in',
-- created_by = null, grade_level = 'grade_5', matching 0027/0071/0072's
-- pattern. question_bank.topic is tagged to match the owning lesson's title
-- (matches 0027/0071/0072's tagging), for the Highest/Lowest Performing
-- Topics dashboard metric (schema comment, 0008).
--
-- Each question's 4 choices are inserted in a single statement, so the
-- deferred `enforce_at_least_one_correct` constraint trigger (0014) never
-- observes a question with zero correct choices mid-transaction (matches
-- 0027/0071/0072's pattern).
--
-- Quiz expressions deliberately differ from the lesson's worked-example
-- values (per the one-to-one Lesson 9 <-> Quiz 9 pairing requested), so the
-- quiz tests understanding of GMDAS rather than memorized lesson examples.
-- Every expression below — whole numbers, fractions, and decimals — was
-- independently recomputed (via Fraction/Decimal arithmetic, not manual
-- estimation) before writing the question, including every distractor's
-- corresponding "common mistake" path.
-- =============================================================================

do $$
declare
  v_lesson_id uuid;
  v_quiz_id   uuid;

  -- Quiz 9 — GMDAS with Fractions and Decimals
  v_q1  uuid; v_q2  uuid; v_q3  uuid; v_q4  uuid; v_q5  uuid;
  v_q6  uuid; v_q7  uuid; v_q8  uuid; v_q9  uuid; v_q10 uuid;
begin

  -- ===========================================================================
  -- Lesson 9 — GMDAS with Fractions and Decimals
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'GMDAS with Fractions and Decimals',
    'Learn to apply GMDAS (Grouping symbols, Multiplication, Division, Addition, Subtraction) to solve expressions involving whole numbers, fractions, and decimals, following the correct order of operations step by step.',
    'built_in',
    null,
    'grade_5'
  )
  returning id into v_lesson_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn how to solve expressions with more than one operation by following the correct order of operations, called GMDAS. We will apply GMDAS to expressions involving whole numbers, fractions, and decimals.'
  ),
  (
    v_lesson_id, 2, 'vocabulary', 'What Is GMDAS?',
    E'GMDAS tells us the order to follow when an expression has more than one operation:\n\n' ||
    E'  G - Grouping symbols\n' ||
    E'  M - Multiplication\n' ||
    E'  D - Division\n' ||
    E'  A - Addition\n' ||
    E'  S - Subtraction\n\n' ||
    E'Multiplication and division have equal priority and are solved from left to right, in whichever order they appear. Addition and subtraction also have equal priority and are solved from left to right.'
  ),
  (
    v_lesson_id, 3, 'explanation', 'Grouping Symbols',
    E'Grouping symbols, like parentheses ( ), tell us which part of the expression to solve first.\n\n' ||
    E'Worked Example:\n' ||
    E'  (6 + 4) x 2\n' ||
    E'  First, solve inside the grouping symbols: 6 + 4 = 10\n' ||
    E'  Then multiply: 10 x 2 = 20\n' ||
    E'  Answer: 20\n\n' ||
    E'Always solve what is inside grouping symbols before moving on to the rest of the expression.'
  ),
  (
    v_lesson_id, 4, 'explanation', 'Multiplication and Division: Left to Right',
    E'Multiplication and division are solved before addition and subtraction, when there are no grouping symbols to solve first.\n\n' ||
    E'Multiplication and division have equal priority, so when both appear in the same expression, solve them in the order they appear, from left to right. Do not always multiply first just because M comes before D in GMDAS.\n\n' ||
    E'Worked Example:\n' ||
    E'  24 / 4 x 3\n' ||
    E'  Since division appears first, solve it first: 24 / 4 = 6\n' ||
    E'  Then multiply: 6 x 3 = 18\n' ||
    E'  Answer: 18'
  ),
  (
    v_lesson_id, 5, 'explanation', 'Addition and Subtraction: Left to Right',
    E'Addition and subtraction are solved after multiplication and division. They also have equal priority, so when both appear in the same expression, solve them in the order they appear, from left to right.\n\n' ||
    E'Worked Example:\n' ||
    E'  20 - 8 + 3\n' ||
    E'  Solve from left to right:\n' ||
    E'  20 - 8 = 12\n' ||
    E'  12 + 3 = 15\n' ||
    E'  Answer: 15'
  ),
  (
    v_lesson_id, 6, 'examples', 'Solving GMDAS Expressions',
    E'Follow these steps to solve any GMDAS expression:\n' ||
    E'  1. Solve what is inside grouping symbols.\n' ||
    E'  2. Perform multiplication and division from left to right.\n' ||
    E'  3. Perform addition and subtraction from left to right.\n' ||
    E'  4. Check the final answer.\n\n' ||
    E'Worked Example:\n' ||
    E'  8 + 3 x 2\n' ||
    E'  Step 2: Multiply first: 3 x 2 = 6\n' ||
    E'  Step 3: Add: 8 + 6 = 14\n' ||
    E'  Answer: 14'
  ),
  (
    v_lesson_id, 7, 'examples', 'GMDAS with Fractions',
    E'We follow the same GMDAS steps when an expression has fractions.\n\n' ||
    E'Worked Example:\n' ||
    E'  1/2 + 1/4 x 2\n' ||
    E'  Step 2: Multiply first: 1/4 x 2 = 2/4 = 1/2\n' ||
    E'  Step 3: Add: 1/2 + 1/2 = 1\n' ||
    E'  Answer: 1'
  ),
  (
    v_lesson_id, 8, 'examples', 'GMDAS with Decimals',
    E'We follow the same GMDAS steps when an expression has decimals.\n\n' ||
    E'Worked Example:\n' ||
    E'  2.5 + 1.5 x 2\n' ||
    E'  Step 2: Multiply first: 1.5 x 2 = 3\n' ||
    E'  Step 3: Add: 2.5 + 3 = 5.5\n' ||
    E'  Answer: 5.5\n\n' ||
    E'Always line up the decimal points carefully when adding, subtracting, or multiplying decimals.'
  ),
  (
    v_lesson_id, 9, 'examples', 'Real-Life Application',
    E'Worked Example:\n' ||
    E'  Ana has ₱2.00. She buys 3 pieces of candy that cost ₱0.50 each, then her mother gives her an extra ₱1.00. How much money does Ana have now?\n\n' ||
    E'  Expression: 2.00 - 3 x 0.50 + 1.00\n' ||
    E'  Step 2: Multiply first: 3 x 0.50 = 1.50\n' ||
    E'  Step 3: Subtract and add from left to right: 2.00 - 1.50 = 0.50, then 0.50 + 1.00 = 1.50\n' ||
    E'  Answer: Ana has ₱1.50.'
  ),
  (
    v_lesson_id, 10, 'explanation', 'Common Mistakes to Avoid',
    E'Mistake 1: Solving strictly from left to right without checking for multiplication or division first.\n' ||
    E'  Always apply GMDAS instead of just reading left to right.\n\n' ||
    E'Mistake 2: Adding before multiplying.\n' ||
    E'  Multiplication and division come before addition and subtraction.\n\n' ||
    E'Mistake 3: Always multiplying before dividing, even when division appears first.\n' ||
    E'  Multiplication and division have equal priority — solve them in the order they appear.\n\n' ||
    E'Mistake 4: Always adding before subtracting, even when subtraction appears first.\n' ||
    E'  Addition and subtraction have equal priority — solve them in the order they appear.\n\n' ||
    E'Mistake 5: Ignoring grouping symbols.\n' ||
    E'  Always solve what is inside grouping symbols first.\n\n' ||
    E'Mistake 6: Making errors when adding, subtracting, or multiplying fractions and decimals.\n' ||
    E'  Double-check every fraction and decimal calculation before moving to the next step.'
  ),
  (
    v_lesson_id, 11, 'summary', 'Remember',
    E'  - GMDAS stands for Grouping symbols, Multiplication, Division, Addition, and Subtraction.\n' ||
    E'  - Always solve grouping symbols first.\n' ||
    E'  - Multiplication and division have equal priority — solve them from left to right.\n' ||
    E'  - Addition and subtraction have equal priority — solve them from left to right.\n' ||
    E'  - The same GMDAS steps apply to expressions with fractions and decimals.\n' ||
    E'  - Always check your final answer.'
  );

  -- ===========================================================================
  -- Quiz 9 — built-in Internal Quiz for Lesson 9
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 9: GMDAS with Fractions and Decimals',
    'internal', 'built_in', null, 'grade_5', true, true
  )
  returning id into v_quiz_id;

  -- --- Q1 (basic — identify the correct GMDAS order) ------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'GMDAS with Fractions and Decimals',
    'What is the correct order of operations in GMDAS?',
    'GMDAS stands for Grouping symbols, Multiplication, Division, Addition, and Subtraction — solved in that order, with multiplication/division and addition/subtraction each solved left to right when they appear together.'
  )
  returning id into v_q1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1, 'Grouping symbols, Multiplication, Division, Addition, Subtraction', true,  1),
    (v_q1, 'Grouping symbols, Addition, Subtraction, Multiplication, Division', false, 2),
    (v_q1, 'Multiplication, Division, Grouping symbols, Addition, Subtraction', false, 3),
    (v_q1, 'Addition, Subtraction, Multiplication, Division, Grouping symbols', false, 4);

  -- --- Q2 (basic — solve a simple GMDAS expression) --------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'GMDAS with Fractions and Decimals',
    'What is 7 + 4 x 3?',
    'Multiply first: 4 x 3 = 12. Then add: 7 + 12 = 19.'
  )
  returning id into v_q2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2, '19', true,  1),
    (v_q2, '33', false, 2),
    (v_q2, '31', false, 3),
    (v_q2, '14', false, 4);

  -- --- Q3 (basic/intermediate — grouping symbols) ----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'GMDAS with Fractions and Decimals',
    'What is (5 + 3) x 4?',
    'Solve inside the grouping symbols first: 5 + 3 = 8. Then multiply: 8 x 4 = 32.'
  )
  returning id into v_q3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q3, '32', true,  1),
    (v_q3, '17', false, 2),
    (v_q3, '23', false, 3),
    (v_q3, '20', false, 4);

  -- --- Q4 (intermediate — multiplication and division, left to right) -------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'GMDAS with Fractions and Decimals',
    'What is 36 ÷ 6 x 2?',
    'Division appears first, so solve it first: 36 ÷ 6 = 6. Then multiply: 6 x 2 = 12.'
  )
  returning id into v_q4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q4, '12', true,  1),
    (v_q4, '6',  false, 2),
    (v_q4, '3',  false, 3),
    (v_q4, '24', false, 4);

  -- --- Q5 (intermediate — fractions) -----------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'GMDAS with Fractions and Decimals',
    'What is 1/3 + 1/6 x 2?',
    'Multiply first: 1/6 x 2 = 2/6 = 1/3. Then add: 1/3 + 1/3 = 2/3.'
  )
  returning id into v_q5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5, '2/3', true,  1),
    (v_q5, '1',   false, 2),
    (v_q5, '1/2', false, 3),
    (v_q5, '5/6', false, 4);

  -- --- Q6 (intermediate — decimals) ------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'GMDAS with Fractions and Decimals',
    'What is 4.5 - 1.5 x 2?',
    'Multiply first: 1.5 x 2 = 3. Then subtract: 4.5 - 3 = 1.5.'
  )
  returning id into v_q6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6, '1.5', true,  1),
    (v_q6, '6',   false, 2),
    (v_q6, '3',   false, 3),
    (v_q6, '7.5', false, 4);

  -- --- Q7 (intermediate/application — multi-step expression) -----------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'GMDAS with Fractions and Decimals',
    'What is 10 + 2 x (3 + 1) - 4?',
    'Solve the grouping symbols first: 3 + 1 = 4. Then multiply: 2 x 4 = 8. Then add and subtract from left to right: 10 + 8 = 18, then 18 - 4 = 14.'
  )
  returning id into v_q7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q7, '14', true,  1),
    (v_q7, '18', false, 2),
    (v_q7, '44', false, 3),
    (v_q7, '10', false, 4);

  -- --- Q8 (application — real-life word problem with decimals) ---------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'GMDAS with Fractions and Decimals',
    'Jenny has ₱50.00. She buys 3 notebooks that cost ₱12.50 each. Then her mother gives her ₱20.00. How much money does Jenny have now?',
    'Multiply first: 3 x ₱12.50 = ₱37.50. Then subtract and add from left to right: ₱50.00 - ₱37.50 = ₱12.50, then ₱12.50 + ₱20.00 = ₱32.50.'
  )
  returning id into v_q8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q8, '₱32.50', true,  1),
    (v_q8, '₱12.50', false, 2),
    (v_q8, '-₱7.50', false, 3),
    (v_q8, '₱34.00', false, 4);

  -- --- Q9 (application — identify the mistake in a solution) -----------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'GMDAS with Fractions and Decimals',
    'A student solved 6 + 4 x 2 and got 20 by adding first: 6 + 4 = 10, then 10 x 2 = 20. What mistake did the student make?',
    'The student added before multiplying. Multiplication should be done first: 4 x 2 = 8, then 6 + 8 = 14. The correct answer is 14, not 20.'
  )
  returning id into v_q9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9, 'The student added before multiplying, but multiplication should come first', true,  1),
    (v_q9, 'The student multiplied before adding, which is correct',                     false, 2),
    (v_q9, 'The student ignored a grouping symbol',                                      false, 3),
    (v_q9, 'The student made a decimal error',                                           false, 4);

  -- --- Q10 (application — real-life word problem with fractions) -------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'GMDAS with Fractions and Decimals',
    'A recipe needs 1/4 cup of sugar for each batch. Mia makes 2 batches, then adds an extra 1/2 cup of sugar for a topping. How much sugar does she use in total?',
    'Multiply first: 1/4 x 2 = 1/2 cup for the batches. Then add the topping: 1/2 + 1/2 = 1 cup.'
  )
  returning id into v_q10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10, '1 cup',       true,  1),
    (v_q10, '3/4 cup',     false, 2),
    (v_q10, '1 1/4 cups',  false, 3),
    (v_q10, '1/2 cup',     false, 4);

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
  -- Lesson 9 -> Quiz 9 link (0032's linked_quiz_id, same pattern as 0033/0071/0072)
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz_id where id = v_lesson_id;

end $$;
