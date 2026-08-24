-- =============================================================================
-- Migration: 0084_seed_grade6_lesson10_lcm.sql
-- Content-seeding migration only — no schema changes (same pattern as
-- 0027/0029/0033: lessons + lesson_pages + quiz + question_bank/choices +
-- quiz_questions + linked_quiz_id, all via existing tables/columns).
--
-- Seeds Grade 6 built-in content:
--   Lesson 10 — Common Multiples and Least Common Multiple (LCM)
--   Quiz 10   — Internal Quiz for Lesson 10 (10 questions)
--
-- This MUST be Lesson 10 / Quiz 10 in the Grade 6 sequence (position 10,
-- immediately after Lesson 9 — Common Factors and Greatest Common Factor
-- (GCF)). No other Grade 6 lesson/quiz numbering is touched or created by
-- this migration.
--
-- Conventions followed (matching 0007/0008/0009/0028/0032, and the
-- concrete 0027/0029/0033 seed precedent):
--   - lessons/quizzes: source_type = 'built_in', created_by = null,
--     grade_level = 'grade_6'.
--   - question_bank has no grade_level column (per 0008/0026 design).
--   - question_bank.topic tagged to the owning lesson's title, for the
--     Highest/Lowest Performing Topics dashboard metric (0008 comment).
--   - lessons.body is shrunk to a short 1-2 sentence list-screen
--     description; full content lives in lesson_pages (0028), one row per
--     ordered slide — same restructuring 0029 already established.
--   - `worked_example` (0030) is intentionally left null on every page
--     here: that jsonb shape is fixed to a 6-column place-value
--     addition/subtraction panel (POC scope, per 0030's own column
--     comment) and does not generalize to a multiples/LCM listing — so
--     every worked example below is plain-text `body`, exactly like every
--     lesson_pages row outside 0031's two converted POC examples.
--   - Each question's 4 choices are inserted in a single statement, so
--     the deferred `enforce_at_least_one_correct` constraint trigger
--     (0014) never observes a question with zero correct choices
--     mid-transaction (same pattern 0027 used).
--   - linked_quiz_id (0032) is set from Lesson 10 to Quiz 10 as a pure UI
--     convenience shortcut — never a dependency in either direction
--     (0032's own comment).
--   - assessment_type (0043) is left null: Quiz 10 is an ordinary quiz,
--     not a Pre-Test/Post-Test.
--
-- MATHEMATICAL VALIDATION (every multiple/common-multiple/LCM claim below
-- independently re-verified before writing the SQL — see inline notes at
-- each worked example and quiz question for the specific check):
--   - Every listed "multiple of n" was checked to equal n times a whole
--     number.
--   - Every claimed "common multiple" was checked to be a multiple of
--     EVERY number in that example.
--   - Every claimed LCM was checked to be (a) a positive common multiple,
--     and (b) that no smaller positive common multiple exists (checked by
--     confirming every multiple listed before it is missing from at least
--     one of the other numbers' multiple lists).
--   - No LCM answer is ever 0.
-- =============================================================================

do $$
declare
  v_lesson10_id uuid;
  v_quiz10_id   uuid;

  v_q1  uuid; v_q2  uuid; v_q3  uuid; v_q4  uuid; v_q5  uuid;
  v_q6  uuid; v_q7  uuid; v_q8  uuid; v_q9  uuid; v_q10 uuid;
begin

  -- ===========================================================================
  -- Lesson 10 — Common Multiples and Least Common Multiple (LCM)
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Common Multiples and Least Common Multiple (LCM)',
    'Learn what multiples and common multiples are, then find the Least Common Multiple (LCM) of two or three numbers by listing multiples, including real-world repeating-event problems.',
    'built_in',
    null,
    'grade_6'
  )
  returning id into v_lesson10_id;

  -- ---------------------------------------------------------------------------
  -- Lesson pages (12 pages)
  -- ---------------------------------------------------------------------------
  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson10_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn about multiples, common multiples, and the Least Common Multiple (LCM) — and how the LCM can help us solve real-world problems about events that repeat.'
  ),
  (
    v_lesson10_id, 2, 'vocabulary', 'Understanding Multiples',
    E'A multiple of a number is what you get when you multiply that number by a whole number (1, 2, 3, 4, ...).\n\n' ||
    E'Multiples of 3:\n' ||
    E'  3 x 1 = 3\n' ||
    E'  3 x 2 = 6\n' ||
    E'  3 x 3 = 9\n' ||
    E'  3 x 4 = 12\n' ||
    E'So the multiples of 3 are: 3, 6, 9, 12, 15, 18, 21, 24, ...\n\n' ||
    E'Multiples of a number continue forever — there is no "last" multiple, so we usually just list the first several.'
  ),
  (
    v_lesson10_id, 3, 'explanation', 'Multiples Using Skip Counting',
    E'You can also find multiples by skip counting — counting forward by the same number again and again.\n\n' ||
    E'Skip counting by 7: 7, 14, 21, 28, 35, 42, ...\n' ||
    E'Each number is 7 more than the one before it, and each one is a multiple of 7 (7x1, 7x2, 7x3, and so on).\n\n' ||
    E'Skip counting is a quick way to build a list of multiples without multiplying every time.'
  ),
  (
    v_lesson10_id, 4, 'explanation', 'Common Multiples',
    E'A common multiple of two or more numbers is a number that appears in the multiples list of EVERY one of those numbers.\n\n' ||
    E'Multiples of 4: 4, 8, 12, 16, 20, 24, 28, 32, 36, ...\n' ||
    E'Multiples of 6: 6, 12, 18, 24, 30, 36, ...\n\n' ||
    E'Common multiples of 4 and 6: 12, 24, 36, ...\n' ||
    E'(12 appears in both lists, 24 appears in both lists, and 36 appears in both lists.)\n\n' ||
    E'A number must be a multiple of every given number to count as a common multiple — being a multiple of just one of them is not enough.'
  ),
  (
    v_lesson10_id, 5, 'explanation', 'The Least Common Multiple (LCM)',
    E'The Least Common Multiple, or LCM, is the SMALLEST POSITIVE common multiple of two or more numbers.\n\n' ||
    E'From the previous page, the common multiples of 4 and 6 begin: 12, 24, 36, ...\n' ||
    E'The smallest one is 12, so the LCM of 4 and 6 is 12.\n\n' ||
    E'Important: the LCM is the LEAST common multiple, not just any common multiple. 24 and 36 are also common multiples of 4 and 6, but they are not the LCM, because 12 is smaller.'
  ),
  (
    v_lesson10_id, 6, 'explanation', 'Finding the LCM by Listing Multiples',
    E'To find the LCM of two (or more) numbers by listing:\n' ||
    E'  1. List several multiples of the first number.\n' ||
    E'  2. List several multiples of the second number (and third, if there is one).\n' ||
    E'  3. Circle the multiples that appear in every list — these are the common multiples.\n' ||
    E'  4. Choose the SMALLEST positive common multiple. This is the LCM.\n' ||
    E'  5. Check your answer: divide it by every given number. If it divides evenly every time, your LCM is correct.\n\n' ||
    E'If you do not find a common multiple right away, list a few more multiples for each number and check again.'
  ),
  (
    v_lesson10_id, 7, 'examples', 'LCM of Two Numbers — Basic and Moderate',
    E'Worked Example 1 (Basic): Find the LCM of 3 and 5.\n' ||
    E'  Multiples of 3: 3, 6, 9, 12, 15, 18, ...\n' ||
    E'  Multiples of 5: 5, 10, 15, 20, 25, ...\n' ||
    E'  Common multiples: 15, 30, ...\n' ||
    E'  The smallest is 15, so the LCM of 3 and 5 is 15.\n' ||
    E'  Check: 15 / 3 = 5. 15 / 5 = 3. Both divide evenly, so 15 is correct.\n\n' ||
    E'Worked Example 2 (Moderate): Find the LCM of 6 and 8.\n' ||
    E'  Multiples of 6: 6, 12, 18, 24, 30, 36, 42, 48, ...\n' ||
    E'  Multiples of 8: 8, 16, 24, 32, 40, 48, ...\n' ||
    E'  Common multiples: 24, 48, ...\n' ||
    E'  The smallest is 24, so the LCM of 6 and 8 is 24.\n' ||
    E'  Check: 24 / 6 = 4. 24 / 8 = 3. Both divide evenly, so 24 is correct.'
  ),
  (
    v_lesson10_id, 8, 'examples', 'LCM of Two Numbers — Challenging',
    E'Worked Example 3 (Challenging): Find the LCM of 9 and 12.\n' ||
    E'  Multiples of 9: 9, 18, 27, 36, 45, 54, ...\n' ||
    E'  Multiples of 12: 12, 24, 36, 48, 60, ...\n' ||
    E'  Common multiples: 36, 72, ...\n' ||
    E'  The smallest is 36, so the LCM of 9 and 12 is 36.\n' ||
    E'  Check: 36 / 9 = 4. 36 / 12 = 3. Both divide evenly, so 36 is correct.\n\n' ||
    E'Notice that 18 and 24 are multiples of only one of the two numbers (18 is a multiple of 9 but not 12; 24 is a multiple of 12 but not 9), so neither one counts as a common multiple.'
  ),
  (
    v_lesson10_id, 9, 'examples', 'LCM of Three Numbers',
    E'When finding the LCM of three numbers, follow the same steps — the LCM must be a common multiple of ALL three.\n\n' ||
    E'Worked Example 4: Find the LCM of 2, 3, and 4.\n' ||
    E'  Multiples of 2: 2, 4, 6, 8, 10, 12, 14, ...\n' ||
    E'  Multiples of 3: 3, 6, 9, 12, 15, ...\n' ||
    E'  Multiples of 4: 4, 8, 12, 16, 20, ...\n' ||
    E'  Common multiples of all three: 12, 24, ...\n' ||
    E'  The smallest is 12, so the LCM of 2, 3, and 4 is 12.\n' ||
    E'  Check: 12 / 2 = 6. 12 / 3 = 4. 12 / 4 = 3. All three divide evenly, so 12 is correct.\n\n' ||
    E'Notice 4 and 8 are multiples of 2 and 4, but not of 3 — so they are not common multiples of all three numbers.'
  ),
  (
    v_lesson10_id, 10, 'explanation', 'Factors vs Multiples, GCF vs LCM',
    E'Because the last lesson covered the Greatest Common Factor (GCF), it helps to compare GCF and LCM side by side.\n\n' ||
    E'FACTORS vs MULTIPLES\n' ||
    E'  Factors divide evenly INTO a number (the factors of 12 are 1, 2, 3, 4, 6, 12).\n' ||
    E'  Multiples are made BY multiplying a number (the multiples of 12 are 12, 24, 36, 48, ...).\n\n' ||
    E'GCF vs LCM (using 12 and 18):\n' ||
    E'  GCF works with FACTORS and finds the GREATEST factor shared by the numbers.\n' ||
    E'    Factors of 12: 1, 2, 3, 4, 6, 12. Factors of 18: 1, 2, 3, 6, 9, 18.\n' ||
    E'    Common factors: 1, 2, 3, 6. The GCF of 12 and 18 is 6.\n' ||
    E'  LCM works with MULTIPLES and finds the LEAST positive multiple shared by the numbers.\n' ||
    E'    Multiples of 12: 12, 24, 36, 48, ... Multiples of 18: 18, 36, 54, ...\n' ||
    E'    Common multiples: 36, 72, ... The LCM of 12 and 18 is 36.\n\n' ||
    E'GCF is always less than or equal to the smaller number. LCM is always greater than or equal to the larger number.'
  ),
  (
    v_lesson10_id, 11, 'explanation', 'Common Mistakes with LCM',
    E'Watch out for these common mistakes:\n' ||
    E'  - Confusing factors with multiples (factors divide into a number; multiples are built by multiplying it).\n' ||
    E'  - Picking a common multiple that is not the smallest one (for example, choosing 24 when 12 is also a common multiple).\n' ||
    E'  - Picking a number that is a multiple of only ONE of the given numbers, not all of them.\n' ||
    E'  - Using 0 as the LCM. The LCM must be the smallest POSITIVE common multiple, so 0 is never used as the answer.\n' ||
    E'  - Stopping the multiples lists too early, before any common multiple has appeared.\n' ||
    E'  - Forgetting that the LCM must be evenly divisible by every one of the given numbers — always check by dividing.\n' ||
    E'  - Mixing up GCF and LCM. GCF looks for the GREATEST shared factor; LCM looks for the LEAST shared multiple.'
  ),
  (
    v_lesson10_id, 12, 'examples', 'LCM and Repeating Events',
    E'When two or more events repeat at regular intervals and start together, the LCM tells us when they will next happen together again.\n\n' ||
    E'Worked Example 5: Bell A rings every 4 minutes and Bell B rings every 6 minutes. Both bells ring together at exactly 8:00 AM. When will they ring together again?\n' ||
    E'  We need the LCM of 4 and 6.\n' ||
    E'  Multiples of 4: 4, 8, 12, 16, 20, ...\n' ||
    E'  Multiples of 6: 6, 12, 18, 24, ...\n' ||
    E'  Common multiples: 12, 24, ...\n' ||
    E'  LCM = 12.\n' ||
    E'  The bells will ring together again 12 minutes after 8:00 AM, which is 8:12 AM.\n\n' ||
    E'Worked Example 6 (three events): Three warning lights flash every 3 seconds, 4 seconds, and 5 seconds. All three flash together at the same moment. After how many seconds will all three flash together again?\n' ||
    E'  We need the LCM of 3, 4, and 5.\n' ||
    E'  Common multiples of 3 and 4: 12, 24, 36, 48, 60, ...\n' ||
    E'  Checking which of those are also multiples of 5: 12, 24, 36, and 48 are not; 60 is (60 / 5 = 12).\n' ||
    E'  LCM = 60.\n' ||
    E'  All three lights will flash together again after 60 seconds.'
  ),
  (
    v_lesson10_id, 13, 'summary', 'Remember',
    E'  - A multiple is the result of multiplying a number by a whole number.\n' ||
    E'  - Multiples can be found by skip counting and continue forever.\n' ||
    E'  - A common multiple is shared by every one of the given numbers, not just one of them.\n' ||
    E'  - LCM means Least Common Multiple — the SMALLEST POSITIVE common multiple.\n' ||
    E'  - To find the LCM by listing, list multiples of each number and find the first one they all share.\n' ||
    E'  - Always check an LCM answer by dividing it by every given number.\n' ||
    E'  - The LCM is never 0 — it must be a positive number.\n' ||
    E'  - Factors divide into a number; multiples are built by multiplying it.\n' ||
    E'  - GCF finds the greatest shared factor; LCM finds the least shared multiple.\n' ||
    E'  - The LCM can help solve problems about events that repeat at regular intervals.'
  );

  -- ===========================================================================
  -- Quiz 10 — built-in Internal Quiz for Lesson 10
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 10: Common Multiples and Least Common Multiple (LCM)',
    'internal', 'built_in', null, 'grade_6', true, true
  )
  returning id into v_quiz10_id;

  -- --- Q1 (concept) ---------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Multiples and Least Common Multiple (LCM)',
    'What is a multiple of a number?',
    'A multiple is the result of multiplying a number by a whole number (1, 2, 3, ...). For example, 12 is a multiple of 4 because 4 x 3 = 12.'
  )
  returning id into v_q1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1, 'The result of multiplying the number by a whole number', true,  1),
    (v_q1, 'A number that divides evenly into it', false, 2),
    (v_q1, 'The smallest number in its multiplication table', false, 3),
    (v_q1, 'Any number that is greater than it', false, 4);

  -- --- Q2 (identify multiples) -----------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Multiples and Least Common Multiple (LCM)',
    'Which of the following is a multiple of 7?',
    '28 is a multiple of 7 because 7 x 4 = 28. 30, 27, and 25 cannot be made by multiplying 7 by a whole number, so they are not multiples of 7.'
  )
  returning id into v_q2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2, '28', true,  1),
    (v_q2, '30', false, 2),
    (v_q2, '27', false, 3),
    (v_q2, '25', false, 4);

  -- --- Q3 (identify common multiple) -----------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Multiples and Least Common Multiple (LCM)',
    'Multiples of 4: 4, 8, 12, 16, 20, 24, ... Multiples of 5: 5, 10, 15, 20, 25, 30, ... Which number is a common multiple of 4 and 5?',
    '20 appears in both lists (a multiple of 4 and a multiple of 5), so it is a common multiple. 15 and 25 are multiples of 5 only, and 16 is a multiple of 4 only.'
  )
  returning id into v_q3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q3, '20', true,  1),
    (v_q3, '15', false, 2),
    (v_q3, '16', false, 3),
    (v_q3, '25', false, 4);

  -- --- Q4 (choose correct multiple list) --------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Multiples and Least Common Multiple (LCM)',
    'Which list correctly shows the first five multiples of 6?',
    '6, 12, 18, 24, 30 are 6 x 1 through 6 x 5. The list starting with 0 wrongly includes 0; the list 1, 2, 3, 6 shows factors of 6, not multiples; and 6, 13, 19, 25, 31 is not built by repeatedly adding 6.'
  )
  returning id into v_q4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q4, '6, 12, 18, 24, 30', true,  1),
    (v_q4, '0, 6, 12, 18, 24', false, 2),
    (v_q4, '1, 2, 3, 6', false, 3),
    (v_q4, '6, 13, 19, 25, 31', false, 4);

  -- --- Q5 (LCM of two numbers, basic) -----------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Multiples and Least Common Multiple (LCM)',
    'What is the LCM of 3 and 5?',
    'Multiples of 3: 3, 6, 9, 12, 15, ... Multiples of 5: 5, 10, 15, 20, ... The first common multiple is 15, so the LCM of 3 and 5 is 15. 30 is also a common multiple, but it is not the least.'
  )
  returning id into v_q5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5, '15', true,  1),
    (v_q5, '30', false, 2),
    (v_q5, '3',  false, 3),
    (v_q5, '8',  false, 4);

  -- --- Q6 (LCM of two numbers, moderate) ---------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Multiples and Least Common Multiple (LCM)',
    'What is the LCM of 6 and 8?',
    'Multiples of 6: 6, 12, 18, 24, 30, ... Multiples of 8: 8, 16, 24, 32, ... The first common multiple is 24, so the LCM of 6 and 8 is 24. 48 is also a common multiple, but not the least. 16 is a multiple of 8 only, and 18 is a multiple of 6 only.'
  )
  returning id into v_q6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6, '24', true,  1),
    (v_q6, '48', false, 2),
    (v_q6, '16', false, 3),
    (v_q6, '18', false, 4);

  -- --- Q7 (GCF vs LCM) ----------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Multiples and Least Common Multiple (LCM)',
    'The GCF of 12 and 18 is 6. What is the LCM of 12 and 18?',
    'GCF and LCM are different: GCF (6) is the greatest shared factor, found from factors of 12 (1,2,3,4,6,12) and 18 (1,2,3,6,9,18). LCM is the least shared multiple: multiples of 12 (12,24,36,...) and 18 (18,36,...) first share 36, so the LCM is 36 — not the GCF value, and not simply 12 x 18 = 216.'
  )
  returning id into v_q7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q7, '36',  true,  1),
    (v_q7, '6',   false, 2),
    (v_q7, '216', false, 3),
    (v_q7, '18',  false, 4);

  -- --- Q8 (zero and LCM) ---------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Multiples and Least Common Multiple (LCM)',
    'A student says the LCM of 5 and 10 is 0, since 0 is technically a multiple of every number. Is the student correct?',
    'No. The LCM is defined as the smallest POSITIVE common multiple, so 0 is never used as an LCM answer even though it is technically a multiple of every number. The LCM of 5 and 10 is 10.'
  )
  returning id into v_q8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q8, 'No, because the LCM must be the smallest POSITIVE common multiple, and 0 is not used', true,  1),
    (v_q8, 'Yes, because 0 is a multiple of every number', false, 2),
    (v_q8, 'No, because 0 is not a multiple of any number', false, 3),
    (v_q8, 'Yes, because 0 is smaller than 5', false, 4);

  -- --- Q9 (LCM of three numbers) ---------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Multiples and Least Common Multiple (LCM)',
    'What is the LCM of 2, 3, and 4?',
    'Multiples of 2: 2,4,6,8,10,12,... Multiples of 3: 3,6,9,12,... Multiples of 4: 4,8,12,16,... The first number shared by all three lists is 12, so the LCM of 2, 3, and 4 is 12. 24 is also common to all three but not the least; 6 is a multiple of 2 and 3 but not 4; 4 is a multiple of 2 and 4 but not 3.'
  )
  returning id into v_q9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9, '12', true,  1),
    (v_q9, '24', false, 2),
    (v_q9, '6',  false, 3),
    (v_q9, '4',  false, 4);

  -- --- Q10 (real-world / repeating event) -------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Multiples and Least Common Multiple (LCM)',
    'Bell A rings every 4 minutes and Bell B rings every 6 minutes. Both bells ring together at exactly 8:00 AM. What is the next time they will ring together?',
    'This is the LCM of 4 and 6. Multiples of 4: 4,8,12,16,... Multiples of 6: 6,12,18,... The first shared multiple is 12, so the bells ring together again 12 minutes after 8:00 AM, at 8:12 AM. 8:24 AM uses 24, a common multiple but not the least; 8:06 AM only accounts for Bell B.'
  )
  returning id into v_q10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10, '8:12 AM', true,  1),
    (v_q10, '8:24 AM', false, 2),
    (v_q10, '8:10 AM', false, 3),
    (v_q10, '8:06 AM', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz10_id, v_q1,  1),
    (v_quiz10_id, v_q2,  2),
    (v_quiz10_id, v_q3,  3),
    (v_quiz10_id, v_q4,  4),
    (v_quiz10_id, v_q5,  5),
    (v_quiz10_id, v_q6,  6),
    (v_quiz10_id, v_q7,  7),
    (v_quiz10_id, v_q8,  8),
    (v_quiz10_id, v_q9,  9),
    (v_quiz10_id, v_q10, 10);

  -- ---------------------------------------------------------------------------
  -- Link Lesson 10 to Quiz 10 (0032) — pure UI "Take Quiz" convenience
  -- shortcut, never a dependency (see 0032's own column comment).
  -- ---------------------------------------------------------------------------
  update public.lessons set linked_quiz_id = v_quiz10_id where id = v_lesson10_id;

end $$;
