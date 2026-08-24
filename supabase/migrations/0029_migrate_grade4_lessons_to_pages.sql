-- =============================================================================
-- Migration: 0029_migrate_grade4_lessons_to_pages.sql
-- Content-migration follow-up to 0028's schema change, kept separate by
-- design (schema first, content second — same split 0026/0027 used).
--
-- Restructures the two existing Grade 4 lessons seeded in 0027 — both flat
-- `lessons.body` blobs — into ordered `lesson_pages` rows, and shrinks each
-- lesson's `body` down to the short 1-2 sentence description the lesson
-- list screen now shows instead of the full text.
--
-- Looked up by (title, source_type = 'built_in', grade_level = 'grade_4')
-- rather than a hardcoded id, since 0027 never captured either lesson's
-- generated id anywhere this migration could read it back from.
--
-- CONTENT PRESERVATION: every worked example and explanation paragraph
-- below is copied verbatim from 0027's `lessons.body` text — this is a
-- restructuring, not a rewrite.
--
-- NOTE ON STRING CONCATENATION: each multi-line page body below uses
-- explicit `||` between fragments instead of relying on Postgres's
-- implicit adjacent-string-literal concatenation (which only triggers
-- when the whitespace between two literals contains a real newline —
-- fragile against copy/paste or editor reformatting). Explicit `||` is
-- unambiguous regardless of how this file gets pasted/reformatted.
-- =============================================================================

do $$
declare
  v_lesson1_id uuid;
  v_lesson2_id uuid;
