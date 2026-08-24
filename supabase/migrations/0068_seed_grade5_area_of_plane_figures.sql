-- =============================================================================
-- Migration: 0068_seed_grade5_area_of_plane_figures.sql
-- Content-seeding migration, same consolidated pattern as
-- 0066_seed_grade5_solving_operations_using_gmdas.sql and
-- 0067_seed_grade5_multiplying_dividing_fractions.sql — schema (lessons,
-- lesson_pages, question_bank, question_choices, quizzes, quiz_questions,
-- lessons.linked_quiz_id) is already fully in place, so lesson, pages,
-- quiz, questions, choices, and the lesson-to-quiz link are all seeded
-- together in one migration.
--
-- Seeds Grade 5 (MELC-level) built-in content:
--   Lesson 4 — Finding the Area of Plane Figures
--   Quiz 4   — Internal Quiz for Lesson 4 (10 questions)
--
-- This is the FOURTH Grade 5 lesson in the sequence. Lessons 1-3 are
-- assumed to already exist (Lesson 1 outside this reference package;
-- Lessons 2 and 3 seeded by 0066/0067); this migration does not read
-- from or depend on any of them — it only creates new rows.
--
-- FIGURE SCOPE: the reference files contain no existing geometry/area
-- content to confirm scope against, so this migration follows the
-- standard Grade 5 (Philippine MELC) area topics named in the task as
-- "potential figures" — rectangle, square, triangle, parallelogram — all
-- four, since Grade 5 covers all four and nothing in the reference
-- narrows that scope. No figures beyond these four (no volume, surface
-- area, circumference, or composite figures) are introduced, per the
-- explicit topic boundary in the task.
--
-- Conventions matched against 0027/0029/0031/0033/0066/0067 (all re-read
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
--     page, same reasoning as 0066/0067: that column is explicitly scoped
--     to a fixed 6-column place-value addition/subtraction POC and does
--     not fit area content.
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
--     assessment_type (0043) left null — ordinary practice quiz.
--   - quiz_questions: display_order 1-10, inserted all at once.
--   - lessons.linked_quiz_id: set via UPDATE in the same DO block after
--     both the lesson and quiz exist, same relationship 0032/0033/0066/
--     0067 established.
--
-- All ids are database-generated (gen_random_uuid()) and captured via
-- `returning ... into`, never hardcoded.
--
-- MATH INDEPENDENTLY VERIFIED for every lesson example and every quiz
-- question/distractor before writing (see inline comments below):
--   Rectangle: A = length x width.
--   Square:    A = side x side.
--   Triangle:  A = 1/2 x base x height (perpendicular height, not a
--              slanted side).
--   Parallelogram: A = base x height (perpendicular height, not the
--              slanted side).
-- Every answer includes the correct squared unit; no lesson or quiz
-- number is reused verbatim between the two (0021's "different numbers,
-- same skill" alignment rule).
-- =============================================================================

do $$
declare
  v_lesson4_id uuid;
  v_quiz4_id   uuid;

  -- Quiz 4 — Finding the Area of Plane Figures
  v_q_1  uuid; v_q_2  uuid; v_q_3  uuid; v_q_4  uuid; v_q_5  uuid;
  v_q_6  uuid; v_q_7  uuid; v_q_8  uuid; v_q_9  uuid; v_q_10 uuid;
begin

  -- ===========================================================================
  -- Lesson 4 — Finding the Area of Plane Figures
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Finding the Area of Plane Figures',
    'Learn to find the area of rectangles, squares, triangles, and parallelograms using their formulas, expressed in the correct square units.',
    'built_in',
    null,
    'grade_5'
  )
  returning id into v_lesson4_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson4_id, 1, 'introduction', 'Introduction',
    E'Area tells us how much surface is covered inside a plane figure - like how much floor a rug covers, or how much paper a poster uses. In this lesson, we will learn how to find the area of rectangles, squares, triangles, and parallelograms.'
  ),
  (
    v_lesson4_id, 2, 'explanation', 'Area vs. Perimeter',
    E'Area and perimeter both describe a figure, but they measure different things:\n' ||
    E'  Area - the amount of surface covered INSIDE the figure.\n' ||
    E'  Perimeter - the distance AROUND the outside of the figure.\n\n' ||
    E'This lesson focuses on area. Remember: area is about the space inside, not the distance around.'
  ),
  (
    v_lesson4_id, 3, 'explanation', 'Units of Area',
    E'Because area covers a flat surface, it is measured in SQUARE units, such as square centimeters (cm²) or square meters (m²).\n\n' ||
    E'A rectangle measuring 5 cm by 3 cm has an area of 15 cm² - not 15 cm. The small 2 means the unit is squared, since we covered a surface, not just measured a single length.'
  ),
  (
    v_lesson4_id, 4, 'explanation', 'Area of a Rectangle',
    E'A rectangle has a length and a width. To find its area, multiply the length by the width.\n\n' ||
    E'  A = l x w\n\n' ||
    E'Worked Example:\n' ||
    E'  Length = 8 cm, Width = 5 cm.\n' ||
    E'  A = 8 x 5.\n' ||
    E'  A = 40 cm².'
  ),
  (
    v_lesson4_id, 5, 'explanation', 'Area of a Square',
    E'A square has four equal sides. Since the length and width are the same, we multiply the side by itself.\n\n' ||
    E'  A = s x s\n\n' ||
    E'Worked Example:\n' ||
    E'  Side = 6 cm.\n' ||
    E'  A = 6 x 6.\n' ||
    E'  A = 36 cm².\n\n' ||
    E'We use the same measurement twice because all four sides of a square are equal.'
  ),
  (
    v_lesson4_id, 6, 'explanation', 'Area of a Triangle',
    E'A triangle has a base and a height. The height is the PERPENDICULAR distance from the base to the opposite corner - not a slanted side.\n\n' ||
    E'  A = 1/2 x b x h\n\n' ||
    E'Worked Example:\n' ||
    E'  Base = 10 cm, Height = 6 cm.\n' ||
    E'  A = 1/2 x 10 x 6.\n' ||
    E'  A = 1/2 x 60.\n' ||
    E'  A = 30 cm².\n\n' ||
    E'Do not forget the 1/2 - a triangle covers half the area of a rectangle with the same base and height.'
  ),
  (
    v_lesson4_id, 7, 'explanation', 'Area of a Parallelogram',
    E'A parallelogram has a base and a height, just like a triangle. The height is the perpendicular distance between the base and the opposite side - not the slanted side.\n\n' ||
    E'  A = b x h\n\n' ||
    E'Worked Example:\n' ||
    E'  Base = 9 cm, Height = 4 cm.\n' ||
    E'  A = 9 x 4.\n' ||
    E'  A = 36 cm².\n\n' ||
    E'Even if a slanted side is given, always use the height - the perpendicular distance - not the slanted side.'
  ),
  (
    v_lesson4_id, 8, 'explanation', 'Choosing the Correct Formula',
    E'Before solving, identify the figure and pick the matching formula:\n' ||
    E'  Rectangle: A = l x w\n' ||
    E'  Square: A = s x s\n' ||
    E'  Triangle: A = 1/2 x b x h\n' ||
    E'  Parallelogram: A = b x h\n\n' ||
    E'Then follow these steps:\n' ||
    E'  1. Identify the figure.\n' ||
    E'  2. Identify the given measurements.\n' ||
    E'  3. Select the correct formula.\n' ||
    E'  4. Substitute the measurements.\n' ||
    E'  5. Calculate.\n' ||
    E'  6. Write the answer with the correct square unit.'
  ),
  (
    v_lesson4_id, 9, 'examples', 'Solving Step by Step',
    E'Find the area of a rectangle with a length of 12 cm and a width of 4 cm.\n\n' ||
    E'  Step 1 - Identify the formula: A = l x w.\n' ||
    E'  Step 2 - Substitute: A = 12 x 4.\n' ||
    E'  Step 3 - Calculate: A = 48.\n' ||
    E'  Step 4 - Add the correct unit: A = 48 cm².'
  ),
  (
    v_lesson4_id, 10, 'explanation', 'Common Mistakes to Avoid',
    E'Here are mistakes learners often make when finding area:\n\n' ||
    E'Mistake 1: Using perimeter instead of area - adding all the sides instead of multiplying the correct dimensions.\n\n' ||
    E'Mistake 2: Forgetting square units - writing 40 cm instead of 40 cm².\n\n' ||
    E'Mistake 3: Using the wrong dimension - using a slanted side instead of the height for a triangle or parallelogram.\n\n' ||
    E'Mistake 4: Forgetting the 1/2 in the triangle formula - this gives double the correct area.'
  ),
  (
    v_lesson4_id, 11, 'examples', 'Applying Area to Real Life',
    E'Worked Example 1 (rectangle):\n' ||
    E'  A rectangular garden is 9 meters long and 6 meters wide. What is its area?\n' ||
    E'  A = l x w = 9 x 6.\n' ||
    E'  Answer: A = 54 m².\n\n' ||
    E'Worked Example 2 (triangle):\n' ||
    E'  A triangular garden bed has a base of 14 meters and a height of 5 meters. What is its area?\n' ||
    E'  A = 1/2 x b x h = 1/2 x 14 x 5.\n' ||
    E'  A = 1/2 x 70.\n' ||
    E'  Answer: A = 35 m².'
  ),
  (
    v_lesson4_id, 12, 'summary', 'Remember',
    E'  - Area is the space INSIDE a figure, measured in square units (cm², m²).\n' ||
    E'  - Rectangle: A = l x w.\n' ||
    E'  - Square: A = s x s.\n' ||
    E'  - Triangle: A = 1/2 x b x h - do not forget the 1/2.\n' ||
    E'  - Parallelogram: A = b x h - use the height, not a slanted side.\n' ||
    E'  - Always write your final answer with the correct square unit.'
  );

  -- ===========================================================================
  -- Quiz 4 — built-in Internal Quiz for Lesson 4
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 4: Finding the Area of Plane Figures',
    'internal', 'built_in', null, 'grade_5', true, true
  )
  returning id into v_quiz4_id;

  -- --- Q1 (identify what area means, basic/conceptual) -------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Area of Plane Figures',
    'What does the area of a figure tell you?',
    'Area is the amount of surface covered inside a figure. The distance around the outside of a figure is its perimeter, not its area.'
  )
  returning id into v_q_1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_1, 'The amount of surface covered inside the figure', true,  1),
    (v_q_1, 'The distance around the outside of the figure', false, 2),
    (v_q_1, 'The length of one side only', false, 3),
    (v_q_1, 'The number of corners the figure has', false, 4);

  -- --- Q2 (identify the correct formula - rectangle) ----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Area of Plane Figures',
    'Which formula is used to find the area of a rectangle?',
    'The area of a rectangle is found by multiplying its length by its width: A = l x w.'
  )
  returning id into v_q_2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_2, 'A = l x w', true,  1),
    (v_q_2, 'A = s x s', false, 2),
    (v_q_2, 'A = 1/2 x b x h', false, 3),
    (v_q_2, 'A = b x h', false, 4);

  -- --- Q3 (find area of rectangle) ---------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Area of Plane Figures',
    'What is the area of a rectangle with a length of 7 cm and a width of 6 cm?',
    'A = l x w = 7 x 6 = 42 cm². Remember to write the square unit.'
  )
  returning id into v_q_3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_3, '42 cm²', true,  1),
    (v_q_3, '26 cm²', false, 2),
    (v_q_3, '13 cm²', false, 3),
    (v_q_3, '42 cm', false, 4);

  -- --- Q4 (find area of square) --------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Area of Plane Figures',
    'What is the area of a square with a side of 9 cm?',
    'A = s x s = 9 x 9 = 81 cm². A square area is found by multiplying the side by itself, not by adding sides.'
  )
  returning id into v_q_4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_4, '81 cm²', true,  1),
    (v_q_4, '18 cm²', false, 2),
    (v_q_4, '36 cm²', false, 3),
    (v_q_4, '81 cm', false, 4);

  -- --- Q5 (find area of triangle) --------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Area of Plane Figures',
    'What is the area of a triangle with a base of 8 cm and a height of 5 cm?',
    'A = 1/2 x b x h = 1/2 x 8 x 5 = 1/2 x 40 = 20 cm². Forgetting the 1/2 would incorrectly give 40 cm².'
  )
  returning id into v_q_5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_5, '20 cm²', true,  1),
    (v_q_5, '40 cm²', false, 2),
    (v_q_5, '13 cm²', false, 3),
    (v_q_5, '20 cm', false, 4);

  -- --- Q6 (find area of parallelogram) -----------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Area of Plane Figures',
    'What is the area of a parallelogram with a base of 11 cm and a height of 4 cm?',
    'A = b x h = 11 x 4 = 44 cm². A parallelogram does not use the 1/2 that a triangle uses.'
  )
  returning id into v_q_6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_6, '44 cm²', true,  1),
    (v_q_6, '15 cm²', false, 2),
    (v_q_6, '22 cm²', false, 3),
    (v_q_6, '44 cm', false, 4);

  -- --- Q7 (correct dimension: height vs. slanted side) -----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Area of Plane Figures',
    'A parallelogram has a base of 10 cm, a slanted side of 7 cm, and a height of 6 cm. Which measurements should be used to find its area?',
    'Area uses the base and the perpendicular height, not the slanted side. So the correct measurements are the base (10 cm) and the height (6 cm).'
  )
  returning id into v_q_7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_7, 'Base 10 cm and height 6 cm', true,  1),
    (v_q_7, 'Base 10 cm and slanted side 7 cm', false, 2),
    (v_q_7, 'Height 6 cm and slanted side 7 cm', false, 3),
    (v_q_7, 'Slanted side 7 cm only', false, 4);

  -- --- Q8 (real-life word problem, rectangle) -----------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Area of Plane Figures',
    'A rectangular garden is 13 meters long and 4 meters wide. What is its area?',
    'A = l x w = 13 x 4 = 52 m².'
  )
  returning id into v_q_8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_8, '52 m²', true,  1),
    (v_q_8, '34 m²', false, 2),
    (v_q_8, '17 m²', false, 3),
    (v_q_8, '52 m', false, 4);

  -- --- Q9 (real-life word problem, triangle) -------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Area of Plane Figures',
    'A triangular banner has a base of 12 cm and a height of 5 cm. What is its area?',
    'A = 1/2 x b x h = 1/2 x 12 x 5 = 1/2 x 60 = 30 cm².'
  )
  returning id into v_q_9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_9, '30 cm²', true,  1),
    (v_q_9, '60 cm²', false, 2),
    (v_q_9, '17 cm²', false, 3),
    (v_q_9, '30 cm', false, 4);

  -- --- Q10 (reasoning: identify the mistake in a solution) ------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Finding the Area of Plane Figures',
    'Ella found the area of a triangle with a base of 8 cm and a height of 3 cm. She wrote: Area = 8 x 3 = 24 cm². What mistake did Ella make?',
    'A triangle''s area formula includes 1/2: A = 1/2 x b x h = 1/2 x 8 x 3 = 12 cm². Ella used the correct base, height, and square unit, but forgot to multiply by 1/2.'
  )
  returning id into v_q_10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_10, 'She forgot to multiply by 1/2', true,  1),
    (v_q_10, 'She used the wrong base value', false, 2),
    (v_q_10, 'She used the wrong height value', false, 3),
    (v_q_10, 'She forgot to include square units', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz4_id, v_q_1,  1),
    (v_quiz4_id, v_q_2,  2),
    (v_quiz4_id, v_q_3,  3),
    (v_quiz4_id, v_q_4,  4),
    (v_quiz4_id, v_q_5,  5),
    (v_quiz4_id, v_q_6,  6),
    (v_quiz4_id, v_q_7,  7),
    (v_quiz4_id, v_q_8,  8),
    (v_quiz4_id, v_q_9,  9),
    (v_quiz4_id, v_q_10, 10);

  -- ===========================================================================
  -- Link Lesson 4 -> Quiz 4 (0032's linked_quiz_id, same pattern as 0033/0066/0067)
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz4_id where id = v_lesson4_id;

end $$;
