// update-teacher-email
//
// Wraps `public.update_teacher_email` (0049 -> `app.update_teacher_email`,
// same migration) AND separately updates the teacher's actual sign-in
// email in `auth.users`, since Postgres/PostgREST cannot reach the Supabase
// Auth (GoTrue) Admin API on its own (see 0049's header comment). This
// function is the only place those two updates are stitched together.
//
// Auth model — TWO clients, same shape as create-student + student-login
// combined, for two different reasons:
//   1. Forwarded-JWT client (ANON key + caller's own Authorization header,
//      same pattern as create-student/index.ts): used for the profiles.email
//      lookup/update via `update_teacher_email`, so `auth.uid()` inside
//      `app.update_teacher_email` resolves to the real calling Admin and its
//      own `app.is_admin()` check works exactly as if the Admin had called
//      it directly. This function does not re-implement that authorization
//      check itself — it trusts the RPC's own admin-only guard.
//   2. service_role client (no forwarded Authorization, same pattern as
//      student-login/index.ts): used ONLY for `supabase.auth.admin.
//      updateUserById`, since the Auth Admin API is service_role-only by
//      Supabase design — there is no way to reach it with a forwarded user
//      JWT, admin or not.
//
// ORDERING / PARTIAL-FAILURE HANDLING: `profiles.email` is updated first
// (step 7), THEN `auth.users.email` (step 8), because the RPC is what
// performs the actual authorization + "must be an approved teacher" +
// validation checks — attempting the Auth Admin API call first would mean
// possibly changing the real sign-in email before we even know the caller
// is allowed to. If the Auth Admin API call then fails, we best-effort roll
// `profiles.email` back to what it was (step 9) so the two tables don't
// drift out of sync silently. This rollback is best-effort only: it cannot
// be wrapped in a real transaction with the RPC call (they're two separate
// HTTP round-trips to two different Postgres roles), so a failure of the
// rollback itself is logged, not thrown — the caller still needs to see the
// real (502) error, not a rollback error masking it.
//
// `email_confirm: true` on updateUserById is a deliberate product decision
// (per the handoff prompt) — the new email takes effect immediately with no
// confirmation-email step. Do not add one without checking with product
// first.
//
// NOT COMPILER-VERIFIED — I have no Deno/Supabase CLI environment to run
// `deno check` or `supabase functions serve` against this file, same
// caveat as create-student/index.ts and student-login/index.ts. Written by
// close cross-reference against the other Edge Functions in this codebase
// and documented Supabase Edge Functions / supabase-js Admin API usage, not
// by executing it. In particular, the exact shape of
// `supabase.auth.admin.updateUserById`'s error object (whether it always
// has `.message`, whether it can throw instead of returning `{ error }`,
// etc.) is taken from supabase-js's documented AuthError shape, not
// verified against a live call — please run
// `supabase functions serve update-teacher-email` locally and exercise the
// happy path, the "email already in use" path (both the profiles-level
// 23505 AND, if reachable, an auth.users-level collision), and a forced
// step-8 failure (e.g. temporarily wrong service role key) before deploying.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

declare const Deno: any;

Deno.serve(async (req: Request) => {
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

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      console.error("update-teacher-email is missing required environment secrets.");
      return jsonResponse(500, {
        code: "server_misconfigured",
        message: "Something went wrong. Please try again.",
      });
    }

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return jsonResponse(400, { code: "invalid_body", message: "Request body must be JSON." });
    }

    const { teacher_id, new_email } = body as Record<string, unknown>;

    if (typeof teacher_id !== "string" || teacher_id.trim().length === 0) {
      return jsonResponse(400, { code: "validation_error", message: "teacher_id is required." });
    }
    if (typeof new_email !== "string" || new_email.trim().length === 0) {
      return jsonResponse(400, { code: "validation_error", message: "new_email is required." });
    }

    // Normalize ONCE and reuse the same string for both the RPC call and
    // the Auth Admin API call below. app.update_teacher_email (0049)
    // normalizes internally (lower(trim(...))) before storing to
    // profiles.email, but GoTrue's own normalization of auth.users.email
    // is not guaranteed to produce an identical result from the raw input
    // independently — normalizing here guarantees the exact same string
    // reaches both tables, rather than relying on two separate
    // normalization implementations agreeing.
    const normalizedEmail = new_email.trim().toLowerCase();

    // Forward the caller's own JWT — never service_role for the RPC call,
    // so app.update_teacher_email's own app.is_admin() check runs as the
    // real calling Admin, not this function.
    const supabase = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    // Look up the CURRENT email before changing anything, so we have a
    // known-good value to roll back to if the Auth Admin API call (step 8)
    // fails after the profiles update (step 7) has already succeeded.
    const { data: existingProfile, error: lookupError } = await supabase
      .from("profiles")
      .select("email")
      .eq("id", teacher_id)
      .maybeSingle();

    if (lookupError || !existingProfile) {
      return jsonResponse(404, { code: "not_found", message: "Teacher not found." });
    }

    const oldEmail = existingProfile.email as string;

    const { error: rpcError } = await supabase.rpc("update_teacher_email", {
      p_teacher_id: teacher_id,
      p_new_email: normalizedEmail,
    });

    if (rpcError) {
      // Nothing has been touched yet at this point — the RPC call either
      // fully succeeded or fully failed, so no rollback is needed here.
      const { status, message } = classifyPostgresError(rpcError);
      return jsonResponse(status, { code: "update_teacher_email_failed", message });
    }

    // profiles.email is now updated. From here on, a failure means the two
    // tables are at risk of drifting out of sync, so we attempt a rollback
    // on failure below.
    const serviceRoleClient = createClient(supabaseUrl, serviceRoleKey);

    const { error: authUpdateError } = await serviceRoleClient.auth.admin.updateUserById(
      teacher_id,
      { email: normalizedEmail, email_confirm: true },
    );

    if (authUpdateError) {
      console.error("update-teacher-email: auth.users email update failed:", authUpdateError);

      // Best-effort rollback of profiles.email to the pre-update value.
      // Wrapped separately so a rollback failure doesn't mask the real
      // error being returned below.
      try {
        const { error: rollbackError } = await supabase.rpc("update_teacher_email", {
          p_teacher_id: teacher_id,
          p_new_email: oldEmail,
        });
        if (rollbackError) {
          console.error(
            "update-teacher-email: rollback of profiles.email also failed:",
            rollbackError,
          );
        }
      } catch (rollbackErr) {
        console.error(
          "update-teacher-email: unexpected error during rollback of profiles.email:",
          rollbackErr,
        );
      }

      return jsonResponse(502, {
        code: "auth_email_update_failed",
        message: "Could not update the sign-in email. Please try again.",
      });
    }

    return jsonResponse(200, { success: true });
  } catch (err) {
    console.error("update-teacher-email unexpected error:", err);
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
    return { status: 403, message: "You are not permitted to update this teacher's email." };
  }
  if (message.includes("not found") || message.includes("not active")) {
    return { status: 404, message: "Teacher not found." };
  }
  if (message.includes("valid email")) {
    return { status: 400, message: "A valid email is required." };
  }
  if (error.code === "23505") {
    return { status: 409, message: "That email is already in use." };
  }
  return { status: 400, message: "Could not update the email." };
}
