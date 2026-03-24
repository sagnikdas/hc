import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

// ── Constants ─────────────────────────────────────────────────────────────────

/** Maximum completions accepted per user per hour. Legitimate users do 1–3/day. */
const RATE_LIMIT_PER_HOUR = 20;

/** Only accept completed_at timestamps within this window (ms). */
const MAX_EVENT_AGE_MS = 7 * 24 * 60 * 60 * 1000; // 7 days
const MIN_EVENT_AGE_MS = -60 * 1000; // 1 min future drift allowed

// ── Helpers ───────────────────────────────────────────────────────────────────

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function isValidSessionId(id: unknown): id is string {
  return typeof id === "string" && id.length >= 1 && id.length <= 128;
}

function isValidCompletedAt(raw: unknown): raw is string {
  if (typeof raw !== "string") return false;
  const ts = Date.parse(raw);
  if (isNaN(ts)) return false;
  const now = Date.now();
  const age = now - ts;
  return age <= MAX_EVENT_AGE_MS && age >= MIN_EVENT_AGE_MS;
}

function isValidSource(s: unknown): s is string {
  return typeof s === "string" && ["app", "widget", "test"].includes(s);
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  // Only POST accepted.
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  // ── 1. Verify JWT ──────────────────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "missing_token" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  // Use the caller's JWT to get the authenticated user (validates signature).
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) {
    return jsonResponse({ error: "invalid_token" }, 401);
  }

  // ── 2. Parse + validate payload ────────────────────────────────────────────
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const { session_id, completed_at, source = "app" } = body;

  if (!isValidSessionId(session_id)) {
    return jsonResponse({ error: "invalid_session_id" }, 400);
  }
  if (!isValidCompletedAt(completed_at)) {
    return jsonResponse({ error: "invalid_completed_at" }, 400);
  }
  if (!isValidSource(source)) {
    return jsonResponse({ error: "invalid_source" }, 400);
  }

  // ── 3. Rate limiting (per user, per hour) ──────────────────────────────────
  const admin = createClient(supabaseUrl, serviceKey);
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();

  const { count, error: countError } = await admin
    .from("listen_events")
    .select("*", { count: "exact", head: true })
    .eq("user_id", user.id)
    .gte("completed_at", oneHourAgo);

  if (countError) {
    console.error("rate limit check failed:", countError.message);
    return jsonResponse({ error: "internal_error" }, 500);
  }

  if ((count ?? 0) >= RATE_LIMIT_PER_HOUR) {
    console.warn(`rate_limited user=${user.id} count=${count}`);
    return jsonResponse({ error: "rate_limited" }, 429);
  }

  // ── 4. Idempotent insert ───────────────────────────────────────────────────
  // UNIQUE(user_id, session_id) on the table handles concurrent retries.
  const { error: insertError } = await admin.from("listen_events").insert({
    user_id: user.id,
    session_id,
    completed_at,
    source,
  });

  if (insertError) {
    // Duplicate — already ingested. Return 200 so the client marks it synced.
    if (insertError.code === "23505") {
      return jsonResponse({ ok: true, duplicate: true });
    }
    console.error("insert failed:", insertError.message);
    return jsonResponse({ error: "internal_error" }, 500);
  }

  // ── 5. Refresh materialized leaderboard view (best-effort) ────────────────
  // Runs async so it never blocks the response.
  admin.rpc("refresh_leaderboard").then(({ error }) => {
    if (error) console.warn("leaderboard refresh failed:", error.message);
  });

  return jsonResponse({ ok: true });
});
