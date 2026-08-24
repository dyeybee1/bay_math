-- =============================================================================
-- Migration: 0070_seed_grade5_using_divisibility_rules.sql
--
-- Content-seeding migration (schema-only changes are NOT needed here — this
-- reuses `lessons` / `lesson_pages` (0028) / `quizzes` / `question_bank` /
-- `question_choices` / `quiz_questions` / `lessons.linked_quiz_id` (0032)
-- exactly as they already exist, following the same collapsed single-
-- migration pattern as 0069 (lesson + pages + quiz + questions + choices +
-- link, all created together, so no by-title lookup is needed the way
-- 0033 needed one for a pre-existing pair).
--
-- Seeds Grade 5 built-in content:
--   Lesson 6 — Using Divisibility Rules (19 pages)
--   Quiz 6   — Internal Quiz for Lesson 6 (10 questions, mixed divisibility
--               by 2, 3, 5, 6, 9, and 10)
--
-- RULES INCLUDED: 2, 5, 10, 3, 9, 6 — all six are covered, matching every
-- rule the lesson brief itself spells out in full worked-example detail
-- (last-digit rules for 2/5/10, digit-sum rules for 3/9, and the
-- both-2-and-3 rule for 6). No broader topic (prime factorization, GCF,
-- LCM, long division) is introduced.
--
-- All ids are database-generated (gen_random_uuid(), the default on every
-- affected table's id column) and captured via `returning ... into`, never
-- hardcoded. lessons/quizzes/question_bank rows use source_type =
-- 'built_in', created_by = null, grade_level = 'grade_5' (lessons/quizzes
-- only — question_bank has no grade_level column, matching 0027/0008).
-- question_bank.topic is tagged to match the owning lesson's title, for
-- the Highest/Lowest Performing Topics dashboard metric (schema comment,
-- 0008) — same convention 0027/0069 used.
--
-- quizzes.assessment_type (0043) is left null — this is an ordinary
-- practice/graded quiz, not a Pre-Test/Post-Test.
--
-- No `worked_example` (0030) is used on any page: that column is an
-- explicitly-scoped proof of concept for whole-number addition/
-- subtraction place-value columns (see 0030's column comment) and does
-- not fit divisibility content. Every page below uses plain `body` text,
-- same as 0069 and every existing page outside that POC.
--
-- Every quiz answer choice is single-correct (RadioGroup/RadioListTile in
-- `quiz_taking_screen.dart` — confirmed by reading the actual widget
-- before writing this migration), so no question here relies on the
-- schema's theoretical (but UI-unsupported) multiple-correct-choice
-- allowance.
--
-- Each question's 4 choices are inserted in a single statement, so the
-- deferred `enforce_at_least_one_correct` constraint trigger (0014) never
-- observes a question with zero correct choices mid-transaction — same
-- approach 0027/0069 used.
--
-- Quiz numbers were deliberately chosen to avoid reusing the lesson's own
-- example numbers where the same skill is being tested (0069 followed the
-- same practice) — e.g. the lesson's showcase multi-rule number is 90 and
-- its real-life example is 45, so the quiz uses 65/84/85/105/etc. instead.
--
-- MATH VERIFIED INDEPENDENTLY (via Python modulo/digit-sum checks, not by
-- hand) before writing this migration:
--   Lesson:
--     24 / 6 = 4 r0 (divisible);  25 / 6 = 4 r1 (not divisible)
--     div by 2: 18,42,96 yes; 75 no
--     div by 5: 35,120 yes; 47 no
--     div by 10: 40,150,200 yes; 126,205 no (205 is div by 5, not 10)
--     div by 3: 123 (1+2+3=6) yes; 124 (1+2+4=7) no
--     div by 9: 729 (7+2+9=18) yes; 725 (7+2+5=14) no
--     div by 6: 42 (div2 & div3, 4+2=6) yes; 44 (div2 but 4+4=8) no
--     90: divisible by 2,3,5,6,9,10 (all six checked independently, all true)
--     45: divisible by 5 (ends in 5), 45 / 5 = 9 groups
--   Quiz (different numbers from the lesson, same skills):
--     84 div2 yes; 57,93,71 div2 no
--     65 div5 yes; 67,82,79 div5 no
--     85 div5 yes / div10 no; 60,110,190 div5 yes AND div10 yes
--     246 (2+4+6=12) div3 yes
--     918 (9+1+8=18) div9 yes
--     54 div2 (last digit 4) yes, div3 (5+4=9) yes -> div6 yes
--     63 (6+3=9) div9 yes -> 63 / 9 = 7 groups
--     105 (1+0+5=6) div3 yes, ends in 5 div5 yes (divisible by both);
--       80 div5-only, 51 div3-only, 82 divisible by neither
-- =============================================================================

do $$
declare
  v_lesson6_id uuid;
  v_quiz6_id   uuid;

  v_q_1  uuid; v_q_2  uuid; v_q_3  uuid; v_q_4  uuid; v_q_5  uuid;
  v_q_6  uuid; v_q_7  uuid; v_q_8  uuid; v_q_9  uuid; v_q_10 uuid;
begin

  -- ===========================================================================
  -- Lesson 6 — Using Divisibility Rules
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Using Divisibility Rules',
    'Learn quick rules to check whether a whole number is divisible by 2, 3, 5, 6, 9, or 10 without doing long division, with worked examples and simple grouping word problems.',
    'built_in',
    null,
    'grade_5'
  )
  returning id into v_lesson6_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson6_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn how to use divisibility rules to quickly tell whether a whole number is divisible by another number, without doing long division every time.'
  ),
  (
    v_lesson6_id, 2, 'vocabulary', 'What Does "Divisible" Mean?',
    E'A number is divisible by another number when dividing them results in a whole number with no remainder.\n\n' ||
    E'For example:\n' ||
    E'  24 ÷ 6 = 4, with no remainder.\n' ||
    E'  So, 24 is divisible by 6.\n\n' ||
    E'Compare this with:\n' ||
    E'  25 ÷ 6 = 4, remainder 1.\n' ||
    E'  Since there is a remainder, 25 is not divisible by 6.\n\n' ||
    E'Divisibility rules let us check this quickly, without doing the division.'
  ),
  (
    v_lesson6_id, 3, 'explanation', 'Divisibility by 2',
    E'A whole number is divisible by 2 if its last digit is 0, 2, 4, 6, or 8. These are the even digits. We only need to look at the last digit — the other digits do not matter.'
  ),
  (
    v_lesson6_id, 4, 'examples', 'Divisibility by 2 — Examples',
    E'18 → the last digit is 8, so 18 is divisible by 2.\n' ||
    E'42 → the last digit is 2, so 42 is divisible by 2.\n' ||
    E'75 → the last digit is 5, so 75 is not divisible by 2.\n' ||
    E'96 → the last digit is 6, so 96 is divisible by 2.'
  ),
  (
    v_lesson6_id, 5, 'explanation', 'Divisibility by 5',
    E'A whole number is divisible by 5 if its last digit is 0 or 5.'
  ),
  (
    v_lesson6_id, 6, 'examples', 'Divisibility by 5 — Examples',
    E'35 → the last digit is 5, so 35 is divisible by 5.\n' ||
    E'120 → the last digit is 0, so 120 is divisible by 5.\n' ||
    E'47 → the last digit is 7, so 47 is not divisible by 5.'
  ),
  (
    v_lesson6_id, 7, 'explanation', 'Divisibility by 10',
    E'A whole number is divisible by 10 if its last digit is 0.\n\n' ||
    E'This rule is close to the rule for 5, but not the same: every number divisible by 10 is also divisible by 5, but not every number divisible by 5 is divisible by 10.'
  ),
  (
    v_lesson6_id, 8, 'examples', 'Divisibility by 10 — Examples',
    E'40 → the last digit is 0, so 40 is divisible by 10.\n' ||
    E'150 → the last digit is 0, so 150 is divisible by 10.\n' ||
    E'126 → the last digit is 6, so 126 is not divisible by 10.\n\n' ||
    E'Compare 200 and 205:\n' ||
    E'  200 ends in 0, so it is divisible by 10.\n' ||
    E'  205 ends in 5, so it is divisible by 5, but NOT by 10.'
  ),
  (
    v_lesson6_id, 9, 'explanation', 'Divisibility by 3',
    E'To check divisibility by 3, add all the digits of the number. If the sum of the digits is divisible by 3, then the original number is divisible by 3 too.'
  ),
  (
    v_lesson6_id, 10, 'examples', 'Divisibility by 3 — Examples',
    E'123 → 1 + 2 + 3 = 6. Since 6 is divisible by 3, 123 is divisible by 3.\n' ||
    E'124 → 1 + 2 + 4 = 7. Since 7 is not divisible by 3, 124 is not divisible by 3.'
  ),
  (
    v_lesson6_id, 11, 'explanation', 'Divisibility by 9',
    E'To check divisibility by 9, add all the digits of the number. If the digit sum is divisible by 9, then the original number is divisible by 9.\n\n' ||
    E'This rule looks like the rule for 3, but the digit sum has to be divisible by 9, not just by 3.'
  ),
  (
    v_lesson6_id, 12, 'examples', 'Divisibility by 9 — Examples',
    E'729 → 7 + 2 + 9 = 18. Since 18 is divisible by 9, 729 is divisible by 9.\n' ||
    E'725 → 7 + 2 + 5 = 14. Since 14 is not divisible by 9, 725 is not divisible by 9.'
  ),
  (
    v_lesson6_id, 13, 'explanation', 'Divisibility by 6',
    E'A number is divisible by 6 if it is divisible by both 2 and 3. Check both rules — the number must pass both checks.'
  ),
  (
    v_lesson6_id, 14, 'examples', 'Divisibility by 6 — Examples',
    E'42:\n' ||
    E'  Divisible by 2? Last digit is 2, so yes.\n' ||
    E'  Divisible by 3? 4 + 2 = 6, which is divisible by 3, so yes.\n' ||
    E'  Since 42 passes both checks, 42 is divisible by 6.\n\n' ||
    E'44:\n' ||
    E'  Divisible by 2? Last digit is 4, so yes.\n' ||
    E'  Divisible by 3? 4 + 4 = 8, which is not divisible by 3, so no.\n' ||
    E'  Since 44 fails the check for 3, 44 is not divisible by 6.'
  ),
  (
    v_lesson6_id, 15, 'vocabulary', 'Divisibility Rules at a Glance',
    E'Divisor 2: last digit is 0, 2, 4, 6, or 8\n' ||
    E'Divisor 3: sum of digits is divisible by 3\n' ||
    E'Divisor 5: last digit is 0 or 5\n' ||
    E'Divisor 6: divisible by both 2 and 3\n' ||
    E'Divisor 9: sum of digits is divisible by 9\n' ||
    E'Divisor 10: last digit is 0'
  ),
  (
    v_lesson6_id, 16, 'examples', 'Applying Multiple Rules',
    E'Let''s check which numbers 90 is divisible by.\n' ||
    E'  Divisible by 2? Last digit is 0, so yes.\n' ||
    E'  Divisible by 3? 9 + 0 = 9, which is divisible by 3, so yes.\n' ||
    E'  Divisible by 5? Last digit is 0, so yes.\n' ||
    E'  Divisible by 6? Divisible by both 2 and 3, so yes.\n' ||
    E'  Divisible by 9? 9 + 0 = 9, which is divisible by 9, so yes.\n' ||
    E'  Divisible by 10? Last digit is 0, so yes.\n\n' ||
    E'90 is divisible by 2, 3, 5, 6, 9, and 10.'
  ),
  (
    v_lesson6_id, 17, 'examples', 'Real-Life Applications',
    E'There are 45 pencils. Can they be placed into groups of 5 with none left over?\n' ||
    E'  Check divisibility by 5: the last digit of 45 is 5, so 45 is divisible by 5.\n' ||
    E'  Yes, the pencils can be grouped equally into groups of 5, with 9 pencils in each group.'
  ),
  (
    v_lesson6_id, 18, 'explanation', 'Common Mistakes to Avoid',
    E'Mistake 1: Checking only the first digit instead of the last digit for the rules for 2, 5, and 10.\n\n' ||
    E'Mistake 2: For divisibility by 3 or 9, looking only at the last digit instead of adding all the digits.\n\n' ||
    E'Mistake 3: Assuming a number divisible by 2 is automatically divisible by 6. Divisibility by 6 needs both 2 and 3.\n\n' ||
    E'Mistake 4: Confusing divisibility by 5 and 10. A number ending in 5 is divisible by 5, but not by 10.'
  ),
  (
    v_lesson6_id, 19, 'summary', 'Remember',
    E'  - A number is divisible by another number when there is no remainder.\n' ||
    E'  - Divisibility by 2: last digit is 0, 2, 4, 6, or 8.\n' ||
    E'  - Divisibility by 5: last digit is 0 or 5.\n' ||
    E'  - Divisibility by 10: last digit is 0.\n' ||
    E'  - Divisibility by 3: sum of digits is divisible by 3.\n' ||
    E'  - Divisibility by 9: sum of digits is divisible by 9.\n' ||
    E'  - Divisibility by 6: divisible by both 2 and 3.'
  );

  -- ===========================================================================
  -- Quiz 6 — built-in Internal Quiz for Lesson 6
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 6: Using Divisibility Rules',
    'internal', 'built_in', null, 'grade_5', true, true
  )
  returning id into v_quiz6_id;

  -- --- Q1 (basic: identify the rule) -----------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Using Divisibility Rules',
    'Which statement correctly describes how to check if a number is divisible by 3?',
    'Divisibility by 3 is checked using the digit-sum rule: add all the digits of the number, and if that sum is divisible by 3, the original number is divisible by 3 as well.'
  )
  returning id into v_q_1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_1, 'Add all the digits; if the sum is divisible by 3, the number is divisible by 3', true,  1),
    (v_q_1, 'Check if the last digit is 0, 3, or 6', false, 2),
    (v_q_1, 'Check if the last digit is divisible by 3', false, 3),
    (v_q_1, 'Divide the number by 2 first', false, 4);

  -- --- Q2 (basic/intermediate: divisibility by 2) -----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Using Divisibility Rules',
    'Which of the following numbers is divisible by 2?',
    'A number is divisible by 2 if its last digit is 0, 2, 4, 6, or 8. 84 ends in 4, so it is divisible by 2. 57, 93, and 71 all end in odd digits, so none of them are divisible by 2.'
  )
  returning id into v_q_2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_2, '84', true,  1),
    (v_q_2, '57', false, 2),
    (v_q_2, '93', false, 3),
    (v_q_2, '71', false, 4);

  -- --- Q3 (basic/intermediate: divisibility by 5) -----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Using Divisibility Rules',
    'Which of the following numbers is divisible by 5?',
    'A number is divisible by 5 if its last digit is 0 or 5. 65 ends in 5, so it is divisible by 5. 67, 82, and 79 do not end in 0 or 5, so none of them are divisible by 5.'
  )
  returning id into v_q_3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_3, '65', true,  1),
    (v_q_3, '67', false, 2),
    (v_q_3, '82', false, 3),
    (v_q_3, '79', false, 4);

  -- --- Q4 (intermediate: distinguishing 5 from 10) -----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Using Divisibility Rules',
    'Which number is divisible by 5 but NOT divisible by 10?',
    '85 ends in 5, so it is divisible by 5 — but since it does not end in 0, it is not divisible by 10. 60, 110, and 190 all end in 0, so each of them is divisible by both 5 and 10.'
  )
  returning id into v_q_4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_4, '85',  true,  1),
    (v_q_4, '60',  false, 2),
    (v_q_4, '110', false, 3),
    (v_q_4, '190', false, 4);

  -- --- Q5 (intermediate: digit-sum rule for 3) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Using Divisibility Rules',
    'Using the digit-sum rule, is 246 divisible by 3?',
    'The digits of 246 add up to 2 + 4 + 6 = 12. Since 12 is divisible by 3, 246 is divisible by 3. The rule uses the sum of all the digits, not just the last digit.'
  )
  returning id into v_q_5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_5, 'Yes — because 2 + 4 + 6 = 12, and 12 is divisible by 3', true,  1),
    (v_q_5, 'No — because 2 + 4 + 6 = 12, and 12 is not divisible by 3', false, 2),
    (v_q_5, 'Yes — because the last digit, 6, is divisible by 3', false, 3),
    (v_q_5, 'No — because the number does not end in 3, 6, or 9', false, 4);

  -- --- Q6 (intermediate: digit-sum rule for 9) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Using Divisibility Rules',
    'What is the digit sum of 918, and is 918 divisible by 9?',
    'The digits of 918 add up to 9 + 1 + 8 = 18. Since 18 is divisible by 9, 918 is divisible by 9. Divisibility by 9 depends on the digit sum, not on the last digit alone.'
  )
  returning id into v_q_6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_6, 'Yes — because 9 + 1 + 8 = 18, and 18 is divisible by 9', true,  1),
    (v_q_6, 'Yes — because 9 + 1 + 8 = 18, and 18 is divisible by 3', false, 2),
    (v_q_6, 'No — because 9 + 1 + 8 = 17', false, 3),
    (v_q_6, 'No — because the last digit is 8, not 9', false, 4);

  -- --- Q7 (intermediate: divisibility by 6, both 2 and 3) ----------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Using Divisibility Rules',
    'Is 54 divisible by 6?',
    'A number is divisible by 6 only if it passes both the divisibility-by-2 check and the divisibility-by-3 check. 54 ends in 4 (divisible by 2), and 5 + 4 = 9 is divisible by 3, so 54 is divisible by 6.'
  )
  returning id into v_q_7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_7, 'Yes — 54 is divisible by 2 (last digit 4) and by 3 (5 + 4 = 9), so it is divisible by 6', true,  1),
    (v_q_7, 'Yes — 54 is divisible by 2, so it must be divisible by 6', false, 2),
    (v_q_7, 'No — 54 is divisible by 2 but 5 + 4 = 9 is not divisible by 3', false, 3),
    (v_q_7, 'No — 54 is an even number, so it cannot be divisible by 6', false, 4);

  -- --- Q8 (reasoning: identify which rule to use) -------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Using Divisibility Rules',
    'Maria wants to check whether 372 is divisible by 9. What should she do?',
    'To check divisibility by 9, add all the digits of the number and see if that sum is divisible by 9. Checking the last digit or checking for evenness does not work for divisibility by 9.'
  )
  returning id into v_q_8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_8, 'Add all the digits of 372 and check if the sum is divisible by 9', true,  1),
    (v_q_8, 'Check whether the last digit of 372 is 0 or 9', false, 2),
    (v_q_8, 'Check whether 372 is an even number', false, 3),
    (v_q_8, 'Divide 372 by 3 and see if the quotient is a whole number', false, 4);

  -- --- Q9 (application: grouping word problem) -----------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Using Divisibility Rules',
    'There are 63 apples. Can they be arranged into groups of 9 with none left over?',
    'Adding the digits of 63 gives 6 + 3 = 9, and 9 is divisible by 9, so 63 is divisible by 9. This means 63 apples can be arranged into groups of 9 with none left over.'
  )
  returning id into v_q_9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_9, 'Yes, because 6 + 3 = 9, and 9 is divisible by 9', true,  1),
    (v_q_9, 'No, because 63 is an odd number', false, 2),
    (v_q_9, 'No, because 6 + 3 = 9 is not divisible by 9', false, 3),
    (v_q_9, 'Yes, because the last digit is 3', false, 4);

  -- --- Q10 (application: multiple rules together) ---------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Using Divisibility Rules',
    'Which number is divisible by both 3 and 5?',
    '105 ends in 5 (divisible by 5) and its digits add up to 1 + 0 + 5 = 6, which is divisible by 3, so 105 is divisible by both. 80 is divisible by 5 only, 51 is divisible by 3 only, and 82 is divisible by neither.'
  )
  returning id into v_q_10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q_10, '105', true,  1),
    (v_q_10, '80',  false, 2),
    (v_q_10, '51',  false, 3),
    (v_q_10, '82',  false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz6_id, v_q_1,  1),
    (v_quiz6_id, v_q_2,  2),
    (v_quiz6_id, v_q_3,  3),
    (v_quiz6_id, v_q_4,  4),
    (v_quiz6_id, v_q_5,  5),
    (v_quiz6_id, v_q_6,  6),
    (v_quiz6_id, v_q_7,  7),
    (v_quiz6_id, v_q_8,  8),
    (v_quiz6_id, v_q_9,  9),
    (v_quiz6_id, v_q_10, 10);

  -- ===========================================================================
  -- Link Lesson 6 -> Quiz 6 (0032's linked_quiz_id) — both ids are already
  -- local variables from this same DO block.
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz6_id where id = v_lesson6_id;

end $$;
