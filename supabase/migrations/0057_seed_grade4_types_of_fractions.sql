-- =============================================================================
-- Migration: 0057_seed_grade4_types_of_fractions.sql
-- Content-seeding migration, following the same pattern already used for
-- built-in Grade 4 content: 0027 (Lesson 1/2 + Quiz 1/2), 0055 (Lesson 3 +
-- Quiz 3), 0056 (Lesson 4 + Quiz 4). Like 0055/0056, this seeds the lesson
-- directly into paginated `lesson_pages` form (0028) and links it to its
-- quiz via `lessons.linked_quiz_id` (0032) in a single pass, since both
-- columns already exist as schema by this point in the migration history.
--
-- Seeds Grade 4 (MELC-level) built-in content:
--   Lesson 5 — Types of Fractions (10 pages)
--   Quiz 5   — Quiz 5: Types of Fractions (10 questions), linked to the
--              lesson via `lessons.linked_quiz_id`.
--
-- This is the fifth built-in Grade 4 lesson/quiz pair, following:
--   Lesson 1 / Quiz 1 — Addition and Subtraction of Numbers up to 1,000,000 (0027)
--   Lesson 2 / Quiz 2 — Comparing Numbers up to 1,000,000 (0027)
--   Lesson 3 / Quiz 3 — Place Value of Whole Numbers (0055)
--   Lesson 4 / Quiz 4 — Multiplication, Division, and MDAS (0056)
-- "Quiz 5" continues that same numbering. Numbered 0057 as the next free
-- migration number after the requester's actual latest migration (0054)
-- plus the two migrations already generated in this same session (0055,
-- 0056) — not blindly assumed from the trimmed reference ZIP alone, which
-- only went up to 0043.
--
-- Scope deliberately limited to fraction TYPES only (proper, improper,
-- mixed number) and how to identify them — no addition/subtraction/
-- multiplication/division of fractions, no simplifying, no LCD, no
-- fraction-to-fraction conversion beyond what's needed to describe a
-- mixed number's two parts. This matches the lesson brief's explicit
-- scope limit and keeps the lesson focused the same way each prior
-- Grade 4 lesson stayed scoped to exactly one skill.
--
-- All ids are database-generated (gen_random_uuid()) and captured via
-- `returning ... into`, never hardcoded — same approach as 0027/0055/0056.
--
-- Each question's 4 choices are inserted in a single statement, so the
-- deferred `enforce_at_least_one_correct` constraint trigger (0014) never
-- observes a question with zero correct choices mid-transaction — same
-- approach as 0027/0055/0056.
--
-- CLASSIFICATIONS VERIFIED (every fraction below checked against the rule
-- numerator < denominator => proper; numerator >= denominator => improper,
-- including the numerator = denominator case, which equals exactly one
-- whole and is still improper by this rule) before writing any lesson page
-- or quiz question:
--   3/5   -> 3 < 5   -> proper    (lesson example)
--   2/7   -> 2 < 7   -> proper    (lesson example)
--   6/9   -> 6 < 9   -> proper    (lesson example)
--   7/4   -> 7 > 4   -> improper  (lesson example)
--   9/5   -> 9 > 5   -> improper  (lesson example)
--   6/6   -> 6 = 6   -> improper  (lesson example, equals one whole)
--   5/8   -> 5 < 8   -> proper    (quiz Q2 correct choice)
--   9/4   -> 9 > 4   -> improper  (quiz Q2 distractor)
--   7/3   -> 7 > 3   -> improper  (quiz Q2 distractor)
--   9/9   -> 9 = 9   -> improper  (quiz Q3 correct choice)
--   4/9   -> 4 < 9   -> proper    (quiz Q3 distractor / quiz Q5 correct choice)
--   11/6  -> 11 > 6  -> improper  (quiz Q4 correct choice)
--   7/10  -> 7 < 10  -> proper    (quiz Q8 correct choice)
--   8/8   -> 8 = 8   -> improper, equals exactly one whole (quiz Q9 correct choice)
--   3/8, 5/9, 6/11    -> all proper, each less than one whole (quiz Q9 distractors)
-- =============================================================================

do $$
declare
  v_lesson_id uuid;
  v_quiz_id   uuid;

  v_q1  uuid; v_q2  uuid; v_q3  uuid; v_q4  uuid; v_q5  uuid;
  v_q6  uuid; v_q7  uuid; v_q8  uuid; v_q9  uuid; v_q10 uuid;
