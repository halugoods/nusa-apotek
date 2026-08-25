// ============================================================================
// NUSA — InstanPay (QRIS) Payment Edge Function
// Deploy: supabase functions deploy instanpay --project-ref sakeuhcbcnueplzlkltm
// ============================================================================
// Actions:
//   { action: "create", product, package, google_id, customer_name? }
//     → Creates a QRIS invoice via InstanPay, stores a pending payment row.
//     → Returns { success, transactionId, qrCodeSvg, qrisString, baseAmount,
//                 totalAmount, uniqueCode, expiredAt }
//   { action: "status", transactionId }
//     → Polls InstanPay status; on PAID it generates the license key once.
//     → Returns { success, status, key?, expires_at? }
//
// Env vars required:
//   INSTANPAY_API_KEY     — from InstanPay dashboard (sk_live_... / sk_test_...)
//   NUSA_PRIVATE_KEY      — 64-char hex Ed25519 private key (for keygen)
//   NUSA_PUBLIC_KEY       — 64-char hex Ed25519 public key (for register_activation)
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY — auto-injected by Supabase
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as ed from "https://esm.sh/@noble/ed25519@2";
import { sha512 } from "https://esm.sh/@noble/hashes@1/sha512";
import { crypto } from "https://deno.land/std@0.177.0/crypto/mod.ts";

ed.etc.sha512Sync = (...msgs: Uint8Array[]): Uint8Array => {
  const h = sha512.create();
  for (const m of msgs) h.update(m);
  return h.digest();
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const INSTANPAY_API_KEY = Deno.env.get("INSTANPAY_API_KEY") ?? "";
const PRIVATE_KEY_HEX = Deno.env.get("NUSA_PRIVATE_KEY") ?? "";

const INSTANPAY_API = "https://instanpay.net/api/v1";

// ─── Price config (same as midtrans / /pay page) ─────────────────
const PRICES: Record<string, number> = {
  "1bulan": 49000,
  lifetime: 249000,
};

const PACKAGE_DURATION: Record<string, number | null> = {
  "1bulan": 30,
  lifetime: null,
};

const PACKAGE_TIER: Record<string, string> = {
  "1bulan": "1month",
  lifetime: "lifetime",
};

// ─── Keygen (identical to license-manager / midtrans) ────────────

const SERIAL_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const B32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
const SERIAL_LEN = 8;
const PREFIX = "NUSA-";

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
  let bits = 0, value = 0;
  const out: string[] = [];
  for (const b of data) {
    value = (value << 8) | b;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.push(B32_ALPHABET[(value >> bits) & 31]);
    }
  }
  if (bits > 0) out.push(B32_ALPHABET[(value << (5 - bits)) & 31]);
  return out.join("");
}

function hexToBytes(hex: string): Uint8Array {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.substring(i * 2, i * 2 + 2), 16);
  }
  return out;
}

async function generateKey(): Promise<{ serial: string; key: string }> {
  const serial = generateSerial();
  const sig = await ed.sign(
    new TextEncoder().encode(serial),
    hexToBytes(PRIVATE_KEY_HEX),
  );
  const groups: string[] = [];
  for (let i = 0; i < serial.length; i += 4) groups.push(serial.substring(i, i + 4));
  const sigB32 = base32Encode(sig);
  for (let i = 0; i < sigB32.length; i += 4) groups.push(sigB32.substring(i, i + 4));
  return { serial, key: PREFIX + groups.join("-") };
}

// ─── Helpers ─────────────────────────────────────────────────────

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

// ─── InstanPay API calls ─────────────────────────────────────────

async function instanpayCreateInvoice(params: {
  amount: number;
  customerName?: string;
}): Promise<{
  transactionId: string;
  qrCodeSvg: string;
  qrisString: string;
  baseAmount: number;
  uniqueCode: number;
  totalAmount: number;
  expiredAt: string;
}> {
  const res = await fetch(`${INSTANPAY_API}/payments`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-API-Key": INSTANPAY_API_KEY,
    },
    body: JSON.stringify({
      amount: params.amount,
      ...(params.customerName ? { customer_name: params.customerName } : {}),
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`InstanPay create error: ${res.status} ${err}`);
  }

  const data = await res.json();
  if (!data.success) {
    throw new Error(data.message ?? "InstanPay create failed");
  }
  return data.data;
}

async function instanpayCheckStatus(
  transactionId: string,
): Promise<{ status: string; paidAt?: string }> {
  const res = await fetch(`${INSTANPAY_API}/status/${transactionId}`, {
    headers: { "X-API-Key": INSTANPAY_API_KEY, "Accept": "application/json" },
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`InstanPay status error: ${res.status} ${err}`);
  }
  const data = await res.json();
  if (!data.success) {
    throw new Error(data.message ?? "InstanPay status failed");
  }
  return { status: data.data.status, paidAt: data.data.paidAt };
}

