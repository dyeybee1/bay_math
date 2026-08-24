-- =============================================================================
-- Migration: 0033_link_grade4_lessons_to_quizzes.sql
-- Content-migration follow-up to 0032's schema change, kept separate by
-- design (schema first, content second — same split used throughout this
-- project's lesson_pages/lessons migrations).
--
-- Links the two built-in Grade 4 lessons to their already-seeded (0027)
-- counterpart quizzes — the pairing 0027's own migration comments already
-- named ("Quiz 1 — built-in Internal Quiz for Lesson 1", "Quiz 2 —
-- built-in Internal Quiz for Lesson 2") but never actually encoded as a
-- relationship until 0032 added the column to do so:
--   Lesson "Addition and Subtraction of Numbers up to 1,000,000"
--     -> Quiz  "Quiz 1: Addition and Subtraction of Numbers up to 1,000,000"
--   Lesson "Comparing Numbers up to 1,000,000"
--     -> Quiz  "Quiz 2: Comparing Numbers up to 1,000,000"
--
-- Looked up by title/source_type on both sides (same approach 0029/0031
-- used) rather than hardcoded ids, since none of 0027/0029/0031 captured
-- either side's generated id anywhere this migration could read it back
-- from.
-- =============================================================================

do $$
declare
  v_lesson1_id uuid;
  v_lesson2_id uuid;
  v_quiz1_id uuid;
  v_quiz2_id uuid;
begin

  select id into v_lesson1_id
  from public.lessons
  where title = 'Addition and Subtraction of Numbers up to 1,000,000'
    and source_type = 'built_in'
    and grade_level = 'grade_4';

  if v_lesson1_id is null then
    raise exception '0033: Lesson 1 (Addition and Subtraction ...) not found — expected 0027/0029 to have run first.';
  end if;

  select id into v_lesson2_id
  from public.lessons
  where title = 'Comparing Numbers up to 1,000,000'
    and source_type = 'built_in'
    and grade_level = 'grade_4';

  if v_lesson2_id is null then
    raise exception '0033: Lesson 2 (Comparing Numbers ...) not found — expected 0027/0029 to have run first.';
  end if;

  select id into v_quiz1_id
  from public.quizzes
  where title = 'Quiz 1: Addition and Subtraction of Numbers up to 1,000,000'
    and source_type = 'built_in'
    and grade_level = 'grade_4';

  if v_quiz1_id is null then
    raise exception '0033: Quiz 1 (Addition and Subtraction ...) not found — expected 0027 to have run first.';
  end if;

  select id into v_quiz2_id
  from public.quizzes
  where title = 'Quiz 2: Comparing Numbers up to 1,000,000'
    and source_type = 'built_in'
    and grade_level = 'grade_4';

  if v_quiz2_id is null then
    raise exception '0033: Quiz 2 (Comparing Numbers ...) not found — expected 0027 to have run first.';
  end if;

  update public.lessons set linked_quiz_id = v_quiz1_id where id = v_lesson1_id;
  update public.lessons set linked_quiz_id = v_quiz2_id where id = v_lesson2_id;

end $$;
