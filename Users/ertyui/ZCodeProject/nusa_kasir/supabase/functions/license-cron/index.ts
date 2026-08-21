// ============================================================================
// NUSA — License Cron Edge Function (v2.2.44 L1)
// Deploy: supabase functions deploy license-cron --project-ref sakeuhcbcnueplzlkltm
// Schedule: supabase functions schedule? — pakai pg_cron / external cron hitting
//   POST https://sakeuhcbcnueplzlkltm.supabase.co/functions/v1/license-cron
//   dengan header Authorization: Bearer <SERVICE_ROLE_KEY> tiap 1 jam.
// ============================================================================
// Menjalankan auto-revoke:
//   1. Semua lisensi dengan expires_at < now() DAN status Active/Trial →
//      status='Expired' + catat event 'expired'.
//   2. (L2) Grace 7 hari = waktu BAYAR sebelum revoke. Setelah status Expired,
//      key TIDAK lagi bisa dipakai (register_activation blokir status Expired),
//      jadi app sudah terkunci sejak hari pertama lewat masa berlaku. Cron ini
//      hanya menandai Expired agar tampilan/laporan konsisten.
//   3. Log semua perubahan ke license_events (audit).
//
// Env vars required:
//   NUSA_CRON_KEY — secret yang dipakai header x-cron-key (bukan service role
//   yang diedarkan ke publik). Default "nusa-cron-2024" untuk dev.
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CRON_KEY = Deno.env.get("NUSA_CRON_KEY") ?? "nusa-cron-2024";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  // Auth: x-cron-key (opsional kalau dipanggil oleh pg_cron internal).
  const cronKey = req.headers.get("x-cron-key") ?? "";
  if (cronKey && cronKey !== CRON_KEY) {
    return json({ error: "Unauthorized" }, 401);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: "Supabase not configured" }, 500);
    }
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const now = new Date().toISOString();

    // ─── 1. Mark expired: Active/Trial dengan expires_at lewat ──────────
    // status='Expired' = terkunci di app (register_activation blokir). Grace
    // 7 hari dihitung oleh app UI (countdown), bukan status terpisah — key
    // langsung tak dipakai begitu expires_at lewat (keputusan user: langsung
    // terkunci).
    const { data: expired } = await supabase
      .from("licenses")
      .select("id, key, status, tier, expires_at")
      .lt("expires_at", now)
      .in("status", ["Active", "Trial"])
      .limit(500);

    let expiredCount = 0;
    for (const lic of (expired ?? [])) {
      const { error: updErr } = await supabase
        .from("licenses")
        .update({ status: "Expired" })
        .eq("id", lic.id);
      if (updErr) continue;
      expiredCount++;
      // Audit trail
      await supabase.from("license_events").insert({
        license_id: lic.id,
        event: "expired",
        detail: `expires_at ${lic.expires_at} < now (${now}); tier=${lic.tier}`,
      });
    }

    // ─── 2. (Opsional) Revoke total: Expired lebih dari 7 hari → status
    // Cancelled (key dicabut permanen). Register_activation sudah memblokir
    // Expired, jadi ini hanya pembersihan label + audit — aman untuk
    // dijalankan tiap jam.
    const graceCutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
    const { data: stale } = await supabase
      .from("licenses")
      .select("id, status, expires_at")
      .eq("status", "Expired")
      .lt("expires_at", graceCutoff)
      .limit(500);

    let revokedCount = 0;
    for (const lic of (stale ?? [])) {
      const { error: updErr } = await supabase
        .from("licenses")
        .update({ status: "Cancelled" })
        .eq("id", lic.id);
      if (updErr) continue;
      revokedCount++;
      await supabase.from("license_events").insert({
        license_id: lic.id,
        event: "revoked",
        detail: `grace 7 hari lewat (expires_at ${lic.expires_at})`,
      });
    }

    return json({
      ok: true,
      expired: expiredCount,
      revoked: revokedCount,
      run_at: now,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
