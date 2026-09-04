// ============================================================================
// NUSA — Midtrans Payment (port dari supabase/functions/midtrans)
// ============================================================================
// Actions (POST /api/midtrans/{action}, body JSON sisanya identik):
//   get_token — { product, package, google_id, customer_name, customer_email }
//     → { token, order_id, redirect_url }
//   verify    — { order_id }
//     → Verifies payment with Midtrans API, generates license key if settled
//     → { success, key, expires_at }
//
// Secrets: MIDTRANS_SERVER_KEY, MIDTRANS_CLIENT_KEY, NUSA_PRIVATE_KEY.
// Keygen Ed25519 via WebCrypto native (reuse license_manager.generateKey —
// signature deterministik RFC 8032, identik dengan noble).
// ============================================================================

import { json, Router, type FnContext } from '../router';
import { generateKey } from './license_manager';
import { nowIso } from './db';

type Params = Record<string, unknown>;
type Row = Record<string, any>;

const MIDTRANS_API = 'https://api.sandbox.midtrans.com';
const MIDTRANS_SNAP = 'https://app.sandbox.midtrans.com/snap/v1/transactions';

// ─── Price config ────────────────────────────────────────────────
const PRICES: Record<string, number> = {
  '1bulan': 49000,
  lifetime: 249000,
};

const PACKAGE_DURATION: Record<string, number | null> = {
  '1bulan': 30, // 30 days
  lifetime: null, // never expires
};

// Map UI package id → licenses.tier value (trial/1month/lifetime)
const PACKAGE_TIER: Record<string, string> = {
  '1bulan': '1month',
  lifetime: 'lifetime',
};

// ─── Helpers ─────────────────────────────────────────────────────

function authHeader(serverKey: string): string {
  return 'Basic ' + btoa(serverKey + ':');
}

function generateOrderId(googleId: string): string {
  const shortId = googleId.slice(0, 8);
  const ts = Date.now().toString(36);
  const rand = Math.random().toString(36).slice(2, 6);
  return `NUSA-${shortId}-${ts}-${rand}`;
}

// ─── Midtrans API calls ──────────────────────────────────────────

async function midtransGetToken(serverKey: string, params: {
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
      category: 'Digital Product',
    }],
    customer_details: {
      first_name: params.customerName || 'Pelanggan NUSA',
      email: params.customerEmail || 'pelanggan@nusa.app',
      phone: '',
    },
    callbacks: {
      finish: `nusa://payment-success?order_id=${params.orderId}`,
      error: `nusa://payment-failed?order_id=${params.orderId}`,
      pending: `nusa://payment-pending?order_id=${params.orderId}`,
    },
    credit_card: { secure: true },
  };

  const res = await fetch(MIDTRANS_SNAP, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': authHeader(serverKey),
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Midtrans Snap error: ${res.status} ${err}`);
  }

  const data = (await res.json()) as any;
  return { token: data.token as string, redirect_url: data.redirect_url as string };
}

async function midtransVerify(serverKey: string, orderId: string): Promise<{
  status: string;
  fraud: string;
}> {
  const res = await fetch(`${MIDTRANS_API}/v2/${orderId}/status`, {
    headers: { 'Authorization': authHeader(serverKey), 'Accept': 'application/json' },
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Midtrans status error: ${res.status} ${err}`);
  }

  const data = (await res.json()) as any;
  return {
    status: data.transaction_status as string,
    fraud: (data.fraud_status as string) ?? 'accept',
  };
}

// ─── Handlers ────────────────────────────────────────────────────

async function handleGetToken(ctx: FnContext, params: Params): Promise<Response> {
  const env = ctx.env;
  if (!env.MIDTRANS_SERVER_KEY || !env.MIDTRANS_CLIENT_KEY) {
    return json({ error: 'Midtrans not configured' }, 500);
  }
  if (!env.NUSA_PRIVATE_KEY) {
    return json({ error: 'License keygen not configured' }, 500);
  }

  const { product, package: pkg, google_id, customer_name, customer_email } = params as any;
  if (!product || !pkg || !google_id) {
    return json({ error: 'Missing: product, package, google_id' }, 400);
  }

  const price = PRICES[pkg as string];
  if (!price) {
    return json({ error: `Invalid package: ${pkg}. Use '1bulan' or 'lifetime'` }, 400);
  }

  // Check if user already has an active license for this product
  const existing = await ctx.env.DB.prepare(
    `SELECT id, key, status, expires_at FROM licenses
     WHERE google_user_id = ? AND product = ? AND status = 'Active' LIMIT 1`,
  ).bind(google_id, product).first<Row>();

  if (existing) {
    // Check expiry
    const isExpired = existing.expires_at && new Date(existing.expires_at as string) < new Date();
    if (!isExpired) {
      return json({
        error: 'already_active',
        message: 'Anda sudah memiliki lisensi aktif untuk produk ini',
        key: existing.key,
        expires_at: existing.expires_at,
      }, 409);
    }
  }

  try {
    const orderId = generateOrderId(google_id as string);
    const productName = (product as string).replace('nusa-', 'NUSA ').toUpperCase();
    const pkgLabel = pkg === '1bulan' ? '1 Bulan' : 'Lifetime';

    const { token, redirect_url } = await midtransGetToken(env.MIDTRANS_SERVER_KEY, {
      orderId,
      amount: price,
      productName: `${productName} — ${pkgLabel}`,
      googleId: google_id as string,
      customerName: (customer_name as string) ?? 'Pelanggan NUSA',
      customerEmail: (customer_email as string) ?? 'pelanggan@nusa.app',
    });

    // Store pending payment record
    await env.DB.prepare(
      `INSERT INTO payments (id, order_id, google_id, product, package, amount, status, snap_token, provider, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, 'midtrans', ?, ?)`,
    )
      .bind(crypto.randomUUID(), orderId, google_id, product, pkg, price, token, nowIso(), nowIso())
      .run();

    return json({
      success: true,
      token,
      redirect_url,
      order_id: orderId,
      snap_url: MIDTRANS_SNAP, // for client-side snap.js initialization
      client_key: env.MIDTRANS_CLIENT_KEY,
    });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return json({ error: 'midtrans_error', message: msg }, 500);
  }
}

