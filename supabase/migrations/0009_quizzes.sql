-- =============================================================================
-- Migration: 0009_quizzes.sql
-- Source: Phase 2 schema §3.13 (quizzes), §3.14 (quiz_sections),
--         §3.15 (quiz_questions).
--
-- No lesson_id column on quizzes — quizzes and lessons are kept completely
-- independent (schema §9, Recommendation 6, explicitly re-confirmed).
--
-- The "quiz_questions rows must only exist for quiz_type = 'internal'"
-- invariant (schema §3.15) is a cross-table check and is enforced by a
-- trigger in 0014_triggers.sql (schema §9, Recommendation 5, confirmed).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- quizzes  (Internal Quiz or External Activity)
-- ---------------------------------------------------------------------------
create table public.quizzes (
  id                        uuid primary key default gen_random_uuid(),
  title                     text not null,
  quiz_type                 quiz_type not null,
  source_type               content_source_type not null,
  created_by                uuid references public.profiles (id) on delete restrict on update cascade,
  external_url              text,
  external_platform_hint    external_platform_hint,
  shuffle_questions         boolean not null default true,
  shuffle_choices           boolean not null default true,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),

  constraint quizzes_source_created_by_pairing check (
    (source_type = 'built_in' and created_by is null)
    or (source_type = 'teacher' and created_by is not null)
  ),
  constraint quizzes_type_url_pairing check (
    (quiz_type = 'internal' and external_url is null)
    or (quiz_type = 'external_activity' and external_url is not null)
  ),
  constraint quizzes_external_url_https check (
    external_url is null or external_url like 'https://%'
  )
);

comment on table public.quizzes is
  'Internal Quiz or External Activity, sharing one ownership/section model. Phase 2 schema §3.13.';

comment on column public.quizzes.external_platform_hint is
  'Display icon hint only — never validated against the actual URL (schema §3.13).';

create index quizzes_created_by_idx on public.quizzes (created_by);
create index quizzes_source_type_idx on public.quizzes (source_type);
create index quizzes_quiz_type_idx on public.quizzes (quiz_type);

-- ---------------------------------------------------------------------------
-- quiz_sections
-- Same default-isolated, built-in-has-zero-rows pattern as lesson_sections.
-- ---------------------------------------------------------------------------
create table public.quiz_sections (
  id           uuid primary key default gen_random_uuid(),
  quiz_id      uuid not null references public.quizzes (id) on delete cascade on update cascade,
  section_id   uuid not null references public.sections (id) on delete cascade on update cascade,
  assigned_by  uuid references public.profiles (id) on delete set null on update cascade,
  assigned_at  timestamptz not null default now(),

  constraint quiz_sections_quiz_section_unique unique (quiz_id, section_id)
);

comment on table public.quiz_sections is
  'Section-visibility join for teacher-created quizzes/external activities. Phase 2 schema §3.14.';

create index quiz_sections_section_id_idx on public.quiz_sections (section_id);

-- ---------------------------------------------------------------------------
-- quiz_questions  (Internal Quiz only — see trigger enforcement, 0014)
-- ---------------------------------------------------------------------------
create table public.quiz_questions (
  id             uuid primary key default gen_random_uuid(),
  quiz_id        uuid not null references public.quizzes (id) on delete cascade on update cascade,
  question_id    uuid not null references public.question_bank (id) on delete restrict on update cascade,
  display_order  smallint not null,

  constraint quiz_questions_quiz_question_unique unique (quiz_id, question_id),
  constraint quiz_questions_quiz_order_unique unique (quiz_id, display_order)
);

comment on table public.quiz_questions is
  'Questions <-> Internal Quiz, in order. Not used by External Activities. Phase 2 schema §3.15.';

create index quiz_questions_quiz_id_idx on public.quiz_questions (quiz_id, display_order);
