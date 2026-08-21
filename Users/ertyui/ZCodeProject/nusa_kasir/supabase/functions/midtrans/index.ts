// ============================================================================
// NUSA — Midtrans Payment Edge Function (v1)
// Deploy: supabase functions deploy midtrans --project-ref sakeuhcbcnueplzlkltm
// ============================================================================
// Actions:
//   { action: "get_token", product, package, google_id, customer_name, customer_email }
//     → Returns { token, order_id, redirect_url }
//   { action: "verify", order_id }
//     → Verifies payment with Midtrans API, generates license key if settled
//     → Returns { success, key, expires_at }
//
// Env vars required:
//   MIDTRANS_SERVER_KEY  — from Midtrans Dashboard → Settings → Access Keys
//   MIDTRANS_CLIENT_KEY  — from Midtrans Dashboard → Settings → Access Keys
//   NUSA_PRIVATE_KEY     — 64-char hex Ed25519 private key (for keygen)
//   NUSA_PUBLIC_KEY      — 64-char hex Ed25519 public key (for register_activation)
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

const MIDTRANS_SERVER_KEY = Deno.env.get("MIDTRANS_SERVER_KEY") ?? "";
const MIDTRANS_CLIENT_KEY = Deno.env.get("MIDTRANS_CLIENT_KEY") ?? "";
const PRIVATE_KEY_HEX = Deno.env.get("NUSA_PRIVATE_KEY") ?? "";
const PUBLIC_KEY_HEX = Deno.env.get("NUSA_PUBLIC_KEY") ?? "";

// Midtrans API base (sandbox: api.sandbox.midtrans.com, production: api.midtrans.com)
const MIDTRANS_API = "https://api.sandbox.midtrans.com";
const MIDTRANS_SNAP = "https://app.sandbox.midtrans.com/snap/v1/transactions";

// ─── Price config ────────────────────────────────────────────────
const PRICES: Record<string, number> = {
  "1bulan": 49000,
  lifetime: 249000,
};

const PACKAGE_DURATION: Record<string, number | null> = {
  "1bulan": 30, // 30 days
  lifetime: null, // never expires
};

// Map UI package id → licenses.tier value (check constraint only allows trial/1month/lifetime)
const PACKAGE_TIER: Record<string, string> = {
  "1bulan": "1month",
  lifetime: "lifetime",
};

// ─── Keygen (identical to license-manager/index.ts) ──────────────

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

function authHeader(): string {
  return "Basic " + btoa(MIDTRANS_SERVER_KEY + ":");
}

function generateOrderId(googleId: string): string {
  const shortId = googleId.slice(0, 8);
  const ts = Date.now().toString(36);
  const rand = Math.random().toString(36).slice(2, 6);
  return `NUSA-${shortId}-${ts}-${rand}`;
}

// ─── Midtrans API calls ──────────────────────────────────────────

async function midtransGetToken(params: {
  orderId: string;
  amount: number;
  productName: string;
  googleId: string;
  customerName: string;
  customerEmail: string;
}) {
  const body = {
    transaction_details: {
      order_id: params.orderId,
      gross_amount: params.amount,
    },
    item_details: [{
      id: params.googleId.slice(0, 12),
      price: params.amount,
      quantity: 1,
      name: params.productName,
      category: "Digital Product",
    }],
    customer_details: {
      first_name: params.customerName || "Pelanggan NUSA",
      email: params.customerEmail || "pelanggan@nusa.app",
      phone: "",
    },
    callbacks: {
      finish: `nusa://payment-success?order_id=${params.orderId}`,
      error: `nusa://payment-failed?order_id=${params.orderId}`,
      pending: `nusa://payment-pending?order_id=${params.orderId}`,
    },
    credit_card: { secure: true },
  };

  const res = await fetch(MIDTRANS_SNAP, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": authHeader(),
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Midtrans Snap error: ${res.status} ${err}`);
  }

  const data = await res.json();
  return { token: data.token, redirect_url: data.redirect_url };
}

async function midtransVerify(orderId: string): Promise<{
  status: string;
  fraud: string;
}> {
  const res = await fetch(`${MIDTRANS_API}/v2/${orderId}/status`, {
    headers: { "Authorization": authHeader(), "Accept": "application/json" },
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Midtrans status error: ${res.status} ${err}`);
  }

  const data = await res.json();
  return {
    status: data.transaction_status,
    fraud: data.fraud_status ?? "accept",
  };
}

