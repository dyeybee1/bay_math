-- =============================================================================
-- Migration: 0080_seed_grade6_lesson6_perimeter_area.sql
-- Content-seeding migration only — no schema changes. Follows the same
-- conventions as 0027/0029/0031/0033 (Grade 4 seed) and 0079 (Grade 6
-- Lesson 5 / Quiz 5 seed):
--
--   Lesson 6 — Perimeter and Area of Plane and Composite Figures  (grade_level = 'grade_6')
--   Quiz 6   — Internal Quiz for Lesson 6 (10 questions)
--
-- Written directly against `lesson_pages` (0028), matching current-
-- generation lesson shape — `lessons.body` is set to the short list-screen
-- description only.
--
-- DIAGRAMS: the project's models/schema were re-checked (Lesson, LessonPage,
-- WorkedExample, Quiz, QuestionBankItem, QuestionChoice) and there is no
-- image/diagram/svg field or table anywhere in this project — lesson pages
-- and question prompts are plain text only. No new diagram format is
-- invented here; composite figures are instead described precisely in
-- words (component shape dimensions, or the dimensions needed to derive
-- missing sides), the same way every other page/prompt in this project
-- conveys geometry.
--
-- `worked_example` (0030/0031) is left null on every page, same reasoning
-- as 0079: that jsonb shape is fixed POC scope for 6-digit place-value
-- addition/subtraction and does not apply to perimeter/area content.
--
-- All ids are database-generated (gen_random_uuid()) and captured via
-- `returning ... into`, never hardcoded. lesson/quiz/question_bank rows
-- use source_type = 'built_in', created_by = null, grade_level = 'grade_6'.
-- question_bank.topic is tagged to match the lesson title, matching 0027's
-- convention for the Highest/Lowest Performing Topics dashboard metric.
--
-- Each question's 4 choices are inserted in a single statement, so the
-- deferred `enforce_at_least_one_correct` constraint trigger (0014) never
-- observes a question with zero correct choices mid-transaction.
--
-- Lesson 6 is linked to Quiz 6 via `lessons.linked_quiz_id` (0032) at the
-- end of this migration, matching the pairing 0033/0079 already
-- established for earlier lessons.
--
-- MATHEMATICAL VALIDATION (independently re-checked before writing):
--   Perimeter examples: rect 2x(12+7)=38 | square 4x9=36 | triangle 5+6+7=18
--   Area examples:      rect 10x6=60     | square 8^2=64  | triangle 0.5x10x6=30
--   Composite area (divide+add, classroom floor): 8x5 + 4x3 = 40+12 = 52 m^2
--   Composite area (large-minus-missing, wall/doorway): 6x3 - 1x2 = 18-2 = 16 m^2
--   Composite perimeter (garden with corner notch, 12x8 minus 5x3 corner):
--     derived sides = (8-3)=5 and (12-5)=7; total = 12+5+5+3+7+8 = 40 m
--     (matches original rectangle's own perimeter 2x(12+8)=40, as expected
--     for a single corner notch — confirms no boundary length was lost)
--   Quiz Q5 (rect. perimeter): 2x(15+9)=48 | distractors: 15+9=24, 15x9=135, 2x15+9=39
--   Quiz Q6 (square area):     11^2=121   | distractors: 4x11=44, 11x2=22, slip=111
--   Quiz Q7 (triangle area):   0.5x14x10=70 | distractors: 14x10=140, 14+10=24, 0.5x0.5x14x10=35
--   Quiz Q8 (composite area):  7x4 + 3x2 = 34 | distractors: 7x4=28, 28x6=168, 7+4+3+2=16
--   Quiz Q9 (composite perim.): 10x6 patio minus 2x2 corner -> 10+(6-2)+2+2+(10-2)+6=32
--     (= 2x(10+6)=32, confirmed) | distractors: 32-4=28, 32+4=36, 10x6-2x2=56 (area, not perimeter)
--   Quiz Q10 (word problem, picture frame): 2x(24+18)=84 | distractors: 24x18=432, 24+18=42, 2x24+18=66
-- =============================================================================

do $$
declare
  v_lesson6_id uuid;
  v_quiz6_id   uuid;

  -- Quiz 6 — Perimeter and Area of Plane and Composite Figures
  v_q6_1  uuid; v_q6_2  uuid; v_q6_3  uuid; v_q6_4  uuid; v_q6_5  uuid;
  v_q6_6  uuid; v_q6_7  uuid; v_q6_8  uuid; v_q6_9  uuid; v_q6_10 uuid;