async function handleVerify(ctx: FnContext, params: Params): Promise<Response> {
  const env = ctx.env;
  if (!env.MIDTRANS_SERVER_KEY || !env.MIDTRANS_CLIENT_KEY) {
    return json({ error: 'Midtrans not configured' }, 500);
  }
  if (!env.NUSA_PRIVATE_KEY) {
    return json({ error: 'License keygen not configured' }, 500);
  }

  const { order_id } = params as any;
  if (!order_id) {
    return json({ error: 'order_id required' }, 400);
  }

  // Check if this payment was already processed
  const existingKey = await env.DB.prepare(
    'SELECT key, expires_at, status FROM licenses WHERE order_id = ? LIMIT 1',
  ).bind(order_id).first<Row>();

  if (existingKey) {
    return json({
      success: true,
      already_processed: true,
      key: existingKey.key,
      expires_at: existingKey.expires_at,
      status: existingKey.status,
    });
  }

  // Fetch payment record
  const payment = await env.DB.prepare(
    'SELECT * FROM payments WHERE order_id = ? LIMIT 1',
  ).bind(order_id).first<Row>();

  if (!payment) {
    return json({ error: 'Payment record not found' }, 404);
  }

  // Verify with Midtrans
  const { status, fraud } = await midtransVerify(env.MIDTRANS_SERVER_KEY, order_id as string);

  const isSettled = (status === 'settlement' || status === 'capture') && fraud === 'accept';

  if (!isSettled) {
    // Update payment status
    await env.DB.prepare(
      'UPDATE payments SET status = ?, updated_at = ? WHERE order_id = ?',
    ).bind(status, nowIso(), order_id).run();

    return json({
      success: false,
      status,
      message: `Pembayaran belum selesai. Status: ${status}`,
    });
  }

  // Payment confirmed — generate license key (D1 UNIQUE(order_id) pada
  // payments + cek existing di atas = idempotent; collision key licensi
  // ekstrem langka → coba ulang sekali bila INSERT gagal UNIQUE).
  const expiresAt = expiryFor(payment.package as string);
  let inserted = false;
  let lastErr = '';
  for (let attempt = 0; attempt < 2 && !inserted; attempt++) {
    try {
      const { serial, key } = await generateKey(env);
      await env.DB.prepare(
        `INSERT INTO licenses (id, key, serial, product, status, google_user_id, expires_at, order_id, tier, owner_email)
         VALUES (?, ?, ?, ?, 'Active', ?, ?, ?, ?, NULL)`,
      )
        .bind(crypto.randomUUID(), key, serial, payment.product, payment.google_id, expiresAt, order_id, PACKAGE_TIER[payment.package as string] ?? 'lifetime')
        .run();
      await env.DB.prepare(
        'UPDATE payments SET status = ?, license_key = ?, updated_at = ? WHERE order_id = ?',
      ).bind('settled', key, nowIso(), order_id).run();
      return json({ success: true, key, serial, expires_at: expiresAt });
    } catch (e: any) {
      lastErr = e?.message ?? String(e);
      // UNIQUE violation pada licenses.key → coba key baru; lainnya → gagal.
      if (!/UNIQUE/i.test(lastErr)) break;
    }
  }
  return json({ error: 'db_error', message: lastErr }, 500);
}

function expiryFor(pkg: string): string | null {
  const durationDays = PACKAGE_DURATION[pkg];
  return durationDays
    ? new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString()
    : null;
}

// ─── Registrasi route ────────────────────────────────────────────

Router.registerAll('midtrans', {
  get_token: handleGetToken,
  verify: handleVerify,
});
