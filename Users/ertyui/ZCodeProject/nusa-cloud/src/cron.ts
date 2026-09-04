/**
 * cron.ts — dua cron trigger (wrangler.toml):
 *   - License cron harian: beri tanda Expired pada lisensi lewat masa berlaku,
 *     jalankan grace 7 hari lalu revoke (port license-cron Supabase).
 *   - Sheets archive cron bulanan: placeholder (dipanggil tanggal 1) —
 *     port sheets-archive-cron (kanal D1, bukan Sheets API; logika inti
 *     ada di sheets_admin.archive).
 * Dilindungi: scheduled() dipanggil platform (bukan request publik).
 */
import type { Env } from './index';

export async function runCrons(env: Env): Promise<void> {
  await licenseCron(env);
  // sheets-archive cron dijalankan fn/sheets_archive_cron saat tanggal 1.
  const day = new Date().getUTCDate();
  if (day === 1) {
    const { runSheetsArchiveCron } = await import('./fn/sheets_archive_cron');
    await runSheetsArchiveCron(env);
  }
}

async function licenseCron(env: Env): Promise<void> {
  const now = new Date().toISOString();
  const db = env.DB;

  // 1. Lisensi aktif/trial yang expires_at-nya lewat → Expired.
  const expired = await db.prepare(
    "SELECT id, google_user_id FROM licenses WHERE status IN ('Trial','Active') AND expires_at IS NOT NULL AND expires_at < ?",
  ).bind(now).all<{ id: string; google_user_id: string | null }>();

  for (const lic of expired.results ?? []) {
    await db.batch([
      db.prepare("UPDATE licenses SET status = 'Expired' WHERE id = ?").bind(lic.id),
      db.prepare("INSERT INTO license_events (id, license_id, event, detail) VALUES (?, ?, 'expired', ?)")
        .bind(crypto.randomUUID(), lic.id, `expired at ${now}`),
    ]);
  }

  // 2. Grace 7 hari: Expired lebih dari 7 hari → Cancelled (revoke).
  const graceCutoff = new Date(Date.now() - 7 * 24 * 3600_000).toISOString();
  const revoke = await db.prepare(
    "SELECT id FROM licenses WHERE status = 'Expired' AND expires_at IS NOT NULL AND expires_at < ?",
  ).bind(graceCutoff).all<{ id: string }>();

  for (const lic of revoke.results ?? []) {
    await db.batch([
      db.prepare("UPDATE licenses SET status = 'Cancelled' WHERE id = ?").bind(lic.id),
      db.prepare("INSERT INTO license_events (id, license_id, event, detail) VALUES (?, ?, 'revoked', ?)")
        .bind(crypto.randomUUID(), lic.id, 'grace 7 hari lewat — revoked otomatis'),
    ]);
  }
}
