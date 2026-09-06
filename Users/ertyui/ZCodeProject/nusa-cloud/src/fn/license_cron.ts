// ============================================================================
// NUSA — License Cron (port dari cron.ts licenseCron)
// ============================================================================
// Dipanggil scheduled() (harian 07:00 UTC, lihat wrangler.toml) ATAU manual
// via POST /api/license-cron/run (admin key) — tanpa body.
//   1. Lisensi Trial/Active yang expires_at-nya lewat → Expired.
//   2. Grace 7 hari: Expired lebih dari 7 hari → Cancelled (revoke).
//   3. Log event ke license_events (audit trail).
// Logika di-port dari src/cron.ts (lines 20-50) supaya fn mandiri bisa
// di-trigger manual untuk debugging/ops.
// ============================================================================

import { json, Router, type FnContext } from '../router';
import type { Env } from '../index';

type Row = Record<string, any>;

/**
 * Jalankan logika license cron. Idempotent — jalan 2x aman (status sudah
// Expired/Cancelled tidak di-update lagi).
 */
export async function runLicenseCron(env: Env): Promise<{
  expired: number;
  revoked: number;
}> {
  const now = new Date().toISOString();
  const db = env.DB;
  let expiredCount = 0;
  let revokedCount = 0;

  // 1. Lisensi aktif/trial yang expires_at-nya lewat → Expired.
  const expired = await db
    .prepare(
      "SELECT id FROM licenses WHERE status IN ('Trial','Active') AND expires_at IS NOT NULL AND expires_at < ?",
    )
    .bind(now)
    .all<{ id: string }>();

  for (const lic of expired.results ?? []) {
    await db.batch([
      db.prepare("UPDATE licenses SET status = 'Expired' WHERE id = ?").bind(lic.id),
      db
        .prepare(
          "INSERT INTO license_events (id, license_id, event, detail) VALUES (?, ?, 'expired', ?)",
        )
        .bind(crypto.randomUUID(), lic.id, `expired at ${now}`),
    ]);
    expiredCount++;
  }

  // 2. Grace 7 hari: Expired lebih dari 7 hari → Cancelled (revoke).
  const graceCutoff = new Date(Date.now() - 7 * 24 * 3600_000).toISOString();
  const revoke = await db
    .prepare(
      "SELECT id FROM licenses WHERE status = 'Expired' AND expires_at IS NOT NULL AND expires_at < ?",
    )
    .bind(graceCutoff)
    .all<{ id: string }>();

  for (const lic of revoke.results ?? []) {
    await db.batch([
      db.prepare("UPDATE licenses SET status = 'Cancelled' WHERE id = ?").bind(lic.id),
      db
        .prepare(
          "INSERT INTO license_events (id, license_id, event, detail) VALUES (?, ?, 'revoked', ?)",
        )
        .bind(crypto.randomUUID(), lic.id, 'grace 7 hari lewat — revoked otomatis'),
    ]);
    revokedCount++;
  }

  console.log(
    `[license-cron] expired=${expiredCount} revoked=${revokedCount} at ${now}`,
  );
  return { expired: expiredCount, revoked: revokedCount };
}

async function handleRun(
  ctx: FnContext,
  _params: Record<string, unknown>,
): Promise<Response> {
  try {
    if (!ctx.isAdmin) return json({ error: 'Unauthorized' }, 401);

    const result = await runLicenseCron(ctx.env);
    return json({
      ok: true,
      ...result,
      ran_at: new Date().toISOString(),
    });
  } catch (e: any) {
    console.error(`[license-cron] ${e?.stack ?? e}`);
    return json({ error: e?.message ?? String(e) }, 500);
  }
}

Router.registerAll('license-cron', {
  run: handleRun,
});
