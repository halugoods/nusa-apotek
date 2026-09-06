// ============================================================================
// NUSA — Backup Cron (auto-export D1 + .nus1 ke Google Drive)
// ============================================================================
// Cron trigger: backup D1 harian + generate .nus1 untuk semua user aktif,
// upload ke Google Drive folder "NUSA-Backups".
//
// Setup sekali:
//   1. Set GOOGLE_OAUTH_CLIENT_ID + GOOGLE_OAUTH_CLIENT_SECRET di worker secrets
//   2. Set GOOGLE_DRIVE_REFRESH_TOKEN (via wrangler secret)
//   3. Set GOOGLE_DRIVE_FOLDER_ID (folder "NUSA-Backups" di Drive)
//
// Flow:
//   - Cron 0 7 * * * → export D1 JSON + semua .nus1 → upload ke Drive
//   - File naming: d1_export_YYYY-MM-DD.json, {uid}_{product}_YYYY-MM-DD.nus1
// ============================================================================

import { uid } from './db';

type Row = Record<string, any>;

const TABLES = [
  'licenses', 'activations', 'payments', 'license_events',
  'app_min_versions', 'tutorials', 'store_settings',
  'online_products', 'online_orders', 'promos', 'online_customers',
  'branches', 'print_form_configs', 'ai_settings', 'ai_chat_history',
  'sheets_settings', 'sheets_accounts', 'sheets_registry', 'sheets_archive',
  'accounts', 'reset_tokens',
];

interface Env {
  DB: D1Database;
  BUCKET_BACKUPS: R2Bucket;
  GOOGLE_OAUTH_CLIENT_ID: string;
  GOOGLE_OAUTH_CLIENT_SECRET: string;
  GOOGLE_DRIVE_REFRESH_TOKEN: string;
  GOOGLE_DRIVE_FOLDER_ID: string;
}

// ─── Google Drive upload helper ───────────────────────────────────────

// ─── Find existing file in Drive folder ──────────────────────────────

async function findFileId(env: Env, fileName: string): Promise<string | null> {
  const token = await getAccessToken(env);
  const q = encodeURIComponent(`name='${fileName}' and '${env.GOOGLE_DRIVE_FOLDER_ID}' in parents and trashed=false`);
  const res = await fetch(`https://www.googleapis.com/drive/v3/files?q=${q}&fields=files(id,name)`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) return null;
  const data = await res.json() as any;
  return data.files?.[0]?.id ?? null;
}

async function deleteFile(env: Env, fileId: string): Promise<void> {
  const token = await getAccessToken(env);
  await fetch(`https://www.googleapis.com/drive/v3/files/${fileId}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });
}

async function getAccessToken(env: Env): Promise<string> {
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: env.GOOGLE_OAUTH_CLIENT_ID,
      client_secret: env.GOOGLE_OAUTH_CLIENT_SECRET,
      refresh_token: env.GOOGLE_DRIVE_REFRESH_TOKEN,
      grant_type: 'refresh_token',
    }),
  });
  if (!res.ok) throw new Error(`OAuth token refresh failed: ${res.status}`);
  const data = await res.json() as any;
  return data.access_token;
}

async function uploadToDrive(
  env: Env,
  fileName: string,
  content: string | Uint8Array,
  mimeType: string
): Promise<boolean> {
  try {
    // Replace: delete existing file first (avoid stacking)
    const existingId = await findFileId(env, fileName);
    if (existingId) {
      await deleteFile(env, existingId);
    }

    const token = await getAccessToken(env);

    // Metadata
    const metadata = {
      name: fileName,
      parents: [env.GOOGLE_DRIVE_FOLDER_ID],
      mimeType,
    };

    // Multipart upload
    const boundary = '-------nusa_boundary_' + Date.now();
    const delimiter = `\r\n--${boundary}\r\n`;
    const closeDelimiter = `\r\n--${boundary}--`;

    const bodyParts: string[] = [];
    bodyParts.push(delimiter);
    bodyParts.push('Content-Type: application/json; charset=UTF-8\r\n\r\n');
    bodyParts.push(JSON.stringify(metadata));
    bodyParts.push(delimiter);
    bodyParts.push(`Content-Type: ${mimeType}\r\n\r\n`);

    let bodyString = bodyParts.join('');
    if (typeof content === 'string') {
      bodyString += content;
    } else {
      bodyString += new TextDecoder().decode(content);
    }
    bodyString += closeDelimiter;

    const res = await fetch('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': `multipart/related; boundary=${boundary}`,
      },
      body: bodyString,
    });

    return res.ok;
  } catch (e: any) {
    console.error(`[BackupCron] Upload failed for ${fileName}: ${e?.message ?? e}`);
    return false;
  }
}

// ─── Main backup function ────────────────────────────────────────────

export async function runBackup(env: Env): Promise<void> {
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD

  // 1. Export D1
  const dump: Record<string, Row[]> = {};
  for (const table of TABLES) {
    try {
      const res = await env.DB.prepare(`SELECT * FROM ${table}`).all<Row>();
      dump[table] = res.results ?? [];
    } catch {}
  }

  const d1Json = JSON.stringify({
    exported_at: new Date().toISOString(),
    worker: 'nusa-cloud',
    date: today,
    tables: dump,
    counts: Object.fromEntries(Object.entries(dump).map(([k, v]) => [k, v.length])),
  }, null, 2);

  await uploadToDrive(env, `d1_export_latest.json`, d1Json, 'application/json');

  // 2. Generate .nus1 untuk setiap user yang punya backup
  const licenses = await env.DB.prepare(
    "SELECT id, key, serial, product, status, owner_email, google_user_id FROM licenses WHERE google_user_id IS NOT NULL AND status = 'Active'"
  ).all<Row>();

  for (const lic of licenses.results ?? []) {
    const uid_val = lic.google_user_id;
    const product = lic.product ?? 'nusa-kasir';
    const backupPath = `${uid_val}/${product}/backup.sqlite.enc`;

    try {
      const backupObj = await env.BUCKET_BACKUPS.get(backupPath);
      if (!backupObj) continue;

      const backupBytes = new Uint8Array(await backupObj.arrayBuffer());

      // Build .nus1
      const fileName = 'backup.sqlite.enc';
      const nameBytes = new TextEncoder().encode(fileName);

      const header = new Uint8Array(8);
      const view = new DataView(header.buffer);
      view.setUint8(0, 0x4E); view.setUint8(1, 0x55); view.setUint8(2, 0x53); view.setUint8(3, 0x31);
      view.setUint32(4, 1);

      const entryHeader = new Uint8Array(6);
      const entryView = new DataView(entryHeader.buffer);
      entryView.setUint16(0, nameBytes.length);
      entryView.setUint32(2, backupBytes.length);

      const nus1Bytes = new Uint8Array(header.length + entryHeader.length + nameBytes.length + backupBytes.length);
      nus1Bytes.set(header, 0);
      nus1Bytes.set(entryHeader, header.length);
      nus1Bytes.set(nameBytes, header.length + entryHeader.length);
      nus1Bytes.set(backupBytes, header.length + entryHeader.length + nameBytes.length);

      const nus1Name = `${uid_val}_${product}_latest.nus1`;
      await uploadToDrive(env, nus1Name, nus1Bytes, 'application/octet-stream');
    } catch (e: any) {
      console.error(`[BackupCron] Failed for ${uid_val}: ${e?.message ?? e}`);
    }
  }
}
