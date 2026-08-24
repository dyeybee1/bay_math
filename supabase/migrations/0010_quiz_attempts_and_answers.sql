-- =============================================================================
-- Migration: 0010_quiz_attempts_and_answers.sql
-- Source: Phase 2 schema §3.16 (quiz_attempts), §3.17 (quiz_attempt_answers),
--         §3.18 (quiz_attempt_answer_choice_snapshots).
--
-- HISTORICAL SNAPSHOT FIELDS — preserved exactly as approved:
--   - quiz_attempts.section_id       (frozen at attempt time)
--   - quiz_attempts.school_year_id   (frozen at attempt time; intentional
--                                      denormalization approved in the Phase 2
--                                      review — schema §9, Recommendation 1)
--   - quiz_attempt_answers.question_text_snapshot
--   - quiz_attempt_answer_choice_snapshots (whole table)
-- Immutability of these is enforced by triggers in 0014_triggers.sql, not by
-- declarative constraints alone (Postgres has no "immutable after insert"
-- column-level primitive).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- quiz_attempts
-- Exactly one ACTIVE attempt per student per quiz; every attempt ever made
-- (including superseded ones) is retained permanently (schema §3.16, §7.5).
-- ---------------------------------------------------------------------------
create table public.quiz_attempts (
  id                uuid primary key default gen_random_uuid(),
  student_id        uuid not null references public.students (id) on delete restrict on update cascade,
  quiz_id           uuid not null references public.quizzes (id) on delete restrict on update cascade,
  section_id        uuid not null references public.sections (id) on delete restrict on update cascade,
  school_year_id    uuid not null references public.school_years (id) on delete restrict on update cascade,
  attempt_status    quiz_attempt_status not null default 'active',
  total_questions   smallint,
  score             numeric,
  opened_at         timestamptz not null default now(),
  submitted_at      timestamptz,
  reset_by          uuid references public.profiles (id) on delete set null on update cascade,
  reset_at          timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  constraint quiz_attempts_score_non_negative check (score is null or score >= 0)
);

comment on table public.quiz_attempts is
  'One student''s interaction with one quiz. section_id and school_year_id are frozen historical context, immutable after insert (enforced by trigger). Phase 2 schema §3.16.';

comment on column public.quiz_attempts.school_year_id is
  'Intentional historical-snapshot denormalization, approved in Phase 2 review. Captured once at insert, never updated afterward (trigger-enforced in 0014).';

create index quiz_attempts_section_quiz_idx on public.quiz_attempts (section_id, quiz_id);
create index quiz_attempts_school_year_idx on public.quiz_attempts (school_year_id);
create index quiz_attempts_school_year_student_idx on public.quiz_attempts (school_year_id, student_id);

-- Exactly one active attempt per student per quiz — this index IS the
-- enforcement mechanism for the "one attempt" policy (schema §3.16).
create unique index quiz_attempts_one_active_per_student_quiz
  on public.quiz_attempts (student_id, quiz_id)
  where attempt_status = 'active';

create index quiz_attempts_active_by_quiz_idx
  on public.quiz_attempts (quiz_id)
  where attempt_status = 'active';

-- ---------------------------------------------------------------------------
-- quiz_attempt_answers
-- ---------------------------------------------------------------------------
create table public.quiz_attempt_answers (
  id                        uuid primary key default gen_random_uuid(),
  quiz_attempt_id           uuid not null references public.quiz_attempts (id) on delete cascade on update cascade,
  question_id               uuid not null references public.question_bank (id) on delete restrict on update cascade,
  question_text_snapshot    text not null,
  selected_choice_id        uuid references public.question_choices (id) on delete set null on update cascade,
  is_correct                boolean not null,
  answered_at               timestamptz not null default now(),

  constraint quiz_attempt_answers_attempt_question_unique unique (quiz_attempt_id, question_id)
);

comment on table public.quiz_attempt_answers is
  'One answer within an Internal Quiz attempt. question_text_snapshot is one of two deliberate denormalization exceptions in this schema, named directly in the blueprint (§7.6). Phase 2 schema §3.17.';

comment on column public.quiz_attempt_answers.selected_choice_id is
  'Live-row backlink only, for traceability. question_text_snapshot and the rows in quiz_attempt_answer_choice_snapshots remain authoritative regardless of later edits to the live question_choices row.';

create index quiz_attempt_answers_attempt_id_idx on public.quiz_attempt_answers (quiz_attempt_id);

-- ---------------------------------------------------------------------------
-- quiz_attempt_answer_choice_snapshots
-- ---------------------------------------------------------------------------
create table public.quiz_attempt_answer_choice_snapshots (
  id                        uuid primary key default gen_random_uuid(),
  quiz_attempt_answer_id    uuid not null references public.quiz_attempt_answers (id) on delete cascade on update cascade,
  choice_text_snapshot      text not null,
  was_correct               boolean not null,
  was_selected              boolean not null,
  display_order             smallint not null,

  constraint quiz_attempt_answer_choice_snapshots_order_unique
    unique (quiz_attempt_answer_id, display_order)
);

comment on table public.quiz_attempt_answer_choice_snapshots is
  'Normalizes the answer-choice half of the §7.6 snapshot exception. Phase 2 schema §3.18 (schema §9, Recommendation 4, confirmed).';

create index quiz_attempt_answer_choice_snapshots_answer_id_idx
  on public.quiz_attempt_answer_choice_snapshots (quiz_attempt_answer_id);
