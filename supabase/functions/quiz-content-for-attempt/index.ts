// quiz-content-for-attempt
//
// Phase 6 (Quiz-Taking) Connection-B function #1 of 2. Returns sanitized
// (no is_correct) question/choice content for an Internal Quiz attempt, plus
// which questions the student has already answered (resume support).
//
// Auth model: the student's own custom JWT is verified independently here
// (see ../_shared/jwt.ts) — never forwarded to PostgREST, since this
// function talks to app.svc_fetch_quiz_content directly over service_role
// (that function is revoked from every other role, 0018). The verified
// student_id claim is what's passed to the DB — a client-supplied
// student_id is never trusted.
//
// app.svc_fetch_quiz_content independently re-verifies that p_attempt_id is
// an ACTIVE attempt owned by p_student_id before returning anything, so this
// function does not duplicate that check — a Postgres exception here means
// "not found/owned/active" and is mapped to 404 below.
//
// Shuffling: this project's shuffle_questions/shuffle_choices settings are
// applied in-function, deterministically seeded from `attempt_id` (not
// persisted as a separate column). Order is not part of grading, but it
// DOES need to stay stable across repeated fetches within the same
// attempt — the Flutter client can legitimately call this more than once
// per attempt (resume, retries), and a re-shuffled order on each call was
// previously observed to make the quiz-taking screen look like it was
// silently jumping to a different question. Seeding off `attempt_id`
// keeps a single attempt's order fixed while still giving each attempt
// (different student, or the same student's next attempt) its own
// independent shuffle.
//
// Response contract: 200 { questions: [...], answered_question_ids: [...] }
// on success — no is_correct anywhere in this response. 401 for a bad/
// missing/invalid JWT, 404/400 mapped from the underlying Postgres
// exception, 500 for anything unexpected. Same {code, message} shape as
// every other function in this project.
//
// NOT COMPILER-VERIFIED — see the note in student-login/index.ts; the same
// caveat applies here. Please run `supabase functions serve
// quiz-content-for-attempt` locally and confirm against a real attempt
// before relying on this for anything real.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2?no-check";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { InvalidStudentTokenError, verifyStudentJwt } from "../_shared/jwt.ts";

declare const Deno: any;

interface ContentRow {
  question_id: string;
  prompt_text: string;
  question_display_order: number;
  choice_id: string;
  choice_text: string;
  choice_display_order: number;
}

interface QuizRow {
  id: string;
  shuffle_questions: boolean;
  shuffle_choices: boolean;
}

interface QuestionAccumulator {
  question_id: string;
  prompt_text: string;
  display_order: number;
  choices: Map<string, { choice_id: string; choice_text: string; display_order: number }>;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey || !Deno.env.get("STUDENT_JWT_SIGNING_SECRET")) {
      console.error("quiz-content-for-attempt is missing required environment secrets.");
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

    const { attempt_id } = body as Record<string, unknown>;
    if (typeof attempt_id !== "string" || attempt_id.trim().length === 0) {
      return jsonResponse(400, { code: "validation_error", message: "attempt_id is required." });
    }

    // service_role — the only role app.svc_fetch_quiz_content is granted to
    // (0018). No caller JWT is forwarded; PostgREST never sees this call.
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: contentRows, error: contentError } = await supabase.rpc("svc_fetch_quiz_content", {
      p_student_id: studentId,
      p_attempt_id: attempt_id,
    });

    if (contentError) {
      const { status, message } = classifyPostgresError(contentError);
      return jsonResponse(status, { code: "fetch_content_failed", message });
    }

    // Which quiz this attempt belongs to, and its shuffle settings — needed
    // to apply shuffle_questions/shuffle_choices. Read via the same
    // service_role connection since svc_fetch_quiz_content's own return
    // shape does not include quiz_id (it's already scoped to one attempt).
    const { data: attemptRow, error: attemptError } = await supabase
      .from("quiz_attempts")
      .select("quiz_id")
      .eq("id", attempt_id)
      .single();

    if (attemptError || !attemptRow) {
      console.error("quiz-content-for-attempt: could not re-fetch quiz_id:", attemptError);
      return jsonResponse(500, {
        code: "unexpected_error",
        message: "Something went wrong. Please try again.",
      });
    }

    const { data: quizRow, error: quizError } = await supabase
      .from("quizzes")
      .select("id, shuffle_questions, shuffle_choices")
      .eq("id", attemptRow.quiz_id as string)
      .single<QuizRow>();

    if (quizError || !quizRow) {
      console.error("quiz-content-for-attempt: could not fetch quiz settings:", quizError);
      return jsonResponse(500, {
        code: "unexpected_error",
        message: "Something went wrong. Please try again.",
      });
    }

    const { data: answeredRows, error: answeredError } = await supabase
      .from("quiz_attempt_answers")
      .select("question_id")
      .eq("quiz_attempt_id", attempt_id);

    if (answeredError) {
      console.error("quiz-content-for-attempt: could not fetch answered questions:", answeredError);
      return jsonResponse(500, {
        code: "unexpected_error",
        message: "Something went wrong. Please try again.",
      });
    }

    const questions = buildQuestions(
      (contentRows ?? []) as ContentRow[],
      quizRow.shuffle_questions,
      quizRow.shuffle_choices,
      attempt_id,
    );
    const answeredQuestionIds = (answeredRows ?? []).map((row: { question_id: string }) => row.question_id);

    return jsonResponse(200, { questions, answered_question_ids: answeredQuestionIds });
  } catch (err) {
    console.error("quiz-content-for-attempt unexpected error:", err);
    return jsonResponse(500, {
      code: "unexpected_error",
      message: "Something went wrong. Please try again.",
    });
  }
});

