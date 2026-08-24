-- =============================================================================
-- Migration: 0008_question_bank.sql
-- Source: Phase 2 schema §3.11 (question_bank), §3.12 (question_choices).
--
-- The "at least one choice per question must be correct" invariant (schema
-- §3.12) is a cross-row check and cannot be expressed as a plain CHECK
-- constraint here — it is enforced by a deferred constraint trigger in
-- migration 0014_triggers.sql (schema §9, Recommendation 5, confirmed).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- question_bank
-- ---------------------------------------------------------------------------
create table public.question_bank (
  id                uuid primary key default gen_random_uuid(),
  source_type       content_source_type not null,
  created_by        uuid references public.profiles (id) on delete restrict on update cascade,
  topic             text,
  prompt_text       text not null,
  explanation_text  text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  constraint question_bank_source_created_by_pairing check (
    (source_type = 'built_in' and created_by is null)
    or (source_type = 'teacher' and created_by is not null)
  )
);

comment on table public.question_bank is
  'Reusable question pool, used only by Internal Quizzes. Phase 2 schema §3.11.';

comment on column public.question_bank.topic is
  'Supports Highest/Lowest Performing Topics dashboard metrics. Schema §9, Recommendation 2 (confirmed, free text).';

create index question_bank_created_by_idx on public.question_bank (created_by);
create index question_bank_source_type_idx on public.question_bank (source_type);
create index question_bank_topic_idx on public.question_bank (topic);

-- ---------------------------------------------------------------------------
-- question_choices
-- ---------------------------------------------------------------------------
create table public.question_choices (
  id             uuid primary key default gen_random_uuid(),
  question_id    uuid not null references public.question_bank (id) on delete cascade on update cascade,
  choice_text    text not null,
  is_correct     boolean not null,
  display_order  smallint not null,

  constraint question_choices_question_order_unique unique (question_id, display_order)
);

comment on table public.question_choices is
  'Normalizes each question''s answer options. Phase 2 schema §3.12 (schema §9, Recommendation 4, confirmed).';

create index question_choices_question_id_idx on public.question_choices (question_id, display_order);
