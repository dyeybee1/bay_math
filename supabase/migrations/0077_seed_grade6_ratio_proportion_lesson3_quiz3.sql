-- =============================================================================
-- Migration: 0077_seed_grade6_ratio_proportion_lesson3_quiz3.sql
-- Content-seeding migration only — no schema changes. `grade_level =
-- 'grade_6'` already exists on the GradeLevel enum (see
-- lib/core/models/section.dart), and `lesson_pages` / `lesson_pages.
-- worked_example` (0028/0030) and `lessons.linked_quiz_id` (0032) are
-- already in place, so this migration seeds directly into `lesson_pages`
-- rather than the old "single lessons.body blob, split later" two-step
-- (0027 -> 0029) that predates 0028.
--
-- Adds:
--   Grade 6 Lesson 3 — Understanding Ratio and Proportion (14 lesson_pages)
--   Grade 6 Quiz 3   — Understanding Ratio and Proportion (10 questions)
-- Links the new lesson to the new quiz via `lessons.linked_quiz_id`
-- (convenience shortcut only, per 0032 — never a hard dependency).
--
-- SEQUENCE NOTE: this is Grade 6 Lesson 3 / Quiz 3 in the intended
-- Grade 6 sequence (Lesson 1: Operations with Fractions, Whole Numbers,
-- and Mixed Numbers — not created by this migration; Lesson 2:
-- Operations with Decimals, seeded in 0076; Lesson 3: this migration).
-- Deliberately does NOT create or modify Lesson 1, Quiz 1, Lesson 2
-- (0076), or Quiz 2 (0076) records — `linked_quiz_id` links Lesson 3
-- directly to Quiz 3 by id, so no lookup against any other lesson's
-- title is needed.
--
-- Deliberately does NOT use the `worked_example` jsonb POC shape (0030):
-- that shape is fixed to exactly 6 place-value columns for addition/
-- subtraction (Hundred Thousands..Ones) and is explicitly scoped as a
-- non-generalizing POC (0030's column comment). Ratio/proportion worked
-- examples don't fit that shape, so every worked example here is plain
-- `body` text, matching the standard (non-interactive) lesson_pages
-- format already used everywhere outside the two POC pages from 0031.
--
-- DUPLICATE GUARD: the whole seed is wrapped in
-- `if not exists (select 1 from public.lessons where title = ... )`, so
-- re-running this migration is a no-op instead of creating duplicate
-- Lesson 3 / Quiz 3 rows.
--
-- MATH VERIFICATION: every worked example and quiz question below was
-- independently computed and cross-checked (via cross multiplication,
-- a x d = b x c, for every equivalence/proportion claim) before being
-- written into this migration. See the inline comments on each item.
-- All ids are database-generated (gen_random_uuid()) and captured via
-- `returning ... into`, never hardcoded, matching 0027/0029/0031/0033.
-- =============================================================================

do $$
declare
  v_lesson_id uuid;
  v_quiz_id   uuid;

  -- Quiz 3 question ids
  v_q1  uuid; v_q2  uuid; v_q3  uuid; v_q4  uuid; v_q5  uuid;
  v_q6  uuid; v_q7  uuid; v_q8  uuid; v_q9  uuid; v_q10 uuid;
begin

  if exists (
    select 1 from public.lessons
    where title = 'Understanding Ratio and Proportion'
      and source_type = 'built_in'
      and grade_level = 'grade_6'
  ) then
    raise notice '0077: Grade 6 Lesson 3 (Understanding Ratio and Proportion) already exists — skipping seed entirely.';
    return;
  end if;

  -- ===========================================================================
  -- Grade 6 Lesson 3 — Understanding Ratio and Proportion
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Understanding Ratio and Proportion',
    'Learn how to write and compare ratios, find equivalent ratios, understand rates, and solve simple proportion problems, with worked examples and real-world applications.',
    'built_in',
    null,
    'grade_6'
  )
  returning id into v_lesson_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn about ratios and proportions — how to compare two quantities, write equivalent ratios, understand rates, and solve simple proportion problems.'
  ),
  (
    v_lesson_id, 2, 'vocabulary', 'What Is a Ratio?',
    E'A ratio is a comparison of two quantities.\n\n' ||
    E'For example, imagine a bag with 2 red balls and 3 blue balls. We can compare the number of red balls to the number of blue balls using a ratio.\n\n' ||
    E'A ratio can be written in three ways:\n' ||
    E'  Using the word "to": 2 to 3\n' ||
    E'  Using a colon: 2:3\n' ||
    E'  Using a fraction: 2/3\n\n' ||
    E'All three forms mean the same thing: for every 2 red balls, there are 3 blue balls.\n\n' ||
    E'More examples:\n' ||
    E'  4 boys to 5 girls -> 4:5\n' ||
    E'  6 apples to 2 oranges -> 6:2'
  ),
  (
    v_lesson_id, 3, 'explanation', 'Writing Ratios in the Correct Order',
    E'When writing a ratio, the order of the numbers matters — it must match the order the quantities are mentioned in.\n\n' ||
    E'Worked Example:\n' ||
    E'  A basket has 7 apples and 5 bananas.\n' ||
    E'  Ratio of bananas to apples = 5:7 (bananas is mentioned first, so its number comes first).\n' ||
    E'  Ratio of apples to bananas = 7:5 (apples is mentioned first here instead).\n\n' ||
    E'Notice that 5:7 and 7:5 are NOT the same comparison — reversing the order changes the meaning of the ratio.\n\n' ||
    E'Remember: always identify which quantity is mentioned first, and write that number first.'
  ),
  (
    v_lesson_id, 4, 'explanation', 'Equivalent Ratios',
    E'Two ratios are equivalent when they express the same comparison, even though the numbers look different.\n\n' ||
    E'You can create an equivalent ratio by multiplying or dividing both terms of a ratio by the same nonzero number.\n\n' ||
    E'Worked Example:\n' ||
    E'  Start with the ratio 2:3.\n' ||
    E'  Multiply both terms by 2: (2x2):(3x2) = 4:6.\n' ||
    E'  Multiply both terms by 3: (2x3):(3x3) = 6:9.\n' ||
    E'  So 2:3, 4:6, and 6:9 are all equivalent ratios.\n\n' ||
    E'Finding a Missing Term:\n' ||
    E'  2:5 = 6:?\n' ||
    E'  Ask: what number was 2 multiplied by to get 6? 2 x 3 = 6.\n' ||
    E'  Multiply the other term by the same number: 5 x 3 = 15.\n' ||
    E'  So 2:5 = 6:15.\n' ||
    E'  Check: 2 x 15 = 30 and 5 x 6 = 30 — equal, so the ratios are equivalent.'
  ),
  (
    v_lesson_id, 5, 'examples', 'More Missing-Term Practice',
    E'Worked Example 1:\n' ||
    E'  3:4 = 9:?\n' ||
    E'  3 was multiplied by 3 to get 9 (3 x 3 = 9).\n' ||
    E'  Multiply 4 by 3 as well: 4 x 3 = 12.\n' ||
    E'  So 3:4 = 9:12.\n' ||
    E'  Check: 3 x 12 = 36 and 4 x 9 = 36 — equal.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  5:6 = ?:24\n' ||
    E'  6 was multiplied by 4 to get 24 (6 x 4 = 24).\n' ||
    E'  Multiply 5 by 4 as well: 5 x 4 = 20.\n' ||
    E'  So 5:6 = 20:24.\n' ||
    E'  Check: 5 x 24 = 120 and 6 x 20 = 120 — equal.'
  ),
  (
    v_lesson_id, 6, 'explanation', 'Simplifying Ratios',
    E'A ratio is in simplest form when both terms share no common factor except 1.\n\n' ||
    E'To simplify a ratio, divide both terms by their greatest common factor (GCF).\n\n' ||
    E'Worked Example:\n' ||
    E'  Simplify 8:12.\n' ||
    E'  The greatest common factor of 8 and 12 is 4.\n' ||
    E'  8 / 4 = 2 and 12 / 4 = 3.\n' ||
    E'  So 8:12 simplifies to 2:3.'
  ),
  (
    v_lesson_id, 7, 'examples', 'Simplifying Ratios Practice',
    E'Worked Example 1:\n' ||
    E'  Simplify 18:24.\n' ||
    E'  GCF of 18 and 24 is 6.\n' ||
    E'  18 / 6 = 3 and 24 / 6 = 4.\n' ||
    E'  18:24 simplifies to 3:4.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  Simplify 45:60.\n' ||
    E'  GCF of 45 and 60 is 15.\n' ||
    E'  45 / 15 = 3 and 60 / 15 = 4.\n' ||
    E'  45:60 simplifies to 3:4.\n\n' ||
    E'Worked Example 3 (word problem):\n' ||
    E'  A classroom has 12 boys and 18 girls. Write the ratio of boys to girls in simplest form.\n' ||
    E'  Ratio of boys to girls = 12:18.\n' ||
    E'  GCF of 12 and 18 is 6.\n' ||
    E'  12 / 6 = 2 and 18 / 6 = 3.\n' ||
    E'  The simplified ratio is 2:3.'
  ),
  (
    v_lesson_id, 8, 'explanation', 'Comparing Ratios',
    E'To check whether two ratios are equivalent, you can use cross multiplication: for a:b and c:d, the ratios are equivalent when a x d = b x c.\n\n' ||
    E'Worked Example 1:\n' ||
    E'  Are 2:3 and 4:6 equivalent?\n' ||
    E'  Cross multiply: 2 x 6 = 12 and 3 x 4 = 12.\n' ||
    E'  Since both products are equal, 2:3 and 4:6 are equivalent.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  Are 3:5 and 4:7 equivalent? Which is greater?\n' ||
    E'  Cross multiply: 3 x 7 = 21 and 5 x 4 = 20.\n' ||
    E'  Since 21 is not equal to 20, the ratios are NOT equivalent.\n' ||
    E'  As decimals, 3/5 = 0.6 and 4/7 is about 0.57, so 3:5 represents the greater comparison.'
  ),
  (
    v_lesson_id, 9, 'explanation', 'Understanding Rates',
    E'A rate is a special kind of comparison between two quantities that have different units.\n\n' ||
    E'Familiar examples of rates:\n' ||
    E'  kilometers per hour (speed)\n' ||
    E'  pesos per item (price)\n' ||
    E'  pages per minute (reading speed)\n\n' ||
    E'A unit rate tells you the amount for just ONE of something. To find a unit rate, divide.\n\n' ||
    E'Worked Example 1:\n' ||
    E'  3 notebooks cost ₱60. What is the cost per notebook?\n' ||
    E'  60 / 3 = 20.\n' ||
    E'  The unit rate is ₱20 per notebook.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  A car travels 240 kilometers in 4 hours. What is its speed?\n' ||
    E'  240 / 4 = 60.\n' ||
    E'  The car travels at a rate of 60 kilometers per hour.'
  ),
  (
    v_lesson_id, 10, 'explanation', 'Introduction to Proportion',
    E'A proportion is an equation that states two ratios are equivalent.\n\n' ||
    E'Worked Example:\n' ||
    E'  2/3 = 4/6 is a proportion, because 2:3 and 4:6 are equivalent ratios.\n' ||
    E'  We can check this using cross multiplication: 2 x 6 = 12 and 3 x 4 = 12. Since both products are equal, the proportion is true.\n\n' ||
    E'If the cross products are NOT equal, the equation is not a true proportion.'
  ),
  (
    v_lesson_id, 11, 'examples', 'Solving Simple Proportions',
    E'To solve a proportion with a missing value, you can use cross multiplication.\n\n' ||
    E'Worked Example 1:\n' ||
    E'  3/5 = x/10\n' ||
    E'  Notice that 5 x 2 = 10, so multiply the numerator by 2 as well: 3 x 2 = 6. So x = 6.\n' ||
    E'  Check with cross multiplication: 3 x 10 = 30 and 5 x 6 = 30 — equal.\n\n' ||
    E'Worked Example 2 (cross multiplication):\n' ||
    E'  4/7 = x/21\n' ||
    E'  Cross multiply: 4 x 21 = 7 x x, so 84 = 7x.\n' ||
    E'  Divide both sides by 7: x = 12.\n' ||
    E'  Check: 4 x 21 = 84 and 7 x 12 = 84 — equal.\n\n' ||
    E'Worked Example 3:\n' ||
    E'  x/8 = 15/24\n' ||
    E'  Cross multiply: 24 x x = 8 x 15, so 24x = 120.\n' ||
    E'  Divide both sides by 24: x = 5.\n' ||
    E'  Check: 5 x 24 = 120 and 8 x 15 = 120 — equal.'
  ),
  (
    v_lesson_id, 12, 'examples', 'Ratio and Proportion Word Problems',
    E'Worked Example 1 (recipe):\n' ||
    E'  A recipe uses 2 cups of flour for every 3 cups of sugar. If you use 9 cups of sugar, how much flour is needed?\n' ||
    E'  Set up a proportion: 2/3 = x/9.\n' ||
    E'  Cross multiply: 3x = 2 x 9 = 18, so x = 6.\n' ||
    E'  You need 6 cups of flour.\n\n' ||
    E'Worked Example 2 (map distance):\n' ||
    E'  On a map, 1 cm represents 5 km. Two cities are 8 cm apart on the map. What is the actual distance?\n' ||
    E'  Set up a proportion: 1/5 = 8/x.\n' ||
    E'  Cross multiply: 1 x x = 5 x 8 = 40, so x = 40.\n' ||
    E'  The actual distance is 40 km.\n\n' ||
    E'Worked Example 3 (shopping):\n' ||
    E'  4 notebooks cost ₱100. At the same rate, how much would 10 notebooks cost?\n' ||
    E'  Set up a proportion: 4/100 = 10/x.\n' ||
    E'  Cross multiply: 4x = 100 x 10 = 1000, so x = 250.\n' ||
    E'  10 notebooks would cost ₱250.'
  ),
  (
    v_lesson_id, 13, 'examples', 'Real-World Applications',
    E'Worked Example 1 (sports statistics):\n' ||
    E'  A basketball player made 15 out of 20 free throws. Write this as a ratio in simplest form.\n' ||
    E'  Ratio made to attempted = 15:20.\n' ||
    E'  GCF of 15 and 20 is 5. 15 / 5 = 3 and 20 / 5 = 4.\n' ||
    E'  The simplified ratio is 3:4.\n\n' ||
    E'Worked Example 2 (mixtures):\n' ||
    E'  A paint mixture uses blue and white paint in the ratio 2:5. If you use 8 liters of blue paint, how many liters of white paint are needed to keep the same ratio?\n' ||
    E'  Set up a proportion: 2/5 = 8/x.\n' ||
    E'  Cross multiply: 2x = 5 x 8 = 40, so x = 20.\n' ||
    E'  You need 20 liters of white paint.\n\n' ||
    E'Worked Example 3 (scale drawing):\n' ||
    E'  A scale drawing uses the ratio 1:50 (1 cm represents 50 cm of actual length). A wall is drawn as 6 cm long. What is the actual length of the wall?\n' ||
    E'  Set up a proportion: 1/50 = 6/x.\n' ||
    E'  Cross multiply: 1 x x = 50 x 6 = 300, so x = 300 cm, which is 3 meters.'
  ),
  (
    v_lesson_id, 14, 'summary', 'Remember',
    E'  - A ratio compares two quantities.\n' ||
    E'  - The order of the terms in a ratio matters.\n' ||
    E'  - Equivalent ratios have the same relationship between quantities.\n' ||
    E'  - Multiply or divide both terms by the same nonzero number to create an equivalent ratio.\n' ||
    E'  - A rate compares quantities with different units.\n' ||
    E'  - A proportion states that two ratios are equivalent.\n' ||
    E'  - Proportions can be used to find unknown quantities.\n' ||
    E'  - Ratios and proportions are useful in real-world situations.'
  );

  -- ===========================================================================
  -- Grade 6 Quiz 3 — built-in Internal Quiz for Lesson 3
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 3: Understanding Ratio and Proportion',
    'internal', 'built_in', null, 'grade_6', true, true
  )
  returning id into v_quiz_id;

  -- --- Q1 (basic ratio identification, simplest form) ---------------------
  -- 14:21, GCF=7 -> 2:3. Verified: 14/7=2, 21/7=3.
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding Ratio and Proportion',
    'A classroom has 14 boys and 21 girls. What is the ratio of boys to girls in simplest form?',
    'The ratio of boys to girls is 14:21. The greatest common factor of 14 and 21 is 7. Dividing both terms by 7 gives 2:3.'
  )
  returning id into v_q1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1, '2:3', true, 1),
    (v_q1, '3:2', false, 2),
    (v_q1, '14:21', false, 3),
    (v_q1, '2:21', false, 4);

  -- --- Q2 (writing a ratio, correct order) ---------------------------------
  -- bananas:apples = 5:7. Verified no simplification needed (GCF=1).
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding Ratio and Proportion',
    'A fruit basket has 7 apples and 5 bananas. What is the ratio of bananas to apples?',
    'Bananas is mentioned first, so its number comes first: 5 (bananas) to 7 (apples) = 5:7.'
  )
  returning id into v_q2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2, '5:7', true, 1),
    (v_q2, '7:5', false, 2),
    (v_q2, '7:12', false, 3),
    (v_q2, '5:12', false, 4);

  -- --- Q3 (equivalent ratio) -----------------------------------------------
  -- 4:5 equivalent to 8:10 (x2). Cross-checked distractors are NOT equivalent:
  -- 5:4 (2*9=... reversed), 4:10 (4*10=40 vs 5*4=20, not equal),
  -- 8:9 (4*9=36 vs 5*8=40, not equal).
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding Ratio and Proportion',
    'Which ratio is equivalent to 4:5?',
    'Multiplying both terms of 4:5 by 2 gives 8:10, so 4:5 = 8:10. Checking with cross multiplication: 4 x 10 = 40 and 5 x 8 = 40 — equal, confirming they are equivalent.'
  )
  returning id into v_q3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q3, '8:10', true, 1),
    (v_q3, '5:4', false, 2),
    (v_q3, '4:10', false, 3),
    (v_q3, '8:9', false, 4);

  -- --- Q4 (simplifying a ratio) ---------------------------------------------
  -- 24:36, GCF=12 -> 2:3. Distractors verified NOT equivalent to 2:3:
  -- 3:2 (reversed), 2:4 (=1:2, inconsistent factors 24/12 and 36/9),
  -- 4:9 (cross 4*3=12 vs 9*2=18, not equal).
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding Ratio and Proportion',
    'Simplify the ratio 24:36 to simplest form.',
    'The greatest common factor of 24 and 36 is 12. Dividing both terms by 12 gives 24/12 = 2 and 36/12 = 3, so the simplest form is 2:3.'
  )
  returning id into v_q4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q4, '2:3', true, 1),
    (v_q4, '3:2', false, 2),
    (v_q4, '2:4', false, 3),
    (v_q4, '4:9', false, 4);

  -- --- Q5 (unit rate) --------------------------------------------------------
  -- 90/6 = 15. Distractors: 96 (added), 84 (subtracted), 540 (multiplied).
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding Ratio and Proportion',
    '6 pencils cost ₱90. What is the cost per pencil?',
    'To find the unit rate, divide the total cost by the number of pencils: 90 / 6 = 15. The cost per pencil is ₱15.'
  )
  returning id into v_q5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5, '₱15', true, 1),
    (v_q5, '₱96', false, 2),
    (v_q5, '₱84', false, 3),
    (v_q5, '₱540', false, 4);

  -- --- Q6 (identifying a true proportion) -------------------------------------
  -- 3/4 = 9/12: cross 3*12=36, 4*9=36 -- true.
  -- 2/5 = 4/8: cross 2*8=16, 5*4=20 -- false.
  -- 5/6 = 6/5: cross 5*5=25, 6*6=36 -- false.
  -- 7/9 = 14/16: cross 7*16=112, 9*14=126 -- false.
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding Ratio and Proportion',
    'Which equation represents a true proportion?',
    '3/4 = 9/12 is true because the cross products are equal: 3 x 12 = 36 and 4 x 9 = 36. In the other choices the cross products are not equal, so they are not true proportions.'
  )
  returning id into v_q6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6, '3/4 = 9/12', true, 1),
    (v_q6, '2/5 = 4/8', false, 2),
    (v_q6, '5/6 = 6/5', false, 3),
    (v_q6, '7/9 = 14/16', false, 4);

  -- --- Q7 (solving for a missing value) ---------------------------------------
  -- 5/9 = n/27. 27/9=3, n=5*3=15. Check 5*27=135, 9*15=135.
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding Ratio and Proportion',
    'Solve for n: 5/9 = n/27',
    'Since 9 x 3 = 27, multiply the numerator by 3 as well: 5 x 3 = 15, so n = 15. Checking with cross multiplication: 5 x 27 = 135 and 9 x 15 = 135 — equal.'
  )
  returning id into v_q7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q7, '15', true, 1),
    (v_q7, '5', false, 2),
    (v_q7, '45', false, 3),
    (v_q7, '13', false, 4);

  -- --- Q8 (real-world application, recipe) -------------------------------------
  -- 3/5 = x/20. Cross: 5x=60, x=12.
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding Ratio and Proportion',
    'A recipe calls for 3 cups of sugar for every 5 cups of flour. If you use 20 cups of flour, how many cups of sugar are needed?',
    'Set up a proportion: 3/5 = x/20. Cross multiply: 5x = 3 x 20 = 60, so x = 12. You need 12 cups of sugar.'
  )
  returning id into v_q8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q8, '12 cups', true, 1),
    (v_q8, '20 cups', false, 2),
    (v_q8, '60 cups', false, 3),
    (v_q8, '8 cups', false, 4);

  -- --- Q9 (comparing rates) -----------------------------------------------------
  -- Store A: 800/4=200. Store B: 1200/6=200. Same rate.
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding Ratio and Proportion',
    'A store sells 4 shirts for ₱800, and another store sells 6 shirts for ₱1,200. Do the two stores charge the same rate per shirt?',
    'Store A: 800 / 4 = ₱200 per shirt. Store B: 1,200 / 6 = ₱200 per shirt. Both unit rates are equal, so yes, both stores charge ₱200 per shirt.'
  )
  returning id into v_q9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9, 'Yes, both charge ₱200 per shirt', true, 1),
    (v_q9, 'No, Store A is cheaper', false, 2),
    (v_q9, 'No, Store B is cheaper', false, 3),
    (v_q9, 'Yes, both charge ₱150 per shirt', false, 4);

  -- --- Q10 (multi-step application, scale drawing) -------------------------------
  -- 2/5 = 10/x. Cross: 2x=50, x=25.
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding Ratio and Proportion',
    'On a scale drawing, 2 cm represents 5 meters of actual length. If a wall is drawn as 10 cm on the drawing, what is the actual length of the wall?',
    'Set up a proportion: 2/5 = 10/x. Cross multiply: 2x = 5 x 10 = 50, so x = 25. The actual length of the wall is 25 meters.'
  )
  returning id into v_q10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10, '25 meters', true, 1),
    (v_q10, '4 meters', false, 2),
    (v_q10, '50 meters', false, 3),
    (v_q10, '20 meters', false, 4);

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
  -- Link Lesson 3 -> Quiz 3 (0032 convenience shortcut, never a dependency)
  -- ===========================================================================
  update public.lessons
  set linked_quiz_id = v_quiz_id
  where id = v_lesson_id;

end $$;
