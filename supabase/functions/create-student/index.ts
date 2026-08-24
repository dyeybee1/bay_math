// create-student
//
// Wraps `public.create_student` (0020, itself a pass-through to
// `app.create_student`, 0017). This is the ONLY sanctioned way the Flutter
// client creates a student account — never `.rpc()` directly (see
// 0017_student_authentication.sql's comment and the handoff prompt §6):
// the encryption key must never exist in the Flutter client.
//
// Auth model: forwards the CALLER's OWN JWT (the signed-in Teacher's
// bearer token) to Postgres, so `auth.uid()` inside `app.create_student`
// resolves to the real teacher and its own `app.is_admin() or
// (app.is_approved_teacher() and app.teacher_has_section(...))` check
// works exactly as if the Teacher had called it directly. This function
// does NOT use the service_role key — unlike student-login, it must not
// bypass RLS/ownership checks.
//
// NOT COMPILER-VERIFIED: I do not have a Deno/Supabase CLI environment to
// run `deno check` or `supabase functions serve` against this file. Written
// by close cross-reference against the documented Supabase Edge Functions
// pattern (createClient from esm.sh, Deno.serve, forwarding Authorization),
// not by executing it. Please run `supabase functions serve create-student`
// locally before deploying, per the handoff prompt's request to flag
// anything unverified rather than presenting it as tested.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const DenoRuntime = (globalThis as any).Deno;

DenoRuntime.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse(401, {
        code: "missing_authorization",
        message: "You must be signed in to do this.",
      });
    }

    const encryptionKey = DenoRuntime.env.get("STUDENT_CREDENTIALS_ENCRYPTION_KEY");
    const supabaseUrl = DenoRuntime.env.get("SUPABASE_URL");
    const anonKey = DenoRuntime.env.get("SUPABASE_ANON_KEY");

    if (!encryptionKey || !supabaseUrl || !anonKey) {
      console.error("create-student is missing required environment secrets.");
      return jsonResponse(500, {
        code: "server_misconfigured",
        message: "Something went wrong. Please try again.",
      });
    }

    // Forward the caller's own JWT — never service_role here.
    const supabase = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return jsonResponse(400, { code: "invalid_body", message: "Request body must be JSON." });
    }

    const { username, full_name, password, section_id, student_number } = body as Record<string, unknown>;

    if (typeof username !== "string" || username.trim().length === 0) {
      return jsonResponse(400, { code: "validation_error", message: "Username is required." });
    }
    if (typeof full_name !== "string" || full_name.trim().length === 0) {
      return jsonResponse(400, { code: "validation_error", message: "Full name is required." });
    }
    if (typeof password !== "string" || password.length < 4) {
      return jsonResponse(400, {
        code: "validation_error",
        message: "Password must be at least 4 characters.",
      });
    }
    if (typeof section_id !== "string" || section_id.trim().length === 0) {
      return jsonResponse(400, { code: "validation_error", message: "section_id is required." });
    }

    const { data, error } = await supabase.rpc("create_student", {
      p_username: username,
      p_full_name: full_name,
      p_password: password,
      p_section_id: section_id,
      p_encryption_key: encryptionKey,
      p_student_number:
        typeof student_number === "string" && student_number.trim().length > 0
          ? student_number.trim()
          : null,
    });

    if (error) {
      const { status, message } = classifyPostgresError(error);
      return jsonResponse(status, { code: "create_student_failed", message });
    }

    return jsonResponse(200, { student_id: data });
  } catch (err) {
    console.error("create-student unexpected error:", err);
    return jsonResponse(500, {
      code: "unexpected_error",
      message: "Something went wrong. Please try again.",
    });
  }
});

function classifyPostgresError(error: { message?: string; code?: string }): {
  status: number;
  message: string;
} {
  const message = (error.message ?? "").toLowerCase();

  if (message.includes("not authorized")) {
    return { status: 403, message: "You are not permitted to add a student to this section." };
  }
  if (message.includes("does not meet the minimum length")) {
    return { status: 400, message: "Password must be at least 4 characters." };
  }
  if (error.code === "23505") {
    return { status: 409, message: "That username is already taken." };
  }
  return { status: 400, message: "Could not create the student account." };
}
