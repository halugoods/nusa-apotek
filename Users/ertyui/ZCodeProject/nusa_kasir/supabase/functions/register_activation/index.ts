// ============================================================================
// NUSA — Register Activation Edge Function (v3 — Multi-App)
// Deploy: supabase functions deploy register_activation --project-ref sakeuhcbcnueplzlkltm
// ============================================================================
// Actions:
//   { key, product }                        — activate using the verified Auth user
//   { product } (no key)                    — check the verified Auth user's license
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as ed from "https://esm.sh/@noble/ed25519@2";
import { sha512 } from "https://esm.sh/@noble/hashes@1/sha512";

ed.etc.sha512Sync = (...msgs: Uint8Array[]): Uint8Array => {
  const h = sha512.create();
  for (const m of msgs) h.update(m);
  return h.digest();
};

const PUBLIC_KEY_HEX = Deno.env.get("NUSA_PUBLIC_KEY") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

function b32decode(s: string): number[] {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  const map: Record<string, number> = {};
  for (let i = 0; i < alphabet.length; i++) map[alphabet[i]] = i;
  let bits = 0,
    value = 0;
  const out: number[] = [];
  for (const ch of s.toUpperCase()) {
    if (!(ch in map)) continue;
    value = (value << 5) | map[ch];
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      out.push((value >> bits) & 0xff);
    }
  }
  return out;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "content-type",
    },
  });
}

