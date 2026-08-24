-- =============================================================================
-- Migration: 0032_lessons_linked_quiz.sql
-- Adds a nullable `linked_quiz_id` column to `lessons`, pointing at an
-- OPTIONAL, suggested quiz to take after this lesson.
--
-- NOT a violation of 0009's "quizzes and lessons are kept completely
-- independent" decision (schema §9, Recommendation 6) — re-confirmed with
-- the requester before writing this migration. That decision was about
-- never REQUIRING one to complete the other; this column is a pure UI
-- convenience shortcut on top of that, not a dependency:
--   - `lesson_progress` (0007) and `quiz_attempts` (0010) remain
--     completely independent tables/signals. A student can reach
--     `completed` on a lesson's `lesson_progress` row without ever
--     opening the linked quiz, and can complete a quiz attempt without
--     ever having opened the lesson (e.g. the teacher taught the material
--     traditionally, in person, and just wants to quiz the student in the
--     app afterward).
--   - No trigger, check constraint, or RLS policy here reads or writes
--     `quiz_attempts`/`lesson_progress` — this column only ever drives a
--     "Take Quiz" button in the guided Student viewer (see
--     `lesson_viewer_screen.dart`). Nothing enforces the student ever
--     presses it.
--
-- `on delete set null` (not `cascade` or `restrict`): if the linked quiz
-- is ever deleted, the lesson itself is unaffected and simply stops
-- suggesting a quiz — matches the "convenience, not dependency" framing
-- above; a lesson's own existence/content was never contingent on the
-- quiz existing.
--
-- CONFIRMED AGAINST ACTUAL SCHEMA before writing this (0007, re-read in
-- full before this migration): `public.lessons` columns are
-- id/title/body/source_type/created_by/created_at/updated_at, no existing
-- FK to quizzes. `lessons_student_select`/`lessons_teacher_select` (0015)
-- are purely row-level RLS on `lessons` itself and don't reference any
-- specific column, so adding one more nullable column doesn't require
-- touching them — same reasoning already verified for 0028/0030's column
-- additions to `lesson_pages`.
-- =============================================================================

alter table public.lessons
  add column linked_quiz_id uuid references public.quizzes (id) on delete set null;

comment on column public.lessons.linked_quiz_id is
  'Optional. Points at a suggested quiz to take after this lesson — a pure UI convenience shortcut, never a dependency in either direction. lesson_progress and quiz_attempts stay completely independent regardless of this link (0009/0032). Null means the guided viewer shows no "Take Quiz" suggestion.';

create index lessons_linked_quiz_id_idx on public.lessons (linked_quiz_id);
