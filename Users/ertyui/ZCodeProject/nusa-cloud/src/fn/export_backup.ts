// ============================================================================
// NUSA — Export & Backup Recovery
// ============================================================================
// Endpoint admin:
//   POST /api/export/d1                  → dump semua tabel D1
//   POST /api/export/user-detail         → metadata lisensi + email + UID
//   POST /api/export/user-nus1            → metadata (JSON kecil)
//   POST /api/export/user-nus1-download  → stream .nus1 file (bypass 17MB limit)
//   POST /api/export/backup-now          → trigger manual backup ke Google Drive
// ============================================================================

import { json, errorJson, Router, type FnContext } from '../router';

type Params = Record<string, unknown>;
type Row = Record<string, any>;

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-admin-key',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const TABLES = [
  'licenses', 'activations', 'payments', 'license_events',
  'app_min_versions', 'tutorials', 'store_settings',
  'online_products', 'online_orders', 'promos', 'online_customers',
  'branches', 'print_form_configs', 'ai_settings', 'ai_chat_history',
  'sheets_settings', 'sheets_accounts', 'sheets_registry', 'sheets_archive',
  'accounts', 'reset_tokens',
];

// ─── Export D1 ─────────────────────────────────────────────────────────

async function handleExportD1(ctx: FnContext, _params: Params): Promise<Response> {
  if (!ctx.isAdmin) return errorJson('Unauthorized — admin key required', 401);
  const dump: Record<string, Row[]> = {};
  for (const table of TABLES) {
    try {
      const res = await ctx.env.DB.prepare(`SELECT * FROM ${table}`).all<Row>();
      dump[table] = res.results ?? [];
    } catch {}
  }
  return json({
    exported_at: new Date().toISOString(),
    worker: 'nusa-cloud',
    tables: dump,
    counts: Object.fromEntries(Object.entries(dump).map(([k, v]) => [k, v.length])),
  });
}

// ─── User detail ──────────────────────────────────────────────────────

async function handleUserDetail(ctx: FnContext, params: Params): Promise<Response> {
  if (!ctx.isAdmin) return errorJson('Unauthorized — admin key required', 401);
  const email = String(params.email ?? '').trim().toLowerCase();
  const googleUserId = String(params.googleUserId ?? '').trim();
  if (!email && !googleUserId) return errorJson('email or googleUserId required', 400);

  let licQuery: string, binds: string[];
  if (email) { licQuery = 'SELECT * FROM licenses WHERE LOWER(owner_email) = ?'; binds = [email]; }
  else { licQuery = 'SELECT * FROM licenses WHERE google_user_id = ?'; binds = [googleUserId]; }

  const licRes = await ctx.env.DB.prepare(`${licQuery} ORDER BY created_at DESC`).bind(...binds).all<Row>();
  const licenses = licRes.results ?? [];
  if (licenses.length === 0) return json({ found: false, message: 'Tidak ada lisensi', email, googleUserId });

  const records = await Promise.all(licenses.map(async (lic) => {
    const actRes = await ctx.env.DB.prepare(
      'SELECT * FROM activations WHERE license_id = ? ORDER BY created_at DESC'
    ).bind(lic.id).all<Row>();

    const uid_val = lic.google_user_id ?? 'unknown';
    const product = lic.product ?? 'nusa-kasir';
    const backupPath = `${uid_val}/${product}/backup.sqlite.enc`;
    let backupExists = false, backupSize = 0;
    try {
      const obj = await ctx.env.BUCKET_BACKUPS.head(backupPath);
      backupExists = obj != null;
      backupSize = obj?.size ?? 0;
    } catch {}

    return { license: lic, activations: actRes.results ?? [], backup: { path: backupPath, exists: backupExists, size_bytes: backupSize } };
  }));

  return json({
    found: true, email, googleUserId: licenses[0]?.google_user_id ?? googleUserId,
    product: licenses[0]?.product, licenses_count: licenses.length, records,
  });
}

// ─── User .nus1 metadata (JSON, no base64) ────────────────────────────

