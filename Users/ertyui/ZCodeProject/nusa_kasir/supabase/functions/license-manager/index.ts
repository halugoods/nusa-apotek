// ============================================================================
// NUSA — License Manager Edge Function (v2 — Multi-App + Tier)
// Deploy: supabase functions deploy license-manager --project-ref sakeuhcbcnueplzlkltm
// ============================================================================
// Admin operations for activation key management:
//   action: 'generate'   — generate new signed activation key(s)
//   action: 'add'        — add a pre-generated key (from keygen.dart CLI)
//   action: 'list'       — list all licenses with activation counts
//   action: 'detail'     — get single license with its activations
//   action: 'revoke'     — revoke a license key
//   action: 'delete'     — delete an unused license
//   action: 'stats'      — summary stats
//
// Env vars required for keygen:
//   NUSA_PRIVATE_KEY — 64-char hex Ed25519 private key
//   NUSA_PUBLIC_KEY  — 64-char hex Ed25519 public key
//   NUSA_ADMIN_KEY   — required admin secret (no default; function fails closed)
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as ed from "https://esm.sh/@noble/ed25519@2";
import { sha512 } from "https://esm.sh/@noble/hashes@1/sha512";
import { crypto } from "https://deno.land/std@0.177.0/crypto/mod.ts";

// Polyfill sync sha512 for noble-ed25519 (Deno needs explicit hash setup)
ed.etc.sha512Sync = (...msgs: Uint8Array[]): Uint8Array => {
  const h = sha512.create();
  for (const m of msgs) h.update(m);
  return h.digest();
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-admin-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ADMIN_KEY = Deno.env.get("NUSA_ADMIN_KEY") ?? "";
const PRIVATE_KEY_HEX = Deno.env.get("NUSA_PRIVATE_KEY") ?? "";
const PUBLIC_KEY_HEX = Deno.env.get("NUSA_PUBLIC_KEY") ?? "";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const RESEND_FROM_EMAIL =
  Deno.env.get("RESEND_FROM_EMAIL") ?? "nusa@halugoods.com";

// ─── Keygen (matches tools/keygen/bin/keygen.dart exactly) ────────────

const PREFIX = "NUSA-";
const SERIAL_LEN = 8;
const SERIAL_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const B32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

function generateSerial(): string {
  const bytes = new Uint8Array(SERIAL_LEN);
  crypto.getRandomValues(bytes);
  let buf = "";
  for (let i = 0; i < SERIAL_LEN; i++) {
    buf += SERIAL_ALPHABET[bytes[i] % SERIAL_ALPHABET.length];
  }
  return buf;
}

function base32Encode(data: Uint8Array): string {
  let bits = 0,
    value = 0;
  const out: string[] = [];
  for (const b of data) {
    value = (value << 8) | b;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.push(B32_ALPHABET[(value >> bits) & 31]);
    }
  }
  if (bits > 0) {
    out.push(B32_ALPHABET[(value << (5 - bits)) & 31]);
  }
  return out.join("");
}

function formatKey(serial: string, signature: Uint8Array): string {
  const sigB32 = base32Encode(signature);
  const groups: string[] = [];
  for (let i = 0; i < serial.length; i += 4) {
    groups.push(serial.substring(i, i + 4));
  }
  for (let i = 0; i < sigB32.length; i += 4) {
    groups.push(sigB32.substring(i, i + 4));
  }
  return PREFIX + groups.join("-");
}

function hexToBytes(hex: string): Uint8Array {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.substring(i * 2, i * 2 + 2), 16);
  }
  return out;
}

async function generateKey(): Promise<{ key: string; serial: string }> {
  if (!PRIVATE_KEY_HEX) {
    throw new Error("NUSA_PRIVATE_KEY not set in environment");
  }

  const serial = generateSerial();
  const privKeyBytes = hexToBytes(PRIVATE_KEY_HEX);
  const sig = await ed.sign(new TextEncoder().encode(serial), privKeyBytes);
  const key = formatKey(serial, sig);
  return { key, serial };
}

