// ============================================================================
// NUSA — InstanPay (QRIS) Payment (port dari supabase/functions/instanpay)
// ============================================================================
// Actions (POST /api/instanpay/{action}, body JSON sisanya identik):
//   create — { product, package, google_id, customer_name? }
//     → Creates a QRIS invoice via InstanPay, stores a pending payment row.
//     → { success, transactionId, qrCodeSvg, qrisString, baseAmount,
//         totalAmount, uniqueCode, expiredAt }
//   status — { transactionId }
//     → Polls InstanPay status; on PAID it generates the license key once.
//     → { success, status, key?, expires_at? }
//
// Secrets: INSTANPAY_API_KEY, NUSA_PRIVATE_KEY.
// Keygen reuse license_manager.generateKey (WebCrypto Ed25519 native).
// ============================================================================

import { json, Router, type FnContext } from '../router';
import { generateKey } from './license_manager';
import { nowIso } from './db';

type Params = Record<string, unknown>;
type Row = Record<string, any>;

const INSTANPAY_API = 'https://instanpay.net/api/v1';

// ─── Price config (same as midtrans / /pay page) ─────────────────
const PRICES: Record<string, number> = {
  '1bulan': 49000,
  lifetime: 249000,
};

const PACKAGE_DURATION: Record<string, number | null> = {
  '1bulan': 30,
  lifetime: null,
};

const PACKAGE_TIER: Record<string, string> = {
  '1bulan': '1month',
  lifetime: 'lifetime',
};

// ─── InstanPay API calls ─────────────────────────────────────────

async function instanpayCreateInvoice(apiKey: string, params: {
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
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': apiKey,
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

  const data = (await res.json()) as any;
  if (!data.success) {
    throw new Error(data.message ?? 'InstanPay create failed');
  }
  return data.data;
}

async function instanpayCheckStatus(
  apiKey: string,
  transactionId: string,
): Promise<{ status: string; paidAt?: string }> {
  const res = await fetch(`${INSTANPAY_API}/status/${transactionId}`, {
    headers: { 'X-API-Key': apiKey, 'Accept': 'application/json' },
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`InstanPay status error: ${res.status} ${err}`);
  }
  const data = (await res.json()) as any;
  if (!data.success) {
    throw new Error(data.message ?? 'InstanPay status failed');
  }
  return { status: data.data.status, paidAt: data.data.paidAt };
}

// ─── Handlers ────────────────────────────────────────────────────

async function handleCreate(ctx: FnContext, params: Params): Promise<Response> {
  const env = ctx.env;
  if (!env.INSTANPAY_API_KEY) {
    return json({ error: 'InstanPay not configured' }, 500);
  }
  if (!env.NUSA_PRIVATE_KEY) {
    return json({ error: 'License keygen not configured' }, 500);
  }

  const { product, package: pkg, google_id, customer_name } = params as any;
  if (!product || !pkg || !google_id) {
    return json({ error: 'Missing: product, package, google_id' }, 400);
  }

  const price = PRICES[pkg as string];
  if (!price) {
    return json({ error: `Invalid package: ${pkg}. Use '1bulan' or 'lifetime'` }, 400);
  }

  // Check if user already has an active license for this product
  const existing = await env.DB.prepare(
    `SELECT id, key, status, expires_at FROM licenses
     WHERE google_user_id = ? AND product = ? AND status = 'Active' LIMIT 1`,
  ).bind(google_id, product).first<Row>();

  if (existing) {
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
    const inv = await instanpayCreateInvoice(env.INSTANPAY_API_KEY, {
      amount: price,
      customerName: (customer_name as string) ?? undefined,
    });

    // Store pending payment record (order_id = InstanPay transactionId)
    try {
      await env.DB.prepare(
        `INSERT INTO payments (id, order_id, google_id, product, package, amount, status, snap_token, provider, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, 'instanpay', ?, ?)`,
      )
        .bind(crypto.randomUUID(), inv.transactionId, google_id, product, pkg, price, inv.transactionId, nowIso(), nowIso())
        .run();
    } catch (e: any) {
      return json({
        error: 'db_error',
        message: `payments insert failed: ${e?.message ?? String(e)}`,
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
    });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return json({ error: 'instanpay_error', message: msg }, 500);
  }
}

async function handleStatus(ctx: FnContext, params: Params): Promise<Response> {
  const env = ctx.env;
  if (!env.INSTANPAY_API_KEY) {
    return json({ error: 'InstanPay not configured' }, 500);
  }
  if (!env.NUSA_PRIVATE_KEY) {
    return json({ error: 'License keygen not configured' }, 500);
  }

  const { transactionId } = params as any;
  if (!transactionId) {
    return json({ error: 'transactionId required' }, 400);
  }

  // Fetch payment record
  const payment = await env.DB.prepare(
    'SELECT * FROM payments WHERE order_id = ? LIMIT 1',
  ).bind(transactionId).first<Row>();

  if (!payment) {
    return json({ error: 'Payment record not found' }, 404);
  }

  // Check InstanPay current status
  let ipStatus: string;
  try {
    const s = await instanpayCheckStatus(env.INSTANPAY_API_KEY, transactionId as string);
    ipStatus = s.status;
  } catch (e: unknown) {
    // Transient network error — report as not-settled, do not generate key
    return json({
      success: false,
      status: 'UNKNOWN',
      message: e instanceof Error ? e.message : 'Status check failed',
    });
  }

  if (ipStatus !== 'PAID') {
    await env.DB.prepare(
      'UPDATE payments SET status = ?, updated_at = ? WHERE order_id = ?',
    ).bind(ipStatus.toLowerCase(), nowIso(), transactionId).run();

    return json({
      success: false,
      status: ipStatus,
      message: `Pembayaran belum selesai. Status: ${ipStatus}`,
    });
  }

  // Check if license already generated (idempotent — repeated polls must not
  // generate a second key)
  const existingKey = await env.DB.prepare(
    'SELECT key, expires_at, status, serial FROM licenses WHERE order_id = ? LIMIT 1',
  ).bind(transactionId).first<Row>();

  if (existingKey) {
    return json({
      success: true,
      already_processed: true,
      key: existingKey.key,
      expires_at: existingKey.expires_at,
      status: existingKey.status,
    });
  }

  // Payment confirmed — generate license key (retry sekali bila collision).
  const durationDays = PACKAGE_DURATION[payment.package as string];
  const expiresAt = durationDays
    ? new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString()
    : null;

  let lastErr = '';
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const { serial, key } = await generateKey(env);
      await env.DB.prepare(
        `INSERT INTO licenses (id, key, serial, product, status, google_user_id, expires_at, order_id, tier, owner_email)
         VALUES (?, ?, ?, ?, 'Active', ?, ?, ?, ?, NULL)`,
      )
        .bind(crypto.randomUUID(), key, serial, payment.product, payment.google_id, expiresAt, transactionId, PACKAGE_TIER[payment.package as string] ?? 'lifetime')
        .run();
      await env.DB.prepare(
        'UPDATE payments SET status = ?, license_key = ?, updated_at = ? WHERE order_id = ?',
      ).bind('settled', key, nowIso(), transactionId).run();
      return json({ success: true, key, serial, expires_at: expiresAt });
    } catch (e: any) {
      lastErr = e?.message ?? String(e);
      if (!/UNIQUE/i.test(lastErr)) break;
    }
  }
  return json({ error: 'db_error', message: lastErr }, 500);
}

// ─── Registrasi route ────────────────────────────────────────────

Router.registerAll('instanpay', {
  create: handleCreate,
  status: handleStatus,
});
