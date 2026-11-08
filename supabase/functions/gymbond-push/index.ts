// GymBond push (8 Nov 2026, docs/GYMBOND-PLAN.md): sends the rows queued in gb_bond_notifications to
// the recipient's iPhones through APNs, then marks them sent. Called by the database trigger on each
// new row (pg_net, with the shared secret from the Vault) and safe to call with no body, which drains
// whatever is waiting. Deploy with `supabase functions deploy gymbond-push --no-verify-jwt` and set
// the secrets in supabase/README.md §6. Never sends names anywhere but to the bonded friend's phone.

import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import { importPKCS8, SignJWT } from "npm:jose@5.9.6";

const env = (key: string) => Deno.env.get(key) ?? "";
const PUSH_KEY = env("GYMBOND_PUSH_KEY");
const TEAM_ID = env("APNS_TEAM_ID");
const KEY_ID = env("APNS_KEY_ID");
const TOPIC = env("APNS_TOPIC") || "com.sodhera.gymblock";
// The .p8 file's contents; a one-line secret may carry its newlines escaped.
const PRIVATE_KEY = env("APNS_PRIVATE_KEY").replace(/\\n/g, "\n");

type Row = { id: string; user_id: string; kind: string; title: string; body: string; payload: Record<string, unknown> };
type Device = { install_id: string; apns_token: string; apns_environment: string | null };

// APNs accepts a provider token for an hour; one is signed per cold start and reused for 50 minutes.
let provider: { token: string; at: number } | null = null;
async function providerToken(): Promise<string> {
  if (provider && Date.now() - provider.at < 50 * 60 * 1000) return provider.token;
  const key = await importPKCS8(PRIVATE_KEY, "ES256");
  const token = await new SignJWT({}).setProtectedHeader({ alg: "ES256", kid: KEY_ID }).setIssuer(TEAM_ID).setIssuedAt().sign(key);
  provider = { token, at: Date.now() };
  return token;
}

async function send(device: Device, row: Row): Promise<{ ok: boolean; reason?: string; gone?: boolean }> {
  // A Debug build registers with the sandbox; the App Store build with production.
  const host = device.apns_environment === "development" ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com";
  const response = await fetch(`${host}/3/device/${device.apns_token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${await providerToken()}`,
      "apns-topic": TOPIC,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-expiration": `${Math.floor(Date.now() / 1000) + 6 * 3600}`,
      "apns-collapse-id": `gymbond-${row.kind}`,
    },
    body: JSON.stringify({
      aps: { alert: { title: row.title, body: row.body }, sound: "default", "thread-id": "gymbond" },
      gymbond: { kind: row.kind, ...row.payload },
    }),
  });
  if (response.ok) return { ok: true };
  let reason = `${response.status}`;
  try { reason = (await response.json()).reason ?? reason; } catch { /* no body */ }
  // The token no longer belongs to the app: drop it so the row isn't retried against it.
  const gone = response.status === 410 || reason === "BadDeviceToken" || reason === "Unregistered" || reason === "DeviceTokenNotForTopic";
  return { ok: false, reason, gone };
}

Deno.serve(async (request) => {
  if (!PUSH_KEY || request.headers.get("authorization") !== `Bearer ${PUSH_KEY}`) {
    return new Response("forbidden", { status: 403 });
  }
  if (!TEAM_ID || !KEY_ID || !PRIVATE_KEY) {
    return Response.json({ error: "APNS_TEAM_ID, APNS_KEY_ID and APNS_PRIVATE_KEY must be set" }, { status: 500 });
  }
  const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), { auth: { persistSession: false } });

  let wanted: string | null = null;
  try { wanted = (await request.json())?.id ?? null; } catch { /* no body: drain the queue */ }
  let query = supabase.from("gb_bond_notifications").select("id, user_id, kind, title, body, payload")
    .is("sent_at", null).order("created_at").limit(50);
  if (wanted) query = query.eq("id", wanted);
  const { data: rows, error } = await query;
  if (error) return Response.json({ error: error.message }, { status: 500 });

  let sent = 0, failed = 0;
  for (const row of (rows ?? []) as Row[]) {
    const { data: devices } = await supabase.from("gb_devices").select("install_id, apns_token, apns_environment")
      .eq("user_id", row.user_id).not("apns_token", "is", null);
    const errors: string[] = [];
    let delivered = 0;
    for (const device of (devices ?? []) as Device[]) {
      try {
        const result = await send(device, row);
        if (result.ok) { delivered += 1; continue; }
        errors.push(`${device.install_id}: ${result.reason}`);
        if (result.gone) {
          await supabase.from("gb_devices").update({ apns_token: null, apns_environment: null }).eq("install_id", device.install_id);
        }
      } catch (caught) {
        errors.push(`${device.install_id}: ${caught instanceof Error ? caught.message : String(caught)}`);
      }
    }
    // Marked sent either way: a row with no phone to reach, or none that accepted it, is finished.
    const note = (devices ?? []).length === 0 ? "no device token" : errors.length ? errors.join("; ").slice(0, 300) : null;
    await supabase.from("gb_bond_notifications").update({ sent_at: new Date().toISOString(), error: note }).eq("id", row.id);
    if (delivered > 0) sent += 1; else failed += 1;
  }
  return Response.json({ sent, failed });
});