// ─── Main handler ────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { action } = body;

    if (!INSTANPAY_API_KEY) {
      return json({ error: "InstanPay not configured" }, 500);
    }
    if (!PRIVATE_KEY_HEX) {
      return json({ error: "License keygen not configured" }, 500);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: "Supabase not configured" }, 500);
    }
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // ─── CREATE ───────────────────────────────────────────────
    if (action === "create") {
      const { product, package: pkg, google_id, customer_name } = body;
      if (!product || !pkg || !google_id) {
        return json({ error: "Missing: product, package, google_id" }, 400);
      }

      const price = PRICES[pkg];
      if (!price) {
        return json({ error: `Invalid package: ${pkg}. Use '1bulan' or 'lifetime'` }, 400);
      }

      // Check if user already has an active license for this product
      const { data: existing } = await supabase
        .from("licenses")
        .select("id, key, status, expires_at")
        .eq("google_user_id", google_id)
        .eq("product", product)
        .eq("status", "Active")
        .maybeSingle();

      if (existing) {
        const isExpired = existing.expires_at && new Date(existing.expires_at) < new Date();
        if (!isExpired) {
          return json({
            error: "already_active",
            message: "Anda sudah memiliki lisensi aktif untuk produk ini",
            key: existing.key,
            expires_at: existing.expires_at,
          }, 409);
        }
      }

      try {
        const inv = await instanpayCreateInvoice({
          amount: price,
          customerName: customer_name ?? undefined,
        });

        // Store pending payment record (order_id = InstanPay transactionId)
        const { error: payErr } = await supabase.from("payments").insert({
          order_id: inv.transactionId,
          google_id,
          product,
          package: pkg,
          amount: price,
          status: "pending",
          snap_token: inv.transactionId,
          provider: "instanpay",
        });

        if (payErr) {
          return json({
            error: "db_error",
            message: `payments insert failed: ${payErr.message}`,
          }, 500);
        }

        return json({
          success: true,
          transactionId: inv.transactionId,
          qrCodeSvg: inv.qrCodeSvg,
          qrisString: inv.qrisString,
          baseAmount: inv.baseAmount,
          uniqueCode: inv.uniqueCode,
          totalAmount: inv.totalAmount,
          expiredAt: inv.expiredAt,
        }, 200);
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        return json({ error: "instanpay_error", message: msg }, 500);
      }
    }

    // ─── STATUS ───────────────────────────────────────────────
    if (action === "status") {
      const { transactionId } = body;
      if (!transactionId) {
        return json({ error: "transactionId required" }, 400);
      }

      // Fetch payment record
      const { data: payment } = await supabase
        .from("payments")
        .select("*")
        .eq("order_id", transactionId)
        .maybeSingle();

      if (!payment) {
        return json({ error: "Payment record not found" }, 404);
      }

      // Check InstanPay current status
      let ipStatus: string;
      try {
        const s = await instanpayCheckStatus(transactionId);
        ipStatus = s.status;
      } catch (e: unknown) {
        // Transient network error — report as not-settled, do not generate key
        return json({
          success: false,
          status: "UNKNOWN",
          message: e instanceof Error ? e.message : "Status check failed",
        }, 200);
      }

      if (ipStatus !== "PAID") {
        await supabase
          .from("payments")
          .update({ status: ipStatus.toLowerCase(), updated_at: new Date().toISOString() })
          .eq("order_id", transactionId);

        return json({
          success: false,
          status: ipStatus,
          message: `Pembayaran belum selesai. Status: ${ipStatus}`,
        }, 200);
      }

      // Check if license already generated (idempotent — repeated polls must not
      // generate a second key)
      const { data: existingKey } = await supabase
        .from("licenses")
        .select("key, expires_at, status, serial")
        .eq("order_id", transactionId)
        .maybeSingle();

      if (existingKey) {
        return json({
          success: true,
          already_processed: true,
          key: existingKey.key,
          expires_at: existingKey.expires_at,
          status: existingKey.status,
        }, 200);
      }

      // Payment confirmed — generate license key
      const { serial, key } = await generateKey();

      const durationDays = PACKAGE_DURATION[payment.package];
      const expiresAt = durationDays
        ? new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString()
        : null;

      const { error: insertErr } = await supabase.from("licenses").insert({
        key,
        serial,
        product: payment.product,
        status: "Active",
        google_user_id: payment.google_id,
        expires_at: expiresAt,
        order_id: transactionId,
        tier: PACKAGE_TIER[payment.package] ?? "lifetime",
        owner_email: null,
      });

      if (insertErr) {
        // Key collision (extremely rare) — retry once
        if (insertErr.code === "23505") {
          const retry = await generateKey();
          const { error: retryErr } = await supabase.from("licenses").insert({
            key: retry.key,
            serial: retry.serial,
            product: payment.product,
            status: "Active",
            google_user_id: payment.google_id,
            expires_at: expiresAt,
            order_id: transactionId,
            tier: PACKAGE_TIER[payment.package] ?? "lifetime",
          });
          if (retryErr) {
            return json({ error: "db_error", message: retryErr.message }, 500);
          }
          await supabase
            .from("payments")
            .update({ status: "settled", license_key: retry.key, updated_at: new Date().toISOString() })
            .eq("order_id", transactionId);
          return json({ success: true, key: retry.key, serial: retry.serial, expires_at: expiresAt }, 200);
        }
        return json({ error: "db_error", message: insertErr.message }, 500);
      }

      // Update payment record
      await supabase
        .from("payments")
        .update({ status: "settled", license_key: key, updated_at: new Date().toISOString() })
        .eq("order_id", transactionId);

      return json({ success: true, key, serial, expires_at: expiresAt }, 200);
    }

    return json({ error: "Unknown action. Use 'create' or 'status'" }, 400);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return json({ error: "server_error", message: msg }, 500);
  }
});