-- =============================================================================
-- Migration: 0079_seed_grade6_lesson5_volume_prisms.sql
-- Content-seeding migration only — no schema changes. Follows the same
-- conventions as 0027/0029/0031/0033 (Grade 4 seed) and the existing
-- Grade 6 Lessons 1-4 / Quizzes 1-4 already in this project:
--
--   Lesson 5 — Volume of Cubes and Rectangular Prisms   (grade_level = 'grade_6')
--   Quiz 5   — Internal Quiz for Lesson 5 (10 questions)
--
-- Written directly against `lesson_pages` (0028) rather than a single
-- `lessons.body` blob, matching the current-generation page-based lesson
-- shape (0029 already migrated the older Grade 4 lessons to this same
-- shape) — `lessons.body` is set to the short 1-2 sentence list-screen
-- description only.
--
-- `worked_example` (0030/0031) is deliberately left null on every page
-- here: per 0030's column comment, that jsonb shape is fixed to exactly 6
-- place-value columns for addition/subtraction and is explicit POC scope,
-- "not built to generalize to other digit counts" (and not to a
-- multiplication-based volume formula at all) — so this lesson uses plain
-- `body` text for its worked examples, the same as every other non-POC
-- lesson page in this project.
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
-- Lesson 5 is linked to Quiz 5 via `lessons.linked_quiz_id` (0032) at the
-- end of this migration, matching the pairing 0033 already established for
-- the Grade 4 lessons.
--
-- MATHEMATICAL VALIDATION (independently re-checked before writing):
--   Rectangular prism examples: 9x5x4=180 | 12x6x2=144 | 8x6x3=144
--   Cube examples:              6^3=216   | 7^3=343    | 15^3=3375
--   Missing dimension (lesson): V=210, l=7, w=6 -> h=210/(7x6)=210/42=5
--   Real-world (aquarium):      40x25x30=30000 cm^3 (=30 L, since 1 L=1000 cm^3)
--   Quiz Q5 (rect. prism):      6x4x5=120   | distractors: 6x4=24, 4x5=20, 6+4+5=15
--   Quiz Q6 (cube):             4^3=4x4x4=64 | distractors: 4^2=16, 4x3=12, slip=48
--   Quiz Q7 (word, rect.):      50x20x30=30000 | distractors: 50x20=1000, 50+20+30=100, 3000 (dropped zero)
--   Quiz Q8 (word, cube):       10^3=1000   | distractors: 10^2=100, 10x3=30, 300
--   Quiz Q9 (missing dim.):     V=192,l=8,w=6 -> h=192/(8x6)=192/48=4 | distractors: 192/8=24, 192/6=32, 6 (copied width)
-- =============================================================================

do $$
declare
  v_lesson5_id uuid;
  v_quiz5_id   uuid;

  -- Quiz 5 — Volume of Cubes and Rectangular Prisms
  v_q5_1  uuid; v_q5_2  uuid; v_q5_3  uuid; v_q5_4  uuid; v_q5_5  uuid;
  v_q5_6  uuid; v_q5_7  uuid; v_q5_8  uuid; v_q5_9  uuid; v_q5_10 uuid;
