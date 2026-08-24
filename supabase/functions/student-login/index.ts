// student-login
//
// The one Edge Function in this set that legitimately uses service_role:
// `public.verify_student_credentials` (0020 -> `app.verify_student_credentials`,
// 0017) is revoked from every other role because an unauthenticated student
// has no JWT yet at login time — there is no caller identity to forward.
//
// On success, mints a custom-signed JWT per the frozen contract (handoff
// prompt §6 — reproduced exactly, not altered):
//   sub, student_id (same value as sub), role: "authenticated",
//   iat, exp = iat + 8h (flat lifetime, no refresh token, by design),
//   session_id (debugging/log-correlation only, never used in any auth
//   decision).
// Signed with the same secret PostgREST verifies against
// (STUDENT_JWT_SIGNING_SECRET — same value as the project's actual JWT
// secret, just not stored under a SUPABASE_-prefixed name; that prefix is
// reserved by the platform and `supabase secrets set` silently rejects it,
// which is exactly what caused this function to report itself
// misconfigured) — Supabase's own documented custom-auth pattern.
// Response contract (do not alter): 200 {access_token, expires_at} on
// success, 401 {code, message} on failure.
//
// NOT COMPILER-VERIFIED — I have no Deno/Supabase CLI environment to run
// `deno check` or `supabase functions serve` against this file, including
// the djwt import. Written by close cross-reference against documented
// Supabase Edge Functions + djwt usage patterns, not by executing it.
// Please run `supabase functions serve student-login` locally and confirm
// a minted token is actually accepted by PostgREST (e.g. a `GET
// /rest/v1/students` call with it as the bearer token) before relying on
// this for anything real.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2?no-check";
// Use a stable v2.x release of djwt which is widely available on deno.land
import { create } from "https://deno.land/x/djwt@v2.8/mod.ts";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

// For TypeScript checks in non-Deno environments
declare const Deno: any;

const EIGHT_HOURS_IN_SECONDS = 8 * 60 * 60;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const encryptionKey = Deno.env.get("STUDENT_CREDENTIALS_ENCRYPTION_KEY");
    const jwtSecret = Deno.env.get("STUDENT_JWT_SIGNING_SECRET");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!encryptionKey || !jwtSecret || !supabaseUrl || !serviceRoleKey) {
      console.error("student-login is missing required environment secrets.");
      return jsonResponse(500, {
        code: "server_misconfigured",
        message: "Something went wrong. Please try again.",
      });
    }

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return jsonResponse(400, { code: "invalid_body", message: "Request body must be JSON." });
    }

    const { username, password } = body as Record<string, unknown>;
    if (
      typeof username !== "string" ||
      username.trim().length === 0 ||
      typeof password !== "string" ||
      password.length === 0
    ) {
      return jsonResponse(400, {
        code: "validation_error",
        message: "Username and password are required.",
      });
    }

    // service_role — the only role verify_student_credentials is granted to
    // (0017/0020). No caller JWT to forward; there isn't one yet.
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: studentId, error } = await supabase.rpc("verify_student_credentials", {
      p_username: username,
      p_password: password,
      p_encryption_key: encryptionKey,
    });

    if (error) {
      console.error("verify_student_credentials error:", error);
      return jsonResponse(500, {
        code: "unexpected_error",
        message: "Something went wrong. Please try again.",
      });
    }

    if (!studentId) {
      return jsonResponse(401, {
        code: "invalid_credentials",
        message: "Incorrect username or password.",
      });
    }

    const cryptoKey = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(jwtSecret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );

    const issuedAt = Math.floor(Date.now() / 1000);
    const expiresAt = issuedAt + EIGHT_HOURS_IN_SECONDS;

    const accessToken = await create(
      { alg: "HS256", typ: "JWT" },
      {
        sub: studentId,
        student_id: studentId,
        role: "authenticated",
        iat: issuedAt,
        exp: expiresAt,
        session_id: crypto.randomUUID(),
      },
      cryptoKey,
    );

    return jsonResponse(200, { access_token: accessToken, expires_at: expiresAt });
  } catch (err) {
    console.error("student-login unexpected error:", err);
    return jsonResponse(500, {
      code: "unexpected_error",
      message: "Something went wrong. Please try again.",
    });
  }
});