// ─── Main ─────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Fail closed when the deployment is missing its admin secret.
    const adminKey = req.headers.get("x-admin-key") ?? "";
    if (!ADMIN_KEY || !adminKey || adminKey !== ADMIN_KEY) {
      return json({ error: "Unauthorized" }, 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const { action, ...params } = await req.json();

    switch (action) {
      case "generate":
        return handleGenerate(supabase, params);
      case "add":
        return handleAdd(supabase, params);
      case "list":
        return handleList(supabase, params);
      case "detail":
        return handleDetail(supabase, params);
      case "revoke":
        return handleRevoke(supabase, params);
      case "delete":
        return handleDelete(supabase, params);
      case "stats":
        return handleStats(supabase);
      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (e) {
    return json({ error: e.message }, 500);
  }
});

// ─── Generate new signed activation key(s) ───────────────────────────

async function handleGenerate(supabase: any, params: any) {
  const count = Math.max(1, Math.min(params.count ?? 1, 100));
  const ownerEmail = params.owner_email ?? null;
  const buyerName = params.buyer_name ?? null;
  const sendEmail = params.send_email === true && ownerEmail !== null;
  const isTrial = params.is_trial === true;
  const tier = params.tier ?? (isTrial ? "trial" : "lifetime");
  const product = params.product ?? "nusa-kasir";

  const keys: { key: string; serial: string }[] = [];

  for (let i = 0; i < count; i++) {
    try {
      const k = await generateKey();
      keys.push(k);
    } catch (e) {
      return json({ error: e.message, generated: keys.length }, 500);
    }
  }

  // Calculate expiry based on tier
  let trialExpires: string | null = null;
  if (tier === "trial") {
    trialExpires = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(); // 3 hari
  } else if (tier === "1month") {
    trialExpires = new Date(
      Date.now() + 30 * 24 * 60 * 60 * 1000,
    ).toISOString(); // 1 bulan
  }
  // lifetime: expires_at stays null

  // Insert all into licenses table
  const { error } = await supabase.from("licenses").insert(
    keys.map((k) => ({
      key: k.key,
      serial: k.serial,
      product,
      tier,
      status: tier === "trial" ? "Trial" : "Generated",
      owner_email: ownerEmail,
      expires_at: trialExpires,
    })),
  );

  if (error) {
    return json({ error: error.message, generated: 0 }, 500);
  }

  // Send email if requested
  let emailSent = false;
  let emailError: string | null = null;

  if (sendEmail && ownerEmail && RESEND_API_KEY) {
    try {
      await sendActivationEmail(
        ownerEmail,
        buyerName || "Pelanggan NUSA",
        keys.map((k) => k.key),
        tier,
        product,
      );
      emailSent = true;
    } catch (e) {
      emailError = e.message;
    }
  }

  return json({
    ok: true,
    count: keys.length,
    keys: keys.map((k) => k.key),
    tier,
    product,
    expires_at: trialExpires,
    email_sent: emailSent,
    email_error: emailError,
  });
}

// ─── Send activation key email via Resend ────────────────────────────

async function sendActivationEmail(
  toEmail: string,
  buyerName: string,
  keys: string[],
  tier = "lifetime",
  product = "nusa-kasir",
): Promise<void> {
  const keyList = keys
    .map(
      (k) =>
        `<code style="background:#f3f4f6;padding:4px 8px;border-radius:6px;font-size:13px;font-family:monospace">${k}</code>`,
    )
    .join("<br>");
  const singleKey = keys.length === 1 ? keys[0] : "";
  const stepActivation = singleKey
    ? `<p style="margin:8px 0"><strong>2.</strong> Buka aplikasi &amp; login dengan akun Google Anda</p>
       <p style="margin:8px 0"><strong>3.</strong> Masukkan key aktivasi: <code style="background:#fde8ea;padding:3px 8px;border-radius:5px;font-size:14px;font-weight:600">${singleKey}</code></p>`
    : `<p style="margin:8px 0"><strong>2.</strong> Buka aplikasi &amp; login dengan akun Google Anda</p>
       <p style="margin:8px 0"><strong>3.</strong> Masukkan salah satu key aktivasi di bawah</p>`;

  const productNames: Record<string, string> = {
    "nusa-kelontong": "NUSA Kelontong",
    "nusa-fnb": "NUSA F&B",
    "nusa-laundry": "NUSA Laundry",
    "nusa-bengkel": "NUSA Bengkel",
    "nusa-salon": "NUSA Salon",
    "nusa-apotek": "NUSA Apotek",
    "nusa-fotocopy": "NUSA Fotocopy",
    "nusa-servis": "NUSA Servis",
    "nusa-kasir": "NUSA Kasir",
  };
  const productName = productNames[product] ?? "NUSA";

  const tierLabel =
    tier === "trial"
      ? "Trial 3 Hari"
      : tier === "1month"
        ? "1 Bulan"
        : "Lifetime";
  const tierPrice =
    tier === "trial" ? "GRATIS" : tier === "1month" ? "Rp 49K" : "Rp 199K";

  const subject =
    tier === "trial"
      ? `Trial ${productName} 3 Hari — Key Aktivasi Anda`
      : tier === "1month"
        ? `Lisensi ${productName} 1 Bulan — Key Aktivasi Anda`
        : `Lisensi ${productName} Lifetime — Key Aktivasi Anda`;

  const badge = `<p style="color:#fde8ea;margin:6px 0 0;font-size:13px">${tierLabel} — ${tierPrice}</p>`;

  const trialNotice =
    tier === "trial"
      ? `<div style="background:#fef3c7;border-left:4px solid #f59e0b;border-radius:8px;padding:12px 16px;margin-bottom:24px">
        <p style="margin:0;font-size:13px;color:#92400e">
          ⏳ <strong>Trial 3 Hari</strong> — Key ini berlaku selama 3 hari sejak aktivasi pertama.<br>
          Setelah masa trial habis, kamu bisa beli lisensi seharga <strong>Rp 49K/bulan</strong> atau <strong>Rp 199K lifetime</strong>.
        </p>
      </div>`
      : tier === "1month"
        ? `<div style="background:#fef3c7;border-left:4px solid #f59e0b;border-radius:8px;padding:12px 16px;margin-bottom:24px">
        <p style="margin:0;font-size:13px;color:#92400e">
          📅 <strong>Lisensi 1 Bulan</strong> — Berlaku 30 hari sejak aktivasi.<br>
          Ingin selamanya? Upgrade ke <strong>Rp 199K lifetime</strong> kapan saja.
        </p>
      </div>`
        : `<div style="background:#fef3c7;border-left:4px solid #f59e0b;border-radius:8px;padding:12px 16px;margin-bottom:24px">
        <p style="margin:0;font-size:13px;color:#92400e">
          💡 <strong>Tips:</strong> Satu lisensi bisa dipakai di beberapa perangkat selama menggunakan akun Google yang sama.
        </p>
      </div>`;

  const html = `<!DOCTYPE html>
<html lang="id">
<head><meta charset="utf-8"></head>
<body style="font-family:Arial,Helvetica,sans-serif;background:#f7f7f9;padding:0;margin:0">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f7f7f9;padding:40px 0">
<tr><td align="center">
<table width="540" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.06)">

  <!-- Header -->
  <tr>
    <td style="background:linear-gradient(135deg,#e63946,#c1121f);padding:32px 40px;text-align:center">
      <h1 style="color:#fff;margin:0;font-size:22px;font-weight:800;letter-spacing:-0.5px">${productName}</h1>
      ${badge}
    </td>
  </tr>

  <!-- Body -->
  <tr>
    <td style="padding:32px 40px">

      <p style="font-size:16px;color:#1f2937;margin:0 0 8px">Halo <strong>${buyerName}</strong>, 👋</p>
      <p style="font-size:14px;color:#6b7280;line-height:1.7;margin:0 0 24px">
        ${tier === "trial" ? `Terima kasih sudah mencoba <strong>${productName}</strong>! Berikut key aktivasi trial 3 hari:` : `Terima kasih sudah berlangganan <strong>${productName}</strong>! Berikut key aktivasi:`}
      </p>

      <!-- Key box -->
      <div style="background:#f9fafb;border:1px solid #e5e7eb;border-radius:12px;padding:20px;margin-bottom:24px">
        ${
          keys.length === 1
            ? `<p style="font-size:18px;font-weight:700;font-family:monospace;color:#e63946;text-align:center;margin:0;letter-spacing:0.5px">${singleKey}</p>`
            : `<div style="font-size:14px;font-family:monospace;color:#1f2937;line-height:2;text-align:center">${keyList}</div>`
        }
      </div>

      <!-- Steps -->
      <h2 style="font-size:15px;color:#1f2937;margin:0 0 12px">📱 Langkah Aktivasi</h2>
      <div style="background:#f9fafb;border-radius:12px;padding:16px 20px;margin-bottom:24px">
        <p style="margin:8px 0;font-size:14px;color:#374151"><strong>1.</strong> Download ${productName} dari link yang diberikan</p>
        ${stepActivation}
        <p style="margin:8px 0;font-size:14px;color:#374151"><strong>4.</strong> Setup data toko &amp; mulai jualan! 🎉</p>
      </div>

      ${trialNotice}

      <!-- Footer -->
      <p style="font-size:12px;color:#9ca3af;line-height:1.6;margin:0">
        Jika ada pertanyaan, silakan hubungi kami di<br>
        <a href="mailto:support@halugoods.com" style="color:#e63946;text-decoration:none">support@halugoods.com</a>
        &nbsp;|&nbsp;
        <a href="https://wa.me/628976280303" style="color:#e63946;text-decoration:none">WhatsApp</a>
      </p>
    </td>
  </tr>

  <!-- Footer bar -->
  <tr>
    <td style="background:#f9fafb;padding:16px 40px;text-align:center">
      <p style="font-size:11px;color:#9ca3af;margin:0">
        © ${new Date().getFullYear()} NUSA — Aplikasi Kasir Indonesia
      </p>
    </td>
  </tr>

</table>
</td></tr>
</table>
</body>
</html>`;

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: `NUSA Kasir <${RESEND_FROM_EMAIL}>`,
      to: [toEmail],
      subject,
      html,
    }),
  });

  if (!res.ok) {
    const errBody = await res.text();
    throw new Error(`Resend API error: ${res.status} ${errBody}`);
  }
}

