-- =============================================================================
-- Migration: 0072_seed_grade5_understanding_and_solving_probability.sql
-- Content-seeding migration, following the same conventions established by
-- 0027 (Grade 4 seed) / 0029 (lesson_pages) / 0033 (lesson -> quiz link) /
-- 0071 (Grade 5 Lesson 7 / Quiz 7 seed — the most recent same-shape seed).
--
-- Seeds Grade 5 built-in content:
--   Lesson 8 — Understanding and Solving Probability (10 lesson_pages)
--   Quiz 8   — Internal Quiz for Lesson 8 (10 questions, 4 choices each)
--
-- Single migration (no schema-then-content split) because every schema
-- piece this needs (lesson_pages from 0028/0030, lessons.linked_quiz_id
-- from 0032) already exists as of this project's current migration state
-- (through 0071) — only new rows are added here, matching 0071's approach.
--
-- All ids are database-generated (gen_random_uuid(), the default on every
-- affected table's id column) and captured via `returning ... into`, never
-- hardcoded. lessons/quizzes rows use source_type = 'built_in',
-- created_by = null, grade_level = 'grade_5', matching 0027/0071's pattern.
-- question_bank.topic is tagged to match the owning lesson's title (matches
-- 0027/0071's tagging), for the Highest/Lowest Performing Topics dashboard
-- metric (schema comment, 0008).
--
-- Each question's 4 choices are inserted in a single statement, so the
-- deferred `enforce_at_least_one_correct` constraint trigger (0014) never
-- observes a question with zero correct choices mid-transaction (matches
-- 0027/0071's pattern).
--
-- Quiz numbers deliberately differ from the lesson's worked-example numbers
-- (per the one-to-one Lesson 8 <-> Quiz 8 pairing requested), so the quiz
-- tests understanding of the probability method rather than memorized
-- lesson examples. Every probability calculation below was independently
-- recomputed (favorable outcomes / total outcomes, simplified where noted)
-- before writing the question.
-- =============================================================================

do $$
declare
  v_lesson_id uuid;
  v_quiz_id   uuid;

  -- Quiz 8 — Understanding and Solving Probability
  v_q1  uuid; v_q2  uuid; v_q3  uuid; v_q4  uuid; v_q5  uuid;
  v_q6  uuid; v_q7  uuid; v_q8  uuid; v_q9  uuid; v_q10 uuid;
begin

  -- ===========================================================================
  -- Lesson 8 — Understanding and Solving Probability
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level)
  values (
    'Understanding and Solving Probability',
    'Learn how to describe the likelihood of events and calculate simple probabilities as a fraction of favorable outcomes over total outcomes, using coins, dice, and bags of colored objects.',
    'built_in',
    null,
    'grade_5'
  )
  returning id into v_lesson_id;

  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn about probability — a way of describing how likely something is to happen. We will use familiar situations like flipping a coin, rolling a die, and picking objects from a bag to understand and solve simple probability problems.'
  ),
  (
    v_lesson_id, 2, 'vocabulary', 'Events and Outcomes',
    E'An outcome is one possible result of an experiment, like flipping a coin or rolling a die.\n\n' ||
    E'For example, when rolling a standard six-sided die, the possible outcomes are:\n' ||
    E'  1, 2, 3, 4, 5, and 6\n\n' ||
    E'An event is a specific result or group of results we are interested in.\n\n' ||
    E'For example, the event "rolling an even number" includes the outcomes 2, 4, and 6.'
  ),
  (
    v_lesson_id, 3, 'explanation', 'Describing Likelihood',
    E'We can describe how likely an event is using words like impossible, unlikely, equally likely, likely, and certain.\n\n' ||
    E'Impossible: an event that cannot happen.\n' ||
    E'  Example: rolling a 7 on a standard six-sided die.\n\n' ||
    E'Certain: an event that will always happen.\n' ||
    E'  Example: rolling a number less than 7 on a standard six-sided die.\n\n' ||
    E'Likely: an event that has a greater chance of happening than not happening.\n\n' ||
    E'Unlikely: an event that has a smaller chance of happening than not happening.\n\n' ||
    E'Equally likely: events that have the same chance of happening.\n' ||
    E'  Example: flipping heads or tails on a fair coin.'
  ),
  (
    v_lesson_id, 4, 'explanation', 'Favorable Outcomes and the Probability Formula',
    E'A favorable outcome is an outcome that matches the event we are looking for.\n\n' ||
    E'For example, a bag contains 3 red balls and 2 blue balls. If we want to pick a red ball, the favorable outcomes are the 3 red balls.\n\n' ||
    E'We can calculate probability using this formula:\n\n' ||
    E'  Probability = Number of favorable outcomes / Total number of possible outcomes\n\n' ||
    E'For the bag above, the probability of picking a red ball is:\n\n' ||
    E'  3 favorable outcomes / 5 total outcomes = 3/5'
  ),
  (
    v_lesson_id, 5, 'examples', 'Solving Simple Probability Problems',
    E'Worked Example 1:\n' ||
    E'  A fair six-sided die is rolled. What is the probability of rolling a 4?\n' ||
    E'  Favorable outcomes: 4 (just 1 outcome)\n' ||
    E'  Total outcomes: 1, 2, 3, 4, 5, 6 (6 outcomes)\n' ||
    E'  Probability = 1/6\n\n' ||
    E'Worked Example 2:\n' ||
    E'  A die is rolled. What is the probability of rolling an even number?\n' ||
    E'  Favorable outcomes: 2, 4, 6 (3 outcomes)\n' ||
    E'  Total outcomes: 6\n' ||
    E'  Probability = 3/6, which simplifies to 1/2'
  ),
  (
    v_lesson_id, 6, 'explanation', 'Probability as a Fraction from 0 to 1',
    E'Probability is often written as a fraction.\n' ||
    E'  numerator = number of favorable outcomes\n' ||
    E'  denominator = total number of possible outcomes\n\n' ||
    E'Probability is always between 0 and 1.\n' ||
    E'  0 means the event is impossible.\n' ||
    E'  1 means the event is certain.\n\n' ||
    E'For example, the probability of rolling a 7 on a standard six-sided die is 0/6 = 0, because it is impossible. The probability of rolling a number less than 7 is 6/6 = 1, because it is certain.'
  ),
  (
    v_lesson_id, 7, 'examples', 'Comparing Probabilities',
    E'Worked Example:\n' ||
    E'  A bag contains 6 red balls and 2 blue balls.\n' ||
    E'  Probability of picking red = 6/8\n' ||
    E'  Probability of picking blue = 2/8\n' ||
    E'  Since 6/8 is greater than 2/8, picking a red ball is more likely than picking a blue ball.'
  ),
  (
    v_lesson_id, 8, 'explanation', 'Real-Life Applications of Probability',
    E'Probability helps us make sense of everyday situations, such as:\n' ||
    E'  - predicting the chance of winning a simple game\n' ||
    E'  - deciding how likely it is to pick a certain colored object from a bag\n' ||
    E'  - understanding the chances involved in flipping a coin or rolling a die during a classroom activity\n\n' ||
    E'Thinking about favorable outcomes and total outcomes helps us describe these chances using numbers.'
  ),
  (
    v_lesson_id, 9, 'explanation', 'Common Mistakes to Avoid',
    E'Mistake 1: Confusing the number of favorable outcomes with the total number of outcomes.\n' ||
    E'  Always identify both numbers separately before writing the probability.\n\n' ||
    E'Mistake 2: Using the total number of objects as the numerator.\n' ||
    E'  The numerator should only be the favorable outcomes, not the total.\n\n' ||
    E'Mistake 3: Forgetting to count all possible outcomes.\n' ||
    E'  Make sure every possible outcome is included in the total.\n\n' ||
    E'Mistake 4: Thinking an event with more favorable outcomes is less likely.\n' ||
    E'  More favorable outcomes usually mean a greater chance of the event happening.\n\n' ||
    E'Mistake 5: Confusing impossible with unlikely.\n' ||
    E'  Impossible means the event can never happen; unlikely means it can happen, but not often.'
  ),
  (
    v_lesson_id, 10, 'summary', 'Remember',
    E'  - An outcome is one possible result of an experiment.\n' ||
    E'  - An event is a specific result or group of results we are interested in.\n' ||
    E'  - Impossible, unlikely, equally likely, likely, and certain describe how likely an event is.\n' ||
    E'  - Probability = Number of favorable outcomes / Total number of possible outcomes.\n' ||
    E'  - Probability is always between 0 (impossible) and 1 (certain).\n' ||
    E'  - Compare probabilities by comparing their fractions.'
  );

  -- ===========================================================================
  -- Quiz 8 — built-in Internal Quiz for Lesson 8
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 8: Understanding and Solving Probability',
    'internal', 'built_in', null, 'grade_5', true, true
  )
  returning id into v_quiz_id;

  -- --- Q1 (basic — identify possible outcomes) ------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding and Solving Probability',
    'A coin is flipped. What are all the possible outcomes?',
    'A coin has exactly two sides, so the only possible outcomes are Heads and Tails.'
  )
  returning id into v_q1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1, 'Heads and Tails',           true,  1),
    (v_q1, 'Heads, Tails, and Edge',    false, 2),
    (v_q1, '1, 2, 3, 4, 5, 6',          false, 3),
    (v_q1, 'Red and Blue',              false, 4);

  -- --- Q2 (basic — classify likelihood: certain) ----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding and Solving Probability',
    'What best describes the chance of rolling a number greater than 0 on a standard six-sided die?',
    'Every face of a standard six-sided die (1, 2, 3, 4, 5, 6) is greater than 0, so this event will always happen — it is certain.'
  )
  returning id into v_q2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q2, 'Impossible',      false, 1),
    (v_q2, 'Unlikely',        false, 2),
    (v_q2, 'Certain',         true,  3),
    (v_q2, 'Equally likely',  false, 4);

  -- --- Q3 (basic — identify an impossible event) ----------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding and Solving Probability',
    'Which event is impossible?',
    'A standard six-sided die only has the faces 1 through 6, so rolling a 7 can never happen — it is impossible. The other events can all actually occur.'
  )
  returning id into v_q3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q3, 'Rolling a 6 on a standard six-sided die',        false, 1),
    (v_q3, 'Rolling a 7 on a standard six-sided die',        true,  2),
    (v_q3, 'Flipping heads on a coin',                       false, 3),
    (v_q3, 'Picking a red ball from a bag of all red balls', false, 4);

  -- --- Q4 (basic/intermediate — identify favorable outcomes) ---------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding and Solving Probability',
    'A bag contains 4 yellow marbles and 3 green marbles. How many favorable outcomes are there for picking a yellow marble?',
    'The favorable outcomes for picking a yellow marble are the yellow marbles themselves, and there are 4 of them.'
  )
  returning id into v_q4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q4, '3', false, 1),
    (v_q4, '4', true,  2),
    (v_q4, '7', false, 3),
    (v_q4, '1', false, 4);

  -- --- Q5 (intermediate — calculate a simple probability) -------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding and Solving Probability',
    'A bag contains 4 yellow marbles and 3 green marbles. What is the probability of picking a yellow marble?',
    'There are 4 favorable outcomes (yellow marbles) out of 4 + 3 = 7 total marbles, so the probability is 4/7.'
  )
  returning id into v_q5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q5, '4/7', true,  1),
    (v_q5, '3/7', false, 2),
    (v_q5, '4/3', false, 3),
    (v_q5, '3/4', false, 4);

  -- --- Q6 (intermediate — probability as a fraction) ------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding and Solving Probability',
    'A standard six-sided die is rolled. What is the probability of rolling an odd number?',
    'The odd numbers on a standard six-sided die are 1, 3, and 5 — 3 favorable outcomes out of 6 total outcomes, so the probability is 3/6 (which simplifies to 1/2).'
  )
  returning id into v_q6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q6, '1/6', false, 1),
    (v_q6, '3/6', true,  2),
    (v_q6, '4/6', false, 3),
    (v_q6, '6/6', false, 4);

  -- --- Q7 (intermediate — solve a simple probability word problem) ---------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding and Solving Probability',
    'A standard six-sided die is rolled. What is the probability of rolling a number greater than 4?',
    'The numbers greater than 4 on a standard six-sided die are 5 and 6 — 2 favorable outcomes out of 6 total outcomes, so the probability is 2/6 (which simplifies to 1/3).'
  )
  returning id into v_q7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q7, '2/6', true,  1),
    (v_q7, '4/6', false, 2),
    (v_q7, '1/6', false, 3),
    (v_q7, '5/6', false, 4);

  -- --- Q8 (intermediate — probability of a certain event as a fraction) ----
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding and Solving Probability',
    'A bag contains only 5 blue balls. What is the probability of picking a blue ball?',
    'All 5 balls in the bag are blue, so there are 5 favorable outcomes out of 5 total outcomes: 5/5 = 1. A probability of 1 means the event is certain.'
  )
  returning id into v_q8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q8, '0/5',       false, 1),
    (v_q8, '1/5',       false, 2),
    (v_q8, '5/5, or 1', true,  3),
    (v_q8, '5/1',       false, 4);

  -- --- Q9 (application — compare two simple probabilities) ------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding and Solving Probability',
    'A jar contains 8 red candies and 2 green candies. Which color is more likely to be picked?',
    'The probability of picking red is 8/10, and the probability of picking green is 2/10. Since 8/10 is greater than 2/10, red is more likely to be picked.'
  )
  returning id into v_q9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q9, 'Red, because 8/10 is greater than 2/10',   true,  1),
    (v_q9, 'Green, because 2/10 is greater than 8/10', false, 2),
    (v_q9, 'Both are equally likely',                  false, 3),
    (v_q9, 'Cannot be determined',                     false, 4);

  -- --- Q10 (application — real-life probability word problem) --------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding and Solving Probability',
    'A classroom has 15 boys and 10 girls. If a teacher randomly picks one student to be the line leader, what is the probability that the student picked is a girl?',
    'There are 10 favorable outcomes (girls) out of 15 + 10 = 25 total students, so the probability is 10/25 (which simplifies to 2/5).'
  )
  returning id into v_q10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q10, '10/25', true,  1),
    (v_q10, '15/25', false, 2),
    (v_q10, '10/15', false, 3),
    (v_q10, '25/10', false, 4);

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
  -- Lesson 8 -> Quiz 8 link (0032's linked_quiz_id, same pattern as 0033/0071)
  -- ===========================================================================
  update public.lessons set linked_quiz_id = v_quiz_id where id = v_lesson_id;

end $$;
