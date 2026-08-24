-- =============================================================================
-- Migration: 0012_audit_logs.sql
-- Source: Phase 2 schema §3.20.
--
-- Append-only, immutable — no updated_at column at all (this table is never
-- updated, only inserted into, per schema §3.20). No FK to its target
-- (target_table/target_id are plain values by design, so a log entry
-- survives even if the referenced row is later deleted).
--
-- Writes happen only through app.log_audit_event() (0013_functions.sql) —
-- no direct INSERT grant is given to authenticated/anon roles (0015_rls.sql).
-- =============================================================================

create table public.audit_logs (
  id                 uuid primary key default gen_random_uuid(),
  actor_profile_id   uuid references public.profiles (id) on delete set null on update cascade,
  actor_role         audit_actor_role not null,
  action             text not null,
  target_table       text not null,
  target_id          uuid not null,
  metadata           jsonb,
  created_at         timestamptz not null default now()
);

comment on table public.audit_logs is
  'Append-only record of sensitive actions. action is intentionally TEXT, not an enum (schema §9, Recommendation 3, confirmed) — the allowed-values catalog is maintained at the application layer. Phase 2 schema §3.20.';

comment on column public.audit_logs.actor_role is
  'Captured at the time of the action, not derived from a live join to profiles.role — same "freeze context" precedent as quiz_attempts.section_id.';

create index audit_logs_created_at_idx on public.audit_logs (created_at);
create index audit_logs_actor_profile_id_idx on public.audit_logs (actor_profile_id);
