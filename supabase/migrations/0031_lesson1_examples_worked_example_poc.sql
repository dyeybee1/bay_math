-- =============================================================================
-- Migration: 0031_lesson1_examples_worked_example_poc.sql
-- Content-migration follow-up to 0030's schema change, kept separate by
-- design (schema first, content second — same split 0028/0029, 0026/0027
-- already used).
--
-- Proof-of-concept scope, exactly as specified: converts ONLY two already-
-- seeded examples — both from Lesson 1 (Addition and Subtraction) — to the
-- new interactive `worked_example` shape. Lesson 2 (Comparing Numbers) is
-- untouched by this migration; neither of its worked examples is an
-- addition/subtraction operation the new shape models, and neither was
-- named in scope.
--
-- Converted (both deliberately chosen in the original request because
-- neither needs regrouping — every carry_in/out and borrow_in/out below is
-- 0 for that reason, not by omission):
--   - Lesson 1, Worked Example 1 (addition): 245,000 + 132,500 = 377,500
--   - Lesson 1, Worked Example 3 (subtraction): 875,432 - 432,432 = 443,000
-- Left as plain text, unchanged, per the explicit instruction not to touch
-- these in this pass (both involve messier carry/borrow chains):
--   - Lesson 1, Worked Example 2 (addition, regroups across 4 columns)
--   - Lesson 1, Worked Example 4 (subtraction, regroups across zeros)
--
-- ARITHMETIC RE-VERIFIED (not just restated from 0029's prose) column by
-- column against the already-published final answers before writing the
-- JSON below:
--   Addition   245000 + 132500: O 0+0=0 · T 0+0=0 · H 0+5=5 · Th 5+2=7 ·
--              TTh 4+3=7 · HTh 2+1=3 → 377500. No column reaches 10, so
--              every carry_in/carry_out is 0 throughout — consistent with
--              this example having been picked specifically because it
--              doesn't regroup.
--   Subtraction 875432 - 432432: O 2-2=0 · T 3-3=0 · H 4-4=0 · Th 5-2=3 ·
--              TTh 7-3=4 · HTh 8-4=4 → 443000. Every top digit is ≥ the
--              bottom digit in every column, so every borrow_in/borrow_out
--              is 0 throughout — same reasoning as above.
--
-- FIELD NAMING: kept carry_in/carry_out and borrow_in/borrow_out as
-- separate, operation-specific field names rather than unifying them under
-- one generic name — a carry and a borrow are directionally different
-- operations on an adjacent column, and the sibling `operation` field
-- already tells a reader which pair of field names to expect.
--
-- RESTRUCTURING: a page can only be either the plain-text panel or the new
-- interactive panel (0030), so each combined "Examples" page is split into
-- two rows — one interactive page for the converted example, one
-- unchanged plain-text page for the example staying as-is. display_order
-- is renumbered so Lesson 1 grows from 7 pages to 9 (+1 for each of its
-- two Examples sections that gets split), matching the "Addition Example
-- 1/2" and "Subtraction Example 1/2" pages inserted below.
--
-- display_order re-sequenced in a collision-safe order (each UPDATE/DELETE
-- targets a slot that's free at the moment it runs, since
-- lesson_pages_lesson_display_order_unique (0028) is a non-deferred unique
-- constraint):
--   1) bump "Remember" 7 -> 9 (9 is free)
--   2) delete the old combined "Subtraction Examples" row at 6 (frees 6)
--   3) bump "Subtracting Numbers up to 1,000,000" 5 -> 6 (now free, and
--      moving it away frees 5)
--   4) delete the old combined "Addition Examples" row at 4 (frees 4)
--   5) insert the four new rows at 4, 5, 7, 8 (all free at this point)
--
-- STRING CONCATENATION: every multi-line page body below uses explicit
-- `||` between fragments instead of relying on Postgres's implicit
-- adjacent-string-literal concatenation (which only triggers when the
-- whitespace between two literals contains a real newline — fragile
-- against copy/paste or editor reformatting; this is the same fix already
-- applied to 0029 after it broke in the SQL editor for exactly this
-- reason).
-- =============================================================================