// ─── Main handler ────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { action } = body;

    if (!MIDTRANS_SERVER_KEY || !MIDTRANS_CLIENT_KEY) {
      return json({ error: "Midtrans not configured" }, 500);
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

    // ─── GET_TOKEN ────────────────────────────────────────────
    if (action === "get_token") {
      const { product, package: pkg, google_id, customer_name, customer_email } = body;
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
        // Check expiry
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
        const orderId = generateOrderId(google_id);
        const productName = product.replace("nusa-", "NUSA ").toUpperCase();
        const pkgLabel = pkg === "1bulan" ? "1 Bulan" : "Lifetime";

        const { token, redirect_url } = await midtransGetToken({
          orderId,
          amount: price,
          productName: `${productName} — ${pkgLabel}`,
          googleId: google_id,
          customerName: customer_name ?? "Pelanggan NUSA",
          customerEmail: customer_email ?? "pelanggan@nusa.app",
        });

        // Store pending payment record
        await supabase.from("payments").insert({
          order_id: orderId,
          google_id,
          product,
          package: pkg,
          amount: price,
          status: "pending",
          snap_token: token,
          provider: "midtrans",
        });

        return json({
          success: true,
          token,
          redirect_url,
          order_id: orderId,
          snap_url: MIDTRANS_SNAP, // for client-side snap.js initialization
          client_key: MIDTRANS_CLIENT_KEY,
        }, 200);
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        return json({ error: "midtrans_error", message: msg }, 500);
      }
    }

    // ─── VERIFY ────────────────────────────────────────────────
    if (action === "verify") {
      const { order_id } = body;
      if (!order_id) {
        return json({ error: "order_id required" }, 400);
      }

      // Check if this payment was already processed
      const { data: existingKey } = await supabase
        .from("licenses")
        .select("key, expires_at, status")
        .eq("order_id", order_id)
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

      // Fetch payment record
      const { data: payment } = await supabase
        .from("payments")
        .select("*")
        .eq("order_id", order_id)
        .maybeSingle();

      if (!payment) {
        return json({ error: "Payment record not found" }, 404);
      }

      // Verify with Midtrans
      const { status, fraud } = await midtransVerify(order_id);

      const isSettled =
        (status === "settlement" || status === "capture") &&
        fraud === "accept";

      if (!isSettled) {
        // Update payment status
        await supabase
          .from("payments")
          .update({ status, updated_at: new Date().toISOString() })
          .eq("order_id", order_id);

        return json({
          success: false,
          status,
          message: `Pembayaran belum selesai. Status: ${status}`,
        }, 200);
      }

      // Payment confirmed — generate license key
      const { serial, key } = await generateKey();

      // Calculate expiry
      const durationDays = PACKAGE_DURATION[payment.package];
      const expiresAt = durationDays
        ? new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString()
        : null;

      // Insert license
      const { error: insertErr } = await supabase.from("licenses").insert({
        key,
        serial,
        product: payment.product,
        status: "Active",
        google_user_id: payment.google_id,
        expires_at: expiresAt,
        order_id,
        tier: PACKAGE_TIER[payment.package] ?? "lifetime",
        owner_email: null,
      });

      if (insertErr) {
        // If key collision (extremely rare), retry once
        if (insertErr.code === "23505") {
          const retry = await generateKey();
          const { error: retryErr } = await supabase.from("licenses").insert({
            key: retry.key,
            serial: retry.serial,
            product: payment.product,
            status: "Active",
            google_user_id: payment.google_id,
            expires_at: expiresAt,
            order_id,
            tier: PACKAGE_TIER[payment.package] ?? "lifetime",
          });
          if (retryErr) {
            return json({ error: "db_error", message: retryErr.message }, 500);
          }
          // Update payment
          await supabase
            .from("payments")
            .update({ status: "settled", license_key: retry.key, updated_at: new Date().toISOString() })
            .eq("order_id", order_id);
          return json({ success: true, key: retry.key, serial: retry.serial, expires_at: expiresAt }, 200);
        }
        return json({ error: "db_error", message: insertErr.message }, 500);
      }

      // Update payment record
      await supabase
        .from("payments")
        .update({ status: "settled", license_key: key, updated_at: new Date().toISOString() })
        .eq("order_id", order_id);

      return json({ success: true, key, serial, expires_at: expiresAt }, 200);
    }

    return json({ error: "Unknown action. Use 'get_token' or 'verify'" }, 400);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return json({ error: "server_error", message: msg }, 500);
  }
});
