// Supabase Edge Function: delete-account
//
// Permanently deletes the calling user. The app (Auth.swift →
// SupabaseAuthClient.deleteAccount) POSTs with the user's own JWT; we resolve
// *that* user from the token and delete them with the service role key, which
// never leaves the server. Every GymBlock table (profiles, friendships,
// workouts, workout_details, personal_records, nudges) cascades from
// auth.users → profiles, so one delete removes everything.
//
// Deploy: supabase functions deploy delete-account

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !service) return json({ error: "Server is misconfigured" }, 500);

  const caller = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
  const { data: { user }, error } = await caller.auth.getUser();
  if (error || !user) return json({ error: "Invalid or expired session" }, 401);

  const admin = createClient(url, service, { auth: { autoRefreshToken: false, persistSession: false } });
  const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
  if (delErr) return json({ error: delErr.message }, 500);

  return json({ deleted: true }, 200);
});