begin

  -- ===========================================================================
  -- Lesson 6 — Perimeter and Area of Plane and Composite Figures
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Perimeter and Area of Plane and Composite Figures',
    'Learn the difference between perimeter and area, find the perimeter and area of squares, rectangles, and triangles, and break composite figures into simpler shapes to solve real-world problems.',
    'built_in',
    null,
    'grade_6'
  )
  returning id into v_lesson6_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson6_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn about perimeter (the distance around a figure) and area (the space inside a figure). We will find the perimeter and area of common plane figures, and then learn how to work with composite figures — shapes made by combining two or more simpler figures.'
  ),
  (
    v_lesson6_id, 2, 'vocabulary', 'Understanding Perimeter and Area',
    E'PERIMETER is the total distance around the outside edge of a plane figure. Since perimeter is a distance, it is measured in LINEAR units, such as cm, m, in, or ft.\n\n' ||
    E'AREA is the amount of surface inside a plane figure. Since area covers a flat space, it is measured in SQUARE units, such as cm², m², in², or ft².\n\n' ||
    E'  PERIMETER -> distance AROUND a figure -> linear units (cm, m)\n' ||
    E'  AREA      -> space INSIDE a figure    -> square units (cm², m²)\n\n' ||
    E'A plane figure is any flat, two-dimensional shape, such as a square, rectangle, or triangle. To find the perimeter or area of a plane figure, you first need to identify its dimensions — the side lengths, or the base and height.'
  ),
  (
    v_lesson6_id, 3, 'explanation', 'Perimeter of Common Figures',
    E'Rectangle:  P = 2(l + w)   — double the sum of the length and width, since a rectangle has 2 lengths and 2 widths.\n' ||
    E'Square:     P = 4s         — a square has 4 equal sides, so multiply the side length by 4.\n' ||
    E'Triangle (and other irregular figures): add all of the side lengths together.\n\n' ||
    E'To find a perimeter:\n' ||
    E'  1. Identify the figure and its given side lengths.\n' ||
    E'  2. Choose the correct formula (or add all sides for a triangle/irregular figure).\n' ||
    E'  3. Substitute the values.\n' ||
    E'  4. Calculate.\n' ||
    E'  5. Write the answer using a LINEAR unit — never a square unit.'
  ),
  (
    v_lesson6_id, 4, 'examples', 'Perimeter Examples',
    E'Worked Example 1 (Rectangle):\n' ||
    E'  A rectangular garden bed is 12 cm long and 7 cm wide. Find its perimeter.\n' ||
    E'  P = 2(l + w)\n' ||
    E'  P = 2(12 + 7)\n' ||
    E'  P = 2(19)\n' ||
    E'  P = 38 cm\n\n' ||
    E'Worked Example 2 (Square):\n' ||
    E'  A square tile has a side length of 9 cm. Find its perimeter.\n' ||
    E'  P = 4s\n' ||
    E'  P = 4(9)\n' ||
    E'  P = 36 cm\n\n' ||
    E'Worked Example 3 (Triangle):\n' ||
    E'  A triangular flag has sides of 5 cm, 6 cm, and 7 cm. Find its perimeter.\n' ||
    E'  P = 5 + 6 + 7\n' ||
    E'  P = 18 cm'
  ),
  (
    v_lesson6_id, 5, 'explanation', 'Area of Common Figures',
    E'Rectangle:  A = l x w\n' ||
    E'Square:     A = s²  (since l = w = s)\n' ||
    E'Triangle:   A = 1/2 x b x h   (b = base, h = height)\n\n' ||
    E'A triangle''s area is HALF of a rectangle with the same base and height, which is why the formula includes 1/2. Forgetting the 1/2 is one of the most common triangle-area mistakes, so always double-check it.\n\n' ||
    E'To find an area:\n' ||
    E'  1. Identify the figure and its given dimensions.\n' ||
    E'  2. Choose the correct formula.\n' ||
    E'  3. Substitute the values.\n' ||
    E'  4. Calculate.\n' ||
    E'  5. Write the answer using a SQUARE unit — never a linear unit.'
  ),
  (
    v_lesson6_id, 6, 'examples', 'Area Examples',
    E'Worked Example 4 (Rectangle):\n' ||
    E'  A rectangular table top is 10 cm long and 6 cm wide. Find its area.\n' ||
    E'  A = l x w\n' ||
    E'  A = 10 x 6\n' ||
    E'  A = 60 cm²\n\n' ||
    E'Worked Example 5 (Square):\n' ||
    E'  A square rug has a side length of 8 cm. Find its area.\n' ||
    E'  A = s²\n' ||
    E'  A = 8²\n' ||
    E'  A = 64 cm²\n\n' ||
    E'Worked Example 6 (Triangle):\n' ||
    E'  A triangular banner has a base of 10 cm and a height of 6 cm. Find its area.\n' ||
    E'  A = 1/2 x b x h\n' ||
    E'  A = 1/2 x 10 x 6\n' ||
    E'  A = 1/2 x 60\n' ||
    E'  A = 30 cm²'
  ),
  (
    v_lesson6_id, 7, 'explanation', 'Perimeter vs. Area',
    E'Before solving a problem, always ask: is this asking for the distance AROUND the figure (perimeter), or the space INSIDE the figure (area)?\n\n' ||
    E'Clue words for PERIMETER: fencing, framing, trim, border, "distance around," "how far around."\n' ||
    E'Clue words for AREA: covering, painting, carpeting, tiling, "how much surface," "how much space."\n\n' ||
    E'Also check the unit in your final answer: a LINEAR unit (cm, m) means perimeter; a SQUARE unit (cm², m²) means area. If your answer''s unit does not match what the question is asking for, you likely used the wrong formula.'
  ),
  (
    v_lesson6_id, 8, 'explanation', 'Composite Figures',
    E'A composite figure is made up of two or more simpler plane figures joined together — for example, an L-shaped room made of two rectangles, or a rectangle with a triangular roof on top.\n\n' ||
    E'To work with composite figures:\n' ||
    E'  1. Identify the simpler shapes inside the composite figure.\n' ||
    E'  2. Find any missing dimensions using the ones you are given.\n' ||
    E'  3. For AREA: find the area of each simpler shape, then add them together — or, if a piece has been removed, find the area of the large shape and subtract the missing piece.\n' ||
    E'  4. For PERIMETER: trace only the OUTER boundary of the whole figure. Never count an internal dividing line — a line used only to split the figure into simpler shapes is not part of the perimeter.'
  ),
  (
    v_lesson6_id, 9, 'examples', 'Composite Area — Divide and Add',
    E'Worked Example 7:\n' ||
    E'  A classroom floor is L-shaped and can be divided into two rectangles: Rectangle A is 8 m by 5 m, and Rectangle B is 4 m by 3 m. Find the total floor area.\n' ||
    E'  Area of Rectangle A = 8 x 5 = 40 m²\n' ||
    E'  Area of Rectangle B = 4 x 3 = 12 m²\n' ||
    E'  Total area = 40 + 12 = 52 m²\n\n' ||
    E'Strategy: when a composite figure is split into non-overlapping shapes, find each shape''s area separately, then ADD them.'
  ),
  (
    v_lesson6_id, 10, 'examples', 'Composite Area — Large Minus Missing Part',
    E'Worked Example 8:\n' ||
    E'  A rectangular wall is 6 m wide and 3 m tall. A rectangular doorway 1 m wide and 2 m tall is cut into the wall. Find the area of the wall that needs to be painted (not including the doorway).\n' ||
    E'  Area of the wall = 6 x 3 = 18 m²\n' ||
    E'  Area of the doorway = 1 x 2 = 2 m²\n' ||
    E'  Area to paint = 18 - 2 = 16 m²\n\n' ||
    E'Strategy: when a piece is missing or removed from a larger figure, find the AREA OF THE WHOLE, find the area of the missing piece, then SUBTRACT.'
  ),
  (
    v_lesson6_id, 11, 'examples', 'Composite Perimeter — Outer Boundary Only',
    E'Worked Example 9:\n' ||
    E'  A rectangular school garden measures 12 m by 8 m. A 5 m by 3 m square corner is fenced off as a storage area and is NOT part of the garden, forming an L-shape. How many meters of fencing are needed to go around the remaining L-shaped garden?\n\n' ||
    E'  Step 1 — Two of the six outer sides are not given directly, so find them first:\n' ||
    E'    Remaining part of the 8 m side = 8 - 3 = 5 m (the storage corner takes up 3 m of it)\n' ||
    E'    Remaining part of the 12 m side = 12 - 5 = 7 m (the storage corner takes up 5 m of it)\n\n' ||
    E'  Step 2 — Add up all SIX outer sides going around the shape (the two inner edges of the cut-off corner ARE part of the outer boundary here, since the garden goes around them; only a line used purely to split the shape on paper would be excluded):\n' ||
    E'    12 + 5 + 5 + 3 + 7 + 8 = 40 m\n\n' ||
    E'  Fencing needed = 40 m\n\n' ||
    E'  Notice this equals the perimeter of the original 12 m by 8 m rectangle, 2(12 + 8) = 40 m — cutting a single corner out of a rectangle reroutes the boundary but does not change its total length.'
  ),
  (
    v_lesson6_id, 12, 'explanation', 'Problem-Solving Strategy', 
    E'Follow these steps for ANY perimeter or area problem:\n' ||
    E'  1. Identify what is being asked — perimeter or area.\n' ||
    E'  2. Identify the figure and its given dimensions.\n' ||
    E'  3. If it is a composite figure, break it into simpler shapes and find any missing dimensions.\n' ||
    E'  4. Choose the correct formula (or add/subtract, for composite figures).\n' ||
    E'  5. Substitute the values and calculate step by step.\n' ||
    E'  6. Write the correct unit — linear for perimeter, square for area.\n' ||
    E'  7. Check if the answer is reasonable for the size of the figure described.'
  ),
  (
    v_lesson6_id, 13, 'summary', 'Remember',
    E'  - Perimeter is the distance around a figure; area is the amount of surface inside it.\n' ||
    E'  - Perimeter uses linear units (cm, m); area uses square units (cm², m²).\n' ||
    E'  - Rectangle: P = 2(l + w), A = l x w. Square: P = 4s, A = s². Triangle: P = sum of sides, A = 1/2 x b x h.\n' ||
    E'  - A composite figure is made of two or more simpler shapes.\n' ||
    E'  - Composite area: add the areas of the parts, or subtract a missing part from a larger shape.\n' ||
    E'  - Composite perimeter: trace only the outer boundary — never count an internal line used just to split the figure.\n' ||
    E'  - Always check that your final answer has the correct unit and is a reasonable size.'
  );

  -- ===========================================================================
  -- Quiz 6 — built-in Internal Quiz for Lesson 6
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 6: Perimeter and Area of Plane and Composite Figures',
    'internal', 'built_in', null, 'grade_6', true, true
  )
  returning id into v_quiz6_id;

  -- --- Q1 (concept — perimeter) ------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Perimeter and Area of Plane and Composite Figures',
    'What does perimeter measure?',
    'Perimeter is the total distance around the outside edge of a figure. It is not the space inside a figure (that is area), a diagonal distance, or a count of sides.'
  )
  returning id into v_q6_1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6_1, 'The total distance around a figure', true,  1),
    (v_q6_1, 'The amount of space inside a figure', false, 2),
    (v_q6_1, 'The distance from one corner to the opposite corner', false, 3),
    (v_q6_1, 'The number of sides a figure has', false, 4);

  -- --- Q2 (concept/units — area) -------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Perimeter and Area of Plane and Composite Figures',
    'Which measurement is expressed in square units, such as cm²?',
    'Area is measured in square units because it covers a flat, two-dimensional surface. Perimeter, length, and width are all linear measurements and use non-squared units like cm.'
  )
  returning id into v_q6_2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6_2, 'Area', true,  1),
    (v_q6_2, 'Perimeter', false, 2),
    (v_q6_2, 'Length', false, 3),
    (v_q6_2, 'Width', false, 4);

  -- --- Q3 (identify formula — rectangle perimeter) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Perimeter and Area of Plane and Composite Figures',
    'Which formula correctly finds the perimeter of a rectangle?',
    'A rectangle has two lengths and two widths, so its perimeter is P = 2(l + w). Multiplying l and w gives area, not perimeter, and forgetting to double the sum (or doubling only one side) leaves out part of the boundary.'
  )
  returning id into v_q6_3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6_3, 'P = 2(l + w)', true,  1),
    (v_q6_3, 'P = l x w', false, 2),
    (v_q6_3, 'P = l + w', false, 3),
    (v_q6_3, 'P = 2l', false, 4);

  -- --- Q4 (identify formula — triangle area) ---------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Perimeter and Area of Plane and Composite Figures',
    'Which formula correctly finds the area of a triangle?',
    'A triangle''s area is half of a rectangle with the same base and height, so A = 1/2 x b x h. Leaving out the 1/2 or multiplying by 2 instead gives an incorrect area, and adding b and h does not give an area at all.'
  )
  returning id into v_q6_4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6_4, 'A = 1/2 x b x h', true,  1),
    (v_q6_4, 'A = b x h', false, 2),
    (v_q6_4, 'A = b + h', false, 3),
    (v_q6_4, 'A = 2 x b x h', false, 4);

  -- --- Q5 (computation — rectangle perimeter) ---------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Perimeter and Area of Plane and Composite Figures',
    'A rectangular banner is 15 cm long and 9 cm wide. What is its perimeter?',
    'P = 2(l + w) = 2(15 + 9) = 2(24) = 48 cm. The lengths and widths must both be counted twice and added, not multiplied together.'
  )
  returning id into v_q6_5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6_5, '48 cm', true,  1),
    (v_q6_5, '24 cm', false, 2),
    (v_q6_5, '135 cm', false, 3),
    (v_q6_5, '39 cm', false, 4);

  -- --- Q6 (computation — square area) -------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Perimeter and Area of Plane and Composite Figures',
    'A square rug has a side length of 11 cm. What is its area?',
    'A = s² = 11 x 11 = 121 cm². Using the perimeter formula (4s) or doubling the side length instead of squaring it does not give the area.'
  )
  returning id into v_q6_6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6_6, '121 cm²', true,  1),
    (v_q6_6, '44 cm²', false, 2),
    (v_q6_6, '22 cm²', false, 3),
    (v_q6_6, '111 cm²', false, 4);

  -- --- Q7 (computation — triangle area) ----------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Perimeter and Area of Plane and Composite Figures',
    'A triangular banner has a base of 14 cm and a height of 10 cm. What is its area?',
    'A = 1/2 x b x h = 1/2 x 14 x 10 = 1/2 x 140 = 70 cm². Forgetting the 1/2, adding the base and height instead of multiplying, or dividing by 2 twice all give an incorrect area.'
  )
  returning id into v_q6_7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6_7, '70 cm²', true,  1),
    (v_q6_7, '140 cm²', false, 2),
    (v_q6_7, '24 cm²', false, 3),
    (v_q6_7, '35 cm²', false, 4);

  -- --- Q8 (composite area — divide and add) ------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Perimeter and Area of Plane and Composite Figures',
    'A room''s floor is L-shaped and can be divided into two rectangles: Rectangle A is 7 m by 4 m, and Rectangle B is 3 m by 2 m. What is the total area of the floor?',
    'Find each rectangle''s area and add them: (7 x 4) + (3 x 2) = 28 + 6 = 34 m². Every part of a composite figure must be included, and the parts are added, not multiplied together.'
  )
  returning id into v_q6_8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6_8, '34 m²', true,  1),
    (v_q6_8, '28 m²', false, 2),
    (v_q6_8, '168 m²', false, 3),
    (v_q6_8, '16 m²', false, 4);

  -- --- Q9 (composite perimeter — outer boundary only) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Perimeter and Area of Plane and Composite Figures',
    'A rectangular patio measures 10 m by 6 m. A 2 m by 2 m square section is cut from one corner and is not part of the patio, forming an L-shape. What is the perimeter of the remaining L-shaped patio?',
    'Tracing the six outer sides of the L-shape: 10 + (6 - 2) + 2 + 2 + (10 - 2) + 6 = 10 + 4 + 2 + 2 + 8 + 6 = 32 m — the same as the original rectangle''s perimeter, 2(10 + 6) = 32 m, since cutting one corner reroutes the boundary without shortening it.'
  )
  returning id into v_q6_9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6_9, '32 m', true,  1),
    (v_q6_9, '28 m', false, 2),
    (v_q6_9, '36 m', false, 3),
    (v_q6_9, '56 m', false, 4);

  -- --- Q10 (word problem — real-world perimeter) --------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Perimeter and Area of Plane and Composite Figures',
    'A rectangular picture is 24 cm wide and 18 cm tall. How much wood trim is needed to frame all the way around the picture?',
    'Framing "around" the picture asks for perimeter: P = 2(l + w) = 2(24 + 18) = 2(42) = 84 cm. Multiplying the dimensions gives the picture''s area, not the trim needed around its edge.'
  )
  returning id into v_q6_10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6_10, '84 cm', true,  1),
    (v_q6_10, '432 cm', false, 2),
    (v_q6_10, '42 cm', false, 3),
    (v_q6_10, '66 cm', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz6_id, v_q6_1,  1),
    (v_quiz6_id, v_q6_2,  2),
    (v_quiz6_id, v_q6_3,  3),
    (v_quiz6_id, v_q6_4,  4),
    (v_quiz6_id, v_q6_5,  5),
    (v_quiz6_id, v_q6_6,  6),
    (v_quiz6_id, v_q6_7,  7),
    (v_quiz6_id, v_q6_8,  8),
    (v_quiz6_id, v_q6_9,  9),
    (v_quiz6_id, v_q6_10, 10);

  -- ===========================================================================
  -- Link Lesson 6 -> Quiz 6 (0032), matching the pairing 0033/0079
  -- established for earlier lessons.
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz6_id where id = v_lesson6_id;

end $$;
