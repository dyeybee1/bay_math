-- =============================================================================
-- Migration: 0065_seed_grade5_12hour_24hour_time.sql
--
-- Seeds the FIRST Grade 5 (MELC-level) built-in content — there is no
-- existing Grade 5 lesson/quiz to follow in this project yet, so this
-- migration follows the same conventions the Grade 4 seeds already
-- established (0027, 0061, 0062), which is the closest available
-- formatting reference, exactly as instructed:
--   Lesson 1 — Understanding 12-Hour and 24-Hour Time
--   Quiz 1   — Internal Quiz for Lesson 1 (10 questions, AM/PM, 12-hour and
--              24-hour reading, both conversion directions, real-life
--              schedules, mixed)
--
-- CONFIRMED AGAINST ACTUAL SCHEMA before writing this (same tables/columns
-- 0061/0062 already used for Grade 4 — re-checked, nothing changed since,
-- and `grade_level` already accepts 'grade_5' per `public.sections` /
-- `GradeLevel` (section.dart), so no schema change is needed to seed
-- Grade 5 content):
--   - `public.lessons` (0007) + `linked_quiz_id` (0032): Quiz 1 (Grade 5)
--     is created first, so its id is set directly on the lesson's own
--     insert — no separate linking migration needed.
--   - `public.lesson_pages` (0028): `section_type` reuses the same
--     free-text values already in use — 'introduction', 'vocabulary',
--     'explanation', 'examples', 'summary' — no new type invented.
--   - `worked_example` (0030) stays null on every page — it is fixed to
--     whole-number addition/subtraction (0030's column comment) and does
--     not model time conversion, so every page here is plain `body` text.
--   - `public.quizzes` (0009) + `assessment_type` (0043): ordinary
--     practice quiz, `assessment_type` left null.
--   - `public.question_bank` (0008): `topic` tagged to the owning lesson's
--     title, matching 0027's original convention.
--   - Each question's 4 choices inserted in a single statement, so the
--     deferred `enforce_at_least_one_correct` trigger (0014) never
--     observes a question with zero correct choices mid-transaction.
--   - All ids are database-generated (gen_random_uuid()), captured via
--     `returning ... into`, never hardcoded.
--
-- TIME CONVERSIONS INDEPENDENTLY VERIFIED for every lesson-page example
-- and every quiz question below (12-hour <-> 24-hour, minutes always
-- preserved, 12:00 AM = 00:00 midnight, 12:00 PM = 12:00 noon):
--   1:00 AM -> 01:00     7:00 AM -> 07:00     12:00 PM -> 12:00
--   1:00 PM -> 13:00     6:00 PM -> 18:00      9:00 PM -> 21:00
--   6:30 AM -> 06:30     12:45 PM -> 12:45     7:15 PM -> 19:15
--   11:45 PM -> 23:45    09:15 -> 9:15 AM      12:45 -> 12:45 PM
--   14:30 -> 2:30 PM     23:45 -> 11:45 PM     15:00 -> 3:00 PM
--   23:30 -> 11:30 PM    08:00 -> 8:00 AM      12:30 PM -> 12:30
--   6:45 AM -> 06:45     5:45 PM -> 17:45      12:20 PM -> 12:20
--   12:10 AM -> 00:10    09:20 -> 9:20 AM      16:25 -> 4:25 PM
--   15:15 -> 3:15 PM
-- Every distractor was checked to NOT be numerically equal to the correct
-- choice, and every minute value is preserved unchanged across every
-- conversion (per the lesson's explicit "do not change the minutes" rule).
-- =============================================================================

do $$
declare
  v_lesson1_id uuid;
  v_quiz1_id   uuid;

  -- Grade 5 Quiz 1 — Understanding 12-Hour and 24-Hour Time
  v_q1_1  uuid; v_q1_2  uuid; v_q1_3  uuid; v_q1_4  uuid; v_q1_5  uuid;
  v_q1_6  uuid; v_q1_7  uuid; v_q1_8  uuid; v_q1_9  uuid; v_q1_10 uuid;
begin

  -- ===========================================================================
  -- Quiz 1 — built-in Internal Quiz for Grade 5 Lesson 1
  -- (created first so its id can be set directly on the lesson insert below)
  -- ===========================================================================
  insert into public.quizzes (
    title, quiz_type, source_type, created_by, grade_level,
    shuffle_questions, shuffle_choices
  )
  values (
    'Quiz 1: Understanding 12-Hour and 24-Hour Time',
    'internal', 'built_in', null, 'grade_5', true, true
  )
  returning id into v_quiz1_id;

  -- --- Q1 (identifying midnight) ---------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding 12-Hour and 24-Hour Time',
    'What does 12:00 AM represent?',
    '12:00 AM marks the very start of a new day, which is midnight.'
  )
  returning id into v_q1_1;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_1, 'Midnight',  true,  1),
    (v_q1_1, 'Noon',      false, 2),
    (v_q1_1, 'Morning',   false, 3),
    (v_q1_1, 'Afternoon', false, 4);

  -- --- Q2 (identifying noon) --------------------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding 12-Hour and 24-Hour Time',
    'What does 12:00 PM represent?',
    '12:00 PM marks the middle of the day, which is noon.'
  )
  returning id into v_q1_2;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_2, 'Noon',     true,  1),
    (v_q1_2, 'Midnight', false, 2),
    (v_q1_2, 'Evening',  false, 3),
    (v_q1_2, 'Morning',  false, 4);

  -- --- Q3 (identifying AM or PM, real-life) -------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding 12-Hour and 24-Hour Time',
    'A movie starts at 9:00 in the evening. Is this time AM or PM?',
    'The evening falls after noon, so 9:00 in the evening is PM.'
  )
  returning id into v_q1_3;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_3, 'PM',                     true,  1),
    (v_q1_3, 'AM',                     false, 2),
    (v_q1_3, 'Both AM and PM',         false, 3),
    (v_q1_3, 'Cannot be determined',   false, 4);

  -- --- Q4 (convert 12-hour AM to 24-hour) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding 12-Hour and 24-Hour Time',
    'What is 6:45 AM in 24-hour time?',
    '6:45 AM is between 1:00 AM and 11:59 AM, so the hour stays the same with a leading zero: 6:45 AM = 06:45.'
  )
  returning id into v_q1_4;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_4, '06:45', true,  1),
    (v_q1_4, '18:45', false, 2),
    (v_q1_4, '06:15', false, 3),
    (v_q1_4, '18:15', false, 4);

  -- --- Q5 (convert 12-hour PM to 24-hour) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding 12-Hour and 24-Hour Time',
    'What is 5:45 PM in 24-hour time?',
    '5:45 PM is between 1:00 PM and 11:59 PM, so add 12 to the hour: 5 + 12 = 17. 5:45 PM = 17:45.'
  )
  returning id into v_q1_5;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_5, '17:45', true,  1),
    (v_q1_5, '05:45', false, 2),
    (v_q1_5, '17:15', false, 3),
    (v_q1_5, '05:15', false, 4);

  -- --- Q6 (convert 12-hour to 24-hour, 12 PM edge case) -------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding 12-Hour and 24-Hour Time',
    'What is 12:20 PM in 24-hour time?',
    '12:00 PM through 12:59 PM keeps the hour as 12 in 24-hour time. 12:20 PM = 12:20.'
  )
  returning id into v_q1_6;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_6, '12:20', true,  1),
    (v_q1_6, '00:20', false, 2),
    (v_q1_6, '24:20', false, 3),
    (v_q1_6, '12:02', false, 4);

  -- --- Q7 (convert 12-hour to 24-hour, 12 AM/midnight edge case) ---------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding 12-Hour and 24-Hour Time',
    'What is 12:10 AM in 24-hour time?',
    '12:00 AM through 12:59 AM is midnight, which becomes 00 in 24-hour time. 12:10 AM = 00:10.'
  )
  returning id into v_q1_7;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_7, '00:10', true,  1),
    (v_q1_7, '12:10', false, 2),
    (v_q1_7, '24:10', false, 3),
    (v_q1_7, '01:10', false, 4);

  -- --- Q8 (convert 24-hour to 12-hour, AM) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding 12-Hour and 24-Hour Time',
    'What is 09:20 in 12-hour time?',
    '09:20 is between 01:00 and 11:59, so it is AM and the hour stays the same. 09:20 = 9:20 AM.'
  )
  returning id into v_q1_8;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_8, '9:20 AM', true,  1),
    (v_q1_8, '9:20 PM', false, 2),
    (v_q1_8, '8:20 AM', false, 3),
    (v_q1_8, '9:02 AM', false, 4);

  -- --- Q9 (convert 24-hour to 12-hour, PM) --------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding 12-Hour and 24-Hour Time',
    'What is 16:25 in 12-hour time?',
    '16:25 is between 13:00 and 23:59, so subtract 12 from the hour and use PM: 16 - 12 = 4. 16:25 = 4:25 PM.'
  )
  returning id into v_q1_9;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_9, '4:25 PM', true,  1),
    (v_q1_9, '4:16 PM', false, 2),
    (v_q1_9, '6:25 PM', false, 3),
    (v_q1_9, '4:25 AM', false, 4);

  -- --- Q10 (real-life schedule application) -------------------------------
  insert into public.question_bank (source_type, created_by, topic, prompt_text, explanation_text)
  values (
    'built_in', null,
    'Understanding 12-Hour and 24-Hour Time',
    'A school''s dismissal time is 15:15. What is this time in the 12-hour system?',
    '15:15 is between 13:00 and 23:59, so subtract 12 from the hour and use PM: 15 - 12 = 3. 15:15 = 3:15 PM.'
  )
  returning id into v_q1_10;
  insert into public.question_choices (question_id, choice_text, is_correct, display_order) values
    (v_q1_10, '3:15 PM', true,  1),
    (v_q1_10, '3:15 AM', false, 2),
    (v_q1_10, '5:15 PM', false, 3),
    (v_q1_10, '3:30 PM', false, 4);

  insert into public.quiz_questions (quiz_id, question_id, display_order) values
    (v_quiz1_id, v_q1_1,  1),
    (v_quiz1_id, v_q1_2,  2),
    (v_quiz1_id, v_q1_3,  3),
    (v_quiz1_id, v_q1_4,  4),
    (v_quiz1_id, v_q1_5,  5),
    (v_quiz1_id, v_q1_6,  6),
    (v_quiz1_id, v_q1_7,  7),
    (v_quiz1_id, v_q1_8,  8),
    (v_quiz1_id, v_q1_9,  9),
    (v_quiz1_id, v_q1_10, 10);

  -- ===========================================================================
  -- Lesson 1 (Grade 5) — Understanding 12-Hour and 24-Hour Time
  -- `body` is the short 1-2 sentence description the lesson list screen
  -- shows (current convention post-0029); full content lives in
  -- `lesson_pages` below. `linked_quiz_id` is set directly to Quiz 1's id.
  -- ===========================================================================
  insert into public.lessons (title, body, source_type, created_by, grade_level, linked_quiz_id)
  values (
    'Understanding 12-Hour and 24-Hour Time',
    'Learn the difference between the 12-hour clock and the 24-hour clock, including AM and PM, reading time both ways, and converting times between the two systems.',
    'built_in',
    null,
    'grade_5',
    v_quiz1_id
  )
  returning id into v_lesson1_id;

  -- ===========================================================================
  -- Lesson 1 (Grade 5) pages (11 pages)
  -- ===========================================================================
  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson1_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will learn how to read and understand time using two systems: the 12-hour clock and the 24-hour clock.'
  ),
  (
    v_lesson1_id, 2, 'vocabulary', 'The 12-Hour Clock and AM/PM',
    E'The 12-hour clock uses the numbers 1 to 12. Each day is divided into two 12-hour periods:\n' ||
    E'  AM (ante meridiem) covers midnight through just before noon\n' ||
    E'  PM (post meridiem) covers noon through just before midnight\n\n' ||
    E'For example:\n' ||
    E'  7:00 AM — morning\n' ||
    E'  12:00 PM — noon\n' ||
    E'  3:00 PM — afternoon\n' ||
    E'  9:00 PM — evening'
  ),
  (
    v_lesson1_id, 3, 'explanation', 'Midnight and Noon',
    E'Two times need extra care:\n\n' ||
    E'  12:00 AM is midnight — the very start of a new day.\n' ||
    E'  12:00 PM is noon — the middle of the day.\n\n' ||
    E'These are easy to mix up, so always remember: 12 AM = midnight, and 12 PM = noon.'
  ),
  (
    v_lesson1_id, 4, 'explanation', 'The 24-Hour Clock',
    E'Instead of restarting at 1 after noon, the 24-hour clock keeps counting all the way to 23, then starts again at 00 at the next midnight.\n\n' ||
    E'For example:\n' ||
    E'  1:00 AM → 01:00\n' ||
    E'  7:00 AM → 07:00\n' ||
    E'  12:00 PM → 12:00\n' ||
    E'  1:00 PM → 13:00\n' ||
    E'  6:00 PM → 18:00\n' ||
    E'  9:00 PM → 21:00'
  ),
  (
    v_lesson1_id, 5, 'examples', 'Reading Both Systems',
    E'Worked Example 1:\n' ||
    E'  07:00 in the 24-hour clock is the same as 7:00 AM.\n\n' ||
    E'Worked Example 2:\n' ||
    E'  15:00 in the 24-hour clock is the same as 3:00 PM.\n\n' ||
    E'Worked Example 3:\n' ||
    E'  23:30 in the 24-hour clock is the same as 11:30 PM.'
  ),
  (
    v_lesson1_id, 6, 'explanation', 'Converting 12-Hour to 24-Hour Time',
    E'To convert a 12-hour time into 24-hour time:\n' ||
    E'  1. If the time is 12:00 AM through 12:59 AM (midnight hour), write the hour as 00.\n' ||
    E'  2. If the time is 1:00 AM through 11:59 AM, keep the hour the same, adding a leading zero if needed.\n' ||
    E'  3. If the time is 12:00 PM through 12:59 PM, keep the hour as 12.\n' ||
    E'  4. If the time is 1:00 PM through 11:59 PM, add 12 to the hour.\n\n' ||
    E'The minutes never change — only the hour and the AM/PM label change.'
  ),
  (
    v_lesson1_id, 7, 'examples', 'Converting 12-Hour to 24-Hour Examples',
    E'Worked Example 4:\n' ||
    E'  6:30 AM → 06:30 (hour stays the same, add a leading zero)\n\n' ||
    E'Worked Example 5:\n' ||
    E'  12:45 PM → 12:45 (hour stays 12)\n\n' ||
    E'Worked Example 6:\n' ||
    E'  7:15 PM → 19:15 (7 + 12 = 19)\n\n' ||
    E'Worked Example 7:\n' ||
    E'  11:45 PM → 23:45 (11 + 12 = 23)'
  ),
  (
    v_lesson1_id, 8, 'explanation', 'Converting 24-Hour to 12-Hour Time',
    E'To convert a 24-hour time into 12-hour time:\n' ||
    E'  1. If the time is 00:00 through 00:59, it is 12:00 AM through 12:59 AM (midnight hour).\n' ||
    E'  2. If the time is 01:00 through 11:59, keep the hour the same and use AM.\n' ||
    E'  3. If the time is 12:00 through 12:59, keep the hour as 12 and use PM.\n' ||
    E'  4. If the time is 13:00 through 23:59, subtract 12 from the hour and use PM.\n\n' ||
    E'Again, the minutes never change — only the hour and the AM/PM label change.'
  ),
  (
    v_lesson1_id, 9, 'examples', 'Converting 24-Hour to 12-Hour Examples',
    E'Worked Example 8:\n' ||
    E'  09:15 → 9:15 AM\n\n' ||
    E'Worked Example 9:\n' ||
    E'  12:45 → 12:45 PM (hour stays 12)\n\n' ||
    E'Worked Example 10:\n' ||
    E'  14:30 → 2:30 PM (14 - 12 = 2)\n\n' ||
    E'Worked Example 11:\n' ||
    E'  23:45 → 11:45 PM (23 - 12 = 11)'
  ),
  (
    v_lesson1_id, 10, 'examples', 'Real-Life Time Situations',
    E'Worked Example 12:\n' ||
    E'  A class begins at 08:00. What time is this in the 12-hour system?\n' ||
    E'  08:00 is between 01:00 and 11:59, so it is AM: 08:00 = 8:00 AM.\n\n' ||
    E'Worked Example 13:\n' ||
    E'  Lunch time is at 12:30 PM. What time is this in the 24-hour system?\n' ||
    E'  12:30 PM is between 12:00 PM and 12:59 PM, so the hour stays 12: 12:30 PM = 12:30.'
  ),
  (
    v_lesson1_id, 11, 'summary', 'Remember',
    E'  - 12:00 AM is midnight; 12:00 PM is noon.\n' ||
    E'  - The 24-hour clock keeps counting past 12 instead of restarting.\n' ||
    E'  - For AM times (1:00 AM-11:59 AM), the hour stays the same in 24-hour time.\n' ||
    E'  - For PM times (1:00 PM-11:59 PM), add 12 to the hour to get 24-hour time.\n' ||
    E'  - 12:00 PM stays 12:00 in 24-hour time; 12:00 AM becomes 00:00.\n' ||
    E'  - The minutes never change during conversion — only the hour and AM/PM change.'
  );

end $$;
