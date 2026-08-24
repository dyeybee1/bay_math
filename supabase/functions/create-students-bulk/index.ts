// create-students-bulk
//
// Wraps `public.create_students_bulk` (supabase/migrations/0055_bulk_create_
// students.sql, itself a pass-through to `app.create_students_bulk` in the
// same migration). This is the sanctioned way the Flutter client bulk-
// creates student accounts for one section — never `.rpc()` directly, for
// the same reason create-student/index.ts already documents: the
// encryption key must never exist in the Flutter client.
//
// Auth model: identical to create-student/index.ts. Forwards the CALLER'S
// OWN JWT (the signed-in Teacher's bearer token) to Postgres, so
// `auth.uid()` inside `app.create_students_bulk` resolves to the real
// teacher and its own `app.is_admin() or (app.is_approved_teacher() and
// app.teacher_has_section(...))` check — checked ONCE for the whole batch,
// not per student — works exactly as if the Teacher had called it
// directly. This function does NOT use the service_role key.
//
// PASSWORD GENERATION HAPPENS HERE, not in Postgres. `app.create_students_
// bulk`'s own header comment is explicit about this split: the database
// never generates predictable passwords, only encrypts whatever plaintext
// it's handed; this function generates that plaintext, keeps it in memory
// for exactly as long as one request, and re-attaches it to the matching
// result row by index before responding — the database's result never
// contains it (see "RESULT SHAPE" in the migration's own header comment).
//
// TWO DISTINCT FAILURE MODES — see the module-level comment on
// classifyBulkPostgresError below for the full explanation of why this
// function's error mapping deliberately does NOT reuse create-student's
// classifyPostgresError as-is (in particular, 23505/unique_violation means
// something different at the batch level than it does for a single
// student).
//
// NOT COMPILER-VERIFIED: same disclosure create-student/index.ts already
// makes, for the same reason — I do not have a Deno/Supabase CLI
// environment to run `deno check` or `supabase functions serve` against
// this file. Written by close cross-reference against the documented
// Supabase Edge Functions pattern and against create-student/index.ts's
// own structure (same createClient-from-esm.sh / Deno.serve / Authorization
// forwarding shape), not by executing it. Please run
// `supabase functions serve create-students-bulk` locally before deploying.
//
// REMAINING UNCERTAINTIES (flagged rather than silently assumed away):
//   - `crypto.getRandomValues` is the standard Web Crypto API and is
//     documented as globally available in the Deno runtime Supabase Edge
//     Functions run on, matching create-student/index.ts's general "written
//     against the documented pattern, not executed" caveat above — I have
//     not run this in an actual Deno process to confirm.
//   - The random-password approach (alphabet, length, source) is described
//     in full below, right above generatePassword(), specifically so the
//     Flutter-side paste UI (a separate follow-up) can be written to match
//     it exactly.
//   - MAX_BATCH_SIZE below (100) is a literal copied from the SQL
//     function's v_max_batch_size at the time of writing. There is no
//     single source of truth for this number across SQL/Edge
//     Function/Flutter — see the comment on the constant itself.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const DenoRuntime = (globalThis as any).Deno;

// Must be kept in sync BY HAND with:
//   - v_max_batch_size in app.create_students_bulk
//     (supabase/migrations/0055_bulk_create_students.sql)
//   - whatever cap the Flutter-side paste UI enforces (Part 2, a separate
//     follow-up — not yet written as of this file).
// Enforcing it here too means a caller gets a clean 400 before any DB
// round trip, instead of the request reaching Postgres only to be rejected
// there with a raw exception. If the SQL constant ever changes, this must
// be changed to match by hand — there is no mechanism in this project that
// keeps the three in sync automatically.
const MAX_BATCH_SIZE = 100;

// ---------------------------------------------------------------------------
// Temporary password generation.
//
// ALPHABET: 8 characters drawn from a 57-character set — uppercase A-Z,
// lowercase a-z, and digits 2-9 — with exactly the five characters the
// spec named excluded: '0' (zero), 'O' (capital o), '1' (one), 'l'
// (lowercase L), 'I' (capital i). Uppercase L and lowercase i/o are
// deliberately KEPT, since the spec named only those five characters, not
// a broader "drop anything that could ever look like anything else" rule.
//
// FLAGGING THIS EXPLICITLY: lowercase 'o' in particular can still look a
// lot like '0' in some fonts, and wasn't on the excluded list. I kept it
// in rather than silently expanding the exclusion set beyond what was
// specified — if a broader exclusion (dropping lowercase o too, for
// instance) is wanted, that's a one-line change to LOWER below, but I
// didn't want to make that call unilaterally since it changes the
// alphabet Part 2 (Flutter) needs to know about.
//
// LENGTH: 8 characters, per the spec's example.
//
// SOURCE OF RANDOMNESS: crypto.getRandomValues (Web Crypto API), NOT
// Math.random() — Math.random() is not a cryptographically secure source
// and these are, even if temporary, real student login credentials.
// secureRandomIndex() below uses rejection sampling (redrawing any byte
// that would introduce modulo bias) rather than a plain `byte % length`,
// so every character of ALPHABET has an exactly equal chance of being
// picked.
// ---------------------------------------------------------------------------
const UPPER = "ABCDEFGHJKLMNPQRSTUVWXYZ"; // A-Z minus I, O
const LOWER = "abcdefghijkmnopqrstuvwxyz"; // a-z minus l
const DIGITS = "23456789"; // 0-9 minus 0, 1
const PASSWORD_ALPHABET = UPPER + LOWER + DIGITS;
const PASSWORD_LENGTH = 8;

