// endless-quiz-check-answer
//
// Phase 7 (Endless Quiz) Connection-B function #2 of 2. The single place
// is_correct is computed for a submitted Endless Quiz practice answer.
//
// Auth model: same independent JWT verification as every other Connection-B
// function (see ../_shared/jwt.ts) — this function calls service_role
// directly (app.svc_check_endless_answer, revoked from every other role,
// 0018), bypassing PostgREST, so nothing upstream verifies the incoming
// token. The verified student_id claim is what's passed to the DB — a
// client-supplied student_id is never trusted.
// app.svc_check_endless_answer (0097) also rejects question_id unless it is
// in the same server-derived eligible pool used by fetching, preventing a
// modified client from probing another grade's question.
//
// Response contract is deliberately minimal: 200 { is_correct } — nothing
// else. svc_check_endless_answer itself only returns a plain boolean (no
// explanation_text, no per-choice correctness) — unlike
// check-quiz-answer's richer response, Endless Quiz is fast-paced
// practice, not an explanation-driven moment, and the underlying SQL
// function simply doesn't provide anything beyond the boolean, so nothing
// else is fabricated here on top of it.
//
// 401 for a bad/missing/invalid JWT, 403 for an ineligible question, and
// 404/400 mapped from the underlying
// Postgres exception (choice not on question, or — should never happen
// behind a validly-signed token, but defended anyway — the student row no
// longer existing), 500 for anything unexpected. Same {code, message}
// shape as every other function in this project.
//
// NOT COMPILER-VERIFIED — see the note in student-login/index.ts; the same
// caveat applies here. Please run `supabase functions serve
// endless-quiz-check-answer` locally and confirm against a real
// question/choice before relying on this for anything real.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2?no-check";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { InvalidStudentTokenError, verifyStudentJwt } from "../_shared/jwt.ts";

declare const Deno: any;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey || !Deno.env.get("STUDENT_JWT_SIGNING_SECRET")) {
      console.error("endless-quiz-check-answer is missing required environment secrets.");
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

    const { question_id, choice_id } = body as Record<string, unknown>;
    if (
      typeof question_id !== "string" || question_id.trim().length === 0 ||
      typeof choice_id !== "string" || choice_id.trim().length === 0
    ) {
      return jsonResponse(400, {
        code: "validation_error",
        message: "question_id and choice_id are required.",
      });
    }

    // service_role — the only role app.svc_check_endless_answer is
    // granted to (0018). No caller JWT is forwarded; PostgREST never sees
    // this call.
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: isCorrect, error: checkError } = await supabase.rpc("svc_check_endless_answer", {
      p_student_id: studentId,
      p_question_id: question_id,
      p_choice_id: choice_id,
    });

    if (checkError) {
      const { status, message } = classifyPostgresError(checkError);
      return jsonResponse(status, { code: "check_answer_failed", message });
    }

    return jsonResponse(200, { is_correct: isCorrect as boolean });
  } catch (err) {
    console.error("endless-quiz-check-answer unexpected error:", err);
    return jsonResponse(500, {
      code: "unexpected_error",
      message: "Something went wrong. Please try again.",
    });
  }
});

function classifyPostgresError(error: { message?: string }): { status: number; message: string } {
  const message = (error.message ?? "").toLowerCase();

  if (message.includes("is not eligible for student")) {
    return { status: 403, message: "That question is not available in your Endless Quiz." };
  }
  if (message.includes("does not belong to question")) {
    return { status: 400, message: "That choice is not valid for this question." };
  }
  if (message.includes("not found")) {
    // "student % not found" — should be unreachable behind a validly
    // signed student JWT, but defended anyway rather than surfacing a
    // raw 400 for what is really a stale/invalid session.
    return { status: 404, message: "Your session is no longer valid. Please sign in again." };
  }
  return { status: 400, message: "Could not check the answer." };
}