begin

  -- ===========================================================================
  -- Lesson 5 — Volume of Cubes and Rectangular Prisms
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Volume of Cubes and Rectangular Prisms',
    'Learn what volume means, how to find the volume of a rectangular prism and a cube, and how to solve real-world and missing-dimension volume problems.',
    'built_in',
    null,
    'grade_6'
  )
  returning id into v_lesson5_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson5_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn about volume — the amount of space a three-dimensional (3D) object takes up. We will find the volume of two common 3D shapes: rectangular prisms (box shapes) and cubes.'
  ),
  (
    v_lesson5_id, 2, 'vocabulary', 'Understanding Volume',
    E'Length tells us how long something is. Area tells us how much flat surface a shape covers, measured in square units (like cm²). Volume tells us how much space is INSIDE a 3D object, measured in cubic units (like cm³).\n\n' ||
    E'  LENGTH  -> one dimension  -> units (cm, m, in)\n' ||
    E'  AREA    -> two dimensions -> square units (cm², m², in²)\n' ||
    E'  VOLUME  -> three dimensions -> cubic units (cm³, m³, in³)\n\n' ||
    E'A cubic unit is the amount of space taken up by a cube that measures 1 unit on every side — for example, 1 cm³ is the space inside a tiny cube that is 1 cm long, 1 cm wide, and 1 cm tall. When we measure volume, we are counting how many of these unit cubes would fit inside the object.'
  ),
  (
    v_lesson5_id, 3, 'explanation', 'Volume of a Rectangular Prism',
    E'A rectangular prism is a box shape with 3 dimensions: length (l), width (w), and height (h).\n\n' ||
    E'FORMULA: V = l x w x h\n\n' ||
    E'To find the volume:\n' ||
    E'  1. Identify the length, width, and height.\n' ||
    E'  2. Write the formula V = l x w x h.\n' ||
    E'  3. Substitute the values into the formula.\n' ||
    E'  4. Multiply.\n' ||
    E'  5. Write the answer using cubic units.'
  ),
  (
    v_lesson5_id, 4, 'examples', 'Rectangular Prism Examples',
    E'Worked Example 1 (Basic):\n' ||
    E'  A shoebox has a length of 9 cm, a width of 5 cm, and a height of 4 cm. Find its volume.\n' ||
    E'  V = l x w x h\n' ||
    E'  V = 9 x 5 x 4\n' ||
    E'  V = 45 x 4\n' ||
    E'  V = 180 cm³\n\n' ||
    E'Worked Example 2 (Moderate — real-world):\n' ||
    E'  A storage container is 12 m long, 6 m wide, and 2 m high. Find its volume.\n' ||
    E'  V = l x w x h\n' ||
    E'  V = 12 x 6 x 2\n' ||
    E'  V = 72 x 2\n' ||
    E'  V = 144 m³\n\n' ||
    E'Notice that the unit is always written CUBED (cm³, m³) because volume fills three dimensions.'
  ),
  (
    v_lesson5_id, 5, 'explanation', 'Volume of a Cube',
    E'A cube is a special rectangular prism where every side is the same length. Instead of length, width, and height, a cube only needs ONE measurement: its side length (s).\n\n' ||
    E'FORMULA: V = s x s x s, or V = s³\n\n' ||
    E'This connects to what we learned in Exponents and GEMDAS: s³ means "s used as a factor 3 times." Since a cube''s length, width, and height are all equal to s, the rectangular prism formula V = l x w x h becomes V = s x s x s = s³.'
  ),
  (
    v_lesson5_id, 6, 'examples', 'Cube Examples',
    E'Worked Example 3 (Basic):\n' ||
    E'  A wooden cube has a side length of 6 cm. Find its volume.\n' ||
    E'  V = s³\n' ||
    E'  V = 6³\n' ||
    E'  V = 6 x 6 x 6\n' ||
    E'  V = 36 x 6\n' ||
    E'  V = 216 cm³\n\n' ||
    E'Worked Example 4 (Moderate):\n' ||
    E'  A storage cube has a side length of 7 in. Find its volume.\n' ||
    E'  V = s³\n' ||
    E'  V = 7³\n' ||
    E'  V = 7 x 7 x 7\n' ||
    E'  V = 49 x 7\n' ||
    E'  V = 343 in³'
  ),
  (
    v_lesson5_id, 7, 'explanation', 'Comparing the Two Formulas',
    E'  Rectangular Prism:  V = l x w x h\n' ||
    E'  Cube:               V = s³ (where l = w = h = s)\n\n' ||
    E'A cube is really just a rectangular prism whose length, width, and height happen to be equal. That is why s x s x s can be written using the shortcut s³. Before solving any volume problem, always check: are all three dimensions the same (use V = s³) or are they different (use V = l x w x h)?\n\n' ||
    E'Also remember not to confuse:\n' ||
    E'  cm  -> length\n' ||
    E'  cm² -> area (used for the flat face of a cube or prism, not its full volume)\n' ||
    E'  cm³ -> volume'
  ),
  (
    v_lesson5_id, 8, 'examples', 'Finding a Missing Dimension',
    E'Sometimes the volume is already known, and one dimension is missing.\n\n' ||
    E'Worked Example 5:\n' ||
    E'  A rectangular prism has a volume of 210 cm³, a length of 7 cm, and a width of 6 cm. What is its height?\n' ||
    E'  V = l x w x h\n' ||
    E'  210 = 7 x 6 x h\n' ||
    E'  210 = 42 x h\n' ||
    E'  h = 210 / 42\n' ||
    E'  h = 5 cm\n\n' ||
    E'Since l x w x h = V, we can find any missing dimension by dividing the volume by the product of the two known dimensions.'
  ),
  (
    v_lesson5_id, 9, 'examples', 'Real-World Applications',
    E'Worked Example 6 (Rectangular prism — fish tank):\n' ||
    E'  A rectangular fish tank is 40 cm long, 25 cm wide, and 30 cm tall. How much water can it hold?\n' ||
    E'  V = l x w x h\n' ||
    E'  V = 40 x 25 x 30\n' ||
    E'  V = 1,000 x 30\n' ||
    E'  V = 30,000 cm³\n' ||
    E'  (Since 1 liter = 1,000 cm³, this tank holds 30 liters.)\n\n' ||
    E'Worked Example 7 (Cube — toy block):\n' ||
    E'  A wooden toy block is a cube with a side length of 15 cm. Find its volume.\n' ||
    E'  V = s³\n' ||
    E'  V = 15³\n' ||
    E'  V = 15 x 15 x 15\n' ||
    E'  V = 225 x 15\n' ||
    E'  V = 3,375 cm³\n\n' ||
    E'Other places you will see volume: storage containers, classrooms, swimming pools, water tanks, packages, and building materials.'
  ),
  (
    v_lesson5_id, 10, 'explanation', 'Problem-Solving Strategy',
    E'Follow these steps for ANY volume problem:\n' ||
    E'  1. Identify what is being asked.\n' ||
    E'  2. Identify the dimensions given.\n' ||
    E'  3. Choose the correct formula (V = l x w x h, or V = s³ if all sides are equal).\n' ||
    E'  4. Substitute the values.\n' ||
    E'  5. Calculate step by step.\n' ||
    E'  6. Write the correct cubic unit.\n' ||
    E'  7. Check if the answer is reasonable — a small box should not have a volume in the millions!'
  ),
  (
    v_lesson5_id, 11, 'summary', 'Remember',
    E'  - Volume measures the space inside a three-dimensional object.\n' ||
    E'  - Volume is always measured in cubic units (cm³, m³, in³).\n' ||
    E'  - The volume of a rectangular prism is V = l x w x h.\n' ||
    E'  - The volume of a cube is V = s³, since a cube has equal length, width, and height.\n' ||
    E'  - To find a missing dimension, divide the volume by the product of the two known dimensions.\n' ||
    E'  - Always choose the correct formula first, then substitute and calculate.\n' ||
    E'  - Check whether your final answer is reasonable.'
  );

  -- ===========================================================================
  -- Quiz 5 — built-in Internal Quiz for Lesson 5
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 5: Volume of Cubes and Rectangular Prisms',
    'internal', 'built_in', null, 'grade_6', true, true
  )
  returning id into v_quiz5_id;

  -- --- Q1 (concept) ---------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Volume of Cubes and Rectangular Prisms',
    'What does volume measure?',
    'Volume measures the amount of space inside a three-dimensional object. This is different from length (one dimension) and area (the flat surface a shape covers).'
  )
  returning id into v_q5_1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5_1, 'The amount of space inside a 3D object', true,  1),
    (v_q5_1, 'The distance around the outside of a shape', false, 2),
    (v_q5_1, 'The flat space a shape covers', false, 3),
    (v_q5_1, 'The distance from one end of an object to the other', false, 4);

  -- --- Q2 (units) -------------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Volume of Cubes and Rectangular Prisms',
    'Which unit is correct for measuring the volume of a box?',
    'Volume is measured in cubic units, such as cm³, because it fills three dimensions (length, width, and height). cm is a length unit and cm² is an area unit — neither measures volume.'
  )
  returning id into v_q5_2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5_2, 'cm³', true,  1),
    (v_q5_2, 'cm²', false, 2),
    (v_q5_2, 'cm', false, 3),
    (v_q5_2, 'kg', false, 4);

  -- --- Q3 (identify formula — rectangular prism) -----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Volume of Cubes and Rectangular Prisms',
    'Which formula correctly finds the volume of a rectangular prism?',
    'The volume of a rectangular prism is found by multiplying its three dimensions: V = l x w x h. Multiplying only two dimensions gives area, and adding the dimensions does not give volume at all.'
  )
  returning id into v_q5_3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5_3, 'V = l x w x h', true,  1),
    (v_q5_3, 'V = l x w', false, 2),
    (v_q5_3, 'V = 2(l + w + h)', false, 3),
    (v_q5_3, 'V = l + w + h', false, 4);

  -- --- Q4 (identify formula — cube) -------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Volume of Cubes and Rectangular Prisms',
    'Which formula correctly finds the volume of a cube?',
    'A cube has equal length, width, and height (s), so its volume formula is V = s³ (s x s x s). Squaring s gives area, not volume, and multiplying s by 3 or 4 does not represent multiplying the side length by itself three times.'
  )
  returning id into v_q5_4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5_4, 'V = s³', true,  1),
    (v_q5_4, 'V = s²', false, 2),
    (v_q5_4, 'V = s x 3', false, 3),
    (v_q5_4, 'V = 4s', false, 4);

  -- --- Q5 (computation — rectangular prism) ------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Volume of Cubes and Rectangular Prisms',
    'A rectangular prism has a length of 6 cm, a width of 4 cm, and a height of 5 cm. What is its volume?',
    'V = l x w x h = 6 x 4 x 5 = 120 cm³. All three dimensions must be multiplied together — multiplying only two of them gives an area, not a volume.'
  )
  returning id into v_q5_5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5_5, '120 cm³', true,  1),
    (v_q5_5, '24 cm³', false, 2),
    (v_q5_5, '20 cm³', false, 3),
    (v_q5_5, '15 cm³', false, 4);

  -- --- Q6 (computation — cube) --------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Volume of Cubes and Rectangular Prisms',
    'A cube has a side length of 4 cm. What is its volume?',
    'V = s³ = 4 x 4 x 4 = 64 cm³. Remember to multiply the side length by itself three times (cube it), not square it or multiply it by 3.'
  )
  returning id into v_q5_6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5_6, '64 cm³', true,  1),
    (v_q5_6, '16 cm³', false, 2),
    (v_q5_6, '12 cm³', false, 3),
    (v_q5_6, '48 cm³', false, 4);

  -- --- Q7 (word problem — rectangular prism) ------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Volume of Cubes and Rectangular Prisms',
    'A rectangular fish tank is 50 cm long, 20 cm wide, and 30 cm tall. How much water can it hold?',
    'V = l x w x h = 50 x 20 x 30 = 1,000 x 30 = 30,000 cm³. All three dimensions must be multiplied together, and the answer must be written in cubic units.'
  )
  returning id into v_q5_7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5_7, '30,000 cm³', true,  1),
    (v_q5_7, '1,000 cm³', false, 2),
    (v_q5_7, '100 cm³', false, 3),
    (v_q5_7, '3,000 cm³', false, 4);

  -- --- Q8 (word problem — cube) ---------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Volume of Cubes and Rectangular Prisms',
    'A storage box shaped like a cube has a side length of 10 cm. What is its volume?',
    'V = s³ = 10 x 10 x 10 = 1,000 cm³. Since all sides of a cube are equal, the side length must be multiplied by itself three times.'
  )
  returning id into v_q5_8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5_8, '1,000 cm³', true,  1),
    (v_q5_8, '100 cm³', false, 2),
    (v_q5_8, '30 cm³', false, 3),
    (v_q5_8, '300 cm³', false, 4);

  -- --- Q9 (missing dimension) -------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Volume of Cubes and Rectangular Prisms',
    'A rectangular prism has a volume of 192 cm³, a length of 8 cm, and a width of 6 cm. What is its height?',
    'V = l x w x h, so h = V / (l x w) = 192 / (8 x 6) = 192 / 48 = 4 cm. Dividing by only one of the two known dimensions (instead of their product) gives an incorrect height.'
  )
  returning id into v_q5_9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5_9, '4 cm', true,  1),
    (v_q5_9, '24 cm', false, 2),
    (v_q5_9, '32 cm', false, 3),
    (v_q5_9, '6 cm', false, 4);

  -- --- Q10 (concept — length vs. area vs. volume) ------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Volume of Cubes and Rectangular Prisms',
    'Which measurement tells you how much space is inside a box, not just how big its surface is?',
    'Volume tells us how much space is inside a 3D object, measured in cubic units. Area only measures a flat surface (square units), and perimeter and length only describe distances around or along a shape.'
  )
  returning id into v_q5_10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5_10, 'Volume', true,  1),
    (v_q5_10, 'Area', false, 2),
    (v_q5_10, 'Perimeter', false, 3),
    (v_q5_10, 'Length', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz5_id, v_q5_1,  1),
    (v_quiz5_id, v_q5_2,  2),
    (v_quiz5_id, v_q5_3,  3),
    (v_quiz5_id, v_q5_4,  4),
    (v_quiz5_id, v_q5_5,  5),
    (v_quiz5_id, v_q5_6,  6),
    (v_quiz5_id, v_q5_7,  7),
    (v_quiz5_id, v_q5_8,  8),
    (v_quiz5_id, v_q5_9,  9),
    (v_quiz5_id, v_q5_10, 10);

  -- ===========================================================================
  -- Link Lesson 5 -> Quiz 5 (0032), matching the pairing 0033 established
  -- for the Grade 4 lessons.
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz5_id where id = v_lesson5_id;

end $$;