function secureRandomIndex(max: number): number {
  // Unbiased random integer in [0, max) via rejection sampling over a
  // single random byte. `range` is the largest multiple of `max` that
  // fits in a byte (0-255); any drawn byte >= range is discarded and
  // redrawn so the remaining outcomes map onto [0, max) with equal
  // probability, avoiding the small bias a plain `byte % max` would
  // introduce whenever 256 is not itself a multiple of max.
  const range = 256 - (256 % max);
  const buf = new Uint8Array(1);
  let x: number;
  do {
    crypto.getRandomValues(buf);
    x = buf[0];
  } while (x >= range);
  return x % max;
}

function generatePassword(): string {
  let out = "";
  for (let i = 0; i < PASSWORD_LENGTH; i++) {
    out += PASSWORD_ALPHABET[secureRandomIndex(PASSWORD_ALPHABET.length)];
  }
  return out;
}

// ---------------------------------------------------------------------------
// The shape one element of app.create_students_bulk's returned JSONB array
// has, per that migration's own "RESULT SHAPE" comment. Duplicated here as
// a type only — not re-declared or re-validated in Postgres.
// ---------------------------------------------------------------------------
interface BulkRpcResultItem {
  index: number;
  full_name: string | null;
  success: boolean;
  student_id?: string;
  username?: string;
  error_code?: string;
  error_message?: string;
}

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
      console.error("create-students-bulk is missing required environment secrets.");
      return jsonResponse(500, {
        code: "server_misconfigured",
        message: "Something went wrong. Please try again.",
      });
    }

    // Forward the caller's own JWT — never service_role here. Same reason
    // create-student/index.ts does this: app.create_students_bulk's
    // authorization check reads auth.uid(), which must resolve to the
    // real signed-in teacher.
    const supabase = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return jsonResponse(400, { code: "invalid_body", message: "Request body must be JSON." });
    }

    const { section_id, full_names } = body as Record<string, unknown>;

    if (typeof section_id !== "string" || section_id.trim().length === 0) {
      return jsonResponse(400, { code: "validation_error", message: "section_id is required." });
    }

    if (!Array.isArray(full_names)) {
      return jsonResponse(400, {
        code: "validation_error",
        message: "full_names must be an array of names.",
      });
    }

    // Trim and drop empties/non-strings before building the RPC payload.
    // Per-name content validation beyond this (max length, etc.) is left
    // to app.create_students_bulk itself, which already reports it as a
    // per-element result rather than a request-level failure — duplicating
    // that here would just be two places to keep in sync for no benefit.
    const trimmedNames = full_names
      .filter((n): n is string => typeof n === "string")
      .map((n) => n.trim())
      .filter((n) => n.length > 0);

    if (trimmedNames.length === 0) {
      return jsonResponse(400, {
        code: "validation_error",
        message: "At least one student name is required.",
      });
    }

    if (trimmedNames.length > MAX_BATCH_SIZE) {
      return jsonResponse(400, {
        code: "batch_size_exceeded",
        message: `You can create at most ${MAX_BATCH_SIZE} students at a time.`,
      });
    }

    // Password generation happens HERE — see the module-level comment
    // above generatePassword(). `passwords[i]` corresponds to
    // `trimmedNames[i]` corresponds to `studentsPayload[i]`, and
    // app.create_students_bulk's own `index` in each result element is
    // documented (see its "RESULT SHAPE" comment) to match that same
    // input array position — so re-attaching by index below is safe.
    const passwords = trimmedNames.map(() => generatePassword());
    const studentsPayload = trimmedNames.map((full_name, i) => ({
      full_name,
      password: passwords[i],
    }));

    const { data, error } = await supabase.rpc("create_students_bulk", {
      p_section_id: section_id,
      p_students: studentsPayload,
      p_encryption_key: encryptionKey,
    });

    if (error) {
      const { status, message } = classifyBulkPostgresError(error);
      return jsonResponse(status, { code: "create_students_bulk_failed", message });
    }

    // Defensive: app.create_students_bulk's contract is "always a JSONB
    // array on success", but a raw `unknown` from .rpc() is worth checking
    // before indexing into it as if the contract always holds.
    if (!Array.isArray(data)) {
      console.error("create-students-bulk: RPC returned a non-array result:", data);
      return jsonResponse(500, {
        code: "unexpected_error",
        message: "Something went wrong. Please try again.",
      });
    }

    const results = (data as BulkRpcResultItem[]).map((item) => {
      if (item.success) {
        return { ...item, password: passwords[item.index] };
      }
      // Never include password on a failed row.
      return item;
    });

    return jsonResponse(200, { results });
  } catch (err) {
    console.error("create-students-bulk unexpected error:", err);
    return jsonResponse(500, {
      code: "unexpected_error",
      message: "Something went wrong. Please try again.",
    });
  }
});

