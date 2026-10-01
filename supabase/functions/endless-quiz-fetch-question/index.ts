// endless-quiz-fetch-question
//
// Phase 7 (Endless Quiz) Connection-B function #1 of 2. Returns one
// sanitized (no is_correct) practice question, chosen uniformly at random
// from the Student's server-derived eligible quiz question ids. Eligibility
// is enforced by app.svc_fetch_endless_question (0097): active enrollment
// and section -> same-grade built-ins plus teacher quizzes assigned to that
// exact section -> DISTINCT canonical question ids. Every call is independent:
// no attempt/session row backs Endless
// Quiz, so there is nothing here to resume and nothing to keep stable
// across calls. A fresh random question every call is the intended
// behavior — this deliberately does NOT do what quiz-content-for-attempt
// does with attempt-seeded shuffle determinism; that logic exists there
// specifically because a quiz attempt's question/choice order must stay
// fixed across repeated fetches of the SAME attempt, which has no
// equivalent concept here.
//
// Auth model: same independent JWT verification as the Phase 6 Connection-B
// functions (see ../_shared/jwt.ts) — this function calls service_role
// directly (app.svc_fetch_endless_question, revoked from every other role,
// 0018), bypassing PostgREST, so nothing upstream verifies the incoming
// token. The verified student_id claim is what's passed to the DB — a
// client-supplied student_id is never trusted.
//
// app.svc_fetch_endless_question independently re-verifies the Student and
// active enrollment before returning anything. It accepts no grade parameter,
// so a modified client cannot spoof grade eligibility.
//
// Response contract: 200 { question_id, prompt_text, choices: [...] } — no
// is_correct anywhere, same as quiz-content-for-attempt's sanitized shape.
// 401 for a bad/missing/invalid JWT, 404/400 mapped from the underlying
// Postgres exception (e.g. no eligible questions for the grade, or — should
// never happen behind a validly-signed token, but defended anyway — the
// student row no longer existing), 500 for anything unexpected. Same
// {code, message} shape as every other function in this project.
//
// NOT COMPILER-VERIFIED — see the note in student-login/index.ts; the same
// caveat applies here. Please run `supabase functions serve
// endless-quiz-fetch-question` locally and confirm against a real student
// session before relying on this for anything real.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2?no-check";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { InvalidStudentTokenError, verifyStudentJwt } from "../_shared/jwt.ts";

declare const Deno: any;

interface EndlessQuestionRow {
  question_id: string;
  prompt_text: string;
  choice_id: string;
  choice_text: string;
  choice_display_order: number;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey || !Deno.env.get("STUDENT_JWT_SIGNING_SECRET")) {
      console.error("endless-quiz-fetch-question is missing required environment secrets.");
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

    // No body needed beyond the JWT — svc_fetch_endless_question takes
    // only p_student_id. Not parsed/validated for that reason (nothing to
    // validate).

    // service_role — the only role app.svc_fetch_endless_question is
    // granted to (0018). No caller JWT is forwarded; PostgREST never sees
    // this call.
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: rows, error: fetchError } = await supabase.rpc("svc_fetch_endless_question", {
      p_student_id: studentId,
    });

    if (fetchError) {
      const { status, message } = classifyPostgresError(fetchError);
      const code = message.startsWith("No Endless Quiz questions")
        ? "no_endless_questions"
        : "fetch_question_failed";
      return jsonResponse(status, { code, message });
    }

    const question = buildQuestion((rows ?? []) as EndlessQuestionRow[]);
    if (!question) {
      // Defensive only — svc_fetch_endless_question raises its own
      // exception ("no questions available in question_bank") before ever
      // returning an empty result set, so this should be unreachable.
      console.error("endless-quiz-fetch-question: svc_fetch_endless_question returned no rows.");
      return jsonResponse(500, {
        code: "unexpected_error",
        message: "Something went wrong. Please try again.",
      });
    }

    return jsonResponse(200, question);
  } catch (err) {
    console.error("endless-quiz-fetch-question unexpected error:", err);
    return jsonResponse(500, {
      code: "unexpected_error",
      message: "Something went wrong. Please try again.",
    });
  }
});

// svc_fetch_endless_question returns one row per choice, all sharing the
// same question_id/prompt_text (it is always exactly one question, unlike
// quiz-content-for-attempt's many-questions case) — grouped here the same
// way regardless, so this stays consistent with that function's
// row-grouping convention rather than special-casing the single-question
// shape.
function buildQuestion(rows: EndlessQuestionRow[]) {
  if (rows.length === 0) return null;

  const choicesById = new Map<string, { choice_id: string; choice_text: string; display_order: number }>();
  for (const row of rows) {
    if (!choicesById.has(row.choice_id)) {
      choicesById.set(row.choice_id, {
        choice_id: row.choice_id,
        choice_text: row.choice_text,
        display_order: row.choice_display_order,
      });
    }
  }

  const choices = Array.from(choicesById.values()).sort((a, b) => a.display_order - b.display_order);

  return {
    question_id: rows[0].question_id,
    prompt_text: rows[0].prompt_text,
    choices: choices.map((choice) => ({ choice_id: choice.choice_id, choice_text: choice.choice_text })),
  };
}

function classifyPostgresError(error: { message?: string }): { status: number; message: string } {
  const message = (error.message ?? "").toLowerCase();

  if (message.includes("no endless quiz questions available")) {
    return { status: 404, message: "No Endless Quiz questions are available for your grade yet." };
  }
  if (message.includes("no active enrollment")) {
    return { status: 404, message: "Your class enrollment is not active. Please ask your teacher for help." };
  }
  if (message.includes("not found")) {
    // "student % not found" — should be unreachable behind a validly
    // signed student JWT, but defended anyway rather than surfacing a
    // raw 400 for what is really a stale/invalid session.
    return { status: 404, message: "Your session is no longer valid. Please sign in again." };
  }
  return { status: 400, message: "Could not load a question." };
}
