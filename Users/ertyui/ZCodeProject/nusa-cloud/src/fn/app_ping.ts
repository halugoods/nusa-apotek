// ============================================================================
// NUSA — App Ping (port dari supabase/functions/app_ping, v2.2.57)
// ============================================================================
// Dipanggil oleh aplikasi NUSA (Flutter) saat start. Dua fungsi sekaligus:
//   1. Catat versi app perangkat ke licenses.last_app_version/_build/last_seen_at
//      (dashboard admin bisa lihat user masih di versi berapa + stale badge).
//   2. Kembalikan versi minimum produk (app_min_versions) → kalau build app
//      < min_build, app menampilkan popup UPDATE WAJIB (blocking).
//
// PUBLIC (tanpa x-admin-key) — app hanya bisa menyentuh baris license yang
// key-nya dia kirim sendiri; tidak ada data lain yang terekspos.
//
// Route : POST /api/app-ping/ping
// Body  : { key, product, version, build }
// Res   : { ok, update_required, min_version, min_build, download_url }
// ============================================================================

import { json, Router, type FnContext } from '../router';
import { nowIso } from './db';

type Params = Record<string, unknown>;
type Row = Record<string, any>;

export async function handlePing(ctx: FnContext, params: Params): Promise<Response> {
  try {
    const { key, product, version, build } = params as any;
    if (!key || !product) {
      return json({ ok: false, error: 'key and product required' }, 400);
    }

    const env = ctx.env;
    const normKey = String(key).trim().toUpperCase();
    const buildNum = Number(build) || 0;

    // 1) Catat versi perangkat (abaikan kalau key tidak ditemukan —
    //    device belum aktivasi tetap boleh cek versi minimum).
    await env.DB.prepare(
      `UPDATE licenses SET last_app_version = ?, last_app_build = ?, last_seen_at = ? WHERE key = ?`
    )
      .bind(String(version ?? ''), buildNum, nowIso(), normKey)
      .run();

    // 2) Versi minimum produk.
    const minRow = await env.DB.prepare(
      'SELECT min_version, min_build, download_url FROM app_min_versions WHERE product = ?'
    )
      .bind(product)
      .first<Row>();

    const minBuild = minRow?.min_build ?? 0;
    const updateRequired = minBuild > 0 && buildNum > 0 && buildNum < minBuild;

    return json({
      ok: true,
      update_required: updateRequired,
      min_version: minRow?.min_version ?? '',
      min_build: minBuild,
      download_url: minRow?.download_url ?? null,
    });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? String(e) }, 500);
  }
}

// ─── Registrasi route ────────────────────────────────────────────────

Router.registerAll('app-ping', {
  ping: handlePing,
});
