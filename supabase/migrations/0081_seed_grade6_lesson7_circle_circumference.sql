-- =============================================================================
-- Migration: 0081_seed_grade6_lesson7_circle_circumference.sql
--
-- Content-only seed. No schema changes — reuses the existing
-- lessons / lesson_pages / quizzes / question_bank / question_choices /
-- quiz_questions architecture exactly as-is (0007-0009, 0026, 0028, 0032,
-- 0043), the same way 0027/0029/0032-0033 combined a lesson, its pages,
-- its quiz, and the lesson<->quiz link into one topic's worth of content.
--
-- Adds Grade 6:
--   Lesson 7 — Parts and Circumference of a Circle (9 pages)
--   Quiz 7   — Internal Quiz for Lesson 7 (10 questions)
--
-- Numbering note: neither `lessons` nor `quizzes` has a sequence-number
-- column — LessonsRepository.fetchVisibleToTeacher() and
-- QuizzesRepository.fetchVisibleToTeacher() both `.order('title')`
-- (confirmed by reading both repositories before writing this). The
-- existing Grade 6 Lessons 1-6 are titled as plain topic names (no
-- "Lesson N:" prefix), matching the Grade 4 precedent in 0027
-- ('Addition and Subtraction of Numbers up to 1,000,000', not 'Lesson 1:
-- ...'). This migration follows that same convention for the lesson
-- title. Quizzes DO carry an explicit "Quiz N: " title prefix in the
-- existing convention (0027: 'Quiz 1: Addition and Subtraction ...',
-- 'Quiz 2: Comparing Numbers ...') — followed here as 'Quiz 7: Parts and
-- Circumference of a Circle' so it continues to sort correctly among
-- Quiz 1-6 and is unambiguous in list views.
--
-- `worked_example` (0030/0031) is intentionally NOT used on any page
-- below — its jsonb shape is fixed to a 6-digit place-value
-- addition/subtraction POC (confirmed by re-reading 0030's column
-- comment and lib/core/models/worked_example.dart before writing this)
-- and does not generalize to circle geometry. Every page here uses plain
-- `body` text, exactly like every non-POC page already does.
--
-- source_type = 'built_in', created_by = null, grade_level = 'grade_6'
-- on both the lesson and the quiz, matching `lessons_source_created_by_
-- pairing` / `quizzes_source_created_by_pairing` (0007/0009) and
-- `lessons_built_in_requires_grade` / `quizzes_built_in_requires_grade`
-- (0026). question_bank has no grade_level column (per 0026, confirmed
-- by re-reading 0008) — its `topic` is set to the lesson's title, same
-- convention 0027 used for the Highest/Lowest Performing Topics
-- dashboard metric.
--
-- All ids are database-generated and captured via `returning ... into`,
-- never hardcoded — same approach as 0027/0029/0033. Each question's 4
-- choices are inserted in the same statement as the question, so the
-- deferred `enforce_at_least_one_correct` trigger (0014) never observes
-- a zero-correct-choice question mid-transaction.
--
-- MATHEMATICAL VALIDATION: every numeric answer and distractor below was
-- independently computed and checked (see chat) using pi = 3.14:
--   r=9  -> d=18       (2*9)
--   d=22 -> r=11        (22/2)
--   r=5  -> C=31.4 cm   (2*3.14*5)
--   r=12 -> C=75.36 in  (2*3.14*12)
--   d=10 -> C=31.4 cm/m (3.14*10)
--   d=25 -> C=78.5 m    (3.14*25)
--   r=7.5 -> C=47.1 cm  (2*3.14*7.5)
--   d=26 -> C=81.64 in  (3.14*26)      [bicycle wheel]
--   r=45 -> C=282.6 cm  (2*3.14*45)    [round table]
--   d=8  -> C=25.12 m   (3.14*8)       [garden]
--   r=30 -> C=188.4 m   (2*3.14*30)    [track]
-- Every quiz-question distractor was verified to be produced by the
-- specific mistake named in its explanation (or left as a plain
-- arithmetic slip where no specific mechanism is claimed). No two
-- choices on any question are mathematically equivalent.
--
-- AUDIT FIX (post-review, before first apply): every string literal
-- containing \u03c0 / \u00b2 / \u2248 / \pi must be an E'...' escape
-- string, or Postgres stores the literal backslash sequence instead of
-- the actual character. The original draft had these as plain '...'
-- strings in lessons.body, one lesson_pages.title, and every Q5-Q10
-- question_bank/question_choices row -- fixed here by adding the E
-- prefix throughout. Also removed a redundant second `update` on
-- lessons.body that re-set it (with the same plain-string bug) right
-- after the initial insert; the correct E'...' text is now set once,
-- in the initial insert.
-- =============================================================================

do $$
declare
  v_lesson7_id uuid;
  v_quiz7_id   uuid;

  v_q1  uuid; v_q2  uuid; v_q3  uuid; v_q4  uuid; v_q5  uuid;
  v_q6  uuid; v_q7  uuid; v_q8  uuid; v_q9  uuid; v_q10 uuid;
begin

  -- ===========================================================================
  -- Lesson 7 — Parts and Circumference of a Circle
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Parts and Circumference of a Circle',
    E'Learn to identify the parts of a circle -- center, radius, and diameter -- and calculate circumference using C = 2\u03c0r and C = \u03c0d.',
    'built_in',
    null,
    'grade_6'
  )
  returning id into v_lesson7_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson7_id, 1, 'introduction', 'Introduction',
    E'A circle is a round, flat shape where every point on its edge is the same distance from one fixed point in the middle. In this lesson, we will learn the important parts of a circle -- the center, radius, and diameter -- and then learn how to calculate a circle''s circumference, the distance around it.'
  ),
  (
    v_lesson7_id, 2, 'vocabulary', 'Parts of a Circle',
    E'CENTER\n' ||
    E'The center is the point exactly in the middle of the circle. Every point on the circle is the same distance from the center.\n\n' ||
    E'RADIUS\n' ||
    E'The radius is the distance from the center of the circle to any point on the circle.\n\n' ||
    E'DIAMETER\n' ||
    E'The diameter is a line segment that passes through the center and connects two points on the circle.\n\n' ||
    E'CIRCUMFERENCE\n' ||
    E'The circumference is the distance around the circle.\n\n' ||
    E'CHORD (good to know)\n' ||
    E'A chord is any line segment that connects two points on the circle. A diameter is actually a special chord -- one that passes through the center.'
  ),
  (
    v_lesson7_id, 3, 'explanation', 'Radius and Diameter Relationship',
    E'The radius and diameter of a circle are directly related:\n' ||
    E'  Diameter = 2 x radius, or  d = 2r\n' ||
    E'  Radius = diameter divided by 2, or  r = d divided by 2\n\n' ||
    E'In other words, the diameter is always twice as long as the radius, and the radius is always half as long as the diameter.\n\n' ||
    E'Example 1: If a circle has a radius of 6 cm, its diameter is\n' ||
    E'  d = 2 x 6 = 12 cm.\n\n' ||
    E'Example 2: If a circle has a diameter of 20 cm, its radius is\n' ||
    E'  r = 20 divided by 2 = 10 cm.'
  ),
  (
    v_lesson7_id, 4, 'explanation', E'Circumference and Pi (\u03c0)',
    E'Circumference is essentially the perimeter of a circle -- just like the perimeter of a square or rectangle, it is the total distance around the outside of the shape.\n\n' ||
    E'To calculate circumference, we use a special number called pi, written with the symbol \u03c0. Pi is the same for every circle, no matter how big or small: it is approximately\n' ||
    E'  \u03c0 \u2248 3.14\n\n' ||
    E'We will use \u03c0 \u2248 3.14 for every calculation in this lesson.'
  ),
  (
    v_lesson7_id, 5, 'explanation', 'Choosing the Circumference Formula',
    E'There are two formulas for circumference, and which one you use depends on whether you are given the radius or the diameter:\n\n' ||
    E'  If you know the RADIUS, use:   C = 2\u03c0r\n' ||
    E'  If you know the DIAMETER, use:  C = \u03c0d\n\n' ||
    E'These two formulas always give the same answer for the same circle, because the diameter is always twice the radius (d = 2r) -- so 2\u03c0r and \u03c0d are just two ways of writing the same calculation.\n\n' ||
    E'Before solving any circumference problem, always check: am I given a radius or a diameter? Using the wrong one in the wrong formula is one of the most common mistakes.\n\n' ||
    E'Circumference is a LENGTH, so it always uses linear units (cm, m, in, ft) -- never square units like cm\u00b2 or m\u00b2. Square units are for area, which we covered in the last lesson.'
  ),
  (
    v_lesson7_id, 6, 'examples', 'Circumference Examples Using Radius',
    E'When the radius is given, use C = 2\u03c0r.\n\n' ||
    E'Worked Example 1 (basic):\n' ||
    E'  A circle has a radius of 5 cm. Find its circumference.\n' ||
    E'  C = 2\u03c0r\n' ||
    E'  C = 2 x 3.14 x 5\n' ||
    E'  C = 31.4 cm\n\n' ||
    E'Worked Example 2 (moderate):\n' ||
    E'  A circle has a radius of 12 in. Find its circumference.\n' ||
    E'  C = 2\u03c0r\n' ||
    E'  C = 2 x 3.14 x 12\n' ||
    E'  C = 75.36 in'
  ),
  (
    v_lesson7_id, 7, 'examples', 'Circumference Examples Using Diameter',
    E'When the diameter is given, use C = \u03c0d. Be careful not to use the diameter as if it were the radius!\n\n' ||
    E'Worked Example 3 (basic):\n' ||
    E'  A circle has a diameter of 10 cm. Find its circumference.\n' ||
    E'  C = \u03c0d\n' ||
    E'  C = 3.14 x 10\n' ||
    E'  C = 31.4 cm\n\n' ||
    E'Worked Example 4 (moderate):\n' ||
    E'  A circle has a diameter of 25 m. Find its circumference.\n' ||
    E'  C = \u03c0d\n' ||
    E'  C = 3.14 x 25\n' ||
    E'  C = 78.5 m\n\n' ||
    E'Worked Example 5 (challenging -- decimal radius):\n' ||
    E'  A circle has a radius of 7.5 cm. Find its circumference.\n' ||
    E'  C = 2\u03c0r\n' ||
    E'  C = 2 x 3.14 x 7.5\n' ||
    E'  C = 47.1 cm'
  ),
  (
    v_lesson7_id, 8, 'examples', 'Real-World Applications',
    E'Circumference shows up any time we measure around something round.\n\n' ||
    E'Worked Example 6 (bicycle wheel):\n' ||
    E'  A bicycle wheel has a diameter of 26 in. What is the circumference of the wheel (the distance it travels in one full turn)?\n' ||
    E'  Given: diameter, so use C = \u03c0d.\n' ||
    E'  C = 3.14 x 26 = 81.64 in\n\n' ||
    E'Worked Example 7 (round table):\n' ||
    E'  A round table has a radius of 45 cm. What is the circumference of the table?\n' ||
    E'  Given: radius, so use C = 2\u03c0r.\n' ||
    E'  C = 2 x 3.14 x 45 = 282.6 cm\n\n' ||
    E'Worked Example 8 (circular garden):\n' ||
    E'  A circular garden has a diameter of 8 m. How much fencing is needed to go all the way around it?\n' ||
    E'  Given: diameter, so use C = \u03c0d.\n' ||
    E'  C = 3.14 x 8 = 25.12 m\n\n' ||
    E'Worked Example 9 (running track):\n' ||
    E'  A circular running track has a radius of 30 m. How far does a runner travel in one lap?\n' ||
    E'  Given: radius, so use C = 2\u03c0r.\n' ||
    E'  C = 2 x 3.14 x 30 = 188.4 m'
  ),
  (
    v_lesson7_id, 9, 'summary', 'Remember',
    E'  - The center is the point exactly in the middle of a circle.\n' ||
    E'  - The radius is the distance from the center to any point on the circle.\n' ||
    E'  - The diameter passes through the center and connects two points on the circle.\n' ||
    E'  - The diameter is twice the radius: d = 2r. The radius is half the diameter: r = d divided by 2.\n' ||
    E'  - Circumference is the distance around a circle -- like a perimeter, but for circles.\n' ||
    E'  - Use C = 2\u03c0r when the radius is given.\n' ||
    E'  - Use C = \u03c0d when the diameter is given.\n' ||
    E'  - \u03c0 (pi) is approximately 3.14 for our calculations.\n' ||
    E'  - Circumference uses linear units (cm, m, in, ft) -- never square units.\n' ||
    E'  - Always check first: is this measurement a radius or a diameter?'
  );

  -- ===========================================================================
  -- Quiz 7 — built-in Internal Quiz for Lesson 7
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 7: Parts and Circumference of a Circle',
    'internal', 'built_in', null, 'grade_6', true, true
  )
  returning id into v_quiz7_id;

  -- --- Q1 (concept: center) -------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Parts and Circumference of a Circle',
    'Which part of a circle is the point that is exactly the same distance from every point on the circle?',
    'The center is the point in the middle of a circle. Every point on the circle is the same distance from the center.'
  )
  returning id into v_q1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1, 'Center', true,  1),
    (v_q1, 'Radius', false, 2),
    (v_q1, 'Diameter', false, 3),
    (v_q1, 'Circumference', false, 4);

  -- --- Q2 (concept: diameter vs radius vs chord) ----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Parts and Circumference of a Circle',
    'Which term describes a line segment that passes through the center of a circle and connects two points on the circle?',
    'The diameter is a line segment that passes through the center and connects two points on the circle. The radius only goes from the center to the edge, and a chord connects two points on the circle without needing to pass through the center.'
  )
  returning id into v_q2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2, 'Diameter', true,  1),
    (v_q2, 'Radius', false, 2),
    (v_q2, 'Chord', false, 3),
    (v_q2, 'Circumference', false, 4);

  -- --- Q3 (radius -> diameter) -----------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Parts and Circumference of a Circle',
    'The radius of a circle is 9 cm. What is its diameter?',
    'Diameter = 2 x radius. 2 x 9 = 18. So the diameter is 18 cm.'
  )
  returning id into v_q3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q3, '18 cm', true,  1),
    (v_q3, '4.5 cm', false, 2),
    (v_q3, '9 cm', false, 3),
    (v_q3, '27 cm', false, 4);

  -- --- Q4 (diameter -> radius) -----------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Parts and Circumference of a Circle',
    'The diameter of a circle is 22 m. What is its radius?',
    'Radius = diameter divided by 2. 22 divided by 2 = 11. So the radius is 11 m.'
  )
  returning id into v_q4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q4, '11 m', true,  1),
    (v_q4, '44 m', false, 2),
    (v_q4, '22 m', false, 3),
    (v_q4, '12 m', false, 4);

  -- --- Q5 (formula identification, radius given) ------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Parts and Circumference of a Circle',
    'A circle''s radius is known. Which formula should be used to find its circumference?',
    E'When the radius is known, use C = 2\u03c0r. The formula C = \u03c0d needs the diameter instead, and C = \u03c0r\u00b2 is the formula for area, not circumference.'
  )
  returning id into v_q5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5, E'C = 2\u03c0r', true,  1),
    (v_q5, E'C = \u03c0d', false, 2),
    (v_q5, E'C = \u03c0r\u00b2', false, 3),
    (v_q5, E'C = 2\u03c0d', false, 4);

  -- --- Q6 (direct calculation, radius) ---------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Parts and Circumference of a Circle',
    E'What is the circumference of a circle with a radius of 5 cm? Use \u03c0 \u2248 3.14.',
    E'C = 2\u03c0r = 2 x 3.14 x 5 = 31.4. The circumference is 31.4 cm.'
  )
  returning id into v_q6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6, '31.4 cm', true,  1),
    (v_q6, '15.7 cm', false, 2),
    (v_q6, '78.5 cm', false, 3),
    (v_q6, E'31.4 cm\u00b2', false, 4);

  -- --- Q7 (direct calculation, diameter) --------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Parts and Circumference of a Circle',
    E'What is the circumference of a circle with a diameter of 10 m? Use \u03c0 \u2248 3.14.',
    E'C = \u03c0d = 3.14 x 10 = 31.4. The circumference is 31.4 m.'
  )
  returning id into v_q7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q7, '31.4 m', true,  1),
    (v_q7, '62.8 m', false, 2),
    (v_q7, '15.7 m', false, 3),
    (v_q7, E'31.4 m\u00b2', false, 4);

  -- --- Q8 (word problem, choosing the correct expression) ---------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Parts and Circumference of a Circle',
    'A circular table has a radius of 20 cm. Which expression correctly calculates its circumference?',
    E'Since the radius is given, use C = 2\u03c0r, which is 2 x 3.14 x 20.'
  )
  returning id into v_q8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q8, '2 x 3.14 x 20', true,  1),
    (v_q8, '3.14 x 20', false, 2),
    (v_q8, E'3.14 x 20\u00b2', false, 3),
    (v_q8, '2 x 20', false, 4);

  -- --- Q9 (unit identification) -----------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Parts and Circumference of a Circle',
    'A circle''s radius is measured in meters. Which unit should be used to express its circumference?',
    E'Circumference is a measurement of length, so it uses the same linear unit as the radius: meters (m). Square units like m\u00b2 are used for area, not circumference.'
  )
  returning id into v_q9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9, 'm', true,  1),
    (v_q9, E'm\u00b2', false, 2),
    (v_q9, E'm\u00b3', false, 3),
    (v_q9, 'No unit is needed', false, 4);

  -- --- Q10 (real-world word problem) -------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Parts and Circumference of a Circle',
    E'A circular garden has a diameter of 8 m. What is the circumference of the garden? Use \u03c0 \u2248 3.14.',
    E'Since the diameter is given, use C = \u03c0d = 3.14 x 8 = 25.12. The circumference of the garden is 25.12 m.'
  )
  returning id into v_q10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10, '25.12 m', true,  1),
    (v_q10, '50.24 m', false, 2),
    (v_q10, '12.56 m', false, 3),
    (v_q10, E'25.12 m\u00b2', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz7_id, v_q1,  1),
    (v_quiz7_id, v_q2,  2),
    (v_quiz7_id, v_q3,  3),
    (v_quiz7_id, v_q4,  4),
    (v_quiz7_id, v_q5,  5),
    (v_quiz7_id, v_q6,  6),
    (v_quiz7_id, v_q7,  7),
    (v_quiz7_id, v_q8,  8),
    (v_quiz7_id, v_q9,  9),
    (v_quiz7_id, v_q10, 10);

  -- ===========================================================================
  -- Link Lesson 7 -> Quiz 7 (0032's linked_quiz_id convenience column,
  -- following the same lookup-by-title approach 0033 used)
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz7_id where id = v_lesson7_id;

end $$;
