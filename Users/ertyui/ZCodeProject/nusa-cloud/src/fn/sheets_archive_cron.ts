// ============================================================================
// NUSA — Sheets Archive Cron (port dari supabase/functions/sheets-archive-cron)
// ============================================================================
// Dipanggil scheduled() (tanggal 1, lihat cron.ts) ATAU manual via
// POST /api/sheets-archive-cron/run (admin key) — tanpa body.
//   * Hitung bulan pembukuan yang baru selesai (bulan sebelumnya, WIB).
//   * Loop semua user di sheets_registry yang punya spreadsheet.
//   * Arsip SEMUA tab spreadsheet user ke sheets_archive (idempotent —
//     unique(user_id, bulan, tab)), lalu kosongkan tab di spreadsheet.
// Logika arsip di-import dari sheets_admin (satu sumber, tidak dobel).
// ============================================================================

import { json, Router, type FnContext } from '../router';
import { archiveUserMonth } from './sheets_admin';
import type { Env } from '../index';

type Row = Record<string, any>;

export async function runSheetsArchiveCron(env: Env): Promise<void> {
  // Bulan pembukuan yang baru selesai = bulan lalu, zona WIB (UTC+7).
  const now = new Date(Date.now() + 7 * 3600 * 1000);
  const prev = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const bulan = `${prev.getFullYear()}-` + String(prev.getMonth() + 1).padStart(2, '0');

  const { results } = await env.DB.prepare(
    `SELECT user_id, spreadsheet_id FROM sheets_registry
     WHERE spreadsheet_id IS NOT NULL AND spreadsheet_id <> '' LIMIT 500`,
  ).all<Row>();
  const regs = results ?? [];

  let ok = 0;
  let fail = 0;
  for (const r of regs) {
    try {
      await archiveUserMonth(env, r.user_id as string, bulan);
      ok++;
    } catch (e: any) {
      console.error(`[sheets-archive-cron] ${r.user_id}: ${e?.message ?? e}`);
      fail++;
    }
  }
  console.log(`[sheets-archive-cron] bulan=${bulan} users=${regs.length} ok=${ok} fail=${fail}`);
}

async function handleRun(ctx: FnContext, _params: Record<string, unknown>): Promise<Response> {
  try {
    if (!ctx.isAdmin) return json({ error: 'Unauthorized' }, 401);

    const now = new Date(Date.now() + 7 * 3600 * 1000);
    const prev = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const bulan = `${prev.getFullYear()}-` + String(prev.getMonth() + 1).padStart(2, '0');

    const { results } = await ctx.env.DB.prepare(
      `SELECT user_id, spreadsheet_id FROM sheets_registry
       WHERE spreadsheet_id IS NOT NULL AND spreadsheet_id <> '' LIMIT 500`,
    ).all<Row>();
    const regs = results ?? [];

    const resultsMap: Record<string, any> = {};
    let ok = 0;
    let fail = 0;
    for (const r of regs) {
      try {
        const res = await archiveUserMonth(ctx.env, r.user_id as string, bulan);
        resultsMap[r.user_id as string] = res;
        ok++;
      } catch (e: any) {
        resultsMap[r.user_id as string] = { error: e?.message ?? String(e) };
        fail++;
      }
    }

    return json({
      ok: fail === 0,
      bulan,
      total_users: regs.length,
      success: ok,
      failed: fail,
      results: resultsMap,
    });
  } catch (e: any) {
    console.error(`[sheets-archive-cron] ${e?.stack ?? e}`);
    return json({ error: e?.message ?? String(e) }, 500);
  }
}

Router.registerAll('sheets-archive-cron', {
  run: handleRun,
});
