-- =============================================================================
-- Migration: 0074_seed_grade5_surface_area.sql
--
-- Seeds Grade 5 (MELC-level) built-in content:
--   Lesson 10 — Finding the Surface Area of Solid Figures
--   Quiz 10   — Internal Quiz for Lesson 10 (10 questions, cube + rectangular
--               prism surface area, mixed)
--
-- Follows the exact pattern already established by 0027 (seed) + 0029
-- (lesson_pages) + 0032/0033 (lesson -> quiz link), collapsed into a single
-- migration here since this is a one-lesson/one-quiz addition rather than a
-- multi-lesson batch. All ids are database-generated (gen_random_uuid(),
-- the default on every affected table's id column) and captured via
-- `returning ... into`, never hardcoded.
--
-- lessons/quizzes/question_bank rows use source_type = 'built_in',
-- created_by = null, grade_level = 'grade_5' (lessons/quizzes only —
-- question_bank has no grade_level column, per 0027's established
-- convention). question_bank.topic is tagged to match the owning lesson's
-- title, for the Highest/Lowest Performing Topics dashboard metric
-- (schema comment, 0008).
--
-- Lesson uses the `lesson_pages` structure directly (0028) rather than a
-- flat `lessons.body` + separate follow-up migration — 0027/0029 only did
-- the two-step split because lesson_pages didn't exist yet when 0027 was
-- written. `lessons.body` is populated with the same short 1-2 sentence
-- list-view description convention 0029 introduced.
--
-- The `worked_example` jsonb column (0030) is deliberately NOT used here:
-- per its own column comment, it is fixed to exactly 6 place-value columns
-- for addition/subtraction and is explicitly "POC scope, not built to
-- generalize to other digit counts" — surface-area worked examples use
-- plain-text `body`, the same as every lesson page outside that POC.
--
-- section_type values used below (introduction, vocabulary, explanation,
-- examples, summary) are exactly the existing free-text values already
-- used by 0029 — no new section_type introduced.
--
-- Each question's 4 choices are inserted in a single statement, so the
-- deferred `enforce_at_least_one_correct` constraint trigger (0014) never
-- observes a question with zero correct choices mid-transaction.
--
-- MATH INDEPENDENTLY VERIFIED before writing this file:
--   Cube SA = 6 * s^2:
--     s=4 -> face 16, SA 96      (Lesson Example 1)
--     s=6 -> face 36, SA 216     (Lesson Example, gift-box application)
--     s=5 -> face 25, SA 150     (Quiz Q4)
--     s=3 -> face 9,  SA 54      (Quiz Q9)
--   Rectangular prism SA = 2(lw + lh + wh):
--     5x3x2 -> lw15+lh10+wh6=31 -> SA 62      (Lesson Example 2)
--     8x4x3 -> lw32+lh24+wh12=68 -> SA 136     (Lesson word problem)
--     6x4x2 -> lw24+lh12+wh8=44 -> SA 88       (Quiz Q5)
--     7x3x2 -> lw21+lh14+wh6=41 -> SA 82        (Quiz Q10, word problem)
--   Face areas: rectangle 9x5 = 45 (Quiz Q3); square side 7 = 49 (Quiz Q2).
--   All quiz dimensions are deliberately different from the lesson's
--   worked-example dimensions (same measurements never reused verbatim),
--   testing the same skill with new numbers.
-- =============================================================================

do $$
declare
  v_lesson10_id uuid;
  v_quiz10_id   uuid;

  -- Quiz 10 — Finding the Surface Area of Solid Figures
  v_q_1  uuid; v_q_2  uuid; v_q_3  uuid; v_q_4  uuid; v_q_5  uuid;
  v_q_6  uuid; v_q_7  uuid; v_q_8  uuid; v_q_9  uuid; v_q_10 uuid;
begin

  -- ===========================================================================
  -- Lesson 10 — Finding the Surface Area of Solid Figures
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Finding the Surface Area of Solid Figures',
    'Learn what surface area means, how to find the areas of the faces of a cube and a rectangular prism, and how to add those areas to find the total surface area.',
    'built_in',
    null,
    'grade_5'
  )
  returning id into v_lesson10_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson10_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn how to find the surface area of solid figures, such as cubes and rectangular prisms.\n\n' ||
    E'A solid figure is a three-dimensional object — it has length, width, and height. Boxes, dice, and bricks are all examples of solid figures we see every day.'
  ),
  (
    v_lesson10_id, 2, 'vocabulary', 'What Is Surface Area?',
    E'Surface area is the total area of all the outer surfaces of a solid figure.\n\n' ||
    E'Think about a box. It has several flat sides. If you added up the area of every one of those sides, you would get the surface area of the box.\n\n' ||
    E'Surface area is different from volume. Surface area measures the space covering the OUTSIDE of a solid. Volume measures the space INSIDE a solid. In this lesson, we will focus on surface area.'
  ),
  (
    v_lesson10_id, 3, 'vocabulary', 'Understanding Faces',
    E'A face is one flat surface of a solid figure.\n\n' ||
    E'  - A cube has 6 square faces, and all 6 faces are the same size.\n' ||
    E'  - A rectangular prism has 6 rectangular faces, arranged in 3 pairs of equal opposite faces.\n\n' ||
    E'To find the surface area of a solid figure, we find the area of each face and then add all the areas together.'
  ),
  (
    v_lesson10_id, 4, 'explanation', 'Reviewing Area of Rectangles and Squares',
    E'Before we calculate surface area, let''s review two area formulas we already know:\n\n' ||
    E'  Area of a rectangle = length x width\n' ||
    E'  Area of a square = side x side\n\n' ||
    E'Example: A rectangle with length 9 cm and width 5 cm has an area of 9 x 5 = 45 cm^2.\n' ||
    E'Example: A square with side 7 cm has an area of 7 x 7 = 49 cm^2.\n\n' ||
    E'We will use these same formulas to find the area of each face of a solid figure.'
  ),
  (
    v_lesson10_id, 5, 'explanation', 'Surface Area of a Cube',
    E'A cube has 6 equal square faces. If the side length is s, then:\n\n' ||
    E'  Surface Area of a Cube = 6 x s x s (or 6 x s^2)\n\n' ||
    E'This works because every face of a cube has the exact same area, so we can find the area of just one face and multiply by 6.'
  ),
  (
    v_lesson10_id, 6, 'examples', 'Example: Surface Area of a Cube',
    E'Find the surface area of a cube with a side length of 4 cm.\n\n' ||
    E'Step 1: Find the area of one face.\n' ||
    E'  4 x 4 = 16 cm^2\n\n' ||
    E'Step 2: Multiply by 6, since a cube has 6 equal faces.\n' ||
    E'  6 x 16 = 96 cm^2\n\n' ||
    E'Answer: The surface area of the cube is 96 cm^2.'
  ),
  (
    v_lesson10_id, 7, 'explanation', 'Surface Area of a Rectangular Prism',
    E'A rectangular prism has 3 pairs of equal rectangular faces: a top and bottom, a front and back, and two sides. If the length is l, the width is w, and the height is h, then:\n\n' ||
    E'  Surface Area = 2 x (lw + lh + wh)\n\n' ||
    E'This formula finds the area of one face from each pair (lw, lh, and wh), adds them together, then multiplies by 2 because each of those faces has a matching, equal-area partner on the opposite side.'
  ),
  (
    v_lesson10_id, 8, 'examples', 'Example: Surface Area of a Rectangular Prism',
    E'Find the surface area of a rectangular prism with length 5 cm, width 3 cm, and height 2 cm.\n\n' ||
    E'Step 1: Find the area of each pair of faces.\n' ||
    E'  l x w = 5 x 3 = 15\n' ||
    E'  l x h = 5 x 2 = 10\n' ||
    E'  w x h = 3 x 2 = 6\n\n' ||
    E'Step 2: Add the three areas together.\n' ||
    E'  15 + 10 + 6 = 31\n\n' ||
    E'Step 3: Multiply by 2, since each face has a matching opposite face.\n' ||
    E'  2 x 31 = 62 cm^2\n\n' ||
    E'Answer: The surface area of the rectangular prism is 62 cm^2.'
  ),
  (
    v_lesson10_id, 9, 'examples', 'Adding the Areas of All Faces',
    E'Instead of memorizing a formula, you can always find surface area by adding the area of every face one at a time. This helps you understand where the formulas come from.\n\n' ||
    E'For the rectangular prism above (5 cm x 3 cm x 2 cm), there are 6 faces in 3 matching pairs:\n' ||
    E'  Top and bottom:  15 cm^2 each -> 15 + 15 = 30\n' ||
    E'  Front and back:  10 cm^2 each -> 10 + 10 = 20\n' ||
    E'  Left and right:   6 cm^2 each ->  6 +  6 = 12\n\n' ||
    E'Adding all 6 faces: 30 + 20 + 12 = 62 cm^2 — the same answer as the formula.'
  ),
  (
    v_lesson10_id, 10, 'vocabulary', 'Square Units',
    E'Surface area is always measured in square units, such as cm^2, m^2, or in^2 — never in cubic units like cm^3.\n\n' ||
    E'Cubic units are used to measure volume, which is the space inside a solid, not the area of its outer surfaces. Always double-check that your surface-area answer uses a squared unit.'
  ),
  (
    v_lesson10_id, 11, 'examples', 'Real-Life Application: Wrapping a Gift Box',
    E'Mia wants to wrap a gift box shaped like a cube with a side length of 6 cm. How much wrapping paper does she need to cover the whole box?\n\n' ||
    E'This is a surface-area problem, since we need to cover every outer face of the box.\n\n' ||
    E'Step 1: Area of one face = 6 x 6 = 36 cm^2\n' ||
    E'Step 2: Surface area = 6 x 36 = 216 cm^2\n\n' ||
    E'Answer: Mia needs at least 216 cm^2 of wrapping paper.'
  ),
  (
    v_lesson10_id, 12, 'examples', 'Real-Life Application: Painting a Box',
    E'A cardboard box shaped like a rectangular prism is 8 cm long, 4 cm wide, and 3 cm high. Ben wants to paint the entire outside of the box. How much surface will he paint?\n\n' ||
    E'Step 1: lw = 8 x 4 = 32,  lh = 8 x 3 = 24,  wh = 4 x 3 = 12\n' ||
    E'Step 2: 32 + 24 + 12 = 68\n' ||
    E'Step 3: 2 x 68 = 136 cm^2\n\n' ||
    E'Answer: Ben will paint 136 cm^2 of surface.'
  ),
  (
    v_lesson10_id, 13, 'summary', 'Common Mistakes to Avoid',
    E'  - Adding the dimensions instead of multiplying to find area.\n' ||
    E'  - Finding the area of only one face and forgetting there are more faces.\n' ||
    E'  - Forgetting to multiply by 6 when finding the surface area of a cube.\n' ||
    E'  - Forgetting one of the three pairs of faces in a rectangular prism.\n' ||
    E'  - Writing the answer in cubic units instead of square units.\n' ||
    E'  - Mixing up surface area (outside covering) with volume (space inside).'
  ),
  (
    v_lesson10_id, 14, 'summary', 'Remember',
    E'  - Surface area is the total area of all the outer faces of a solid figure.\n' ||
    E'  - A cube has 6 equal square faces: Surface Area = 6 x s x s.\n' ||
    E'  - A rectangular prism has 3 pairs of rectangular faces: Surface Area = 2 x (lw + lh + wh).\n' ||
    E'  - You can always check a formula answer by adding the areas of all 6 faces one at a time.\n' ||
    E'  - Surface area is always written in square units (cm^2, m^2, in^2), never cubic units.'
  );

  -- ===========================================================================
  -- Quiz 10 — built-in Internal Quiz for Lesson 10
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 10: Finding the Surface Area of Solid Figures',
    'internal', 'built_in', null, 'grade_5', true, true
  )
  returning id into v_quiz10_id;

  -- --- Q1 (basic — meaning of surface area) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Surface Area of Solid Figures',
    'What is the surface area of a solid figure?',
    'Surface area is the total area of all the outer faces (surfaces) of a solid figure — not the space inside it.'
  )
  returning id into v_q_1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_1, 'The total area of all the outer faces of the solid', true,  1),
    (v_q_1, 'The amount of space inside the solid', false, 2),
    (v_q_1, 'The distance around the base of the solid', false, 3),
    (v_q_1, 'The length of one edge of the solid', false, 4);

  -- --- Q2 (basic/intermediate — area of one square face) ------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Surface Area of Solid Figures',
    'One square face of a cube has a side length of 7 cm. What is the area of that one face?',
    'Area of a square = side x side, so 7 x 7 = 49 cm^2 is the area of one face.'
  )
  returning id into v_q_2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_2, '49 cm^2', true,  1),
    (v_q_2, '14 cm^2', false, 2),
    (v_q_2, '28 cm^2', false, 3),
    (v_q_2, '343 cm^2', false, 4);

  -- --- Q3 (basic/intermediate — area of one rectangular face) -------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Surface Area of Solid Figures',
    'One rectangular face of a box measures 9 cm by 5 cm. What is the area of that one face?',
    'Area of a rectangle = length x width, so 9 x 5 = 45 cm^2 is the area of that face.'
  )
  returning id into v_q_3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_3, '45 cm^2', true,  1),
    (v_q_3, '14 cm^2', false, 2),
    (v_q_3, '28 cm^2', false, 3),
    (v_q_3, '90 cm^2', false, 4);

  -- --- Q4 (intermediate — surface area of a cube) --------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Surface Area of Solid Figures',
    'What is the surface area of a cube with a side length of 5 cm?',
    'Area of one face = 5 x 5 = 25 cm^2. A cube has 6 equal faces, so surface area = 6 x 25 = 150 cm^2.'
  )
  returning id into v_q_4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_4, '150 cm^2', true,  1),
    (v_q_4, '25 cm^2', false, 2),
    (v_q_4, '100 cm^2', false, 3),
    (v_q_4, '125 cm^3', false, 4);

  -- --- Q5 (intermediate — surface area of a rectangular prism) ------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Surface Area of Solid Figures',
    'A rectangular prism has a length of 6 cm, a width of 4 cm, and a height of 2 cm. What is its surface area?',
    'lw = 6x4 = 24, lh = 6x2 = 12, wh = 4x2 = 8. Adding: 24 + 12 + 8 = 44. Multiplying by 2 for the matching opposite faces: 2 x 44 = 88 cm^2.'
  )
  returning id into v_q_5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_5, '88 cm^2', true,  1),
    (v_q_5, '44 cm^2', false, 2),
    (v_q_5, '72 cm^2', false, 3),
    (v_q_5, '48 cm^3', false, 4);

  -- --- Q6 (basic — number of faces) ----------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Surface Area of Solid Figures',
    'How many faces does a cube have?',
    'A cube has 6 equal square faces.'
  )
  returning id into v_q_6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_6, '6', true,  1),
    (v_q_6, '4', false, 2),
    (v_q_6, '8', false, 3),
    (v_q_6, '12', false, 4);

  -- --- Q7 (intermediate — correct unit) ------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Surface Area of Solid Figures',
    'Which unit is correct for expressing the surface area of a box measured in meters?',
    'Surface area is always measured in square units. Since the box is measured in meters, its surface area should be written in m^2.'
  )
  returning id into v_q_7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_7, 'm^2', true,  1),
    (v_q_7, 'm^3', false, 2),
    (v_q_7, 'm', false, 3),
    (v_q_7, 'no unit needed', false, 4);

  -- --- Q8 (intermediate — surface area vs. volume) -------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Surface Area of Solid Figures',
    'Which statement correctly describes the difference between surface area and volume?',
    'Surface area measures the total area of the outer faces of a solid (in square units). Volume measures the amount of space inside a solid (in cubic units).'
  )
  returning id into v_q_8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_8, 'Surface area measures the outside covering; volume measures the space inside', true,  1),
    (v_q_8, 'Surface area and volume both measure the space inside a solid', false, 2),
    (v_q_8, 'Volume measures the outside covering; surface area measures the space inside', false, 3),
    (v_q_8, 'Surface area and volume are always equal for the same solid', false, 4);

  -- --- Q9 (application — adding face areas / cube) -------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Surface Area of Solid Figures',
    'A cube-shaped block has a side length of 3 cm. What is its total surface area?',
    'Area of one face = 3 x 3 = 9 cm^2. A cube has 6 equal faces, so surface area = 6 x 9 = 54 cm^2.'
  )
  returning id into v_q_9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_9, '54 cm^2', true,  1),
    (v_q_9, '9 cm^2', false, 2),
    (v_q_9, '18 cm^2', false, 3),
    (v_q_9, '27 cm^3', false, 4);

  -- --- Q10 (application — word problem, rectangular prism) -----------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Surface Area of Solid Figures',
    'Ana wants to cover a cardboard box shaped like a rectangular prism with colored paper. The box is 7 cm long, 3 cm wide, and 2 cm high. How much paper does she need to cover the whole box?',
    'lw = 7x3 = 21, lh = 7x2 = 14, wh = 3x2 = 6. Adding: 21 + 14 + 6 = 41. Multiplying by 2 for the matching opposite faces: 2 x 41 = 82 cm^2.'
  )
  returning id into v_q_10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_10, '82 cm^2', true,  1),
    (v_q_10, '41 cm^2', false, 2),
    (v_q_10, '21 cm^2', false, 3),
    (v_q_10, '42 cm^3', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz10_id, v_q_1,  1),
    (v_quiz10_id, v_q_2,  2),
    (v_quiz10_id, v_q_3,  3),
    (v_quiz10_id, v_q_4,  4),
    (v_quiz10_id, v_q_5,  5),
    (v_quiz10_id, v_q_6,  6),
    (v_quiz10_id, v_q_7,  7),
    (v_quiz10_id, v_q_8,  8),
    (v_quiz10_id, v_q_9,  9),
    (v_quiz10_id, v_q_10, 10);

  -- ===========================================================================
  -- Lesson 10 -> Quiz 10 link (0032's linked_quiz_id convenience column,
  -- same pattern as 0033)
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz10_id where id = v_lesson10_id;

end $$;
