-- =============================================================================
-- Migration: 0071_seed_grade5_prime_composite_numbers.sql
-- Content-seeding migration, following the same conventions established by
-- 0027 (Grade 4 seed) / 0029 (lesson_pages) / 0033 (lesson -> quiz link).
--
-- Seeds Grade 5 built-in content:
--   Lesson 7 — Prime and Composite Numbers (10 lesson_pages)
--   Quiz 7   — Internal Quiz for Lesson 7 (10 questions, 4 choices each)
--
-- Unlike 0027/0029/0033, this is a single migration rather than a
-- schema-then-content split, because every schema piece it needs
-- (lesson_pages from 0028/0030, lessons.linked_quiz_id from 0032) already
-- exists as of this project's current migration state (through 0070) — no
-- schema change is required here, only new rows.
--
-- All ids are database-generated (gen_random_uuid(), the default on every
-- affected table's id column) and captured via `returning ... into`, never
-- hardcoded. lessons/quizzes rows use source_type = 'built_in',
-- created_by = null, grade_level = 'grade_5', matching 0027's pattern.
-- question_bank.topic is tagged to match the owning lesson's title (matches
-- 0027's tagging), for the Highest/Lowest Performing Topics dashboard
-- metric (schema comment, 0008).
--
-- Each question's 4 choices are inserted in a single statement, so the
-- deferred `enforce_at_least_one_correct` constraint trigger (0014) never
-- observes a question with zero correct choices mid-transaction (matches
-- 0027's pattern).
--
-- Quiz numbers deliberately differ from the lesson's worked-example numbers
-- (per the one-to-one Lesson 7 <-> Quiz 7 pairing requested), so the quiz
-- tests understanding of the classification method rather than memorized
-- lesson examples. Every prime/composite classification below was
-- independently verified by listing and counting factors before writing
-- the question.
-- =============================================================================

do $$
declare
  v_lesson_id uuid;
  v_quiz_id   uuid;

  -- Quiz 7 — Prime and Composite Numbers
  v_q1  uuid; v_q2  uuid; v_q3  uuid; v_q4  uuid; v_q5  uuid;
  v_q6  uuid; v_q7  uuid; v_q8  uuid; v_q9  uuid; v_q10 uuid;
begin

  -- ===========================================================================
  -- Lesson 7 — Prime and Composite Numbers
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Prime and Composite Numbers',
    'Learn to identify prime numbers, composite numbers, and the special case of 1 by examining a number''s factors, with worked examples and common mistakes to avoid.',
    'built_in',
    null,
    'grade_5'
  )
  returning id into v_lesson_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn how to classify whole numbers as prime, composite, or neither by looking at their factors. This will help us understand the building blocks of numbers and how they can be grouped or arranged.'
  ),
  (
    v_lesson_id, 2, 'vocabulary', 'Review: What Are Factors?',
    E'Before we classify numbers, let''s review factors. A factor is a whole number that divides another number exactly, with nothing left over.\n\n' ||
    E'For example:\n' ||
    E'  2 x 6 = 12, so 2 and 6 are factors of 12.\n' ||
    E'  3 x 4 = 12, so 3 and 4 are also factors of 12.\n\n' ||
    E'The complete list of factors of 12 is: 1, 2, 3, 4, 6, and 12.'
  ),
  (
    v_lesson_id, 3, 'explanation', 'What Is a Prime Number?',
    E'A prime number is a whole number greater than 1 that has exactly two factors: 1 and itself.\n\n' ||
    E'This means a prime number cannot be divided evenly by any other whole number.\n\n' ||
    E'2 is the smallest prime number, and it is also the only even prime number. Every other even number is composite, because it can always be divided evenly by 2.'
  ),
  (
    v_lesson_id, 4, 'examples', 'Prime Number Examples',
    E'Worked Example 1:\n' ||
    E'  2 -> factors are 1 and 2. Exactly two factors, so 2 is prime.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  7 -> factors are 1 and 7. Exactly two factors, so 7 is prime.\n\n' ||
    E'Worked Example 3:\n' ||
    E'  11 -> factors are 1 and 11. Exactly two factors, so 11 is prime.\n\n' ||
    E'Other prime numbers include 3, 5, and 13.'
  ),
  (
    v_lesson_id, 5, 'explanation', 'What Is a Composite Number?',
    E'A composite number is a whole number greater than 1 that has more than two factors.\n\n' ||
    E'This means a composite number can be divided evenly by at least one whole number besides 1 and itself.'
  ),
  (
    v_lesson_id, 6, 'examples', 'Composite Number Examples',
    E'Worked Example 1:\n' ||
    E'  4 -> factors are 1, 2, and 4. More than two factors, so 4 is composite.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  9 -> factors are 1, 3, and 9. More than two factors, so 9 is composite.\n\n' ||
    E'Worked Example 3:\n' ||
    E'  12 -> factors are 1, 2, 3, 4, 6, and 12. More than two factors, so 12 is composite.\n\n' ||
    E'Other composite numbers include 6, 8, and 10.'
  ),
  (
    v_lesson_id, 7, 'explanation', 'The Special Case of 1',
    E'The number 1 is neither prime nor composite.\n\n' ||
    E'1 has only one factor: 1 itself.\n' ||
    E'  A prime number must have exactly two factors.\n' ||
    E'  A composite number must have more than two factors.\n\n' ||
    E'Since 1 has only one factor, it does not fit either definition.'
  ),
  (
    v_lesson_id, 8, 'examples', 'How to Classify a Number',
    E'To decide whether a number is prime, composite, or neither, follow these steps:\n' ||
    E'  1. Identify the number.\n' ||
    E'  2. List its factors.\n' ||
    E'  3. Count the factors.\n' ||
    E'  4. Exactly two factors -> the number is prime.\n' ||
    E'  5. More than two factors -> the number is composite.\n' ||
    E'  6. Only one factor (this only happens for 1) -> the number is neither prime nor composite.\n\n' ||
    E'Worked Example (prime):\n' ||
    E'  Classify 13.\n' ||
    E'  Factors of 13: 1, 13.\n' ||
    E'  There are exactly two factors, so 13 is prime.\n\n' ||
    E'Worked Example (composite):\n' ||
    E'  Classify 15.\n' ||
    E'  Factors of 15: 1, 3, 5, 15.\n' ||
    E'  There are more than two factors, so 15 is composite.'
  ),
  (
    v_lesson_id, 9, 'explanation', 'Common Mistakes to Avoid',
    E'Mistake 1: Thinking every odd number is prime.\n' ||
    E'  9 is odd, but its factors are 1, 3, and 9, so 9 is composite.\n\n' ||
    E'Mistake 2: Thinking every even number is composite.\n' ||
    E'  2 is even, but it is prime, because its only factors are 1 and 2.\n\n' ||
    E'Mistake 3: Thinking 1 is prime.\n' ||
    E'  1 has only one factor, so it is neither prime nor composite.\n\n' ||
    E'Mistake 4: Forgetting to list every factor.\n' ||
    E'  Always check all the numbers that divide evenly before deciding.\n\n' ||
    E'Always list and count the factors carefully before classifying a number.'
  ),
  (
    v_lesson_id, 10, 'summary', 'Remember',
    E'  - A factor is a whole number that divides another number exactly.\n' ||
    E'  - A prime number has exactly two factors: 1 and itself.\n' ||
    E'  - A composite number has more than two factors.\n' ||
    E'  - 1 is neither prime nor composite, because it has only one factor.\n' ||
    E'  - 2 is the only even prime number.\n' ||
    E'  - Always list and count the factors before classifying a number.'
  );

  -- ===========================================================================
  -- Quiz 7 — built-in Internal Quiz for Lesson 7
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 7: Prime and Composite Numbers',
    'internal', 'built_in', null, 'grade_5', true, true
  )
  returning id into v_quiz_id;

  -- --- Q1 (basic — identify a prime number) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Prime and Composite Numbers',
    'Which of the following numbers is prime?',
    'The factors of 17 are only 1 and 17, so 17 is prime. 15 (1, 3, 5, 15) and 21 (1, 3, 7, 21) both have more than two factors, so they are composite, and 1 is neither prime nor composite.'
  )
  returning id into v_q1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1, '15', false, 1),
    (v_q1, '17', true,  2),
    (v_q1, '21', false, 3),
    (v_q1, '1',  false, 4);

  -- --- Q2 (basic — identify a composite number) ----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Prime and Composite Numbers',
    'Which of the following numbers is composite?',
    'The factors of 18 are 1, 2, 3, 6, 9, and 18 — more than two factors, so 18 is composite. 19 and 23 each have only 1 and themselves as factors, so they are prime, and 1 is neither prime nor composite.'
  )
  returning id into v_q2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2, '19', false, 1),
    (v_q2, '23', false, 2),
    (v_q2, '18', true,  3),
    (v_q2, '1',  false, 4);

  -- --- Q3 (basic/intermediate — identify factors) --------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Prime and Composite Numbers',
    'What are all the factors of 20?',
    '20 can be divided evenly by 1, 2, 4, 5, 10, and 20 (1x20, 2x10, 4x5), so its complete list of factors is 1, 2, 4, 5, 10, and 20. The other choices each leave out at least one factor.'
  )
  returning id into v_q3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q3, '1, 2, 4, 5, 10, 20', true,  1),
    (v_q3, '1, 2, 5, 20',        false, 2),
    (v_q3, '1, 4, 5, 20',        false, 3),
    (v_q3, '2, 4, 5, 10',        false, 4);

  -- --- Q4 (intermediate — classify from factor count) ----------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Prime and Composite Numbers',
    'A whole number greater than 1 has exactly two factors: 1 and itself. What kind of number is it?',
    'A number with exactly two factors — 1 and itself — always fits the definition of a prime number.'
  )
  returning id into v_q4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q4, 'Prime',                      true,  1),
    (v_q4, 'Composite',                  false, 2),
    (v_q4, 'Neither prime nor composite', false, 3),
    (v_q4, 'Both prime and composite',    false, 4);

  -- --- Q5 (intermediate — classify from a given factor list) ---------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Prime and Composite Numbers',
    'The factors of 21 are 1, 3, 7, and 21. Is 21 prime or composite?',
    '21 has four factors (1, 3, 7, 21), which is more than two, so 21 is composite.'
  )
  returning id into v_q5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5, 'Prime',                     false, 1),
    (v_q5, 'Composite',                 true,  2),
    (v_q5, 'Neither',                   false, 3),
    (v_q5, 'Cannot be determined',      false, 4);

  -- --- Q6 (intermediate — the special case of 1) ---------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Prime and Composite Numbers',
    'Why is 1 neither prime nor composite?',
    'A prime number must have exactly two factors, and a composite number must have more than two factors. 1 has only one factor — itself — so it does not fit either definition.'
  )
  returning id into v_q6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6, 'Because 1 is too small',            false, 1),
    (v_q6, 'Because 1 has only one factor',     true,  2),
    (v_q6, 'Because 1 is an even number',       false, 3),
    (v_q6, 'Because 1 has three factors',       false, 4);

  -- --- Q7 (intermediate — even/odd vs. prime/composite misconception) ------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Prime and Composite Numbers',
    'Which statement about prime and composite numbers is true?',
    '2 is even, but its only factors are 1 and 2, so it is prime — it is the only even prime number. Not all odd numbers are prime (9 is odd and composite), not all even numbers are composite, and 1 is neither prime nor composite.'
  )
  returning id into v_q7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q7, 'All odd numbers are prime',                        false, 1),
    (v_q7, 'All even numbers are composite',                   false, 2),
    (v_q7, '2 is a prime number even though it is even',       true,  3),
    (v_q7, '1 is a prime number',                               false, 4);

  -- --- Q8 (intermediate — odd composite number) -----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Prime and Composite Numbers',
    '15 is an odd number. Is it prime or composite?',
    'Being odd does not automatically make a number prime. The factors of 15 are 1, 3, 5, and 15 — more than two factors — so 15 is composite.'
  )
  returning id into v_q8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q8, 'Prime, because it is odd',                                  false, 1),
    (v_q8, 'Composite, because its factors are 1, 3, 5, and 15',        true,  2),
    (v_q8, 'Neither, because it is odd',                                false, 3),
    (v_q8, 'Cannot be determined without more information',             false, 4);

  -- --- Q9 (application — grouping/arrangement, prime number) ---------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Prime and Composite Numbers',
    'A teacher has 23 pencils and wants to arrange them into more than one equal row, with more than one pencil per row. Can she do this?',
    '23 is prime — its only factors are 1 and 23. That means the only equal arrangement is 1 row of 23 (or 23 rows of 1), so there is no way to split 23 pencils into more than one equal row with more than one pencil per row.'
  )
  returning id into v_q9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9, 'Yes, because 23 has many factors',                                   false, 1),
    (v_q9, 'No, because 23 is a prime number and only has 1 and 23 as factors',  true,  2),
    (v_q9, 'Yes, because 23 is odd',                                             false, 3),
    (v_q9, 'No, because 23 is composite',                                        false, 4);

  -- --- Q10 (application — grouping/arrangement, composite number) ----------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Prime and Composite Numbers',
    'Jenna has 18 stickers and wants to arrange them into equal rows, with more than one sticker per row and more than one row. Is this possible?',
    '18 is composite — its factors include 2, 3, 6, and 9 besides 1 and 18. So Jenna could arrange the stickers into, for example, 2 rows of 9, 3 rows of 6, or 6 rows of 3.'
  )
  returning id into v_q10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10, 'No, because 18 is prime',                                          false, 1),
    (v_q10, 'Yes, because 18 is composite and has factors like 2, 3, 6, and 9', true,  2),
    (v_q10, 'No, because 18 has only two factors',                             false, 3),
    (v_q10, 'Yes, because 18 is odd',                                          false, 4);

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
  -- Lesson 7 -> Quiz 7 link (0032's linked_quiz_id, same pattern as 0033)
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz_id where id = v_lesson_id;

end $$;
