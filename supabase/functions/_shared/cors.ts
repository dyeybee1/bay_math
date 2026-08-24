// Shared CORS headers for every Edge Function in this project.
//
// Required because the Flutter app runs on Web (Chrome) in this project's
// dev/test setup — without these, the browser blocks the response before
// the Flutter client ever sees it, regardless of what the function itself
// returns. `Access-Control-Allow-Origin: *` is fine here because these
// functions require the caller's own JWT (forwarded, never widened) or
// validate credentials server-side (student-login) — CORS is not a
// substitute for that, just what makes the browser deliver the response at
// all.
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