async function handleUserNus1(ctx: FnContext, params: Params): Promise<Response> {
  if (!ctx.isAdmin) return errorJson('Unauthorized — admin key required', 401);
  const email = String(params.email ?? '').trim().toLowerCase();
  const googleUserId = String(params.googleUserId ?? '').trim();

  let lic: Row | null = null;
  if (email) lic = await ctx.env.DB.prepare("SELECT * FROM licenses WHERE LOWER(owner_email) = ? ORDER BY created_at DESC LIMIT 1").bind(email).first<Row>();
  else if (googleUserId) lic = await ctx.env.DB.prepare("SELECT * FROM licenses WHERE google_user_id = ? ORDER BY created_at DESC LIMIT 1").bind(googleUserId).first<Row>();
  if (!lic) return json({ found: false, message: 'Tidak ada lisensi', email, googleUserId });

  const uid_val = lic.google_user_id ?? 'unknown';
  const product = lic.product ?? 'nusa-kasir';
  const backupPath = `${uid_val}/${product}/backup.sqlite.enc`;
  let backupSize = 0, backupExists = false;
  try {
    const obj = await ctx.env.BUCKET_BACKUPS.head(backupPath);
    backupExists = obj != null; backupSize = obj?.size ?? 0;
  } catch {}

  return json({
    found: true, email, googleUserId: lic.google_user_id, product,
    license_key: lic.key, license_status: lic.status,
    backup_path: backupPath, backup_size_bytes: backupSize,
    nus1_file_name: `${uid_val}_${product}.nus1`, created_at: lic.created_at,
    note: backupExists ? 'ready' : 'backup tidak ada di cloud',
  });
}

// ─── Stream .nus1 file (bypass 17MB JSON limit) ──────────────────────

async function handleUserNus1Download(ctx: FnContext, params: Params): Promise<Response> {
  if (!ctx.isAdmin) return errorJson('Unauthorized — admin key required', 401);
  const email = String(params.email ?? '').trim().toLowerCase();
  const googleUserId = String(params.googleUserId ?? '').trim();

  let lic: Row | null = null;
  if (email) lic = await ctx.env.DB.prepare("SELECT * FROM licenses WHERE LOWER(owner_email) = ? ORDER BY created_at DESC LIMIT 1").bind(email).first<Row>();
  else if (googleUserId) lic = await ctx.env.DB.prepare("SELECT * FROM licenses WHERE google_user_id = ? ORDER BY created_at DESC LIMIT 1").bind(googleUserId).first<Row>();
  if (!lic) return errorJson('Tidak ada lisensi', 404);

  const uid_val = lic.google_user_id ?? 'unknown';
  const product = lic.product ?? 'nusa-kasir';
  const backupPath = `${uid_val}/${product}/backup.sqlite.enc`;

  const backupObj = await ctx.env.BUCKET_BACKUPS.get(backupPath);
  if (!backupObj) return errorJson('Backup tidak ditemukan di cloud', 404);

  const backupBytes = new Uint8Array(await backupObj.arrayBuffer());

  const nameBytes = new TextEncoder().encode('backup.sqlite.enc');
  const header = new Uint8Array(8);
  const hView = new DataView(header.buffer);
  hView.setUint8(0, 0x4E); hView.setUint8(1, 0x55); hView.setUint8(2, 0x53); hView.setUint8(3, 0x31);
  hView.setUint32(4, 1);

  const entryHeader = new Uint8Array(6);
  const eView = new DataView(entryHeader.buffer);
  eView.setUint16(0, nameBytes.length);
  eView.setUint32(2, backupBytes.length);

  const nus1Bytes = new Uint8Array(header.length + entryHeader.length + nameBytes.length + backupBytes.length);
  nus1Bytes.set(header, 0);
  nus1Bytes.set(entryHeader, header.length);
  nus1Bytes.set(nameBytes, header.length + entryHeader.length);
  nus1Bytes.set(backupBytes, header.length + entryHeader.length + nameBytes.length);

  const fileNameOut = `${uid_val}_${product}.nus1`;
  return new Response(nus1Bytes, {
    status: 200,
    headers: {
      'Content-Type': 'application/octet-stream',
      'Content-Disposition': `attachment; filename="${fileNameOut}"`,
      'Content-Length': String(nus1Bytes.length),
      ...CORS,
    },
  });
}

// ─── Manual backup trigger ─────────────────────────────────────────────

async function handleBackupNow(ctx: FnContext, _params: Params): Promise<Response> {
  if (!ctx.isAdmin) return errorJson('Unauthorized — admin key required', 401);
  try {
    const { runBackup } = await import('./backup_cron');
    await runBackup(ctx.env as any);
    return json({ ok: true, message: 'Backup berjalan — cek Google Drive dalam 1-2 menit' });
  } catch (e: any) {
    return errorJson(e?.message ?? String(e), 500);
  }
}

// ─── Register routes ───────────────────────────────────────────────────

Router.registerAll('export', {
  d1: handleExportD1,
  'user-detail': handleUserDetail,
  'user-nus1': handleUserNus1,
  'user-nus1-download': handleUserNus1Download,
  'backup-now': handleBackupNow,
});
