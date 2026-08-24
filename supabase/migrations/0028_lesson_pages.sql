-- =============================================================================
-- Migration: 0028_lesson_pages.sql
-- Adds `lesson_pages` — the ordered, per-slide content a lesson's guided
-- Student viewer renders one page at a time, replacing the "one long
-- `lessons.body` blob" approach for that viewer. Schema-only — content
-- migration for the two existing Grade 4 lessons (0027) is a separate,
-- follow-up migration by design (schema first, content second — same
-- split 0026/0027 already used).
--
-- CONFIRMED AGAINST ACTUAL SCHEMA before writing this:
--   - `lesson_sections` (0007) is already the lesson-to-classroom-section
--     visibility join, so this new table needed a distinct name —
--     `lesson_pages` doesn't collide with anything.
--   - `lessons_teacher_select` / `lessons_student_select` (0015) already
--     resolve full Admin/Teacher/Student visibility correctly (confirmed
--     by reading both policy bodies). A bare
--     `exists (select 1 from public.lessons where id = lesson_pages.lesson_id)`
--     inside `lesson_pages`' own SELECT policy re-triggers those same
--     policies for the calling role — this is NOT the same situation as
--     0023's `sections` bug (join against a table with NO student-visible
--     SELECT policy at all, which silently evaluates false for every
--     student). `lessons` has working SELECT coverage for every role that
--     needs to read `lesson_pages`, so the subquery correctly resolves
--     true/false per caller with no SECURITY DEFINER helper needed. This
--     distinction was checked, not assumed.
--   - `question_choices`/`quiz_sections` (0007-0009) are the closest
--     existing "pure child content of a content-owning parent" precedent
--     for `on delete cascade` (vs. the `on delete restrict` used for
--     permanent-record references like `quiz_attempts.quiz_id`) — a
--     lesson's own pages are exactly that shape, so cascade is correct
--     here too.
--
-- SCOPE NOTE: only a SELECT policy is added below. Nothing in this phase
-- writes `lesson_pages` from the app itself (the only writer right now is
-- the 0029 content-migration, run as the migration role, which bypasses
-- RLS entirely) — there is no teacher/admin page-authoring UI yet. Adding
-- speculative INSERT/UPDATE/DELETE policies now would be guessing at an
-- authorization shape for a feature that doesn't exist; flagging this
-- explicitly rather than inventing one. The table-level GRANT below still
-- covers all four verbs (matching every other content table's grant, e.g.
-- `lesson_sections` in 0016) since RLS — not the GRANT — is what actually
-- gates access here; add the write policies in a future migration
-- alongside whatever authoring UI needs them.
-- =============================================================================

create table public.lesson_pages (
  id             uuid primary key default gen_random_uuid(),
  lesson_id      uuid not null references public.lessons (id) on delete cascade,
  display_order  smallint not null,
  section_type   text, -- e.g. 'introduction' | 'vocabulary' | 'explanation' | 'examples' | null; presentation-only, used client-side to pick an icon, not enforced by a DB enum since new types may be added freely later
  title          text not null,
  body           text not null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  constraint lesson_pages_lesson_display_order_unique unique (lesson_id, display_order)
);

comment on table public.lesson_pages is
  'Ordered per-slide content for a lesson''s guided Student viewer. One row per page/section; display_order defines the sequence. Presentation-only section_type picks a client-side icon and never gates access. 0028.';

create index lesson_pages_lesson_id_idx on public.lesson_pages (lesson_id);

alter table public.lesson_pages enable row level security;

-- Single SELECT policy, deliberately not split per-role (unlike
-- lessons_teacher_select/lessons_student_select) — the EXISTS subquery
-- below re-evaluates `lessons`' own SELECT policies for whichever role is
-- calling, so one policy body already covers Admin, Teacher, and Student
-- without duplicating that role logic here. See the migration header for
-- why this is safe for `lessons` specifically.
create policy lesson_pages_select on public.lesson_pages for select
  using (
    exists (
      select 1 from public.lessons
      where id = lesson_pages.lesson_id
    )
  );

-- Full-verb grant to match every other content table's GRANT (e.g.
-- lesson_sections, 0016) — RLS (just the one SELECT policy above, for
-- now) is what actually narrows this, not the GRANT. See the SCOPE NOTE
-- above: no INSERT/UPDATE/DELETE policy exists yet, so those verbs are
-- denied by RLS default-deny regardless of this grant.
grant select, insert, update, delete on public.lesson_pages to authenticated;

-- updated_at maintenance, matching every other table with this column
-- (0014) — added here rather than editing 0014 directly, since that
-- migration is already applied/approved and this project's own convention
-- is to extend, not retroactively edit, approved migrations.
create trigger set_updated_at before update on public.lesson_pages
  for each row execute function app.set_updated_at();
