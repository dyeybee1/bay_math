// check-quiz-answer
//
// Phase 6 (Quiz-Taking) Connection-B function #2 of 2. The single place
// is_correct is computed for a submitted quiz answer — Flutter never
// invents it locally, it only relays this response into the Connection-A
// (`quiz_attempt_answers`) insert.
//
// Auth model: same independent JWT verification as quiz-content-for-attempt
// (see ../_shared/jwt.ts) — this function also calls service_role directly
// (app.svc_check_quiz_answer, revoked from every other role, 0018), bypassing
// PostgREST, so nothing upstream verifies the incoming token.
//
// Also fetches (service_role, same connection, no extra client round-trip):
//   - every choice for the question, with is_correct/display_order — so the
//     client can build quiz_attempt_answer_choice_snapshots without a third
//     service_role call of its own.
//   - question_bank.explanation_text — this is the correct moment to reveal
//     it (svc_fetch_quiz_content withholds it beforehand, by design).
//
// Response contract: 200 { is_correct, explanation_text, choices: [...] }.
// 401 for a bad/missing/invalid JWT, 404/400 mapped from the underlying
// Postgres exception (attempt not found/owned/active, question not in quiz,
// or choice not on question — svc_check_quiz_answer independently
// re-verifies all three), 500 for anything unexpected.
//
// KNOWN GAP (flagged, not fixed here — out of this phase's scope): neither
// this function, svc_check_quiz_answer, nor the quiz_attempt_answers_
// student_insert RLS policy check quiz_attempts.submitted_at. Nothing here
// stops a call against an already-submitted attempt at the DB layer. The
// app-level guard (read-only screen once submitted_at != null) is the
// mitigation for this phase; the real fix — adding `submitted_at is null`
// to that RLS policy's WITH CHECK — is a future migration, intentionally
// not bundled into this one.
//
// NOT COMPILER-VERIFIED — see the note in student-login/index.ts; the same
// caveat applies here. Please run `supabase functions serve
// check-quiz-answer` locally and confirm against a real attempt/question/
// choice before relying on this for anything real.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2?no-check";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { InvalidStudentTokenError, verifyStudentJwt } from "../_shared/jwt.ts";

declare const Deno: any;

interface ChoiceRow {
  id: string;
  choice_text: string;
  is_correct: boolean;
  display_order: number;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey || !Deno.env.get("STUDENT_JWT_SIGNING_SECRET")) {
      console.error("check-quiz-answer is missing required environment secrets.");
      return jsonResponse(500, {
        code: "server_misconfigured",
        message: "Something went wrong. Please try again.",
      });
    }

    let studentId: string;
    try {
      studentId = await verifyStudentJwt(req.headers.get("Authorization"));
    } catch (err) {
      if (err instanceof InvalidStudentTokenError) {
        return jsonResponse(401, { code: "invalid_token", message: "You must be signed in to do this." });
      }
      throw err;
    }

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return jsonResponse(400, { code: "invalid_body", message: "Request body must be JSON." });
    }

    const { attempt_id, question_id, choice_id } = body as Record<string, unknown>;
    if (
      typeof attempt_id !== "string" || attempt_id.trim().length === 0 ||
      typeof question_id !== "string" || question_id.trim().length === 0 ||
      typeof choice_id !== "string" || choice_id.trim().length === 0
    ) {
      return jsonResponse(400, {
        code: "validation_error",
        message: "attempt_id, question_id, and choice_id are required.",
      });
    }

    // service_role — the only role app.svc_check_quiz_answer is granted to
    // (0018). No caller JWT is forwarded; PostgREST never sees this call.
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: isCorrect, error: checkError } = await supabase.rpc("svc_check_quiz_answer", {
      p_student_id: studentId,
      p_attempt_id: attempt_id,
      p_question_id: question_id,
      p_choice_id: choice_id,
    });

    if (checkError) {
      const { status, message } = classifyPostgresError(checkError);
      return jsonResponse(status, { code: "check_answer_failed", message });
    }

    // svc_check_quiz_answer has already authoritatively verified attempt
    // ownership/active status, question membership, and choice membership —
    // these two reads are safe to do as plain lookups on that same
    // service_role connection, not re-checks of their own.
    const [{ data: choiceRows, error: choicesError }, { data: questionRow, error: questionError }] =
      await Promise.all([
        supabase
          .from("question_choices")
          .select("id, choice_text, is_correct, display_order")
          .eq("question_id", question_id)
          .order("display_order"),
        supabase.from("question_bank").select("explanation_text").eq("id", question_id).single(),
      ]);

    if (choicesError || questionError) {
      console.error("check-quiz-answer: could not fetch choices/explanation:", choicesError, questionError);
      return jsonResponse(500, {
        code: "unexpected_error",
        message: "Something went wrong. Please try again.",
      });
    }

    return jsonResponse(200, {
      is_correct: isCorrect as boolean,
      explanation_text: (questionRow?.explanation_text as string | null) ?? null,
      choices: ((choiceRows ?? []) as ChoiceRow[]).map((choice) => ({
        choice_id: choice.id,
        choice_text: choice.choice_text,
        is_correct: choice.is_correct,
        display_order: choice.display_order,
      })),
    });
  } catch (err) {
    console.error("check-quiz-answer unexpected error:", err);
    return jsonResponse(500, {
      code: "unexpected_error",
      message: "Something went wrong. Please try again.",
    });
  }
});

function classifyPostgresError(error: { message?: string }): { status: number; message: string } {
  const message = (error.message ?? "").toLowerCase();

  if (message.includes("is not an active attempt owned by student")) {
    return { status: 404, message: "That quiz attempt could not be found." };
  }
  if (message.includes("is not part of quiz") || message.includes("does not belong to question")) {
    return { status: 400, message: "That question or choice is not valid for this quiz." };
  }
  return { status: 400, message: "Could not check the answer." };
}
