-- =============================================================================
-- Migration: 0085_seed_grade6_quiz4_and_link_exponents_gemdas.sql
-- Content-only migration (no schema change). Run here as two guarded do $$
-- blocks in sequence:
--   Part 1 — seeds Grade 6 Quiz 4 ("Exponents and GEMDAS"): 10
--            question_bank questions, their question_choices, and the
--            quiz_questions ordering.
--   Part 2 — links Grade 6 Lesson 4 to Quiz 4 via lessons.linked_quiz_id,
--            the same optional "Take Quiz" convenience link used
--            elsewhere in the project.
--
-- PREREQUISITE: Migration 0078_seed_grade6_lesson4_exponents_gemdas.sql
-- must already have run — it creates the Grade 6 Lesson 4 row that
-- Part 2 below links against.
--
-- No new schema, no changes to Lesson/Quiz 1-3.
--
-- Every quiz answer/distractor below was independently solved and
-- verified — see the chat response's final validation section for the
-- full working.
-- =============================================================================

-- ===========================================================================
-- PART 1 — Grade 6 Quiz 4: Exponents and GEMDAS (+ questions/choices)
-- ===========================================================================

do $$
declare
  v_quiz_id uuid;
  v_q_id    uuid;
begin

  if exists (
    select 1 from public.quizzes
    where title = 'Quiz 4: Exponents and GEMDAS'
      and source_type = 'built_in'
      and grade_level = 'grade_6'
  ) then
    raise notice '0085: Grade 6 Quiz 4 (Exponents and GEMDAS) already exists — skipping, not creating a duplicate.';
    return;
  end if;

  insert into public.quizzes (title, quiz_type, source_type, grade_level)
  values ('Quiz 4: Exponents and GEMDAS', 'internal', 'built_in', 'grade_6')
  returning id into v_quiz_id;

  -- ---------------------------------------------------------------------
  -- Q1 — identify the base
  -- 7^4: base 7, exponent 4. Base is the number being multiplied.
  -- ---------------------------------------------------------------------
  insert into public.question_bank (source_type, topic, prompt_text, explanation_text)
  values ('built_in', 'Exponents - identifying the base',
    'In 7\u2074, what is the base?',
    'The base is the number being multiplied. In 7\u2074, 7 is written as a factor 4 times, so 7 is the base.')
  returning id into v_q_id;

  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
  (v_q_id, '7', true, 1),
  (v_q_id, '4', false, 2),
  (v_q_id, '11', false, 3),
  (v_q_id, '28', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values (v_quiz_id, v_q_id, 1);

  -- ---------------------------------------------------------------------
  -- Q2 — identify the exponent
  -- 7^4: exponent 4.
  -- ---------------------------------------------------------------------
  insert into public.question_bank (source_type, topic, prompt_text, explanation_text)
  values ('built_in', 'Exponents - identifying the exponent',
    'In 7\u2074, what is the exponent -- the number that tells how many times the base is used as a factor?',
    'The exponent is written above and to the right of the base and tells how many times the base is used as a factor. In 7\u2074, the exponent is 4.')
  returning id into v_q_id;

  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
  (v_q_id, '4', true, 1),
  (v_q_id, '7', false, 2),
  (v_q_id, '3', false, 3),
  (v_q_id, '11', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values (v_quiz_id, v_q_id, 2);

  -- ---------------------------------------------------------------------
  -- Q3 — repeated multiplication -> exponential form
  -- 8x8x8x8x8 = 8^5 (8 repeated as a factor 5 times).
  -- ---------------------------------------------------------------------
  insert into public.question_bank (source_type, topic, prompt_text, explanation_text)
  values ('built_in', 'Exponents - repeated multiplication to exponential form',
    'Which exponential form is equal to 8 \u00d7 8 \u00d7 8 \u00d7 8 \u00d7 8?',
    '8 is repeated as a factor 5 times, so the base is 8 and the exponent is 5: 8 \u00d7 8 \u00d7 8 \u00d7 8 \u00d7 8 = 8\u2075.')
  returning id into v_q_id;

  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
  (v_q_id, '8\u2075', true, 1),
  (v_q_id, '5\u2078', false, 2),
  (v_q_id, '8 \u00d7 5', false, 3),
  (v_q_id, '40', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values (v_quiz_id, v_q_id, 3);

  -- ---------------------------------------------------------------------
  -- Q4 — correctly interpreting a power (5^2 is NOT 5x2)
  -- 5^2 = 5x5 = 25.
  -- ---------------------------------------------------------------------
  insert into public.question_bank (source_type, topic, prompt_text, explanation_text)
  values ('built_in', 'Exponents - interpreting a power correctly',
    'What does 5\u00b2 mean?',
    '5\u00b2 means 5 is used as a factor 2 times: 5 \u00d7 5 = 25. An exponent tells you how many times to WRITE the base -- it does not mean "multiply the base by the exponent."')
  returning id into v_q_id;

  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
  (v_q_id, '5 \u00d7 5', true, 1),
  (v_q_id, '5 \u00d7 2', false, 2),
  (v_q_id, '5 + 5', false, 3),
  (v_q_id, '2 \u00d7 2', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values (v_quiz_id, v_q_id, 4);

  -- ---------------------------------------------------------------------
  -- Q5 — evaluate a power
  -- 3^4 = 3x3x3x3 = 81.
  -- ---------------------------------------------------------------------
  insert into public.question_bank (source_type, topic, prompt_text, explanation_text)
  values ('built_in', 'Exponents - evaluating a power',
    'What is 3\u2074?',
    '3\u2074 = 3 \u00d7 3 \u00d7 3 \u00d7 3. Multiply step by step: 3 \u00d7 3 = 9, 9 \u00d7 3 = 27, 27 \u00d7 3 = 81. So 3\u2074 = 81.')
  returning id into v_q_id;

  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
  (v_q_id, '81', true, 1),
  (v_q_id, '12', false, 2),
  (v_q_id, '64', false, 3),
  (v_q_id, '34', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values (v_quiz_id, v_q_id, 5);

  -- ---------------------------------------------------------------------
  -- Q6 — grouping symbols
  -- (9-4)^2 = 5^2 = 25.
  -- ---------------------------------------------------------------------
  insert into public.question_bank (source_type, topic, prompt_text, explanation_text)
  values ('built_in', 'GEMDAS - grouping symbols',
    'Evaluate: (9 \u2212 4)\u00b2',
    'Solve inside the grouping symbols first: 9 \u2212 4 = 5. Then evaluate the exponent: 5\u00b2 = 5 \u00d7 5 = 25.')
  returning id into v_q_id;

  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
  (v_q_id, '25', true, 1),
  (v_q_id, '5', false, 2),
  (v_q_id, '77', false, 3),
  (v_q_id, '10', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values (v_quiz_id, v_q_id, 6);

  -- ---------------------------------------------------------------------
  -- Q7 — identify the first operation (concept)
  -- 6 + 3 x 2^2 -> evaluate the exponent 2^2 first.
  -- ---------------------------------------------------------------------
  insert into public.question_bank (source_type, topic, prompt_text, explanation_text)
  values ('built_in', 'GEMDAS - identifying the first operation',
    'In the expression 6 + 3 \u00d7 2\u00b2, what should be done first?',
    'There are no grouping symbols, so the next step in GEMDAS is the exponent. Evaluate 2\u00b2 first, before the multiplication or the addition.')
  returning id into v_q_id;

  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
  (v_q_id, 'Evaluate the exponent, 2\u00b2', true, 1),
  (v_q_id, 'Multiply 3 \u00d7 2', false, 2),
  (v_q_id, 'Add 6 + 3', false, 3),
  (v_q_id, 'Work left to right starting with 6 + 3', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values (v_quiz_id, v_q_id, 7);

  -- ---------------------------------------------------------------------
  -- Q8 — multiplication/division left to right
  -- 24 / 6 x 2 = 4 x 2 = 8 (NOT multiplication first).
  -- ---------------------------------------------------------------------
  insert into public.question_bank (source_type, topic, prompt_text, explanation_text)
  values ('built_in', 'GEMDAS - multiplication and division, left to right',
    'Evaluate: 24 \u00f7 6 \u00d7 2',
    'Multiplication and division have equal priority and are solved left to right. Division comes first here: 24 \u00f7 6 = 4. Then multiply: 4 \u00d7 2 = 8.')
  returning id into v_q_id;

  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
  (v_q_id, '8', true, 1),
  (v_q_id, '2', false, 2),
  (v_q_id, '4', false, 3),
  (v_q_id, '288', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values (v_quiz_id, v_q_id, 8);

  -- ---------------------------------------------------------------------
  -- Q9 — addition/subtraction left to right
  -- 18 - 5 + 3 = 13 + 3 = 16 (NOT addition first).
  -- ---------------------------------------------------------------------
  insert into public.question_bank (source_type, topic, prompt_text, explanation_text)
  values ('built_in', 'GEMDAS - addition and subtraction, left to right',
    'Evaluate: 18 \u2212 5 + 3',
    'Addition and subtraction have equal priority and are solved left to right. Subtraction comes first here: 18 \u2212 5 = 13. Then add: 13 + 3 = 16.')
  returning id into v_q_id;

  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
  (v_q_id, '16', true, 1),
  (v_q_id, '10', false, 2),
  (v_q_id, '13', false, 3),
  (v_q_id, '20', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values (v_quiz_id, v_q_id, 9);

  -- ---------------------------------------------------------------------
  -- Q10 — multi-step application: grouping + exponent + mult/div + add/sub
  -- 2x3^2 + 12/4 - 5 = 18 + 3 - 5 = 16.
  -- ---------------------------------------------------------------------
  insert into public.question_bank (source_type, topic, prompt_text, explanation_text)
  values ('built_in', 'GEMDAS - multi-step application',
    'Evaluate: 2 \u00d7 3\u00b2 + 12 \u00f7 4 \u2212 5',
    'Exponent first: 3\u00b2 = 9. Then multiplication/division, left to right: 2 \u00d7 9 = 18, then 12 \u00f7 4 = 3. Then addition/subtraction, left to right: 18 + 3 = 21, then 21 \u2212 5 = 16.')
  returning id into v_q_id;

  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
  (v_q_id, '16', true, 1),
  (v_q_id, '10', false, 2),
  (v_q_id, '34', false, 3),
  (v_q_id, '17', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values (v_quiz_id, v_q_id, 10);

end $$;

-- ===========================================================================
-- PART 2 — Link Grade 6 Lesson 4 to Quiz 4
-- ===========================================================================
-- Plain single-statement UPDATE (no do $$ block, no session variables).
-- This avoids the "relation v_lesson_id does not exist" error that some
-- SQL runners cause by splitting a file on every semicolon -- which breaks
-- a do $$ ... end $$; block apart and runs its inner lines outside of
-- PL/pgSQL, so a plain SELECT ... INTO variable is misread as SELECT ...
-- INTO TABLE. A single UPDATE ... FROM statement has no internal
-- semicolons, so it can't be split apart, and it silently does nothing
-- (0 rows updated) if either the lesson or the quiz row is missing,
-- instead of erroring.

update public.lessons l
set linked_quiz_id = q.id
from public.quizzes q
where l.title = 'Exponents and GEMDAS'
  and l.source_type = 'built_in'
  and l.grade_level = 'grade_6'
  and q.title = 'Quiz 4: Exponents and GEMDAS'
  and q.source_type = 'built_in'
  and q.grade_level = 'grade_6';