// ─── Add a pre-generated key (from keygen.dart CLI) ──────────────────

async function handleAdd(supabase: any, params: any) {
  const { key, serial, owner_email, product } = params;
  if (!key || !serial) {
    return json({ error: "key and serial required" }, 400);
  }

  const { error } = await supabase.from("licenses").insert({
    key: String(key).toUpperCase(),
    serial: String(serial),
    product: product ?? "nusa-kasir",
    status: "Generated",
    owner_email: owner_email ?? null,
  });

  if (error) {
    if (error.code === "23505") {
      return json({ error: "Key already exists" }, 409);
    }
    return json({ error: error.message }, 500);
  }

  return json({ ok: true, key: String(key).toUpperCase() });
}

// ─── List all licenses with activation counts ────────────────────────

async function handleList(supabase: any, params: any) {
  const page = Math.max(0, params.page ?? 0);
  const limit = Math.min(params.limit ?? 50, 200);
  const status = params.status ?? null;
  const search = params.search ?? null;
  const product = params.product ?? null;
  const tier = params.tier ?? null;
  const from = page * limit;
  const to = from + limit - 1;

  // Query activations count per license — we'll do a single join
  // Since we can't join directly, we query licenses and activations separately
  let licenseQuery = supabase
    .from("licenses")
    .select("*", { count: "exact" })
    .order("created_at", { ascending: false });

  if (status) licenseQuery = licenseQuery.eq("status", status);
  if (product) licenseQuery = licenseQuery.eq("product", product);
  if (tier) licenseQuery = licenseQuery.eq("tier", tier);
  if (search)
    licenseQuery = licenseQuery.or(
      `key.ilike.%${search}%,owner_email.ilike.%${search}%`,
    );

  // Apply pagination via range — but we also need total count from a separate query
  // Supabase's .range modifies the query, so we do count first
  const { count, error: countErr } = await licenseQuery;
  if (countErr) return json({ error: countErr.message }, 500);

  const { data, error } = await licenseQuery.range(from, to);
  if (error) return json({ error: error.message }, 500);

  // Get activation counts for returned licenses
  const licenseIds = (data ?? []).map((l: any) => l.id);
  let activationCounts: Record<string, number> = {};

  if (licenseIds.length > 0) {
    const { data: actData } = await supabase
      .from("activations")
      .select("license_id")
      .in("license_id", licenseIds);

    for (const a of actData ?? []) {
      activationCounts[a.license_id] =
        (activationCounts[a.license_id] ?? 0) + 1;
    }
  }

  const licenses = (data ?? []).map((l: any) => ({
    ...l,
    activation_count: activationCounts[l.id] ?? 0,
    activations: undefined,
  }));

  return json({ licenses, total: count ?? 0, page, limit });
}

