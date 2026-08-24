// view-student-password
//
// Wraps `public.view_student_password` (0020 -> `app.view_student_password`,
// 0017). Same auth model as create-student/set-student-password: forwards
// the caller's own JWT, never service_role. Audit-logged server-side on
// every call, not just every change (0017).
//
// This is the "Lower / can defer" item from the handoff prompt §4 — included
// because, given the create-student/set-student-password pattern already
// exists, it added minimal scope on top.
//
// NOT COMPILER-VERIFIED — see the note in create-student/index.ts; the same
// caveat applies here.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

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

    const encryptionKey = Deno.env.get("STUDENT_CREDENTIALS_ENCRYPTION_KEY");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

    if (!encryptionKey || !supabaseUrl || !anonKey) {
      console.error("view-student-password is missing required environment secrets.");
      return jsonResponse(500, {
        code: "server_misconfigured",
        message: "Something went wrong. Please try again.",
      });
    }

    const supabase = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return jsonResponse(400, { code: "invalid_body", message: "Request body must be JSON." });
    }

    const { student_id } = body as Record<string, unknown>;
    if (typeof student_id !== "string" || student_id.trim().length === 0) {
      return jsonResponse(400, { code: "validation_error", message: "student_id is required." });
    }

    const { data, error } = await supabase.rpc("view_student_password", {
      p_student_id: student_id,
      p_encryption_key: encryptionKey,
    });

    if (error) {
      const { status, message } = classifyPostgresError(error);
      return jsonResponse(status, { code: "view_password_failed", message });
    }

    return jsonResponse(200, { password: data });
  } catch (err) {
    console.error("view-student-password unexpected error:", err);
    return jsonResponse(500, {
      code: "unexpected_error",
      message: "Something went wrong. Please try again.",
    });
  }
});

function classifyPostgresError(error: { message?: string }): { status: number; message: string } {
  const message = (error.message ?? "").toLowerCase();

  if (message.includes("not authorized")) {
    return { status: 403, message: "You are not permitted to view this student's password." };
  }
  if (message.includes("not found")) {
    return { status: 404, message: "Student not found." };
  }
  return { status: 400, message: "Could not retrieve the password." };
}
