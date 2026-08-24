-- =============================================================================
-- Migration: 0024_public_rpc_wrappers_for_quiz_svc_functions.sql
-- Phase 6 (Quiz-Taking) prerequisite fix — found while implementing the
-- `quiz-content-for-attempt` / `check-quiz-answer` Edge Functions, NOT part
-- of the originally-scoped "no new SQL" plan. Flagged before writing this,
-- for the same reason as 0023 (see that file's header).
--
-- THE GAP
-- 0018 created `app.svc_fetch_quiz_content` / `app.svc_check_quiz_answer`
-- and granted EXECUTE to service_role — but never wrapped them in `public`,
-- the way `app.create_student`/`app.verify_student_credentials`/etc. were
-- in 0020. 0001's own comment establishes why that matters: `app` is
-- deliberately NOT in PostgREST's exposed-schema list, so
-- `app.svc_fetch_quiz_content` is not reachable via `POST
-- /rest/v1/rpc/svc_fetch_quiz_content` at all — not from the Flutter
-- client (correctly never supposed to call it directly), and not from a
-- Supabase Edge Function either, since an Edge Function using the standard
-- supabase-js/supabase-dart client's `.rpc(...)` also talks to PostgREST
-- over that same HTTP API, service_role credentials or not. Without this,
-- both new Connection-B Edge Functions would fail every call with a
-- PostgREST "function not found" error, regardless of anything in
-- application code.
--
-- THE FIX
-- Add the same one-line pass-through wrapper 0020 already established for
-- exactly this situation. `security invoker` (the default, omitted below)
-- is correct here too, for the same reason 0020 gives: these wrappers add
-- no logic of their own, so the calling role (service_role, from the Edge
-- Function's service-role connection) is what's checked against 0018's
-- existing `grant execute ... to service_role` — unchanged either way.
-- Grants mirror 0018 exactly: service_role only, nothing widened.
-- =============================================================================

create or replace function public.svc_fetch_quiz_content(
  p_student_id uuid,
  p_attempt_id uuid
)
returns table (
  question_id             uuid,
  prompt_text             text,
  question_display_order  smallint,
  choice_id               uuid,
  choice_text             text,
  choice_display_order    smallint
)
language sql
as $$
  select * from app.svc_fetch_quiz_content(p_student_id, p_attempt_id);
$$;

comment on function public.svc_fetch_quiz_content(uuid, uuid) is
  'Public-schema pass-through to app.svc_fetch_quiz_content (0018) so it is reachable via PostgREST from the quiz-content-for-attempt Edge Function — see 0024 header comment. No additional logic.';

revoke all on function public.svc_fetch_quiz_content(uuid, uuid) from public, anon, authenticated;
grant execute on function public.svc_fetch_quiz_content(uuid, uuid) to service_role;

create or replace function public.svc_check_quiz_answer(
  p_student_id  uuid,
  p_attempt_id  uuid,
  p_question_id uuid,
  p_choice_id   uuid
)
returns boolean
language sql
as $$
  select app.svc_check_quiz_answer(p_student_id, p_attempt_id, p_question_id, p_choice_id);
$$;

comment on function public.svc_check_quiz_answer(uuid, uuid, uuid, uuid) is
  'Public-schema pass-through to app.svc_check_quiz_answer (0018) so it is reachable via PostgREST from the check-quiz-answer Edge Function — see 0024 header comment. No additional logic.';

revoke all on function public.svc_check_quiz_answer(uuid, uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.svc_check_quiz_answer(uuid, uuid, uuid, uuid) to service_role;
