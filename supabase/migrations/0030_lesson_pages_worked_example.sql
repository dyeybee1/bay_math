-- =============================================================================
-- Migration: 0030_lesson_pages_worked_example.sql
-- Adds a nullable `worked_example` jsonb column to `lesson_pages` (0028) —
-- proof-of-concept support for an interactive, place-value-aligned
-- step-by-step rendering of a worked example, as an alternative to that
-- page's plain-text `body`. When null (every existing row, and every page
-- that isn't one of the two POC examples), the guided viewer renders
-- exactly as it does today. When present, the viewer renders the new
-- interactive panel INSTEAD of the plain `body` text for that page — see
-- `lesson_viewer_screen.dart`.
--
-- CONFIRMED AGAINST ACTUAL SCHEMA before writing this (0028, re-read in
-- full before this migration):
--   - Table/column names: `public.lesson_pages`, columns
--     id/lesson_id/display_order/section_type/title/body/created_at/
--     updated_at, primary key `id`, unique constraint
--     `lesson_pages_lesson_display_order_unique` on (lesson_id, display_order).
--   - `lesson_pages_select` is a purely row-level RLS policy (an EXISTS
--     subquery against `lessons`, keyed only on `lesson_id`) — it does not
--     reference, filter, or otherwise depend on any specific column, and
--     the 0028 GRANT is table-wide (`select, insert, update, delete on
--     public.lesson_pages`), not a column-restricted grant. Postgres RLS
--     itself is row-level, not column-level, unless column privileges are
--     used — they aren't here. So adding one more nullable column changes
--     nothing about who can see which rows; this assumption was verified
--     against the actual policy body and grant statement, not assumed.
--     No RLS or grant change needed alongside this column addition.
-- =============================================================================

alter table public.lesson_pages
  add column worked_example jsonb;

comment on column public.lesson_pages.worked_example is
  'Nullable. When present, the guided Student viewer renders an interactive, place-value-aligned step-by-step panel for this page instead of plain `body` text. Fixed to exactly 6 place-value columns (Hundred Thousands..Ones) — POC scope, not built to generalize to other digit counts. Shape: {operand_a, operand_b, operation: "addition"|"subtraction", result, steps: [{column_label, digit_a, digit_b, carry_in/carry_out (addition) or borrow_in/borrow_out (subtraction), computation_text, result_digit, action_text}]}. 0030.';