begin

  select id into v_lesson1_id
  from public.lessons
  where title = 'Addition and Subtraction of Numbers up to 1,000,000'
    and source_type = 'built_in'
    and grade_level = 'grade_4';

  if v_lesson1_id is null then
    raise exception 'lesson_pages migration: Lesson 1 (Addition and Subtraction ...) not found — expected the 0027 seed to have run first.';
  end if;

  select id into v_lesson2_id
  from public.lessons
  where title = 'Comparing Numbers up to 1,000,000'
    and source_type = 'built_in'
    and grade_level = 'grade_4';

  if v_lesson2_id is null then
    raise exception 'lesson_pages migration: Lesson 2 (Comparing Numbers ...) not found — expected the 0027 seed to have run first.';
  end if;

  -- ===========================================================================
  -- Lesson 1 — Addition and Subtraction of Numbers up to 1,000,000 (7 pages)
  -- ===========================================================================
  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson1_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will add and subtract whole numbers with up to 7 digits — numbers up to 1,000,000 (one million).'
  ),
  (
    v_lesson1_id, 2, 'vocabulary', 'Place Value Review',
    E'Before adding or subtracting large numbers, it helps to see each digit''s place value. In the number 456,789:\n' ||
    E'  4 is in the hundred thousands place\n' ||
    E'  5 is in the ten thousands place\n' ||
    E'  6 is in the thousands place\n' ||
    E'  7 is in the hundreds place\n' ||
    E'  8 is in the tens place\n' ||
    E'  9 is in the ones place'
  ),
  (
    v_lesson1_id, 3, 'explanation', 'Adding Numbers up to 1,000,000',
    E'To add large numbers, line up the digits by place value (ones under ones, tens under tens, and so on), then add each column from right to left, regrouping (carrying) whenever a column adds up to 10 or more.'
  ),
  (
    v_lesson1_id, 4, 'examples', 'Addition Examples',
    E'Worked Example 1:\n' ||
    E'  245,000 + 132,500 = ?\n' ||
    E'  Line up the numbers:\n' ||
    E'      245,000\n' ||
    E'    + 132,500\n' ||
    E'  Add the ones, tens, and hundreds first: 000 + 500 = 500.\n' ||
    E'  Add the thousands: 245 (thousands) + 132 (thousands) = 377 (thousands).\n' ||
    E'  Answer: 245,000 + 132,500 = 377,500.\n\n' ||
    E'Worked Example 2 (with regrouping):\n' ||
    E'  512,340 + 87,660 = ?\n' ||
    E'      512,340\n' ||
    E'    +  87,660\n' ||
    E'  Ones: 0 + 0 = 0.\n' ||
    E'  Tens: 4 + 6 = 10 -> write 0, carry 1 to the hundreds.\n' ||
    E'  Hundreds: 3 + 6 + 1(carried) = 10 -> write 0, carry 1 to the thousands.\n' ||
    E'  Thousands: 2 + 7 + 1(carried) = 10 -> write 0, carry 1 to the ten thousands.\n' ||
    E'  Ten thousands: 1 + 8 + 1(carried) = 10 -> write 0, carry 1 to the hundred thousands.\n' ||
    E'  Hundred thousands: 5 + 0 + 1(carried) = 6.\n' ||
    E'  Answer: 512,340 + 87,660 = 600,000.'
  ),
  (
    v_lesson1_id, 5, 'explanation', 'Subtracting Numbers up to 1,000,000',
    E'To subtract, line up the digits the same way, then subtract each column from right to left. Whenever the top digit in a column is smaller than the bottom digit, regroup (borrow) 1 from the column to its left.'
  ),
  (
    v_lesson1_id, 6, 'examples', 'Subtraction Examples',
    E'Worked Example 3:\n' ||
    E'  875,432 - 432,432 = ?\n' ||
    E'      875,432\n' ||
    E'    - 432,432\n' ||
    E'  Ones: 2 - 2 = 0.  Tens: 3 - 3 = 0.  Hundreds: 4 - 4 = 0.\n' ||
    E'  Thousands: 5 - 2 = 3.  Ten thousands: 7 - 3 = 4.  Hundred thousands: 8 - 4 = 4.\n' ||
    E'  Answer: 875,432 - 432,432 = 443,000.\n\n' ||
    E'Worked Example 4 (with regrouping across zeros):\n' ||
    E'  700,000 - 256,789 = ?\n' ||
    E'  Since 700,000 has zeros in every place except the hundred thousands, we must regroup across several columns at once: borrow from the 7 (hundred thousands), which turns the number into 6 hundred-thousands, 9 ten-thousands, 9 thousands, 9 hundreds, 9 tens, and 10 ones — then subtract normally.\n' ||
    E'      6 9 9 9 9 10\n' ||
    E'      7 0 0 0 0 0\n' ||
    E'    - 2 5 6 7 8 9\n' ||
    E'    -----------\n' ||
    E'      4 4 3 2 1 1\n' ||
    E'  Answer: 700,000 - 256,789 = 443,211.'
  ),
  (
    v_lesson1_id, 7, 'summary', 'Remember',
    E'  - Always line up the digits by place value before adding or subtracting.\n' ||
    E'  - Work from right to left (ones, then tens, then hundreds, and so on).\n' ||
    E'  - Regroup (carry) when a column in addition totals 10 or more.\n' ||
    E'  - Regroup (borrow) when the top digit in subtraction is smaller than the bottom digit.'
  );

  update public.lessons
  set body = 'Learn to add and subtract whole numbers up to 1,000,000, with a place-value review and step-by-step worked examples for both operations.'
  where id = v_lesson1_id;

  -- ===========================================================================
  -- Lesson 2 — Comparing Numbers up to 1,000,000 (5 pages)
  -- ===========================================================================
  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body) values
  (
    v_lesson2_id, 1, 'introduction', 'Introduction',
    E'In this lesson, we will compare whole numbers up to 1,000,000 using the symbols = (equal to), < (less than), and > (greater than).'
  ),
  (
    v_lesson2_id, 2, 'explanation', 'How to Compare Large Numbers',
    E'To compare two numbers:\n' ||
    E'  1. First compare the number of digits. A number with more digits is always greater (for example, a 7-digit number is always greater than a 6-digit number).\n' ||
    E'  2. If both numbers have the same number of digits, compare digit by digit starting from the leftmost (highest) place value.\n' ||
    E'  3. Move one place to the right only when the digits in the current place are the same.\n' ||
    E'  4. The first place value where the digits differ decides which number is greater.\n' ||
    E'  5. If every digit is exactly the same, the numbers are equal.'
  ),
  (
    v_lesson2_id, 3, 'examples', 'Comparing with > and <',
    E'Worked Example 1 (using >):\n' ||
    E'  Compare 723,450 and 723,405.\n' ||
    E'      7 2 3 4 5 0\n' ||
    E'      7 2 3 4 0 5\n' ||
    E'  Hundred thousands, ten thousands, thousands, and hundreds are the same (7, 2, 3, 4).\n' ||
    E'  At the tens place: 5 versus 0. Since 5 is greater than 0,\n' ||
    E'  723,450 > 723,405.\n\n' ||
    E'Worked Example 2 (using <):\n' ||
    E'  Compare 305,678 and 350,678.\n' ||
    E'      3 0 5 6 7 8\n' ||
    E'      3 5 0 6 7 8\n' ||
    E'  The hundred thousands digit is the same (3).\n' ||
    E'  At the ten thousands place: 0 versus 5. Since 0 is less than 5,\n' ||
    E'  305,678 < 350,678.'
  ),
  (
    v_lesson2_id, 4, 'examples', 'Comparing with = and Different Digit Counts',
    E'Worked Example 3 (using =):\n' ||
    E'  Compare 640,000 and 640,000.\n' ||
    E'  Every digit matches exactly, so\n' ||
    E'  640,000 = 640,000.\n\n' ||
    E'Worked Example 4 (different number of digits):\n' ||
    E'  Compare 999,999 and 1,000,000.\n' ||
    E'  999,999 has 6 digits. 1,000,000 has 7 digits.\n' ||
    E'  A number with more digits is always greater, so\n' ||
    E'  999,999 < 1,000,000.'
  ),
  (
    v_lesson2_id, 5, 'summary', 'Remember',
    E'  - Compare the number of digits first.\n' ||
    E'  - If the digit count is the same, compare from the leftmost place value going right.\n' ||
    E'  - Stop as soon as you find a place value where the digits are different — that place decides the answer.\n' ||
    E'  - Use > for greater than, < for less than, and = for equal to.'
  );

  update public.lessons
  set body = 'Learn to compare whole numbers up to 1,000,000 using =, <, and >, with worked examples covering each symbol and numbers of different digit counts.'
  where id = v_lesson2_id;

end $$;