do $$
declare
  v_lesson1_id uuid;
  v_addition_examples_title text;
  v_subtraction_examples_title text;
begin

  select id into v_lesson1_id
  from public.lessons
  where title = 'Addition and Subtraction of Numbers up to 1,000,000'
    and source_type = 'built_in'
    and grade_level = 'grade_4';

  if v_lesson1_id is null then
    raise exception '0031: Lesson 1 (Addition and Subtraction ...) not found — expected 0027/0029 to have run first.';
  end if;

  -- Defensive checks: this migration mutates rows by (lesson_id,
  -- display_order) position, so confirm 0029's layout is exactly what is
  -- expected before touching anything, rather than assuming it silently.
  select title into v_addition_examples_title
  from public.lesson_pages where lesson_id = v_lesson1_id and display_order = 4;
  if v_addition_examples_title is distinct from 'Addition Examples' then
    raise exception '0031: expected display_order 4 to be "Addition Examples", found %', v_addition_examples_title;
  end if;

  select title into v_subtraction_examples_title
  from public.lesson_pages where lesson_id = v_lesson1_id and display_order = 6;
  if v_subtraction_examples_title is distinct from 'Subtraction Examples' then
    raise exception '0031: expected display_order 6 to be "Subtraction Examples", found %', v_subtraction_examples_title;
  end if;

  -- Step 1: move "Remember" out of the way first (7 -> 9).
  update public.lesson_pages
  set display_order = 9
  where lesson_id = v_lesson1_id and display_order = 7;

  -- Step 2: remove the old combined "Subtraction Examples" row (frees 6).
  delete from public.lesson_pages
  where lesson_id = v_lesson1_id and display_order = 6;

  -- Step 3: move "Subtracting Numbers up to 1,000,000" into the freed slot
  -- (5 -> 6), which in turn frees 5.
  update public.lesson_pages
  set display_order = 6
  where lesson_id = v_lesson1_id and display_order = 5;

  -- Step 4: remove the old combined "Addition Examples" row (frees 4).
  delete from public.lesson_pages
  where lesson_id = v_lesson1_id and display_order = 4;

  -- Step 5: insert the four replacement rows.
  insert into public.lesson_pages (lesson_id, display_order, section_type, title, body, worked_example) values
  (
    v_lesson1_id, 4, 'examples', 'Addition Example 1',
    E'Worked Example 1:\n' ||
    E'  245,000 + 132,500 = ?\n' ||
    E'  Line up the numbers:\n' ||
    E'      245,000\n' ||
    E'    + 132,500\n' ||
    E'  Add the ones, tens, and hundreds first: 000 + 500 = 500.\n' ||
    E'  Add the thousands: 245 (thousands) + 132 (thousands) = 377 (thousands).\n' ||
    E'  Answer: 245,000 + 132,500 = 377,500.',
    '{
      "operand_a": "245000",
      "operand_b": "132500",
      "operation": "addition",
      "result": "377500",
      "steps": [
        {"column_label": "Ones", "digit_a": 0, "digit_b": 0, "carry_in": 0, "computation_text": "0 + 0 = 0", "result_digit": 0, "carry_out": 0, "action_text": "Write 0 in the Ones column."},
        {"column_label": "Tens", "digit_a": 0, "digit_b": 0, "carry_in": 0, "computation_text": "0 + 0 = 0", "result_digit": 0, "carry_out": 0, "action_text": "Write 0 in the Tens column."},
        {"column_label": "Hundreds", "digit_a": 0, "digit_b": 5, "carry_in": 0, "computation_text": "0 + 5 = 5", "result_digit": 5, "carry_out": 0, "action_text": "Write 5 in the Hundreds column."},
        {"column_label": "Thousands", "digit_a": 5, "digit_b": 2, "carry_in": 0, "computation_text": "5 + 2 = 7", "result_digit": 7, "carry_out": 0, "action_text": "Write 7 in the Thousands column."},
        {"column_label": "Ten Thousands", "digit_a": 4, "digit_b": 3, "carry_in": 0, "computation_text": "4 + 3 = 7", "result_digit": 7, "carry_out": 0, "action_text": "Write 7 in the Ten Thousands column."},
        {"column_label": "Hundred Thousands", "digit_a": 2, "digit_b": 1, "carry_in": 0, "computation_text": "2 + 1 = 3", "result_digit": 3, "carry_out": 0, "action_text": "Write 3 in the Hundred Thousands column."}
      ]
    }'::jsonb
  ),
  (
    v_lesson1_id, 5, 'examples', 'Addition Example 2',
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
    E'  Answer: 512,340 + 87,660 = 600,000.',
    null
  ),
  (
    v_lesson1_id, 7, 'examples', 'Subtraction Example 1',
    E'Worked Example 3:\n' ||
    E'  875,432 - 432,432 = ?\n' ||
    E'      875,432\n' ||
    E'    - 432,432\n' ||
    E'  Ones: 2 - 2 = 0.  Tens: 3 - 3 = 0.  Hundreds: 4 - 4 = 0.\n' ||
    E'  Thousands: 5 - 2 = 3.  Ten thousands: 7 - 3 = 4.  Hundred thousands: 8 - 4 = 4.\n' ||
    E'  Answer: 875,432 - 432,432 = 443,000.',
    '{
      "operand_a": "875432",
      "operand_b": "432432",
      "operation": "subtraction",
      "result": "443000",
      "steps": [
        {"column_label": "Ones", "digit_a": 2, "digit_b": 2, "borrow_in": 0, "computation_text": "2 - 2 = 0", "result_digit": 0, "borrow_out": 0, "action_text": "Write 0 in the Ones column."},
        {"column_label": "Tens", "digit_a": 3, "digit_b": 3, "borrow_in": 0, "computation_text": "3 - 3 = 0", "result_digit": 0, "borrow_out": 0, "action_text": "Write 0 in the Tens column."},
        {"column_label": "Hundreds", "digit_a": 4, "digit_b": 4, "borrow_in": 0, "computation_text": "4 - 4 = 0", "result_digit": 0, "borrow_out": 0, "action_text": "Write 0 in the Hundreds column."},
        {"column_label": "Thousands", "digit_a": 5, "digit_b": 2, "borrow_in": 0, "computation_text": "5 - 2 = 3", "result_digit": 3, "borrow_out": 0, "action_text": "Write 3 in the Thousands column."},
        {"column_label": "Ten Thousands", "digit_a": 7, "digit_b": 3, "borrow_in": 0, "computation_text": "7 - 3 = 4", "result_digit": 4, "borrow_out": 0, "action_text": "Write 4 in the Ten Thousands column."},
        {"column_label": "Hundred Thousands", "digit_a": 8, "digit_b": 4, "borrow_in": 0, "computation_text": "8 - 4 = 4", "result_digit": 4, "borrow_out": 0, "action_text": "Write 4 in the Hundred Thousands column."}
      ]
    }'::jsonb
  ),
  (
    v_lesson1_id, 8, 'examples', 'Subtraction Example 2',
    E'Worked Example 4 (with regrouping across zeros):\n' ||
    E'  700,000 - 256,789 = ?\n' ||
    E'  Since 700,000 has zeros in every place except the hundred thousands, we must regroup across several columns at once: borrow from the 7 (hundred thousands), which turns the number into 6 hundred-thousands, 9 ten-thousands, 9 thousands, 9 hundreds, 9 tens, and 10 ones — then subtract normally.\n' ||
    E'      6 9 9 9 9 10\n' ||
    E'      7 0 0 0 0 0\n' ||
    E'    - 2 5 6 7 8 9\n' ||
    E'    -----------\n' ||
    E'      4 4 3 2 1 1\n' ||
    E'  Answer: 700,000 - 256,789 = 443,211.',
    null
  );

end $$;
