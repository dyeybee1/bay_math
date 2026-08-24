-- =============================================================================
-- Migration: 0082_seed_grade6_lesson8_quiz8_area_of_circle.sql
--
-- Seeds Grade 6 built-in content:
--   Lesson 8 — Area of a Circle
--   Quiz 8   — Internal Quiz for Lesson 8 (10 questions)
--
-- Continues the Grade 6 sequence after Lesson 7 / Quiz 7 (Parts and
-- Circumference of a Circle). This migration does NOT touch Lessons/Quizzes
-- 1-7 and does not alter any existing schema — it only inserts new rows,
-- following the exact conventions already established by 0027 (seed),
-- 0029 (lesson_pages restructuring), and 0032/0033 (linked_quiz_id).
--
-- Unlike 0027/0033 (which linked lesson->quiz in a separate follow-up
-- migration because linked_quiz_id didn't exist yet at seed time),
-- linked_quiz_id already exists on `lessons` (0032) by this point, so the
-- lesson->quiz link is set directly at the end of this single migration —
-- no separate content-migration needed.
--
-- lessons/quizzes rows use source_type = 'built_in', created_by = null,
-- grade_level = 'grade_6' (matching GradeLevel.grade6 / 'grade_6' in
-- lib/core/models/section.dart). question_bank.topic is tagged
-- 'Area of a Circle' to match the owning lesson's title, per the existing
-- Highest/Lowest Performing Topics convention (0008 comment, followed by
-- every question in 0027).
--
-- lesson_pages content follows the same page-per-slide, section_type
-- convention as 0029 ('introduction' | 'vocabulary' | 'explanation' |
-- 'examples' | 'summary'), using explicit `||` concatenation between
-- multi-line fragments (0029's convention, avoiding fragile implicit
-- adjacent-string-literal concatenation).
--
-- MATHEMATICAL VALIDATION (π ≈ 3.14 throughout, matching Lesson 7's
-- existing convention): every A = πr² result below (lesson worked examples
-- and quiz answer keys/distractors) was independently computed and
-- verified before writing this migration. r is always squared before
-- multiplying by π; whenever only the diameter is given, r = d / 2 is
-- computed first. Distractors are real, verifiable outputs of the
-- specific mistakes named in each explanation (forgetting to square,
-- using the diameter directly as the radius, applying the circumference
-- formula 2πr instead of πr², or forgetting to multiply by π) — no
-- invented distractor values.
-- =============================================================================

do $$
declare
  v_lesson8_id uuid;
  v_quiz8_id   uuid;

  v_q1  uuid; v_q2  uuid; v_q3  uuid; v_q4  uuid; v_q5  uuid;
  v_q6  uuid; v_q7  uuid; v_q8  uuid; v_q9  uuid; v_q10 uuid;
begin

  -- ===========================================================================
  -- Lesson 8 — Area of a Circle
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Area of a Circle',
    'Learn how to find the area of a circle using A = πr², including how to work with both the radius and the diameter, avoid the most common mistake, and solve real-world area problems.',
    'built_in',
    null,
    'grade_6'
  )
  returning id into v_lesson8_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson8_id, 1, 'introduction', 'Introduction',
    E'In Lesson 7, we learned about the parts of a circle and how to find the circumference — the distance AROUND a circle. In this lesson, we will learn about the AREA of a circle — the amount of space INSIDE a circle.'
  ),
  (
    v_lesson8_id, 2, 'vocabulary', 'Review: Parts of a Circle',
    E'Before we begin, let''s review what we learned in Lesson 7:\n' ||
    E'  center - the point in the middle of the circle, the same distance from every point on the circle\n' ||
    E'  radius (r) - the distance from the center to any point on the circle\n' ||
    E'  diameter (d) - the distance across the circle, passing through the center\n' ||
    E'  circumference (C) - the distance around the circle\n\n' ||
    E'Remember the relationship between radius and diameter:\n' ||
    E'  diameter = 2 x radius (d = 2r)\n' ||
    E'  radius = diameter divided by 2 (r = d / 2)'
  ),
  (
    v_lesson8_id, 3, 'explanation', 'Circumference vs. Area',
    E'Circumference and area measure two different things about a circle.\n' ||
    E'  Circumference measures the distance AROUND the circle. It is measured in linear units (cm, m, in, ft).\n' ||
    E'  Area measures the space INSIDE the circle. It is measured in SQUARE units (cm², m², in², ft²).\n\n' ||
    E'In Lesson 6, we learned that area always uses square units, whether the figure is a square, a rectangle, or a composite figure. The same idea applies to circles.'
  ),
  (
    v_lesson8_id, 4, 'explanation', 'The Area Formula: A = πr²',
    E'To find the area of a circle, we use this formula:\n' ||
    E'  A = πr²\n\n' ||
    E'In this formula:\n' ||
    E'  A stands for area\n' ||
    E'  π (pi) is a constant. We will use π ≈ 3.14\n' ||
    E'  r stands for radius\n' ||
    E'  r² means r x r (radius multiplied by itself)\n\n' ||
    E'Recall from Lesson 4 (Exponents and GEMDAS) that a small raised number is an exponent, and it tells us how many times to multiply a number by itself. For example, 6² = 6 x 6 = 36. In the same way, r² = r x r.\n\n' ||
    E'So the formula A = πr² really means:\n' ||
    E'  A = π x r x r\n\n' ||
    E'The radius must always be SQUARED before it is multiplied by π. This is one of the most important things to remember in this lesson.'
  ),
  (
    v_lesson8_id, 5, 'explanation', 'Calculating Area When the Radius Is Given',
    E'When a problem gives you the radius, follow these steps:\n' ||
    E'  1. Identify the radius (r).\n' ||
    E'  2. Write the formula: A = πr².\n' ||
    E'  3. Square the radius (multiply r by itself).\n' ||
    E'  4. Multiply the result by π (3.14).\n' ||
    E'  5. Write the answer using square units.\n' ||
    E'  6. Check whether the answer is reasonable.'
  ),
  (
    v_lesson8_id, 6, 'examples', 'Worked Examples: Radius Given',
    E'Worked Example 1:\n' ||
    E'  A circle has a radius of 4 cm. Find its area.\n' ||
    E'  Step 1: r = 4 cm\n' ||
    E'  Step 2: A = πr²\n' ||
    E'  Step 3: Square the radius: 4² = 4 x 4 = 16\n' ||
    E'  Step 4: Multiply by π: A = 3.14 x 16 = 50.24\n' ||
    E'  Step 5: A = 50.24 cm²\n\n' ||
    E'Worked Example 2:\n' ||
    E'  A circle has a radius of 9 cm. Find its area.\n' ||
    E'  Step 1: r = 9 cm\n' ||
    E'  Step 2: A = πr²\n' ||
    E'  Step 3: Square the radius: 9² = 9 x 9 = 81\n' ||
    E'  Step 4: Multiply by π: A = 3.14 x 81 = 254.34\n' ||
    E'  Step 5: A = 254.34 cm²'
  ),
  (
    v_lesson8_id, 7, 'explanation', 'Calculating Area When the Diameter Is Given',
    E'Sometimes a problem gives you the diameter instead of the radius. The formula A = πr² needs the RADIUS, so you must find the radius first.\n\n' ||
    E'Follow these steps:\n' ||
    E'  1. Identify the diameter (d).\n' ||
    E'  2. Find the radius: r = d / 2.\n' ||
    E'  3. Write the formula: A = πr².\n' ||
    E'  4. Square the radius.\n' ||
    E'  5. Multiply by π.\n' ||
    E'  6. Write the answer using square units.\n\n' ||
    E'Never use the diameter directly in place of r. Always divide it by 2 first.'
  ),
  (
    v_lesson8_id, 8, 'examples', 'Worked Examples: Diameter Given',
    E'Worked Example 3:\n' ||
    E'  A circle has a diameter of 14 cm. Find its area.\n' ||
    E'  Step 1: d = 14 cm\n' ||
    E'  Step 2: Find the radius: r = 14 / 2 = 7 cm\n' ||
    E'  Step 3: A = πr²\n' ||
    E'  Step 4: Square the radius: 7² = 7 x 7 = 49\n' ||
    E'  Step 5: Multiply by π: A = 3.14 x 49 = 153.86\n' ||
    E'  Step 6: A = 153.86 cm²\n\n' ||
    E'Worked Example 4:\n' ||
    E'  A circle has a diameter of 20 m. Find its area.\n' ||
    E'  Step 1: d = 20 m\n' ||
    E'  Step 2: Find the radius: r = 20 / 2 = 10 m\n' ||
    E'  Step 3: A = πr²\n' ||
    E'  Step 4: Square the radius: 10² = 10 x 10 = 100\n' ||
    E'  Step 5: Multiply by π: A = 3.14 x 100 = 314\n' ||
    E'  Step 6: A = 314 m²'
  ),
  (
    v_lesson8_id, 9, 'explanation', 'Watch Out! A Common Mistake',
    E'A common mistake is using the diameter directly in the formula A = πr², instead of finding the radius first.\n\n' ||
    E'For example, if a circle has a diameter of 10 cm:\n' ||
    E'  WRONG: A = π x 10² = 3.14 x 100 = 314 cm² (this uses the diameter as if it were the radius)\n' ||
    E'  CORRECT: First find the radius: r = 10 / 2 = 5 cm. Then A = π x 5² = 3.14 x 25 = 78.5 cm²\n\n' ||
    E'The correct area is 78.5 cm², not 314 cm². Always check whether you were given the radius or the diameter before substituting into the formula.'
  ),
  (
    v_lesson8_id, 10, 'examples', 'Real-World Applications',
    E'Worked Example 5 (Pizza):\n' ||
    E'  A round pizza has a diameter of 16 inches. What is its area?\n' ||
    E'  Step 1: d = 16 in, so r = 16 / 2 = 8 in\n' ||
    E'  Step 2: A = πr² = 3.14 x 8² = 3.14 x 64 = 200.96\n' ||
    E'  Step 3: A = 200.96 in²\n\n' ||
    E'Worked Example 6 (Flower Garden):\n' ||
    E'  A circular flower garden has a radius of 3 m. What is its area?\n' ||
    E'  Step 1: r = 3 m\n' ||
    E'  Step 2: A = πr² = 3.14 x 3² = 3.14 x 9 = 28.26\n' ||
    E'  Step 3: A = 28.26 m²\n\n' ||
    E'Worked Example 7 (Swimming Pool):\n' ||
    E'  A circular swimming pool has a radius of 12 ft. What is its area?\n' ||
    E'  Step 1: r = 12 ft\n' ||
    E'  Step 2: A = πr² = 3.14 x 12² = 3.14 x 144 = 452.16\n' ||
    E'  Step 3: A = 452.16 ft²'
  ),
  (
    v_lesson8_id, 11, 'summary', 'Remember',
    E'  - Area measures the space INSIDE a circle; circumference measures the distance AROUND a circle.\n' ||
    E'  - The area formula is A = πr².\n' ||
    E'  - r stands for radius; r² means r x r.\n' ||
    E'  - Use π ≈ 3.14.\n' ||
    E'  - If you are given the diameter, find the radius first: r = d / 2. Never use the diameter directly in the formula.\n' ||
    E'  - Diameter is always twice the radius: d = 2r.\n' ||
    E'  - Area is always measured in SQUARE units (cm², m², in², ft²).\n' ||
    E'  - Always check that your answer makes sense before writing your final answer.'
  );

  -- ===========================================================================
  -- Quiz 8 — built-in Internal Quiz for Lesson 8
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 8: Area of a Circle',
    'internal', 'built_in', null, 'grade_6', true, true
  )
  returning id into v_quiz8_id;

  -- --- Q1 (concept) ---------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Area of a Circle',
    'What does the area of a circle measure?',
    'Area measures the amount of space inside a two-dimensional figure, including a circle. The distance around a circle is called the circumference, not the area.'
  )
  returning id into v_q1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1, 'The distance around the circle', false, 1),
    (v_q1, 'The space inside the circle',    true,  2),
    (v_q1, 'The length of the radius',        false, 3),
    (v_q1, 'The length of the diameter',      false, 4);

  -- --- Q2 (radius/diameter relationship) -------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Area of a Circle',
    'A circle has a diameter of 18 cm. What is its radius?',
    'The radius is half of the diameter: r = d ÷ 2 = 18 ÷ 2 = 9 cm.'
  )
  returning id into v_q2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2, '9 cm',  true,  1),
    (v_q2, '18 cm', false, 2),
    (v_q2, '36 cm', false, 3),
    (v_q2, '6 cm',  false, 4);

  -- --- Q3 (formula identification) --------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Area of a Circle',
    'Which formula is used to find the area of a circle?',
    'The area of a circle is found using A = πr², where the radius is squared before multiplying by π. C = 2πr is the formula for circumference, not area.'
  )
  returning id into v_q3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q3, 'A = πr²', true,  1),
    (v_q3, 'C = 2πr', false, 2),
    (v_q3, 'A = 2πr', false, 3),
    (v_q3, 'A = πr',  false, 4);

  -- --- Q4 (r² means r x r, not r x 2) ------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Area of a Circle',
    'If r = 7, what is r²?',
    'r² means r x r. Since r = 7, r² = 7 x 7 = 49 — not 7 x 2 = 14.'
  )
  returning id into v_q4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q4, '49', true,  1),
    (v_q4, '14', false, 2),
    (v_q4, '7',  false, 3),
    (v_q4, '21', false, 4);

  -- --- Q5 (radius given, basic calculation) -------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Area of a Circle',
    'What is the area of a circle with a radius of 6 cm? (Use π ≈ 3.14)',
    'A = πr² = 3.14 x 6² = 3.14 x 36 = 113.04 cm². Square the radius first, then multiply by π.'
  )
  returning id into v_q5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5, '113.04 cm²', true,  1),
    (v_q5, '18.84 cm²',  false, 2),
    (v_q5, '37.68 cm²',  false, 3),
    (v_q5, '36 cm²',     false, 4);

  -- --- Q6 (radius given, moderate calculation) ------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Area of a Circle',
    'What is the area of a circle with a radius of 11 cm? (Use π ≈ 3.14)',
    'A = πr² = 3.14 x 11² = 3.14 x 121 = 379.94 cm².'
  )
  returning id into v_q6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6, '379.94 cm²', true,  1),
    (v_q6, '34.54 cm²',  false, 2),
    (v_q6, '69.08 cm²',  false, 3),
    (v_q6, '121 cm²',    false, 4);

  -- --- Q7 (diameter given) ------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Area of a Circle',
    'A circle has a diameter of 8 cm. What is its area? (Use π ≈ 3.14)',
    'First find the radius: r = 8 ÷ 2 = 4 cm. Then A = πr² = 3.14 x 4² = 3.14 x 16 = 50.24 cm². Using the diameter directly as the radius (3.14 x 8² = 200.96) is a common mistake.'
  )
  returning id into v_q7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q7, '50.24 cm²',  true,  1),
    (v_q7, '200.96 cm²', false, 2),
    (v_q7, '12.56 cm²',  false, 3),
    (v_q7, '16 cm²',     false, 4);

  -- --- Q8 (diameter given, real-world word problem) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Area of a Circle',
    'A circular table has a diameter of 40 cm. What is its area? (Use π ≈ 3.14)',
    'The radius is 40 ÷ 2 = 20 cm. A = πr² = 3.14 x 20² = 3.14 x 400 = 1,256 cm².'
  )
  returning id into v_q8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q8, '1,256 cm²', true,  1),
    (v_q8, '5,024 cm²', false, 2),
    (v_q8, '125.6 cm²', false, 3),
    (v_q8, '62.8 cm²',  false, 4);

  -- --- Q9 (units) ------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Area of a Circle',
    'A circular flower bed has a radius of 5 meters. Which unit should be used to express its area?',
    'Area is the amount of space inside a two-dimensional figure, so it is always measured in square units. Since the radius is in meters, the area should be in square meters (m²).'
  )
  returning id into v_q9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9, 'm²',  true,  1),
    (v_q9, 'm',   false, 2),
    (v_q9, 'm³',  false, 3),
    (v_q9, 'cm',  false, 4);

  -- --- Q10 (area vs circumference) --------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Area of a Circle',
    'Which statement correctly describes the difference between circumference and area?',
    'Circumference (C = 2πr) measures the distance around a circle and is expressed in linear units. Area (A = πr²) measures the space inside a circle and is expressed in square units.'
  )
  returning id into v_q10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10, 'Circumference measures the distance around the circle, and area measures the space inside it.', true,  1),
    (v_q10, 'Circumference measures the space inside the circle, and area measures the distance around it.', false, 2),
    (v_q10, 'Both circumference and area are always measured in square units.', false, 3),
    (v_q10, 'Both circumference and area are always measured in linear units.', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz8_id, v_q1,  1),
    (v_quiz8_id, v_q2,  2),
    (v_quiz8_id, v_q3,  3),
    (v_quiz8_id, v_q4,  4),
    (v_quiz8_id, v_q5,  5),
    (v_quiz8_id, v_q6,  6),
    (v_quiz8_id, v_q7,  7),
    (v_quiz8_id, v_q8,  8),
    (v_quiz8_id, v_q9,  9),
    (v_quiz8_id, v_q10, 10);

  -- ===========================================================================
  -- Link Lesson 8 -> Quiz 8 (linked_quiz_id, 0032) — set directly here since,
  -- unlike 0027/0032/0033, the column already exists at seed time, so no
  -- separate follow-up migration is needed.
  -- ===========================================================================
  update public.lessons
  set linked_quiz_id = v_quiz8_id
  where id = v_lesson8_id;

end $$;
