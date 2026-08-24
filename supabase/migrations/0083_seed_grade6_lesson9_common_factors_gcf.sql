-- =============================================================================
-- Migration: 0083_seed_grade6_lesson9_common_factors_gcf.sql
--
-- Seeds Grade 6 built-in content:
--   Lesson 9 — Common Factors and Greatest Common Factor (GCF)
--   Quiz 9   — Internal Quiz for Lesson 9 (10 questions)
--
-- CONFIRMED AGAINST ACTUAL SCHEMA/CONTENT before writing this (0007, 0008,
-- 0009, 0027, 0028, 0029, 0030, 0032, 0033 all re-read in full):
--   - `lessons`/`quizzes` both carry a `grade_level` enum column
--     ('grade_4' | 'grade_5' | 'grade_6', per `GradeLevel` in
--     lib/core/models/section.dart) — set to 'grade_6' on every row below,
--     matching the `grade_4` pairing 0027 used.
--   - Lesson TITLES never carry a numeric "Lesson N:" prefix in this
--     project (0027: 'Addition and Subtraction of Numbers up to
--     1,000,000', not 'Lesson 1: ...') — Lesson 9's title below follows
--     that same precedent. Quiz titles DO carry the "Quiz N: <Topic>"
--     prefix (0027: 'Quiz 1: Addition and Subtraction ...', 'Quiz 2:
--     Comparing Numbers ...') — Quiz 9's title below matches that
--     precedent exactly: 'Quiz 9: Common Factors and Greatest Common
--     Factor (GCF)'.
--   - `LessonsRepository.fetchVisibleToTeacher()` orders lessons by
--     `title` (alphabetical), not by any lesson-number/created_at field —
--     there is no `lesson_number` column anywhere in the schema. The
--     "Lesson 9" / "Quiz 9" sequence position named in the request is
--     therefore a content-authoring/curriculum convention external to
--     this schema (same as how Lessons 1-8 for Grade 6 are presumably
--     already seeded elsewhere, outside this reference package, which
--     only ships the Grade 4 example per README_AI_REFERENCE.txt) — not
--     something this migration needs to encode as a new field. No schema
--     change is made here.
--   - `lesson_pages.worked_example` (0030) is fixed, POC-scope, to
--     exactly 6 place-value columns for addition/subtraction only (0030's
--     column comment, confirmed again against `WorkedExample`/
--     `WorkedExampleStep` in lib/core/models/worked_example.dart) — it
--     has no representation for factors/GCF, so no `lesson_pages` row
--     below sets it; every page uses plain-text `body`, which is the
--     default/typical case for every existing page except the two 0031
--     POC pages. Per the request's own instruction not to invent a new
--     worked-example JSON shape, this is the correct, non-inventive
--     choice.
--   - `linked_quiz_id` (0032) is set from Lesson 9 to Quiz 9 at the end,
--     mirroring 0033's Grade 4 Lesson->Quiz linking exactly (same
--     `update ... where id = ...` shape, same "pure UI convenience,
--     never a dependency" semantics — no `lesson_progress`/
--     `quiz_attempts` interaction here either).
--   - question_bank/question_choices/quiz_questions all follow 0027's
--     exact shape: `source_type = 'built_in'`, `created_by = null`,
--     `topic` tagged to the lesson's title, 4 choices per question
--     inserted in one statement (so the deferred
--     `enforce_at_least_one_correct` trigger, 0014, never observes a
--     zero-correct-choice question mid-transaction), one correct answer
--     per question, ids captured via `returning ... into` (never
--     hardcoded).
--
-- MATHEMATICAL VALIDATION — every factor list, factor pair, common-factor
-- set, and GCF below was independently computed and verified (brute-force
-- divisor enumeration) before being written into this migration. Summary:
--   factors(18)  = {1,2,3,6,9,18}            factors(30)  = {1,2,3,5,6,10,15,30}
--   factors(8)   = {1,2,4,8}                 multiples(8) = 8,16,24,32,...
--   factors(20)  = {1,2,4,5,10,20}           factors(30)  = {1,2,3,5,6,10,15,30}
--     common(20,30) = {1,2,5,10} -> GCF = 10
--   factors(8)   = {1,2,4,8}   factors(12) = {1,2,3,4,6,12}  common={1,2,4}  GCF=4
--   factors(16)  = {1,2,4,8,16} factors(24) = {1,2,3,4,6,8,12,24} common={1,2,4,8} GCF=8
--   factors(28)  = {1,2,4,7,14,28} factors(42) = {1,2,3,6,7,14,21,42} common={1,2,7,14} GCF=14
--   factors(18)  = {1,2,3,6,9,18} factors(27) = {1,3,9,27} common={1,3,9} GCF=9
--   factors(12)  = {1,2,3,4,6,12} factors(18) = {1,2,3,6,9,18} factors(30) = {1,2,3,5,6,10,15,30}
--     common(12,18,30) = {1,2,3,6} -> GCF = 6
--   factors(18)  = {1,2,3,6,9,18} factors(24) = {1,2,3,4,6,8,12,24} common={1,2,3,6} GCF=6
--   factors(45)  = {1,3,5,9,15,45} factors(60) = {1,2,3,4,5,6,10,12,15,20,30,60} common={1,3,5,15} GCF=15
--   factors(28)  = {1,2,4,7,14,28} (Q2)
--   factors(16)  = {1,2,4,8,16} factors(24) = {1,2,3,4,6,8,12,24} common={1,2,4,8} GCF=8 (Q4)
--   factors(40)  = {1,2,4,5,8,10,20,40}, pairs 1x40,2x20,4x10,5x8 (Q3); 3x14=42 (distractor, not a pair of 40)
--   factors(24)  = {1,2,3,4,6,8,12,24} factors(36) = {1,2,3,4,6,9,12,18,36} common={1,2,3,4,6,12} GCF=12 (Q7)
--   factors(12)  = {1,2,3,4,6,12} factors(20) = {1,2,4,5,10,20} factors(28) = {1,2,4,7,14,28}
--     common(12,20,28) = {1,2,4} -> GCF = 4 (Q8)
--   factors(15)  = {1,3,5,15} factors(20) = {1,2,4,5,10,20} common={1,5} GCF=5 (Q9 reasoning)
--   factors(32)  = {1,2,4,8,16,32} factors(48) = {1,2,3,4,6,8,12,16,24,48} common={1,2,4,8,16} GCF=16 (Q10)
-- =============================================================================

do $$
declare
  v_lesson_id uuid;
  v_quiz_id   uuid;

  v_q_1  uuid; v_q_2  uuid; v_q_3  uuid; v_q_4  uuid; v_q_5  uuid;
  v_q_6  uuid; v_q_7  uuid; v_q_8  uuid; v_q_9  uuid; v_q_10 uuid;
begin

  -- ===========================================================================
  -- Lesson 9 — Common Factors and Greatest Common Factor (GCF)
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Common Factors and Greatest Common Factor (GCF)',
    'Learn what a factor is, how to find the common factors of two or more numbers, and how to find the Greatest Common Factor (GCF) by listing factors and by using factor pairs, with real-world applications.',
    'built_in',
    null,
    'grade_6'
  )
  returning id into v_lesson_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn about factors, common factors, and the Greatest Common Factor, or GCF. Understanding the GCF will help us divide numbers, simplify problems, and split items into equal groups with nothing left over.'
  ),
  (
    v_lesson_id, 2, 'vocabulary', 'What Is a Factor?',
    E'A factor is a whole number that divides another number evenly, with no remainder.\n\n' ||
    E'Example: Factors of 18\n' ||
    E'  1 x 18 = 18\n' ||
    E'  2 x 9  = 18\n' ||
    E'  3 x 6  = 18\n' ||
    E'Since each of these pairs multiplies to 18, every number in the pairs is a factor of 18.\n' ||
    E'Factors of 18: 1, 2, 3, 6, 9, 18\n\n' ||
    E'To check if a number is a factor, divide. If the number divides evenly (no remainder), it is a factor. For example, 18 / 4 = 4.5, so 4 is NOT a factor of 18.'
  ),
  (
    v_lesson_id, 3, 'explanation', 'Finding Factor Pairs',
    E'A factor pair is two numbers that multiply together to make a given number. Listing factor pairs is a reliable way to find every factor of a number without skipping any.\n\n' ||
    E'Example: Factor Pairs of 30\n' ||
    E'  1 x 30 = 30\n' ||
    E'  2 x 15 = 30\n' ||
    E'  3 x 10 = 30\n' ||
    E'  5 x 6  = 30\n' ||
    E'Once the pairs start repeating numbers you already found (the next pair after 5 x 6 would be 6 x 5), you know you have found them all.\n' ||
    E'Factors of 30: 1, 2, 3, 5, 6, 10, 15, 30\n\n' ||
    E'Tip: Start with 1 and work upward, testing each whole number to see if it divides evenly. This keeps your list organized and complete.'
  ),
  (
    v_lesson_id, 4, 'explanation', 'Factors vs. Multiples',
    E'It is easy to mix up factors and multiples, so let''s compare them clearly.\n\n' ||
    E'Factors are numbers that multiply together to produce a given number. A number has a limited set of factors.\n' ||
    E'Multiples are numbers produced by multiplying a number by whole numbers (1, 2, 3, ...). A number has an unlimited set of multiples.\n\n' ||
    E'Example: Factors and Multiples of 8\n' ||
    E'  Factors of 8: 1, 2, 4, 8 (a short, complete list)\n' ||
    E'  Multiples of 8: 8, 16, 24, 32, 40, ... (this list goes on forever)\n\n' ||
    E'Remember: factors divide INTO a number; multiples are what you get when you multiply a number by 1, 2, 3, and so on.'
  ),
  (
    v_lesson_id, 5, 'explanation', 'Common Factors',
    E'Common factors are factors that two or more numbers share.\n\n' ||
    E'Example: Common Factors of 20 and 30\n' ||
    E'  Factors of 20: 1, 2, 4, 5, 10, 20\n' ||
    E'  Factors of 30: 1, 2, 3, 5, 6, 10, 15, 30\n' ||
    E'  Comparing both lists, the numbers that appear in BOTH are: 1, 2, 5, and 10.\n' ||
    E'Common factors of 20 and 30: 1, 2, 5, 10\n\n' ||
    E'To find common factors: list the factors of each number, then circle or write down every number that appears on every list.'
  ),
  (
    v_lesson_id, 6, 'explanation', 'The Greatest Common Factor (GCF)',
    E'The Greatest Common Factor, or GCF, is the largest factor that two or more numbers have in common.\n\n' ||
    E'Using our common factors of 20 and 30 from the last page: 1, 2, 5, 10.\n' ||
    E'The greatest number in that list is 10, so the GCF of 20 and 30 is 10.\n\n' ||
    E'For a number to be the GCF, it must meet BOTH conditions:\n' ||
    E'  1. It must be a factor of every given number.\n' ||
    E'  2. It must be the greatest of all the common factors.\n\n' ||
    E'To check an answer: divide every given number by your GCF. Each division should come out even, and no larger common factor should exist. 20 / 10 = 2 (even) and 30 / 10 = 3 (even), and no common factor of 20 and 30 is greater than 10, so GCF = 10 is confirmed correct.'
  ),
  (
    v_lesson_id, 7, 'examples', 'Finding the GCF by Listing Factors',
    E'Steps: (1) List the factors of the first number. (2) List the factors of the second number. (3) Identify the common factors. (4) Choose the greatest one.\n\n' ||
    E'Worked Example 1 (Basic): GCF of 8 and 12\n' ||
    E'  Factors of 8: 1, 2, 4, 8\n' ||
    E'  Factors of 12: 1, 2, 3, 4, 6, 12\n' ||
    E'  Common factors: 1, 2, 4\n' ||
    E'  Greatest common factor: 4\n' ||
    E'  Check: 8 / 4 = 2 and 12 / 4 = 3, both even, and no common factor is larger than 4.\n' ||
    E'  Answer: GCF(8, 12) = 4\n\n' ||
    E'Worked Example 2 (Moderate): GCF of 16 and 24\n' ||
    E'  Factors of 16: 1, 2, 4, 8, 16\n' ||
    E'  Factors of 24: 1, 2, 3, 4, 6, 8, 12, 24\n' ||
    E'  Common factors: 1, 2, 4, 8\n' ||
    E'  Greatest common factor: 8\n' ||
    E'  Check: 16 / 8 = 2 and 24 / 8 = 3, both even, and no common factor is larger than 8.\n' ||
    E'  Answer: GCF(16, 24) = 8\n\n' ||
    E'Worked Example 3 (Challenging): GCF of 28 and 42\n' ||
    E'  Factors of 28: 1, 2, 4, 7, 14, 28\n' ||
    E'  Factors of 42: 1, 2, 3, 6, 7, 14, 21, 42\n' ||
    E'  Common factors: 1, 2, 7, 14\n' ||
    E'  Greatest common factor: 14\n' ||
    E'  Check: 28 / 14 = 2 and 42 / 14 = 3, both even, and no common factor is larger than 14.\n' ||
    E'  Answer: GCF(28, 42) = 14'
  ),
  (
    v_lesson_id, 8, 'explanation', 'Finding the GCF Using Factor Pairs',
    E'Factor pairs can also help you find the GCF efficiently, since they guarantee you find every factor without missing one.\n\n' ||
    E'Worked Example: GCF of 18 and 27 (using factor pairs)\n' ||
    E'  Factor pairs of 18: 1 x 18, 2 x 9, 3 x 6\n' ||
    E'    Factors of 18: 1, 2, 3, 6, 9, 18\n' ||
    E'  Factor pairs of 27: 1 x 27, 3 x 9\n' ||
    E'    Factors of 27: 1, 3, 9, 27\n' ||
    E'  Common factors: 1, 3, 9\n' ||
    E'  Greatest common factor: 9\n' ||
    E'  Check: 18 / 9 = 2 and 27 / 9 = 3, both even, and no common factor is larger than 9.\n' ||
    E'  Answer: GCF(18, 27) = 9'
  ),
  (
    v_lesson_id, 9, 'examples', 'GCF of Three Numbers',
    E'The same process works for three (or more) numbers — just make sure the factor you choose is common to ALL of them.\n\n' ||
    E'Worked Example: GCF of 12, 18, and 30\n' ||
    E'  Factors of 12: 1, 2, 3, 4, 6, 12\n' ||
    E'  Factors of 18: 1, 2, 3, 6, 9, 18\n' ||
    E'  Factors of 30: 1, 2, 3, 5, 6, 10, 15, 30\n' ||
    E'  Factors common to all three numbers: 1, 2, 3, 6\n' ||
    E'  Greatest common factor: 6\n' ||
    E'  Check: 12 / 6 = 2, 18 / 6 = 3, and 30 / 6 = 5 — all even, and no factor common to all three numbers is greater than 6.\n' ||
    E'  Answer: GCF(12, 18, 30) = 6'
  ),
  (
    v_lesson_id, 10, 'explanation', 'Watch Out! Common Mistakes with GCF',
    E'Keep these common mistakes in mind:\n\n' ||
    E'  - Confusing factors with multiples. Factors divide INTO a number; multiples come FROM multiplying it.\n' ||
    E'  - Listing a number that does not divide evenly. Always double-check with division.\n' ||
    E'  - Forgetting a factor. Using factor pairs (working from 1 upward) helps you catch every one.\n' ||
    E'  - Picking a common factor that is NOT the greatest. 2 might be a common factor, but if 8 is also common, 8 is the GCF, not 2.\n' ||
    E'  - Choosing the greatest factor of only ONE number instead of a factor common to ALL the numbers. For example, 20 is a factor of 20, but it is not a factor of 15, so 20 cannot be the GCF of 15 and 20.'
  ),
  (
    v_lesson_id, 11, 'examples', 'Real-World Applications of GCF',
    E'The GCF is useful anytime you need to split items into equal-sized groups with nothing left over.\n\n' ||
    E'Worked Example 1: A gardener has 18 tomato plants and 24 pepper plants. She wants to plant them in rows, with only one type of plant per row, and every row having the same number of plants. What is the greatest number of plants she can put in each row?\n' ||
    E'  This calls for the GCF of 18 and 24.\n' ||
    E'  Factors of 18: 1, 2, 3, 6, 9, 18\n' ||
    E'  Factors of 24: 1, 2, 3, 4, 6, 8, 12, 24\n' ||
    E'  Common factors: 1, 2, 3, 6\n' ||
    E'  GCF(18, 24) = 6\n' ||
    E'  Answer: She can plant 6 plants per row — 3 rows of tomatoes (18 / 6) and 4 rows of peppers (24 / 6).\n\n' ||
    E'Worked Example 2: A teacher has 45 pencils and 60 crayons and wants to make identical kits for her students with no items left over. What is the greatest number of kits she can make?\n' ||
    E'  This calls for the GCF of 45 and 60.\n' ||
    E'  Factors of 45: 1, 3, 5, 9, 15, 45\n' ||
    E'  Factors of 60: 1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30, 60\n' ||
    E'  Common factors: 1, 3, 5, 15\n' ||
    E'  GCF(45, 60) = 15\n' ||
    E'  Answer: She can make 15 kits, each with 3 pencils (45 / 15) and 4 crayons (60 / 15).'
  ),
  (
    v_lesson_id, 12, 'summary', 'Remember',
    E'  - A factor is a whole number that divides another number evenly, with no remainder.\n' ||
    E'  - Factor pairs help you find every factor of a number without missing one.\n' ||
    E'  - Factors divide INTO a number; multiples are what you get when you multiply it — do not confuse the two.\n' ||
    E'  - Common factors are factors shared by two or more numbers.\n' ||
    E'  - GCF means Greatest Common Factor: the largest factor that all the given numbers share.\n' ||
    E'  - To find the GCF by listing: list each number''s factors, find the common ones, then pick the greatest.\n' ||
    E'  - The same method extends to three or more numbers — the GCF must be common to ALL of them.\n' ||
    E'  - The GCF is useful for splitting items into equal groups with nothing left over.\n' ||
    E'  - Always check your answer: it should divide every given number evenly, and no larger common factor should exist.'
  );

  -- ===========================================================================
  -- Quiz 9 — built-in Internal Quiz for Lesson 9
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 9: Common Factors and Greatest Common Factor (GCF)',
    'internal', 'built_in', null, 'grade_6', true, true
  )
  returning id into v_quiz_id;

  -- --- Q1 (concept: what is a factor) ----------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Factors and Greatest Common Factor (GCF)',
    'Which statement correctly describes a factor of a number?',
    'A factor is a whole number that divides another number evenly, with no remainder. For example, 4 is a factor of 12 because 12 / 4 = 3 exactly.'
  )
  returning id into v_q_1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_1, 'A whole number that divides the number evenly, with no remainder', true,  1),
    (v_q_1, 'A number you multiply the given number by to get a bigger number', false, 2),
    (v_q_1, 'Any whole number that is smaller than the given number', false, 3),
    (v_q_1, 'The answer you get when you divide two numbers', false, 4);

  -- --- Q2 (identify a complete factor list) -----------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Factors and Greatest Common Factor (GCF)',
    'What are all the factors of 28?',
    'Using factor pairs: 1 x 28, 2 x 14, 4 x 7. This gives the complete list 1, 2, 4, 7, 14, 28. A list missing 14 is incomplete, a list including 6 is wrong because 28 / 6 does not divide evenly, and 28, 56, 84, 112 are multiples of 28, not its factors.'
  )
  returning id into v_q_2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_2, '1, 2, 4, 7, 14, 28', true,  1),
    (v_q_2, '1, 2, 4, 7, 28', false, 2),
    (v_q_2, '1, 2, 4, 6, 7, 14, 28', false, 3),
    (v_q_2, '28, 56, 84, 112', false, 4);

  -- --- Q3 (factor pairs) -------------------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Factors and Greatest Common Factor (GCF)',
    'Which of the following is NOT a factor pair of 40?',
    'The factor pairs of 40 are 1 x 40, 2 x 20, 4 x 10, and 5 x 8, giving the factors 1, 2, 4, 5, 8, 10, 20, 40. 3 x 14 = 42, not 40, so 3 x 14 is not a factor pair of 40.'
  )
  returning id into v_q_3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_3, '3 x 14', true,  1),
    (v_q_3, '4 x 10', false, 2),
    (v_q_3, '5 x 8', false, 3),
    (v_q_3, '2 x 20', false, 4);

  -- --- Q4 (identify common factors) --------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Factors and Greatest Common Factor (GCF)',
    'What are the common factors of 16 and 24?',
    'Factors of 16: 1, 2, 4, 8, 16. Factors of 24: 1, 2, 3, 4, 6, 8, 12, 24. The numbers that appear on both lists are 1, 2, 4, and 8. Note that 3 is a factor of 24 but NOT of 16, so it cannot be a common factor, and 8 alone is only the GCF, not the full set of common factors.'
  )
  returning id into v_q_4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_4, '1, 2, 4, 8', true,  1),
    (v_q_4, '1, 2, 4', false, 2),
    (v_q_4, '1, 2, 3, 4, 8', false, 3),
    (v_q_4, '8', false, 4);

  -- --- Q5 (factors vs multiples) -----------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Factors and Greatest Common Factor (GCF)',
    'Which list shows multiples of 9, not factors of 9?',
    'Multiples of 9 come from multiplying 9 by 1, 2, 3, 4...: 9, 18, 27, 36. The list 1, 3, 9 shows the factors of 9 instead. 9, 19, 29, 39 comes from repeatedly adding 10, not multiplying by 9. 3, 6, 9, 12 are multiples of 3, not of 9.'
  )
  returning id into v_q_5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_5, '9, 18, 27, 36', true,  1),
    (v_q_5, '1, 3, 9', false, 2),
    (v_q_5, '9, 19, 29, 39', false, 3),
    (v_q_5, '3, 6, 9, 12', false, 4);

  -- --- Q6 (GCF concept: greatest, not just any, common factor) -----------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Factors and Greatest Common Factor (GCF)',
    'The common factors of two numbers are 1, 2, 4, and 8. What is their GCF?',
    'The GCF is the GREATEST of the common factors, not just any common factor. Among 1, 2, 4, and 8, the greatest value is 8, so the GCF is 8. Choosing 1, 2, or 4 would mean picking a common factor that is not the greatest.'
  )
  returning id into v_q_6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_6, '8', true,  1),
    (v_q_6, '1', false, 2),
    (v_q_6, '2', false, 3),
    (v_q_6, '4', false, 4);

  -- --- Q7 (compute GCF of two numbers) ------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Factors and Greatest Common Factor (GCF)',
    'What is the GCF of 24 and 36?',
    'Factors of 24: 1, 2, 3, 4, 6, 8, 12, 24. Factors of 36: 1, 2, 3, 4, 6, 9, 12, 18, 36. Common factors: 1, 2, 3, 4, 6, 12. The greatest is 12, so GCF(24, 36) = 12. 6 is a common factor but not the greatest, and 24 is a factor of 24 only (not of 36), so it cannot be the GCF.'
  )
  returning id into v_q_7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_7, '12', true,  1),
    (v_q_7, '6', false, 2),
    (v_q_7, '24', false, 3),
    (v_q_7, '4', false, 4);

  -- --- Q8 (compute GCF of three numbers) -----------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Factors and Greatest Common Factor (GCF)',
    'What is the GCF of 12, 20, and 28?',
    'Factors of 12: 1, 2, 3, 4, 6, 12. Factors of 20: 1, 2, 4, 5, 10, 20. Factors of 28: 1, 2, 4, 7, 14, 28. The factors common to all three numbers are 1, 2, and 4, so GCF(12, 20, 28) = 4. 2 is common to all three but not the greatest; 12 is a factor of 12 only; 6 is a factor of 12 but not of 20 or 28, so it is not common to all three.'
  )
  returning id into v_q_8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_8, '4', true,  1),
    (v_q_8, '2', false, 2),
    (v_q_8, '12', false, 3),
    (v_q_8, '6', false, 4);

  -- --- Q9 (reasoning: identify the mistake) --------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Factors and Greatest Common Factor (GCF)',
    'A student is finding the GCF of 15 and 20. He lists the factors of 20 as 1, 2, 4, 5, 10, 20 and picks 20 as the GCF. What mistake did he make?',
    'His factor list for 20 is actually correct. His mistake is that he picked the greatest factor of 20 alone, instead of finding a factor common to BOTH 15 and 20. Since 20 is not even a factor of 15 (15 / 20 is not a whole number), it cannot be their GCF. The factors of 15 are 1, 3, 5, 15; the common factors of 15 and 20 are 1 and 5, so the correct GCF is 5.'
  )
  returning id into v_q_9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_9, 'He chose the greatest factor of only 20 instead of a factor common to both 15 and 20', true,  1),
    (v_q_9, 'He listed the factors of 20 incorrectly', false, 2),
    (v_q_9, 'He forgot to include 1 as a common factor', false, 3),
    (v_q_9, 'He should have multiplied 15 and 20 instead of finding their factors', false, 4);

  -- --- Q10 (real-world application) -----------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Common Factors and Greatest Common Factor (GCF)',
    'A store clerk has 32 apples and 48 oranges. She wants to make identical fruit baskets, using all the fruit, with no fruit left over. What is the greatest number of baskets she can make?',
    'This calls for the GCF of 32 and 48. Factors of 32: 1, 2, 4, 8, 16, 32. Factors of 48: 1, 2, 3, 4, 6, 8, 12, 16, 24, 48. Common factors: 1, 2, 4, 8, 16. GCF(32, 48) = 16, so she can make 16 identical baskets, each with 2 apples (32 / 16) and 3 oranges (48 / 16). 8 is a common factor but not the greatest, and 32 is a factor of the apples only, not of 48.'
  )
  returning id into v_q_10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_10, '16 baskets', true,  1),
    (v_q_10, '8 baskets', false, 2),
    (v_q_10, '32 baskets', false, 3),
    (v_q_10, '4 baskets', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz_id, v_q_1,  1),
    (v_quiz_id, v_q_2,  2),
    (v_quiz_id, v_q_3,  3),
    (v_quiz_id, v_q_4,  4),
    (v_quiz_id, v_q_5,  5),
    (v_quiz_id, v_q_6,  6),
    (v_quiz_id, v_q_7,  7),
    (v_quiz_id, v_q_8,  8),
    (v_quiz_id, v_q_9,  9),
    (v_quiz_id, v_q_10, 10);

  -- ===========================================================================
  -- Link Lesson 9 -> Quiz 9 (mirrors 0033's Grade 4 lesson/quiz linking)
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz_id where id = v_lesson_id;

end $$;
