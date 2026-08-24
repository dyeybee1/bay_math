-- =============================================================================
-- Migration: 0011_endless_quiz_sessions.sql
-- Source: Phase 2 schema §3.19.
--
-- Written once, at session end, with exactly the four confirmed data points.
-- No child/per-question table exists for this feature by design (blueprint
-- §8's final rule: Current Streak is never persisted at all).
-- =============================================================================

create table public.endless_quiz_sessions (
  id                    uuid primary key default gen_random_uuid(),
  student_id            uuid not null references public.students (id) on delete restrict on update cascade,
  started_at            timestamptz not null,
  ended_at              timestamptz not null,
  questions_answered    integer not null,
  best_streak_session   integer not null,
  created_at            timestamptz not null default now(),

  constraint endless_quiz_sessions_ended_after_started check (ended_at >= started_at),
  constraint endless_quiz_sessions_questions_non_negative check (questions_answered >= 0),
  constraint endless_quiz_sessions_streak_non_negative check (best_streak_session >= 0)
);

comment on table public.endless_quiz_sessions is
  'One finalized Endless Quiz session, written once at session end: Session Date (started_at::date), Questions Answered, Best Streak (during session), Session Duration (ended_at - started_at). Phase 2 schema §3.19.';

comment on column public.endless_quiz_sessions.best_streak_session is
  'The peak streak reached during this specific session. Distinct from students.best_endless_streak, the all-time value, updated separately when this session ends.';

create index endless_quiz_sessions_student_started_idx
  on public.endless_quiz_sessions (student_id, started_at);