begin

  -- ===========================================================================
  -- Quiz — created first so its id is available for the lesson's
  -- linked_quiz_id (0032) without a separate follow-up update step.
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 5: Types of Fractions',
    'internal', 'built_in', null, 'grade_4', true, true
  )
  returning id into v_quiz_id;

  -- ===========================================================================
  -- Lesson 5 — Types of Fractions
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level, linked_quiz_id)
  values (
    'Types of Fractions',
    'Learn to recognize and distinguish proper fractions, improper fractions, and mixed numbers by comparing their numerator and denominator.',
    'built_in',
    null,
    'grade_4',
    v_quiz_id
  )
  returning id into v_lesson_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn about different types of fractions - proper fractions, improper fractions, and mixed numbers - and how to identify each type.'
  ),
  (
    v_lesson_id, 2, 'vocabulary', 'Numerator and Denominator Review',
    E'A fraction has two parts.\n\n' ||
    E'The NUMERATOR is the top number. It tells how many parts we have.\n' ||
    E'The DENOMINATOR is the bottom number. It tells how many equal parts make a whole.\n\n' ||
    E'For example, in the fraction 3/5:\n' ||
    E'  3 is the numerator\n' ||
    E'  5 is the denominator'
  ),
  (
    v_lesson_id, 3, 'explanation', 'Proper Fractions',
    E'A PROPER FRACTION is a fraction where the numerator is LESS THAN the denominator.\n\n' ||
    E'This means a proper fraction is always less than one whole.\n\n' ||
    E'Example: 3/5\n' ||
    E'Since 3 is less than 5, 3/5 is a proper fraction.'
  ),
  (
    v_lesson_id, 4, 'examples', 'Proper Fraction Examples',
    E'Worked Example 1:\n' ||
    E'  Is 2/7 a proper fraction?\n' ||
    E'  The numerator is 2 and the denominator is 7. Since 2 is less than 7, 2/7 is a proper fraction.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  Is 6/9 a proper fraction?\n' ||
    E'  The numerator is 6 and the denominator is 9. Since 6 is less than 9, 6/9 is a proper fraction.'
  ),
  (
    v_lesson_id, 5, 'explanation', 'Improper Fractions',
    E'An IMPROPER FRACTION is a fraction where the numerator is EQUAL TO or GREATER THAN the denominator.\n\n' ||
    E'This means an improper fraction is equal to or greater than one whole.\n\n' ||
    E'Example: 7/4\n' ||
    E'Since 7 is greater than 4, 7/4 is an improper fraction.'
  ),
  (
    v_lesson_id, 6, 'examples', 'Improper Fraction Examples',
    E'Worked Example 3:\n' ||
    E'  Is 9/5 an improper fraction?\n' ||
    E'  The numerator is 9 and the denominator is 5. Since 9 is greater than 5, 9/5 is an improper fraction.\n\n' ||
    E'Worked Example 4:\n' ||
    E'  Is 6/6 an improper fraction?\n' ||
    E'  The numerator is 6 and the denominator is 6. Since 6 is equal to 6, 6/6 is an improper fraction - it is exactly equal to one whole.'
  ),
  (
    v_lesson_id, 7, 'explanation', 'Mixed Numbers',
    E'A MIXED NUMBER is made up of a whole number and a proper fraction written together.\n\n' ||
    E'Example: 1 3/4\n' ||
    E'This means 1 whole plus 3/4 of another whole.\n\n' ||
    E'Mixed numbers are another way to write amounts that are more than one whole.'
  ),
  (
    v_lesson_id, 8, 'examples', 'Mixed Number Examples',
    E'Worked Example 5:\n' ||
    E'  What is 2 1/3 made of?\n' ||
    E'  It is made of the whole number 2 and the proper fraction 1/3. This means 2 wholes plus 1/3 of another whole.\n\n' ||
    E'Worked Example 6:\n' ||
    E'  Is 3 2/5 a mixed number?\n' ||
    E'  Yes. It has the whole number 3 and the proper fraction 2/5 written together.'
  ),
  (
    v_lesson_id, 9, 'explanation', 'Comparing and Identifying Fraction Types',
    E'To identify the type of fraction, compare the numerator and denominator:\n\n' ||
    E'  If the numerator is LESS THAN the denominator -> PROPER FRACTION\n' ||
    E'  If the numerator is EQUAL TO or GREATER THAN the denominator -> IMPROPER FRACTION\n' ||
    E'  If there is a whole number written together with a proper fraction -> MIXED NUMBER\n\n' ||
    E'Example: Compare 4/9, 9/4, and 2 1/4.\n' ||
    E'  4/9 - numerator less than denominator -> proper fraction\n' ||
    E'  9/4 - numerator greater than denominator -> improper fraction\n' ||
    E'  2 1/4 - a whole number with a proper fraction -> mixed number'
  ),
  (
    v_lesson_id, 10, 'summary', 'Remember',
    E'  - The numerator is the top number; the denominator is the bottom number.\n' ||
    E'  - A proper fraction has a numerator less than its denominator (for example, 3/5).\n' ||
    E'  - An improper fraction has a numerator equal to or greater than its denominator (for example, 7/4).\n' ||
    E'  - A mixed number is a whole number written together with a proper fraction (for example, 1 3/4).\n' ||
    E'  - Compare the numerator and denominator to identify the type of fraction.'
  );

  -- ===========================================================================
  -- Quiz 5 questions — Types of Fractions
  -- New fractions throughout (not reused from the lesson pages above), so
  -- the student has to apply the classification rules independently.
  -- ===========================================================================

  -- --- Q1 (identify numerator/denominator) ----------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Types of Fractions',
    'In the fraction 5/8, what is the denominator?',
    'The denominator is the bottom number of a fraction. In 5/8, the bottom number is 8.'
  )
  returning id into v_q1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1, '8',  true,  1),
    (v_q1, '5',  false, 2),
    (v_q1, '3',  false, 3),
    (v_q1, '13', false, 4);

  -- --- Q2 (identify a proper fraction from a set) ---------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Types of Fractions',
    'Which of the following is a proper fraction?',
    '5/8 is the only proper fraction here, since its numerator (5) is less than its denominator (8). 9/4, 6/6, and 7/3 all have a numerator equal to or greater than the denominator, so they are improper fractions.'
  )
  returning id into v_q2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2, '5/8', true,  1),
    (v_q2, '9/4', false, 2),
    (v_q2, '6/6', false, 3),
    (v_q2, '7/3', false, 4);

  -- --- Q3 (identify an improper fraction from a set) -------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Types of Fractions',
    'Which of the following is an improper fraction?',
    '9/9 is the only improper fraction here, since its numerator is equal to its denominator. 3/5, 2/7, and 4/9 all have a numerator less than the denominator, so they are proper fractions.'
  )
  returning id into v_q3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q3, '9/9', true,  1),
    (v_q3, '3/5', false, 2),
    (v_q3, '2/7', false, 3),
    (v_q3, '4/9', false, 4);

  -- --- Q4 (classify a given fraction, improper) -------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Types of Fractions',
    'What type of fraction is 11/6?',
    'The numerator (11) is greater than the denominator (6), so 11/6 is an improper fraction.'
  )
  returning id into v_q4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q4, 'Improper fraction', true,  1),
    (v_q4, 'Proper fraction',   false, 2),
    (v_q4, 'Mixed number',      false, 3),
    (v_q4, 'Whole number',      false, 4);

  -- --- Q5 (classify a given fraction, proper) ---------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Types of Fractions',
    'What type of fraction is 4/9?',
    'The numerator (4) is less than the denominator (9), so 4/9 is a proper fraction.'
  )
  returning id into v_q5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5, 'Proper fraction',   true,  1),
    (v_q5, 'Improper fraction', false, 2),
    (v_q5, 'Mixed number',      false, 3),
    (v_q5, 'Whole number',      false, 4);

  -- --- Q6 (identify a mixed number from a set) ---------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Types of Fractions',
    'Which of the following is a mixed number?',
    '2 3/5 is a mixed number because it is a whole number (2) written together with a proper fraction (3/5). 9/5, 3/9, and 8/8 are all single fractions, not a whole number combined with a fraction.'
  )
  returning id into v_q6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6, '2 3/5', true,  1),
    (v_q6, '9/5',   false, 2),
    (v_q6, '3/9',   false, 3),
    (v_q6, '8/8',   false, 4);

  -- --- Q7 (rule-based classification, conceptual) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Types of Fractions',
    'If the numerator of a fraction is greater than its denominator, what type of fraction is it?',
    'A fraction whose numerator is greater than (or equal to) its denominator is an improper fraction, because it represents an amount equal to or greater than one whole.'
  )
  returning id into v_q7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q7, 'Improper fraction', true,  1),
    (v_q7, 'Proper fraction',   false, 2),
    (v_q7, 'Mixed number',      false, 3),
    (v_q7, 'Whole number',      false, 4);

  -- --- Q8 (classify from numerator/denominator values given as numbers) -----------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Types of Fractions',
    'A fraction has a numerator of 7 and a denominator of 10. What type of fraction is it?',
    'Since the numerator (7) is less than the denominator (10), this fraction, 7/10, is a proper fraction.'
  )
  returning id into v_q8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q8, 'Proper fraction',      true,  1),
    (v_q8, 'Improper fraction',    false, 2),
    (v_q8, 'Mixed number',         false, 3),
    (v_q8, 'Cannot be determined', false, 4);

  -- --- Q9 (equal-to-one-whole edge case) -------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Types of Fractions',
    'Which of these fractions is equal to exactly one whole?',
    '8/8 has a numerator equal to its denominator, so it equals exactly one whole. This makes it an improper fraction. 3/8, 5/9, and 6/11 all have a numerator less than their denominator, so each represents less than one whole.'
  )
  returning id into v_q9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9, '8/8',  true,  1),
    (v_q9, '3/8',  false, 2),
    (v_q9, '5/9',  false, 3),
    (v_q9, '6/11', false, 4);

  -- --- Q10 (simple application / classification) ------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Types of Fractions',
    'Ana ate 1 whole pizza and 2/5 of another pizza. What type of number is this amount when written as "1 2/5"?',
    '"1 2/5" is a whole number (1) written together with a proper fraction (2/5), so it is a mixed number.'
  )
  returning id into v_q10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10, 'Mixed number',      true,  1),
    (v_q10, 'Proper fraction',   false, 2),
    (v_q10, 'Improper fraction', false, 3),
    (v_q10, 'Whole number',      false, 4);

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

end $$;