function buildQuestions(
  rows: ContentRow[],
  shuffleQuestions: boolean,
  shuffleChoices: boolean,
  attemptId: string,
) {
  const byQuestion = new Map<string, QuestionAccumulator>();

  for (const row of rows) {
    let question = byQuestion.get(row.question_id);
    if (!question) {
      question = {
        question_id: row.question_id,
        prompt_text: row.prompt_text,
        display_order: row.question_display_order,
        choices: new Map(),
      };
      byQuestion.set(row.question_id, question);
    }
    if (!question.choices.has(row.choice_id)) {
      question.choices.set(row.choice_id, {
        choice_id: row.choice_id,
        choice_text: row.choice_text,
        display_order: row.choice_display_order,
      });
    }
  }

  let questions = Array.from(byQuestion.values()).sort((a, b) => a.display_order - b.display_order);
  if (shuffleQuestions) {
    // Seeded off the attempt alone: same order every call for this
    // attempt, independent order for every other attempt.
    questions = shuffleArray(questions, `${attemptId}:questions`);
  }

  return questions.map((question) => {
    let choices = Array.from(question.choices.values()).sort((a, b) => a.display_order - b.display_order);
    if (shuffleChoices) {
      // Seeded off attempt + question, so each question's choice order is
      // independent of the others' but still fixed for this attempt.
      choices = shuffleArray(choices, `${attemptId}:choices:${question.question_id}`);
    }
    return {
      question_id: question.question_id,
      prompt_text: question.prompt_text,
      choices: choices.map((choice) => ({ choice_id: choice.choice_id, choice_text: choice.choice_text })),
    };
  });
}

// Fisher-Yates, driven by a PRNG seeded from `seedKey` instead of
// Math.random() — makes the shuffle a pure function of `seedKey`, so the
// same key always yields the same order (deterministic per attempt) while
// different keys (different attempts, or different questions within the
// same attempt) still get independently randomized order.
function shuffleArray<T>(items: T[], seedKey: string): T[] {
  const rng = mulberry32(hashStringToSeed(seedKey));
  const result = [...items];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

// FNV-1a — deterministic string -> 32-bit unsigned int. Not cryptographic,
// just needs to be a stable, well-distributed seed for mulberry32.
function hashStringToSeed(str: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < str.length; i++) {
    hash ^= str.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return hash >>> 0;
}

// mulberry32 — small, fast, deterministic PRNG. Given the same 32-bit
// seed it produces the same sequence of [0, 1) floats every time, which
// is exactly what makes the shuffle above reproducible per attempt.
function mulberry32(seed: number): () => number {
  let state = seed;
  return () => {
    state |= 0;
    state = (state + 0x6d2b79f5) | 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function classifyPostgresError(error: { message?: string }): { status: number; message: string } {
  const message = (error.message ?? "").toLowerCase();

  if (message.includes("is not an active attempt owned by student")) {
    return { status: 404, message: "That quiz attempt could not be found." };
  }
  return { status: 400, message: "Could not load the quiz." };
}