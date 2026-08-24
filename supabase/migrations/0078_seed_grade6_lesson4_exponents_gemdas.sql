-- =============================================================================
-- Migration: 0078_seed_grade6_lesson4_exponents_gemdas.sql
-- Content-only migration (no schema change).
-- Seeds the built-in Grade 6 Lesson 4 ("Exponents and GEMDAS") and its
-- lesson_pages.
--
-- NOTE: This migration was split off from what used to be a single combined
-- file (lesson + quiz + link). The quiz seed and the lesson-quiz link now
-- live in migration 0085 (0085_seed_grade6_quiz4_and_link_exponents_gemdas.sql),
-- which must be run AFTER this one.
--
-- worked_example (0030) is intentionally left null on every lesson page:
-- that column's shape is fixed, POC-scope, place-value digit-column
-- addition/subtraction (6 columns, Hundred Thousands..Ones) and cannot
-- represent an exponent/GEMDAS expression, so every worked example here
-- is plain-text body instead, matching every non-POC page already in
-- the project.
--
-- Every lesson calculation below was independently solved and verified —
-- see the chat response's final validation section for the full working.
-- =============================================================================

-- ===========================================================================
-- Grade 6 Lesson 4: Exponents and GEMDAS (+ lesson_pages)
-- ===========================================================================

do $$
declare
  v_lesson_id uuid;
