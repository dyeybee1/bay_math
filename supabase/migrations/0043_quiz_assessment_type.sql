-- Migration: 0043_quiz_assessment_type.sql
--
-- Adds an optional Pre-Test / Post-Test classification to Internal Quizzes.
-- Most quizzes are neither — `assessment_type` stays null for ordinary
-- practice/graded quizzes and is only ever set on the small subset used to
-- measure intervention impact (before/after an intervention period).
--
-- External Activities can never carry this classification (mirrors the
-- existing `quizzes_type_url_pairing` pairing-constraint pattern, 0009).
-- No RLS changes — existing `quizzes` policies already govern this column.
-- No data is seeded here; that is a separate migration.
-- =============================================================================

create type assessment_type as enum ('pre_test', 'post_test');

alter table public.quizzes
  add column assessment_type assessment_type;

alter table public.quizzes
  add constraint quizzes_assessment_type_requires_internal check (
    assessment_type is null or quiz_type = 'internal'
  );

comment on column public.quizzes.assessment_type is
  'Optional Pre-Test / Post-Test classification. Null for ordinary quizzes; only ever set when quiz_type = ''internal'' (quizzes_assessment_type_requires_internal).';

create index quizzes_assessment_type_idx on public.quizzes (assessment_type);