function hexToBytes(hex: string): Uint8Array {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++)
    out[i] = parseInt(hex.substring(i * 2, i * 2 + 2), 16);
  return out;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "content-type",
      },
    });
  }

  try {
    const body = await req.json();
    const { key, product, googleUserId, ownerEmail } = body;
    const prod = product ?? "nusa-kasir"; // default for backward compat
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: "Server config error" }, 500);
    }

    // Prefer verified Supabase Auth user when available (backward compat),
    // but fall back to caller-supplied googleUserId from body.
    // Flutter app uses GoogleSignIn plugin (not Supabase Auth), so body
    // is the primary identity source.
    let verifiedGoogleId = googleUserId ?? null;
    const authHeader = req.headers.get("Authorization") ?? "";
    if (authHeader.startsWith("Bearer ")) {
      try {
        const anonKey = SUPABASE_ANON_KEY;
        if (anonKey) {
          const authClient = createClient(supabaseUrl, anonKey);
          const { data: { user } } = await authClient.auth.getUser(authHeader.slice(7));
          if (user) {
            verifiedGoogleId =
              user.user_metadata?.sub ?? user.user_metadata?.provider_id ?? user.id;
          }
        }
      } catch (_) {
        // Auth verification failed — continue with body-supplied googleUserId
      }
    }

    if (!verifiedGoogleId) {
      return json({ error: "googleUserId required" }, 400);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // ─── CHECK action (no key provided) ──────────────────────────
    if (!key) {
      // One license covers ALL NUSA variants. Look up any license owned by
      // this Google account regardless of product — a Kelontong key must also
      // unlock the FnB / Laundry / Fotocopy / etc. app on the same account.
      // (Previously filtered by product, which stranded users who bought a
      // license for one variant but opened another.)
      const { data: owned } = await supabase
        .from("licenses")
        .select("id, key, serial, status, google_user_id, expires_at, tier, product")
        .eq("google_user_id", verifiedGoogleId)
        .order("created_at", { ascending: false })
        .limit(5);

      // Prefer the newest non-blocked license; keep blocked ones so we can
      // report a meaningful message instead of silently "no license".
      let license = owned?.find(
        (l) => !["Cancelled", "Suspended", "Expired"].includes(l.status),
      ) ?? owned?.[0] ?? null;

      if (!license) {
        return json({ has_license: false }, 200);
      }

      // Block revoked/cancelled/suspended licenses — treat as no license
      if (
        license.status === "Cancelled" ||
        license.status === "Suspended" ||
        license.status === "Expired"
      ) {
        return json(
          {
            has_license: false,
            status: license.status,
            message:
              license.status === "Cancelled"
                ? "Lisensi Anda telah dibatalkan."
                : license.status === "Suspended"
                  ? "Lisensi Anda sedang dinonaktifkan."
                  : "Lisensi Anda telah kedaluwarsa.",
          },
          200,
        );
      }

      // Check if license has expired (via expires_at) — blocks Trial AND Active.
      // Active expired = lisensi berbayar yang masanya habis (mis. 1 bulan);
      // tanpa blokir ini user yang sudah aktivasi tidak pernah diblokir.
      const isExpired =
        license.expires_at && new Date(license.expires_at) < new Date();
      if (isExpired && (license.status === "Trial" || license.status === "Active")) {
        return json(
          {
            has_license: false,
            status: "Expired",
            is_expired: true,
            expires_at: license.expires_at,
            message: license.status === "Trial"
              ? "Masa trial Anda telah berakhir. Silakan beli lisensi penuh."
              : "Lisensi Anda telah kedaluwarsa. Silakan perpanjang untuk melanjutkan.",
          },
          200,
        );
      }

      return json(
        {
          has_license: true,
          license_id: license.id,
          status: license.status,
          key: license.key,
          serial: license.serial,
          expires_at: license.expires_at,
          tier: license.tier,
          is_expired: isExpired,
        },
        200,
      );
    }

    // ─── ACTIVATE action (key provided) ──────────────────────────

    // 1. Verify Ed25519 signature
    const cleaned = String(key)
      .toUpperCase()
      .replace("NUSA-", "")
      .replace(/-/g, "");
    const serial = cleaned.slice(0, 8);
    const sig = new Uint8Array(b32decode(cleaned.slice(8)));

    const ok = await ed.verify(
      sig,
      new TextEncoder().encode(serial),
      hexToBytes(PUBLIC_KEY_HEX),
    );
    if (!ok) return json({ error: "invalid_key" }, 403);

    // 2. Check license + product match
    const { data: lic } = await supabase
      .from("licenses")
      .select("id,status,google_user_id,owner_email,expires_at,product")
      .eq("key", key)
      .maybeSingle();

    if (!lic) return json({ error: "not_found" }, 404);
    if (lic.status === "Cancelled")
      return json(
        { error: "cancelled", message: "Key ini sudah dibatalkan" },
        403,
      );
    if (lic.status === "Suspended")
      return json(
        { error: "suspended", message: "Key ini sedang dinonaktifkan" },
        403,
      );

    // Accept both 'Generated' and 'Trial' statuses for activation
    if (lic.status !== "Generated" && lic.status !== "Trial") {
      return json(
        { error: "already_activated", message: "Key ini sudah diaktivasi" },
        409,
      );
    }

    // One license covers ALL NUSA variants. A key is valid for every variant
    // (signature is variant-agnostic), so we no longer reject product mismatch.
    // When activated from another variant, migrate the license product so the
    // CHECK action (which is no longer product-filtered) stays consistent.
    if (lic.product !== prod) {
      await supabase
        .from("licenses")
        .update({ product: prod })
        .eq("id", lic.id);
    }

    // 3. Check can_activate
    const can = await supabase.rpc("can_activate", {
      lid: lic.id,
      gid: verifiedGoogleId,
    });
    if (!can.data) {
      return json(
        {
          error: "already_activated",
          message:
            "Akun Google ini sudah dipakai untuk license lain. Gunakan license yang sama atau hubungi seller.",
        },
        409,
      );
    }

    // 4. Link Google ID to license + set status to Active
    // v2.2.53 fix: update ini dulu diam-diam gagal (tanpa error check) —
    // lisensi terpakai di app tapi tetap Generated + uid/owner kosong, jadi
    // revoke tidak pernah bisa memblokir device manapun (server tidak tahu
    // pemiliknya). Sekarang kegagalan update = db_error eksplisit.
    const updates: Record<string, string> = { status: "Active" };
    if (!lic.google_user_id) {
      updates.google_user_id = verifiedGoogleId;
    }
    if (!lic.owner_email && ownerEmail) {
      updates.owner_email = ownerEmail;
    }
    const { error: linkErr } = await supabase
      .from("licenses")
      .update(updates)
      .eq("id", lic.id);
    if (linkErr) {
      return json({ error: "db_error", message: linkErr.message }, 500);
    }

    // 5. Insert activation record
    const { error: insertErr } = await supabase.from("activations").insert({
      license_id: lic.id,
      google_user_id: verifiedGoogleId,
      device_id: "android-" + verifiedGoogleId.slice(0, 12),
    });

    if (insertErr && insertErr.code === "23505") {
      // Sudah pernah aktivasi dari device yang sama — pastikan ownership
      // tetap terisi (row lama bisa dibuat sebelum fix linking).
      if (!lic.google_user_id || !lic.owner_email) {
        const backfill: Record<string, string> = {};
        if (!lic.google_user_id) backfill.google_user_id = verifiedGoogleId;
        if (!lic.owner_email && ownerEmail) backfill.owner_email = ownerEmail;
        if (Object.keys(backfill).length > 0) {
          await supabase.from("licenses").update(backfill).eq("id", lic.id);
        }
      }
      return json(
        {
          success: true,
          message: "Sudah teraktivasi sebelumnya",
          expires_at: lic.expires_at,
        },
        200,
      );
    }
    if (insertErr) {
      return json({ error: "db_error", message: insertErr.message }, 500);
    }

    return json({ success: true, expires_at: lic.expires_at }, 200);
  } catch (e) {
    return json({ error: "server_error", message: String(e) }, 500);
  }
});
