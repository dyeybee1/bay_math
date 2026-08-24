// _shared/jwt.ts
//
// The two Phase 6 Connection-B Edge Functions (quiz-content-for-attempt,
// check-quiz-answer) are the first functions in this project that call
// service_role while acting on behalf of an already-logged-in student. Every
// other service_role function either has no caller identity yet
// (student-login) or forwards the caller's own JWT to PostgREST, which
// verifies it natively (create-student/set-student-password/
// view-student-password). These two functions bypass PostgREST entirely —
// they call `app.svc_*` directly over a service_role connection — so nothing
// upstream ever checks the incoming student JWT. This module is that check,
// applied independently in-function, per the architecture note: "Every Edge
// Function independently verifies the incoming JWT's signature against the
// shared signing secret first ... then uses the verified student_id claim —
// never a client-supplied one."
//
// Signed with the same STUDENT_JWT_SIGNING_SECRET that student-login (0017)
// signs with, so a token minted there is exactly what verifies here.
//
// NOT COMPILER-VERIFIED — see the same caveat already on student-login/
// index.ts; written by close cross-reference against documented djwt usage,
// not by executing it against a live Deno runtime.

import { verify } from "https://deno.land/x/djwt@v2.8/mod.ts";

declare const Deno: any;

export class InvalidStudentTokenError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "InvalidStudentTokenError";
  }
}

/**
 * Verifies `authHeader` (the raw `Authorization` header value) as a student
 * JWT signed by student-login, and returns the verified `student_id` claim.
 *
 * Throws `InvalidStudentTokenError` for anything not a well-formed,
 * signature-valid, unexpired student token — callers should map this to a
 * 401, never trust a claim read out before this returns successfully.
 */
export async function verifyStudentJwt(authHeader: string | null): Promise<string> {
  if (!authHeader || !authHeader.toLowerCase().startsWith("bearer ")) {
    throw new InvalidStudentTokenError("Missing or malformed Authorization header.");
  }
  const token = authHeader.slice("bearer ".length).trim();
  if (token.length === 0) {
    throw new InvalidStudentTokenError("Missing bearer token.");
  }

  const jwtSecret = Deno.env.get("STUDENT_JWT_SIGNING_SECRET");
  if (!jwtSecret) {
    // Distinguished from a bad token by the caller — this is a
    // server-misconfiguration case (500), not a 401.
    throw new Error("STUDENT_JWT_SIGNING_SECRET is not configured.");
  }

  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(jwtSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );

  let payload: Record<string, unknown>;
  try {
    payload = (await verify(token, cryptoKey)) as Record<string, unknown>;
  } catch (_err) {
    throw new InvalidStudentTokenError("Invalid or expired session token.");
  }

  const studentId = payload["student_id"];
  if (typeof studentId !== "string" || studentId.trim().length === 0) {
    throw new InvalidStudentTokenError("Session token has no student_id claim.");
  }

  return studentId;
}