begin

  if exists (
    select 1 from public.lessons
    where title = 'Exponents and GEMDAS'
      and source_type = 'built_in'
      and grade_level = 'grade_6'
  ) then
    raise notice '0078: Grade 6 Lesson 4 (Exponents and GEMDAS) already exists — skipping, not creating a duplicate.';
    return;
  end if;

  insert into public.lessons (title, body, source_type, grade_level)
  values (
    'Exponents and GEMDAS',
    'Learn what an exponent means, how to evaluate powers, and how to use GEMDAS — including the left-to-right rule for multiplication/division and addition/subtraction — to solve multi-step numerical expressions.',
    'built_in',
    'grade_6'
  )
  returning id into v_lesson_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values

  (
    v_lesson_id, 1, 'introduction', 'Welcome to Exponents and GEMDAS',
    E'In this lesson, you will learn about exponents -- a shorter way to write repeated multiplication -- and GEMDAS, the set of rules that tells us which operation to do first when a numerical expression has more than one operation.\n\n' ||
    E'By the end of this lesson, you will be able to:\n' ||
    E'  - Identify the base and exponent in a power.\n' ||
    E'  - Write repeated multiplication as an exponent, and expand an exponent back into repeated multiplication.\n' ||
    E'  - Evaluate powers.\n' ||
    E'  - Use GEMDAS to solve numerical expressions with grouping symbols, exponents, multiplication, division, addition, and subtraction.\n' ||
    E'  - Solve multiplication/division and addition/subtraction in the correct left-to-right order.'
  ),

  (
    v_lesson_id, 2, 'vocabulary', 'What Is an Exponent?',
    E'An exponent is a small number written above and to the right of another number. It tells how many times that number -- called the base -- is used as a factor in multiplication.\n\n' ||
    E'  2\u00b3\n' ||
    E'  base: 2 (the number being multiplied)\n' ||
    E'  exponent: 3 (how many times the base is used as a factor)\n\n' ||
    E'2\u00b3 means 2 is used as a factor 3 times:\n' ||
    E'  2\u00b3 = 2 \u00d7 2 \u00d7 2 = 8\n\n' ||
    E'The whole expression, 2\u00b3 = 8, is called a power. "2 to the third power" and "2 cubed" both mean 2\u00b3.\n\n' ||
    E'IMPORTANT: an exponent does NOT tell you to multiply the base by the exponent.\n' ||
    E'  5\u00b2 means 5 \u00d7 5 = 25\n' ||
    E'  5\u00b2 does NOT mean 5 \u00d7 2 = 10\n\n' ||
    E'More examples:\n' ||
    E'  4\u00b3 -> base is 4, exponent is 3 -> 4 \u00d7 4 \u00d7 4 = 64\n' ||
    E'  7\u00b2 -> base is 7, exponent is 2 -> 7 \u00d7 7 = 49\n' ||
    E'  3\u2074 -> base is 3, exponent is 4 -> 3 \u00d7 3 \u00d7 3 \u00d7 3 = 81'
  ),

  (
    v_lesson_id, 3, 'explanation', 'Repeated Multiplication and Exponents',
    E'Any repeated multiplication can be written as a power, and any power can be expanded back into repeated multiplication.\n\n' ||
    E'Repeated multiplication -> Exponential form\n' ||
    E'  6 \u00d7 6 \u00d7 6 \u00d7 6 = 6\u2074\n' ||
    E'  (6 is repeated as a factor 4 times, so the exponent is 4.)\n\n' ||
    E'  2 \u00d7 2 \u00d7 2 \u00d7 2 \u00d7 2 = 2\u2075\n' ||
    E'  (2 is repeated as a factor 5 times, so the exponent is 5.)\n\n' ||
    E'Exponential form -> Repeated multiplication\n' ||
    E'  9\u00b3 = 9 \u00d7 9 \u00d7 9\n' ||
    E'  (The exponent 3 tells us to write 9 as a factor 3 times.)\n\n' ||
    E'  8\u2075 = 8 \u00d7 8 \u00d7 8 \u00d7 8 \u00d7 8\n' ||
    E'  (The exponent 5 tells us to write 8 as a factor 5 times.)\n\n' ||
    E'Tip: the exponent always tells you how many times to WRITE the base -- never what to multiply it by.'
  ),

  (
    v_lesson_id, 4, 'examples', 'Evaluating Powers',
    E'To evaluate a power, expand it into repeated multiplication, then multiply the factors together.\n\n' ||
    E'Worked Example 1 (Basic):\n' ||
    E'  3\u00b2\n' ||
    E'  Base: 3   Exponent: 2\n' ||
    E'  Expand: 3 \u00d7 3\n' ||
    E'  Multiply: 3 \u00d7 3 = 9\n' ||
    E'  Answer: 3\u00b2 = 9\n\n' ||
    E'Worked Example 2 (Moderate):\n' ||
    E'  2\u2074\n' ||
    E'  Base: 2   Exponent: 4\n' ||
    E'  Expand: 2 \u00d7 2 \u00d7 2 \u00d7 2\n' ||
    E'  Multiply: 2 \u00d7 2 = 4, then 4 \u00d7 2 = 8, then 8 \u00d7 2 = 16\n' ||
    E'  Answer: 2\u2074 = 16\n\n' ||
    E'Worked Example 3 (Challenging):\n' ||
    E'  5\u00b3\n' ||
    E'  Base: 5   Exponent: 3\n' ||
    E'  Expand: 5 \u00d7 5 \u00d7 5\n' ||
    E'  Multiply: 5 \u00d7 5 = 25, then 25 \u00d7 5 = 125\n' ||
    E'  Answer: 5\u00b3 = 125'
  ),

  (
    v_lesson_id, 5, 'explanation', 'Understanding GEMDAS',
    E'When a numerical expression has more than one operation, we follow a set order called GEMDAS so that everyone gets the same answer.\n\n' ||
    E'G -- Grouping Symbols: solve what''s inside parentheses ( ), brackets [ ], or braces { } first.\n' ||
    E'E -- Exponents: evaluate powers.\n' ||
    E'M -- Multiplication\n' ||
    E'D -- Division\n' ||
    E'A -- Addition\n' ||
    E'S -- Subtraction\n\n' ||
    E'IMPORTANT:\n' ||
    E'  - Multiplication and Division are NOT separate steps. They have EQUAL priority and are solved from LEFT TO RIGHT, in whichever order they appear.\n' ||
    E'  - Addition and Subtraction also have EQUAL priority and are solved from LEFT TO RIGHT.\n\n' ||
    E'So GEMDAS is really four steps, not six:\n' ||
    E'  1. Grouping symbols\n' ||
    E'  2. Exponents\n' ||
    E'  3. Multiplication AND Division (left to right)\n' ||
    E'  4. Addition AND Subtraction (left to right)'
  ),

  (
    v_lesson_id, 6, 'examples', 'Grouping Symbols Come First',
    E'Whatever is inside grouping symbols must be solved first, before anything outside them -- even before an exponent that is outside the grouping symbols.\n\n' ||
    E'Worked Example 1:\n' ||
    E'  (3 + 5) \u00d7 2\n' ||
    E'  Step 1 -- solve inside the parentheses: 3 + 5 = 8\n' ||
    E'  Rewrite: 8 \u00d7 2\n' ||
    E'  Step 2 -- multiply: 8 \u00d7 2 = 16\n' ||
    E'  Answer: (3 + 5) \u00d7 2 = 16\n\n' ||
    E'Worked Example 2 (grouping symbols with an exponent):\n' ||
    E'  (6 \u2212 2)\u00b2\n' ||
    E'  Step 1 -- solve inside the parentheses: 6 \u2212 2 = 4\n' ||
    E'  Rewrite: 4\u00b2\n' ||
    E'  Step 2 -- evaluate the exponent: 4 \u00d7 4 = 16\n' ||
    E'  Answer: (6 \u2212 2)\u00b2 = 16'
  ),

  (
    v_lesson_id, 7, 'explanation', 'Multiplication and Division: Left to Right',
    E'Multiplication and Division have EQUAL priority. Even though M comes before D in the word GEMDAS, that does NOT mean multiplication always happens first. Solve multiplication and division in the order they appear, left to right.\n\n' ||
    E'Worked Example 1:\n' ||
    E'  24 \u00f7 6 \u00d7 2\n' ||
    E'  Reading left to right, division appears first: 24 \u00f7 6 = 4\n' ||
    E'  Rewrite: 4 \u00d7 2\n' ||
    E'  Now multiply: 4 \u00d7 2 = 8\n' ||
    E'  Answer: 24 \u00f7 6 \u00d7 2 = 8\n\n' ||
    E'  (If you multiplied first instead -- 6 \u00d7 2 = 12, then 24 \u00f7 12 = 2 -- you would get the WRONG answer. Always work left to right.)\n\n' ||
    E'Worked Example 2:\n' ||
    E'  5 \u00d7 8 \u00f7 4\n' ||
    E'  Reading left to right, multiplication appears first: 5 \u00d7 8 = 40\n' ||
    E'  Rewrite: 40 \u00f7 4\n' ||
    E'  Now divide: 40 \u00f7 4 = 10\n' ||
    E'  Answer: 5 \u00d7 8 \u00f7 4 = 10'
  ),

  (
    v_lesson_id, 8, 'explanation', 'Addition and Subtraction: Left to Right',
    E'Addition and Subtraction also have EQUAL priority. Solve them in the order they appear, left to right -- do not automatically add before subtracting.\n\n' ||
    E'Worked Example 1:\n' ||
    E'  18 \u2212 5 + 3\n' ||
    E'  Reading left to right, subtraction appears first: 18 \u2212 5 = 13\n' ||
    E'  Rewrite: 13 + 3\n' ||
    E'  Now add: 13 + 3 = 16\n' ||
    E'  Answer: 18 \u2212 5 + 3 = 16\n\n' ||
    E'Worked Example 2:\n' ||
    E'  7 + 9 \u2212 4\n' ||
    E'  Reading left to right, addition appears first: 7 + 9 = 16\n' ||
    E'  Rewrite: 16 \u2212 4\n' ||
    E'  Now subtract: 16 \u2212 4 = 12\n' ||
    E'  Answer: 7 + 9 \u2212 4 = 12'
  ),

  (
    v_lesson_id, 9, 'examples', 'Exponents Inside GEMDAS Expressions',
    E'Once grouping symbols are handled, exponents are evaluated next -- before multiplication, division, addition, or subtraction.\n\n' ||
    E'Exponent + Addition:\n' ||
    E'  3\u00b2 + 5\n' ||
    E'  Evaluate the exponent first: 3\u00b2 = 9\n' ||
    E'  Rewrite: 9 + 5\n' ||
    E'  Add: 9 + 5 = 14\n' ||
    E'  Answer: 3\u00b2 + 5 = 14\n\n' ||
    E'Exponent + Subtraction:\n' ||
    E'  20 \u2212 2\u00b3\n' ||
    E'  Evaluate the exponent first: 2\u00b3 = 8\n' ||
    E'  Rewrite: 20 \u2212 8\n' ||
    E'  Subtract: 20 \u2212 8 = 12\n' ||
    E'  Answer: 20 \u2212 2\u00b3 = 12\n\n' ||
    E'Exponent + Multiplication:\n' ||
    E'  4 \u00d7 3\u00b2\n' ||
    E'  Evaluate the exponent first: 3\u00b2 = 9\n' ||
    E'  Rewrite: 4 \u00d7 9\n' ||
    E'  Multiply: 4 \u00d7 9 = 36\n' ||
    E'  Answer: 4 \u00d7 3\u00b2 = 36\n\n' ||
    E'Exponent + Division:\n' ||
    E'  100 \u00f7 2\u00b2\n' ||
    E'  Evaluate the exponent first: 2\u00b2 = 4\n' ||
    E'  Rewrite: 100 \u00f7 4\n' ||
    E'  Divide: 100 \u00f7 4 = 25\n' ||
    E'  Answer: 100 \u00f7 2\u00b2 = 25'
  ),

  (
    v_lesson_id, 10, 'examples', 'Multi-Step Expressions',
    E'Let''s put everything together -- grouping symbols, exponents, multiplication, division, addition, and subtraction -- in expressions with more than one step.\n\n' ||
    E'Basic:\n' ||
    E'  2\u00b3 + 4 \u00d7 2\n' ||
    E'  First operation: the exponent 2\u00b3 -- there are no grouping symbols, and exponents come before multiplication.\n' ||
    E'  Step 1: 2\u00b3 = 8 -> Rewrite: 8 + 4 \u00d7 2\n' ||
    E'  Step 2: multiplication next: 4 \u00d7 2 = 8 -> Rewrite: 8 + 8\n' ||
    E'  Step 3: addition: 8 + 8 = 16\n' ||
    E'  Answer: 2\u00b3 + 4 \u00d7 2 = 16\n\n' ||
    E'Moderate:\n' ||
    E'  (7 \u2212 3)\u00b2 \u00f7 4\n' ||
    E'  First operation: inside the grouping symbols -- grouping symbols always come first.\n' ||
    E'  Step 1: 7 \u2212 3 = 4 -> Rewrite: 4\u00b2 \u00f7 4\n' ||
    E'  Step 2: exponent next: 4\u00b2 = 16 -> Rewrite: 16 \u00f7 4\n' ||
    E'  Step 3: division: 16 \u00f7 4 = 4\n' ||
    E'  Answer: (7 \u2212 3)\u00b2 \u00f7 4 = 4\n\n' ||
    E'Challenging:\n' ||
    E'  5 \u00d7 2\u00b3 \u2212 18 \u00f7 3 + 6\n' ||
    E'  First operation: the exponent 2\u00b3 -- no grouping symbols, and exponents come before multiplication, division, addition, and subtraction.\n' ||
    E'  Step 1: 2\u00b3 = 8 -> Rewrite: 5 \u00d7 8 \u2212 18 \u00f7 3 + 6\n' ||
    E'  Step 2: multiplication/division, left to right -- the leftmost is 5 \u00d7 8: 5 \u00d7 8 = 40 -> Rewrite: 40 \u2212 18 \u00f7 3 + 6\n' ||
    E'  Step 3: next multiplication/division: 18 \u00f7 3 = 6 -> Rewrite: 40 \u2212 6 + 6\n' ||
    E'  Step 4: addition/subtraction, left to right -- 40 \u2212 6 = 34 -> Rewrite: 34 + 6\n' ||
    E'  Step 5: 34 + 6 = 40\n' ||
    E'  Answer: 5 \u00d7 2\u00b3 \u2212 18 \u00f7 3 + 6 = 40\n\n' ||
    E'Multi-Step Application:\n' ||
    E'  3\u00b2 \u00d7 (4 + 2) \u2212 10 \u00f7 2\n' ||
    E'  First operation: inside the grouping symbols (4 + 2) -- grouping symbols always come first, even before the exponent.\n' ||
    E'  Step 1: 4 + 2 = 6 -> Rewrite: 3\u00b2 \u00d7 6 \u2212 10 \u00f7 2\n' ||
    E'  Step 2: exponent: 3\u00b2 = 9 -> Rewrite: 9 \u00d7 6 \u2212 10 \u00f7 2\n' ||
    E'  Step 3: multiplication/division, left to right -- 9 \u00d7 6 = 54 -> Rewrite: 54 \u2212 10 \u00f7 2\n' ||
    E'  Step 4: 10 \u00f7 2 = 5 -> Rewrite: 54 \u2212 5\n' ||
    E'  Step 5: subtract: 54 \u2212 5 = 49\n' ||
    E'  Answer: 3\u00b2 \u00d7 (4 + 2) \u2212 10 \u00f7 2 = 49'
  ),

  (
    v_lesson_id, 11, 'summary', 'Remember',
    E'Remember:\n' ||
    E'  - The base is the number being multiplied.\n' ||
    E'  - The exponent tells how many times the base is used as a factor.\n' ||
    E'  - Exponents represent repeated multiplication (5\u00b2 means 5 \u00d7 5, not 5 \u00d7 2).\n' ||
    E'  - GEMDAS determines the order of operations: Grouping symbols, Exponents, Multiplication/Division, Addition/Subtraction.\n' ||
    E'  - Grouping symbols are always handled first.\n' ||
    E'  - Exponents are evaluated before multiplication and division.\n' ||
    E'  - Multiplication and division have equal priority and are evaluated from left to right.\n' ||
    E'  - Addition and subtraction have equal priority and are evaluated from left to right.\n' ||
    E'  - Showing each step helps prevent mistakes.'
  );

end $$;
