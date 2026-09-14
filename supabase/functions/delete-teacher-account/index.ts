// Permanently deletes an archived Teacher's Supabase Auth identity.
// Authorization and dependency eligibility are checked with the caller's own
// JWT before a separate service-role client is created for Auth Admin only.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

declare const Deno: any;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, {
      code: "method_not_allowed",
      message: "Method not allowed.",
    });
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
      console.error("delete-teacher-account is missing required secrets.");
      return jsonResponse(500, {
        code: "server_misconfigured",
        message: "Something went wrong. Please try again.",
      });
    }

    const body = await req.json().catch(() => null);
    const teacherId =
      body && typeof body === "object"
        ? (body as Record<string, unknown>)["teacher_id"]
        : null;
    if (typeof teacherId !== "string" || teacherId.trim().length === 0) {
      return jsonResponse(400, {
        code: "validation_error",
        message: "teacher_id is required.",
      });
    }

    // The forwarded JWT is essential: app.is_admin() must evaluate the real
    // caller, never the service-role client used later for Auth deletion.
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: eligibility, error: eligibilityError } = await callerClient
      .rpc("teacher_account_delete_eligibility", {
        p_teacher_id: teacherId,
      });

    if (eligibilityError) {
      console.error("Teacher delete eligibility failed:", eligibilityError);
      return jsonResponse(400, {
        code: "eligibility_failed",
        message: "Could not verify whether this account can be deleted.",
      });
    }

    const blocked = classifyEligibility(String(eligibility));
    if (blocked) return jsonResponse(blocked.status, blocked.body);

    const serviceRoleClient = createClient(supabaseUrl, serviceRoleKey);
    const { error: deleteError } = await serviceRoleClient.auth.admin.deleteUser(
      teacherId,
      false,
    );
    if (deleteError) {
      console.error("Supabase Auth Teacher deletion failed:", deleteError);
      return jsonResponse(409, {
        code: "teacher_delete_blocked",
        message:
          "This Teacher account has related records that must be preserved and cannot be permanently deleted.",
      });
    }

    // Uploaded lesson images use one flat, per-Teacher folder. Account
    // deletion has already succeeded, so cleanup is best-effort and never
    // exposes Storage errors or credentials to the client.
    await removeTeacherImages(serviceRoleClient, teacherId);

    const { error: auditError } = await callerClient.rpc(
      "record_teacher_account_permanent_delete",
      { p_teacher_id: teacherId },
    );
    if (auditError) {
      console.error(
        "Teacher permanent-delete audit logging failed:",
        auditError,
      );
    }

    return jsonResponse(200, { success: true });
  } catch (error) {
    console.error("delete-teacher-account unexpected error:", error);
    return jsonResponse(500, {
      code: "unexpected_error",
      message: "Something went wrong. Please try again.",
    });
  }
});

function classifyEligibility(value: string):
  | { status: number; body: { code: string; message: string } }
  | null {
  switch (value) {
    case "eligible":
      return null;
    case "not_authorized":
      return {
        status: 403,
        body: {
          code: value,
          message: "You are not permitted to delete Teacher accounts.",
        },
      };
    case "not_found":
    case "not_teacher":
      return {
        status: 404,
        body: { code: value, message: "Teacher account not found." },
      };
    case "not_archived":
      return {
        status: 409,
        body: {
          code: value,
          message: "Only archived Teacher accounts can be permanently deleted.",
        },
      };
    case "has_students":
    case "has_lessons":
    case "has_quizzes":
    case "has_questions":
      return {
        status: 409,
        body: {
          code: value,
          message:
            "This Teacher account owns student or learning records that must be " +
            "preserved and cannot be permanently deleted.",
        },
      };
    default:
      return {
        status: 400,
        body: {
          code: "unknown_eligibility",
          message: "Could not verify whether this account can be deleted.",
        },
      };
  }
}

async function removeTeacherImages(
  client: any,
  teacherId: string,
): Promise<void> {
  try {
    const paths: string[] = [];
    let offset = 0;
    const limit = 100;
    while (true) {
      const { data, error } = await client.storage
        .from("lesson-images")
        .list(teacherId, { limit, offset });
      if (error) throw error;
      const objects = (data ?? []).filter(
        (item: { id?: string | null; name: string }) => item.id != null,
      );
      paths.push(
        ...objects.map(
          (item: { name: string }) => `${teacherId}/${item.name}`,
        ),
      );
      if ((data ?? []).length < limit) break;
      offset += limit;
    }
    if (paths.length > 0) {
      const { error } = await client.storage.from("lesson-images").remove(paths);
      if (error) throw error;
    }
  } catch (error) {
    console.error("Teacher image cleanup failed:", error);
  }
}