// ─── Get single license detail with activations ──────────────────────

async function handleDetail(supabase: any, params: any) {
  const { license_id } = params;
  if (!license_id) return json({ error: "license_id required" }, 400);

  const { data: license, error } = await supabase
    .from("licenses")
    .select("*")
    .eq("id", license_id)
    .single();

  if (error || !license) return json({ error: "License not found" }, 404);

  const { data: activations } = await supabase
    .from("activations")
    .select("*")
    .eq("license_id", license_id)
    .order("created_at", { ascending: false });

  return json({
    license: {
      ...license,
      device_count: (activations ?? []).length,
      activations: activations ?? [],
    },
  });
}

// ─── Revoke a license ────────────────────────────────────────────────

async function handleRevoke(supabase: any, params: any) {
  const { license_id } = params;
  if (!license_id) return json({ error: "license_id required" }, 400);

  const { error } = await supabase
    .from("licenses")
    .update({ status: "Cancelled" })
    .eq("id", license_id);

  if (error) return json({ error: error.message }, 500);

  return json({ ok: true, message: "License cancelled" });
}

// ─── Delete an unused license ────────────────────────────────────────

async function handleDelete(supabase: any, params: any) {
  const { license_id } = params;
  if (!license_id) return json({ error: "license_id required" }, 400);

  // Only delete Generated, unactivated licenses
  const { data: lic } = await supabase
    .from("licenses")
    .select("status")
    .eq("id", license_id)
    .single();

  if (!lic) return json({ error: "License not found" }, 404);
  if (lic.status !== "Generated") {
    return json(
      { error: "Hanya lisensi unused (Generated) yang bisa dihapus" },
      400,
    );
  }

  // Also check no activations exist (belt and suspenders)
  const { count: actCount } = await supabase
    .from("activations")
    .select("*", { count: "exact", head: true })
    .eq("license_id", license_id);

  if ((actCount ?? 0) > 0) {
    return json(
      { error: "Lisensi sudah memiliki aktivasi, tidak bisa dihapus" },
      400,
    );
  }

  const { error } = await supabase
    .from("licenses")
    .delete()
    .eq("id", license_id);

  if (error) return json({ error: error.message }, 500);

  return json({ ok: true, message: "License deleted" });
}

// ─── Summary stats ───────────────────────────────────────────────────

async function handleStats(supabase: any) {
  const { data: allLicenses } = await supabase
    .from("licenses")
    .select("status");

  const stats: Record<string, number> = {
    total: (allLicenses ?? []).length,
    Generated: 0,
    Active: 0,
    Cancelled: 0,
    Trial: 0,
    Expired: 0,
    Suspended: 0,
    total_activations: 0,
  };

  for (const r of allLicenses ?? []) {
    stats[r.status] = (stats[r.status] ?? 0) + 1;
  }

  const { count: activationCount } = await supabase
    .from("activations")
    .select("*", { count: "exact", head: true });

  stats.total_activations = activationCount ?? 0;

  return json({ stats });
}

// ─── Helpers ──────────────────────────────────────────────────────────

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
