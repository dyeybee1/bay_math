-- =============================================================================
-- Migration: 0034_public_rpc_wrappers_for_endless_quiz_svc_functions.sql
-- Phase 7 (Endless Quiz) prerequisite fix — found while wiring up
-- `endless_quiz_screen.dart` (Part 3) and testing it against a real
-- Supabase project. Flagged before writing this, for the same reason as
-- 0023/0024 (see 0024's header).
--
-- THE GAP
-- 0018 created `app.svc_fetch_endless_question` / `app.svc_check_endless_answer`
-- and granted EXECUTE to service_role — but, exactly like the quiz-svc gap
-- 0024 already fixed once, never wrapped them in `public`. `app` is
-- deliberately not in PostgREST's exposed-schema list (0001's own
-- comment), so neither function is reachable via `POST
-- /rest/v1/rpc/svc_fetch_endless_question` / `svc_check_endless_answer` at
-- all — not from the Flutter client, and not from a Supabase Edge
-- Function's `supabase-js`/`supabase-dart` `.rpc(...)` either, since that
-- also talks to PostgREST over the same HTTP API regardless of
-- service_role credentials. Without this, both `endless-quiz-fetch-
-- question` and `endless-quiz-check-answer` fail every call with
-- PostgREST's "function not found" 404, which is exactly the failure
-- observed live: a 404 on `POST /rest/v1/rpc/svc_fetch_endless_question`.
--
-- THE FIX
-- Add the same one-line pass-through wrapper 0020/0024 already established
-- for exactly this situation. `security invoker` (the default, omitted
-- below) is correct here too, for the same reason 0020/0024 give: these
-- wrappers add no logic of their own, so the calling role (service_role,
-- from the Edge Function's service-role connection) is what's checked
-- against 0018's existing `grant execute ... to service_role` — unchanged
-- either way. Grants mirror 0018 exactly: service_role only, nothing
-- widened.
-- =============================================================================

create or replace function public.svc_fetch_endless_question(
  p_student_id uuid
)
returns table (
  question_id           uuid,
  prompt_text           text,
  choice_id             uuid,
  choice_text           text,
  choice_display_order  smallint
)
language sql
as $$
  select * from app.svc_fetch_endless_question(p_student_id);
$$;

comment on function public.svc_fetch_endless_question(uuid) is
  'Public-schema pass-through to app.svc_fetch_endless_question (0018) so it is reachable via PostgREST from the endless-quiz-fetch-question Edge Function — see 0034 header comment. No additional logic.';

revoke all on function public.svc_fetch_endless_question(uuid) from public, anon, authenticated;
grant execute on function public.svc_fetch_endless_question(uuid) to service_role;

create or replace function public.svc_check_endless_answer(
  p_student_id  uuid,
  p_question_id uuid,
  p_choice_id   uuid
)
returns boolean
language sql
as $$
  select app.svc_check_endless_answer(p_student_id, p_question_id, p_choice_id);
$$;

comment on function public.svc_check_endless_answer(uuid, uuid, uuid) is
  'Public-schema pass-through to app.svc_check_endless_answer (0018) so it is reachable via PostgREST from the endless-quiz-check-answer Edge Function — see 0034 header comment. No additional logic.';

revoke all on function public.svc_check_endless_answer(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.svc_check_endless_answer(uuid, uuid, uuid) to service_role;