// ---------------------------------------------------------------------------
// classifyBulkPostgresError — deliberately NOT the same mapping as
// create-student/index.ts's classifyPostgresError, for one important
// reason: at the single-student RPC, a 23505/unique_violation reaching
// this layer means the teacher's own chosen username was already taken —
// a normal, expected outcome mapped to 409. At the BULK RPC, per-student
// username collisions are handled and retried entirely inside
// app.create_students_bulk itself (see that migration's "USERNAME
// CONCURRENCY" comment) — they never surface as a thrown RPC error, only
// as `success: false` on that one element of a normal 200 response. So if
// a unique_violation (or any other Postgres error) DOES reach this
// function as a thrown `.rpc()` error, per app.create_students_bulk's own
// "TRANSACTION STRATEGY" comment that specifically means something
// UNEXPECTED happened and the entire batch was rolled back — not that one
// student's username was taken. Mapping it to 409 "already taken" here
// would actively misreport that as an ordinary, expected outcome. The
// fallback branch below is deliberately a 500, not a 400, for the same
// reason: an unclassified error surfacing from this particular RPC call is
// by construction not the caller's fault.
// ---------------------------------------------------------------------------
function classifyBulkPostgresError(error: { message?: string; code?: string }): {
  status: number;
  message: string;
} {
  const rawMessage = error.message ?? "";
  const message = rawMessage.toLowerCase();

  if (message.includes("not authorized")) {
    return {
      status: 403,
      message: "You are not permitted to add students to this section.",
    };
  }

  if (message.includes("p_encryption_key is required")) {
    // This function already checks STUDENT_CREDENTIALS_ENCRYPTION_KEY is
    // non-empty before ever calling the RPC (see the env-secret check
    // above), so reaching this branch would mean that check passed on a
    // value Postgres itself still considers blank (e.g. whitespace-only) —
    // a server-side configuration problem either way, never the teacher's.
    console.error("create-students-bulk: encryption key rejected by the database:", rawMessage);
    return {
      status: 500,
      message: "Something went wrong. Please try again.",
    };
  }

  if (
    message.includes("p_students must be a json array") ||
    message.includes("p_students must not be empty") ||
    message.includes("section_id is required")
  ) {
    // Shouldn't be reachable given this function's own request validation
    // above, but defensive in case that validation and the SQL function's
    // ever drift apart.
    return {
      status: 400,
      message: "Could not process this batch. Please check the student list and try again.",
    };
  }

  if (message.includes("exceeds the maximum of") && message.includes("students per call")) {
    return {
      status: 400,
      message: `You can create at most ${MAX_BATCH_SIZE} students at a time.`,
    };
  }

  if (
    message.includes("could not determine the unique constraint") ||
    message.includes("unique constraints covering public.students.username")
  ) {
    // The constraint-lookup safety net in app.create_students_bulk found
    // zero or more than one UNIQUE constraint covering students.username —
    // a schema-level problem the teacher has no way to act on. Log the
    // real message for whoever's on call and give the caller a generic
    // failure rather than exposing internal schema details.
    console.error("create-students-bulk: username constraint lookup failed:", rawMessage);
    return {
      status: 500,
      message: "Something went wrong. Please try again.",
    };
  }

  // Unclassified — per this function's header comment, an error reaching
  // this point means the bulk RPC itself threw, which by
  // app.create_students_bulk's own design only happens for a genuinely
  // unexpected error that aborted and rolled back the whole batch. Log it
  // and return 500, not 400 — this is not a caller/input problem.
  console.error("create-students-bulk: unclassified RPC error:", rawMessage, error.code);
  return {
    status: 500,
    message: "Something went wrong. Please try again.",
  };
}
