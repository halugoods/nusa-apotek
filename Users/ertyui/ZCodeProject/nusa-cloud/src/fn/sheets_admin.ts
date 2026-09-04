// ============================================================================
// NUSA — Google Sheets Terpusat (port dari supabase/functions/sheets-admin)
// ============================================================================
// Menghubungkan app NUSA Kasir + dashboard admin ke Google Sheets atas nama
// COMPANY ACCOUNT (OAuth refresh token di tabel sheets_settings / sheets_accounts).
// App kirim user_id (canonical UID) + rows; server menulis spreadsheet.
//
// ACTIONS (POST /api/sheets-admin/{action}):
//   Admin (x-admin-key):
//     oauth_status, oauth_consent_url, oauth_callback, oauth_callback_account,
//     test_credential, list_users, list_accounts, revoke_account,
//     archive_month, list_archives
//   User app (anon/JWT):
//     get_link, create_spreadsheet, write, append, get_archives
// ============================================================================

import { json, Router, type FnContext } from '../router';
import { uid, nowIso } from './db';
import type { Env } from '../index';

type Params = Record<string, unknown>;
type Row = Record<string, any>;
type H = (ctx: FnContext, params: Params) => Promise<Response>;

const OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const OAUTH_SCOPE = 'https://www.googleapis.com/auth/drive.file';
// Loopback paste-code flow (OOB deprecated). Kode auth dibaca user dari
// address bar → paste di dashboard. Tidak perlu didaftarkan di Console.
const OAUTH_REDIRECT_URI = 'http://127.0.0.1:43210';

const SHEETS_API = 'https://sheets.googleapis.com/v4/spreadsheets';
const SHEETS_TABS = [
  'Laporan', 'Produk', 'Transaksi', 'Stok', 'Keuangan',
  'Karyawan', 'Pelanggan', 'Supplier', 'Promo', 'Presensi',
];

// ─── D1 row helpers ─────────────────────────────────────────────────

function firstRow(results: Row[] | undefined): Row | null {
  return (results && results.length > 0 ? results[0] : null) as Row | null;
}

async function queryOne(env: Env, sql: string, ...binds: unknown[]): Promise<Row | null> {
  const res = await env.DB.prepare(sql).bind(...binds).all<Row>();
  return firstRow(res.results);
}

async function queryAll(env: Env, sql: string, ...binds: unknown[]): Promise<Row[]> {
  const res = await env.DB.prepare(sql).bind(...binds).all<Row>();
  return (res.results ?? []) as Row[];
}

// ─── Google OAuth helpers ───────────────────────────────────────────

async function getAccessTokenFromRefresh(
  env: Env,
  refreshToken: string,
): Promise<string> {
  const clientId = env.GOOGLE_OAUTH_CLIENT_ID ?? '';
  const clientSecret = env.GOOGLE_OAUTH_CLIENT_SECRET ?? '';
  const res = await fetch(OAUTH_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Token refresh gagal (${res.status}): ${errText.slice(0, 300)}`);
  }
  const data = (await res.json()) as Record<string, unknown>;
  const token = data['access_token'] as string | undefined;
  if (!token) throw new Error('Token refresh gagal — tidak ada access_token.');
  return token;
}

async function getOauthState(env: Env): Promise<{
  refreshToken: string;
  ownerEmail: string;
  enabled: boolean;
}> {
  // D1 sheets_settings: enabled INTEGER + kolom oauth (lihat addendum schema).
  const row = await queryOne(
    env,
    'SELECT oauth_refresh_token, oauth_owner_email, enabled FROM sheets_settings WHERE id = 1',
  );
  const enabled = Number(row?.enabled ?? 0) === 1;
  const refreshToken = (row?.oauth_refresh_token as string | null) ?? '';
  const ownerEmail = (row?.oauth_owner_email as string | null) ?? '';
  return { refreshToken, ownerEmail, enabled };
}

async function requireAccessToken(env: Env): Promise<{ token: string; ownerEmail: string }> {
  const { refreshToken, ownerEmail, enabled } = await getOauthState(env);
  if (!enabled || !refreshToken) {
    throw new Error('Spreadsheet belum terhubung Google — login Google dulu di dashboard.');
  }
  return { token: await getAccessTokenFromRefresh(env, refreshToken), ownerEmail };
}

/** Token + email akun tertentu dari sheets_accounts (null = akun utama). */
async function tokenForAccount(
  env: Env,
  accountId: string | null,
): Promise<{ token: string; ownerEmail: string }> {
  if (!accountId) return requireAccessToken(env);
  const acc = await queryOne(
    env,
    'SELECT id, email, oauth_refresh_token, enabled FROM sheets_accounts WHERE id = ?',
    accountId,
  );
  if (!acc || Number(acc.enabled ?? 0) !== 1 || !acc.oauth_refresh_token) {
    // Akun hilang/nonaktif (mis. di-revoke) → fallback ke akun utama.
    return requireAccessToken(env);
  }
  return { token: await getAccessTokenFromRefresh(env, acc.oauth_refresh_token), ownerEmail: acc.email };
}

/** Auto-select: akun tambahan enabled dengan user paling SEDIKIT. */
async function pickLeastLoadedAccount(env: Env): Promise<string | null> {
  const accounts = await queryAll(env, 'SELECT id FROM sheets_accounts WHERE enabled = 1');
  if (accounts.length === 0) return null;
  const regs = await queryAll(env, 'SELECT account_id FROM sheets_registry WHERE account_id IS NOT NULL');
  const filled = new Map<string, number>();
  for (const r of regs) {
    const id = r.account_id as string | null;
    if (id) filled.set(id, (filled.get(id) ?? 0) + 1);
  }
  let best: string | null = null;
  let bestCount = Infinity;
  for (const a of accounts) {
    const count = filled.get(a.id as string) ?? 0;
    if (count < bestCount) { bestCount = count; best = a.id as string; }
  }
  return best;
}

// ─── Google Sheets REST helpers ─────────────────────────────────────

async function googleFetch(token: string, url: string, init: RequestInit = {}): Promise<any> {
  const res = await fetch(url, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Google Sheets API (${res.status}): ${errText.slice(0, 300)}`);
  }
  if (res.status === 204) return null;
  return res.json();
}

async function sheetsCreate(
  token: string,
  title: string,
  tabs: string[],
): Promise<{ spreadsheetId: string; url: string }> {
  const body = {
    properties: { title },
    sheets: tabs.map((t) => ({ properties: { title: t } })),
  };
  const data = (await googleFetch(token, SHEETS_API, {
    method: 'POST',
    body: JSON.stringify(body),
  })) as any;
  return {
    spreadsheetId: data.spreadsheetId,
    url: `https://docs.google.com/spreadsheets/d/${data.spreadsheetId}/edit`,
  };
}

async function sheetsShare(token: string, spreadsheetId: string, email: string): Promise<void> {
  if (!email) return;
  // Best-effort — gagal tidak menggagalkan create.
  try {
    await googleFetch(
      token,
      `https://www.googleapis.com/drive/v3/files/${spreadsheetId}/permissions`,
      {
        method: 'POST',
        body: JSON.stringify({ role: 'writer', type: 'user', emailAddress: email }),
      },
    );
  } catch (e) {
    console.error(`[sheets-admin] share ke ${email} gagal (dilewati): ${e}`);
  }
}

// ─── Resolve sheetId asli Google (Bug fix "no sheet with id: 0") ────
// App mengirim request format dengan sheetId = INDEX tab (0-9); server
// resolve dari spreadsheets.get lalu terjemahkan batchUpdate.

async function resolveSheetIds(
  token: string,
  spreadsheetId: string,
): Promise<{ byTitle: Map<string, number>; byIndex: Map<number, number> }> {
  const data = (await googleFetch(
    token,
    `${SHEETS_API}/${spreadsheetId}?fields=sheets.properties(sheetId,title)`,
  )) as any;
  const byTitle = new Map<string, number>();
  const byIndex = new Map<number, number>();
  const sheets: any[] = data?.sheets ?? [];
  sheets.forEach((s: any, idx: number) => {
    const props = s?.properties;
    if (props && typeof props.sheetId === 'number') {
      byIndex.set(idx, props.sheetId);
      if (props.title) byTitle.set(props.title, props.sheetId);
    }
  });
  return { byTitle, byIndex };
}

function translateSheetIds(
  requests: any[],
  byTitle: Map<string, number>,
  byIndex: Map<number, number>,
): any[] {
  const resolve = (v: any, title?: string): any => {
    if (typeof v !== 'number') return v;
    if (title && byTitle.has(title)) return byTitle.get(title);
    const byIdx = byIndex.get(v);
    return byIdx !== undefined ? byIdx : v; // tak dikenal → biarkan (aman)
  };
  const walk = (node: any): any => {
    if (node === null || typeof node !== 'object') return node;
    const title = (node?.properties && typeof node.properties.title === 'string')
      ? node.properties.title
      : undefined;
    if (Array.isArray(node)) return node.map((n) => walk(n));
    const out: any = {};
    for (const [key, value] of Object.entries(node)) {
      if (key === 'sheetId') {
        out[key] = resolve(value, title);
      } else if (value && typeof value === 'object') {
        out[key] = walk(value);
      } else {
        out[key] = value;
      }
    }
    return out;
  };
  return requests.map((r) => walk(r));
}

async function sheetsWrite(
  token: string,
  spreadsheetId: string,
  tab: string,
  values: any[][],
  requests: any[],
): Promise<void> {
  // Tulis data (USER_ENTERED supaya angka/rupiah diformat Google).
  await googleFetch(
    token,
    `${SHEETS_API}/${spreadsheetId}/values/${encodeURIComponent(tab + '!A1')}?valueInputOption=USER_ENTERED`,
    { method: 'PUT', body: JSON.stringify({ values }) },
  );
  // Request format JSON — sheetId index diterjemahkan ke sheetId asli dulu.
  if (Array.isArray(requests) && requests.length > 0) {
    const { byTitle, byIndex } = await resolveSheetIds(token, spreadsheetId);
    const translated = translateSheetIds(requests, byTitle, byIndex);
    await googleFetch(token, `${SHEETS_API}/${spreadsheetId}:batchUpdate`, {
      method: 'POST',
      body: JSON.stringify({ requests: translated }),
    });
  }
}

/**
 * Append baris baru ke tab (live sync). IDEMPOTEN: baca kolom kunci existing,
 * buang baris yang kuncinya sudah ada, lalu values:append sisanya.
 */
async function sheetsAppend(
  token: string,
  spreadsheetId: string,
  tab: string,
  values: any[][],
  keyColumnIndex = 0,
): Promise<{ appended: number }> {
  if (!Array.isArray(values) || values.length === 0) return { appended: 0 };

  let existingKeys = new Set<string>();
  try {
    const col = (await googleFetch(
      token,
      `${SHEETS_API}/${spreadsheetId}/values/${encodeURIComponent(tab + '!A:AZ')}?majorDimension=COLUMNS`,
    )) as any;
    const columns: any[][] = col?.values ?? [];
    const keyCol = columns[keyColumnIndex] ?? [];
    existingKeys = new Set(keyCol.map((v: any) => String(v)));
  } catch {
    // Tab belum ada isinya → semua baris dianggap baru.
  }

  const fresh = values.filter((r) => {
    const key = String(r[keyColumnIndex] ?? '');
    return key === '' ? true : !existingKeys.has(key);
  });
  if (fresh.length === 0) return { appended: 0 };

  await googleFetch(
    token,
    `${SHEETS_API}/${spreadsheetId}/values/${encodeURIComponent(tab + '!A1')}:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS`,
    { method: 'POST', body: JSON.stringify({ values: fresh }) },
  );
  return { appended: fresh.length };
}

// ─── Arsip bulanan (cold storage) — dipakai admin + cron ────────────
// IDEMPOTENT: unique(user_id, bulan, tab) → INSERT OR REPLACE, jalan 2× aman.
// Hapus di sheet HANYA setelah semua tab berhasil tersimpan di D1.

export async function archiveUserMonth(
  env: Env,
  userId: string,
  bulan: string,
): Promise<{ tabs: Record<string, number> }> {
  if (!/^\d{4}-\d{2}$/.test(bulan)) {
    throw new Error('bulan harus format YYYY-MM.');
  }
  const reg = await queryOne(
    env,
    'SELECT spreadsheet_id, account_id FROM sheets_registry WHERE user_id = ?',
    userId,
  );
  if (!reg?.spreadsheet_id) {
    throw new Error('User belum punya spreadsheet.');
  }

  // Token dari akun pemilik spreadsheet (multi-akun) / akun utama.
  let token: string;
  if (reg.account_id) {
    const acc = await queryOne(
      env,
      'SELECT oauth_refresh_token, enabled FROM sheets_accounts WHERE id = ?',
      reg.account_id,
    );
    if (acc && Number(acc.enabled ?? 0) === 1 && acc.oauth_refresh_token) {
      token = await getAccessTokenFromRefresh(env, acc.oauth_refresh_token);
    } else {
      token = await getAccessTokenFromRefresh(env, await mainRefreshToken(env));
    }
  } else {
    token = await getAccessTokenFromRefresh(env, await mainRefreshToken(env));
  }
  const spreadsheetId = reg.spreadsheet_id as string;

  // 1. Baca isi semua tab.
  const meta = (await googleFetch(
    token,
    `${SHEETS_API}/${spreadsheetId}?fields=sheets.properties.title`,
  )) as any;
  const titles: string[] = (meta?.sheets ?? [])
    .map((s: any) => s?.properties?.title)
    .filter(Boolean);

  const results: Record<string, number> = {};
  for (const tab of titles) {
    const vals = (await googleFetch(
      token,
      `${SHEETS_API}/${spreadsheetId}/values/${encodeURIComponent(tab)}?majorDimension=ROWS`,
    )) as any;
    const rows: any[][] = vals?.values ?? [];
    const dataRows = rows.length > 0 ? rows.slice(1) : []; // header tidak ikut
    await env.DB.prepare(
      `INSERT INTO sheets_archive (id, user_id, bulan, tab, rows, row_count, archived_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id, bulan, tab) DO UPDATE SET
         rows = excluded.rows, row_count = excluded.row_count, archived_at = excluded.archived_at`,
    )
      .bind(uid(), userId, bulan, tab, JSON.stringify(dataRows), dataRows.length, nowIso())
      .run();
    results[tab] = dataRows.length;
  }

  // 2. Semua tab aman di D1 → kosongkan sheet (sync berikutnya menulis ulang
  //    header + data bulan berjalan).
  for (const tab of titles) {
    try {
      await googleFetch(
        token,
        `${SHEETS_API}/${spreadsheetId}/values/${encodeURIComponent(tab + '!A1:Z100000')}:clear`,
        { method: 'POST' },
      );
    } catch (e) {
      console.warn(`[sheets] clear ${tab} gagal (diabaikan): ${e}`);
    }
  }

  return { tabs: results };
}

async function mainRefreshToken(env: Env): Promise<string> {
  const row = await queryOne(
    env,
    'SELECT oauth_refresh_token, enabled FROM sheets_settings WHERE id = 1',
  );
  if (!row || Number(row.enabled ?? 0) !== 1 || !row.oauth_refresh_token) {
    throw new Error('Akun Google utama belum terhubung.');
  }
  return row.oauth_refresh_token as string;
}

// ─── Handlers: admin ────────────────────────────────────────────────

async function handleOAuthStatus(ctx: FnContext): Promise<Response> {
  const { refreshToken, ownerEmail, enabled } = await getOauthState(ctx.env);
  return json({
    enabled: enabled && !!refreshToken,
    owner_email: ownerEmail || null,
    has_credential: !!refreshToken,
  });
}

function buildConsentUrl(env: Env): string {
  const params = new URLSearchParams({
    client_id: env.GOOGLE_OAUTH_CLIENT_ID,
    redirect_uri: OAUTH_REDIRECT_URI,
    response_type: 'code',
    scope: OAUTH_SCOPE,
    access_type: 'offline',
    prompt: 'consent',
  });
  return `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
}

async function handleOAuthConsentUrl(ctx: FnContext): Promise<Response> {
  if (!ctx.env.GOOGLE_OAUTH_CLIENT_ID) {
    return json({ error: 'GOOGLE_OAUTH_CLIENT_ID belum di-set (wrangler secret).' }, 500);
  }
  return json({ url: buildConsentUrl(ctx.env) });
}

/** Tukar OAuth code → token; onConflict: akun utama atau akun tambahan. */
async function exchangeCode(
  ctx: FnContext,
  codeRaw: unknown,
): Promise<{ refreshToken: string; accessToken: string; email: string }> {
  let code = typeof codeRaw === 'string' ? codeRaw.trim() : '';
  if (!code) throw new Error('Kode OAuth wajib diisi.');
  // Kode dari address bar bisa ter-encode (4%2F0…) atau sudah di-decode.
  try { code = decodeURIComponent(code); } catch { /* biarkan apa adanya */ }
  if (!ctx.env.GOOGLE_OAUTH_CLIENT_ID || !ctx.env.GOOGLE_OAUTH_CLIENT_SECRET) {
    throw new Error('GOOGLE_OAUTH_CLIENT_ID / SECRET belum di-set (wrangler secret).');
  }
  const res = await fetch(OAUTH_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: ctx.env.GOOGLE_OAUTH_CLIENT_ID,
      client_secret: ctx.env.GOOGLE_OAUTH_CLIENT_SECRET,
      code,
      grant_type: 'authorization_code',
      redirect_uri: OAUTH_REDIRECT_URI,
    }),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Tukar kode gagal (${res.status}): ${errText.slice(0, 300)}`);
  }
  const data = (await res.json()) as Record<string, unknown>;
  const refreshToken = data['refresh_token'] as string | undefined;
  const accessToken = data['access_token'] as string | undefined;
  if (!refreshToken || !accessToken) {
    throw new Error(
      'Tidak ada refresh_token. Pastikan consent screen meminta offline access (access_type=offline).',
    );
  }
  let email = '';
  try {
    const ui = await fetch('https://www.googleapis.com/oauth2/v2/userinfo', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (ui.ok) email = ((await ui.json()) as any).email ?? '';
  } catch { email = ''; }
  return { refreshToken, accessToken, email };
}

async function handleOAuthCallback(ctx: FnContext, params: Params): Promise<Response> {
  const { refreshToken, email } = await exchangeCode(ctx, params.code);
  await ctx.env.DB.prepare(
    `INSERT INTO sheets_settings (id, oauth_refresh_token, oauth_owner_email, enabled, updated_at)
     VALUES (1, ?, ?, 1, ?)
     ON CONFLICT(id) DO UPDATE SET
       oauth_refresh_token = excluded.oauth_refresh_token,
       oauth_owner_email = excluded.oauth_owner_email,
       enabled = 1, updated_at = excluded.updated_at`,
  )
    .bind(refreshToken, email, nowIso())
    .run();
  return json({
    ok: true,
    message: `Google terhubung${email ? ` sebagai ${email}` : ''}.`,
    owner_email: email,
  });
}

/** OAuth code → akun TAMBAHAN baru (sheets_accounts), bukan akun utama. */
async function handleOAuthCallbackAccount(ctx: FnContext, params: Params): Promise<Response> {
  const { refreshToken, email } = await exchangeCode(ctx, params.code);
  if (!email) return json({ error: 'Gagal baca email akun Google dari token.' }, 400);

  // Relink akun sama = update (email UNIQUE).
  const existing = await queryOne(
    ctx.env,
    'SELECT id FROM sheets_accounts WHERE lower(email) = lower(?) LIMIT 1',
    email,
  );
  if (existing) {
    await ctx.env.DB.prepare(
      'UPDATE sheets_accounts SET oauth_refresh_token = ?, enabled = 1, updated_at = ? WHERE id = ?',
    ).bind(refreshToken, nowIso(), existing.id).run();
  } else {
    await ctx.env.DB.prepare(
      `INSERT INTO sheets_accounts (id, email, oauth_refresh_token, enabled, label, created_at, updated_at)
       VALUES (?, ?, ?, 1, ?, ?, ?)`,
    ).bind(uid(), email, refreshToken, (params.label as string | undefined) ?? null, nowIso(), nowIso()).run();
  }

  return json({ ok: true, message: `Akun ${email} terhubung.`, email });
}

async function handleTestCredential(ctx: FnContext): Promise<Response> {
  const { token } = await requireAccessToken(ctx.env);
  const start = Date.now();
  const { url } = await sheetsCreate(token, 'NUSA Test Koneksi', ['Test']);
  const latency = Date.now() - start;
  return json({
    ok: true,
    message: 'Koneksi berhasil! Spreadsheet uji dibuat.',
    url,
    latency_ms: latency,
  });
}

async function handleListUsers(ctx: FnContext): Promise<Response> {
  const users = await queryAll(
    ctx.env,
    'SELECT * FROM sheets_registry ORDER BY updated_at DESC LIMIT 500',
  );
  return json({ users });
}

async function handleListAccounts(ctx: FnContext): Promise<Response> {
  const accounts = await queryAll(
    ctx.env,
    'SELECT id, email, enabled, max_users, label, created_at, updated_at FROM sheets_accounts ORDER BY created_at ASC',
  );
  const regs = await queryAll(ctx.env, 'SELECT account_id FROM sheets_registry WHERE account_id IS NOT NULL');
  const filled = new Map<string, number>();
  for (const r of regs) {
    const id = r.account_id as string | null;
    if (id) filled.set(id, (filled.get(id) ?? 0) + 1);
  }
  const main = await getOauthState(ctx.env);
  return json({
    main_account: {
      email: main.ownerEmail || null,
      enabled: main.enabled && !!main.refreshToken,
      users: regs.length,
      max_users: 50,
    },
    accounts: accounts.map((a) => ({ ...a, users: filled.get(a.id as string) ?? 0 })),
  });
}

async function handleRevokeAccount(ctx: FnContext, params: Params): Promise<Response> {
  const accountId = params.account_id as string | undefined;
  if (!accountId) return json({ error: 'account_id wajib diisi.' }, 400);
  // Nonaktifkan (bukan delete) — token di-nol-kan supaya tidak menggantung.
  const res = await ctx.env.DB.prepare(
    'UPDATE sheets_accounts SET enabled = 0, oauth_refresh_token = NULL, updated_at = ? WHERE id = ?',
  ).bind(nowIso(), accountId).run();
  if (!res.success) throw new Error('Gagal revoke akun.');
  return json({
    ok: true,
    message: 'Akun dinonaktifkan. User terikat tetap terbaca dari arsip; user baru diarahkan ke akun lain.',
  });
}

async function handleArchiveMonth(ctx: FnContext, params: Params): Promise<Response> {
  const { user_id, bulan } = params as { user_id?: string; bulan?: string };
  if (!user_id || !bulan || !/^\d{4}-\d{2}$/.test(bulan)) {
    return json({ error: 'user_id dan bulan (format YYYY-MM) wajib diisi.' }, 400);
  }
  const { tabs } = await archiveUserMonth(ctx.env, user_id, bulan);
  const total = Object.values(tabs).reduce((a, b) => a + b, 0);
  return json({
    ok: true,
    message: `Arsip ${bulan} tersimpan (${total} baris), sheet dikosongkan.`,
    tabs,
  });
}

async function handleListArchives(ctx: FnContext, params: Params): Promise<Response> {
  const userId = params.user_id as string | undefined;
  let sql = 'SELECT user_id, bulan, tab, row_count, archived_at FROM sheets_archive';
  const binds: string[] = [];
  if (userId) {
    sql += ' WHERE user_id = ?';
    binds.push(userId);
  }
  sql += ' ORDER BY bulan DESC LIMIT 500';
  const archives = await queryAll(ctx.env, sql, ...binds);
  return json({ archives });
}

// ─── Handlers: user app ─────────────────────────────────────────────

async function handleGetLink(ctx: FnContext, params: Params): Promise<Response> {
  const userId = params.user_id as string | undefined;
  if (!userId) return json({ error: 'user_id wajib diisi.' }, 400);
  const data = await queryOne(
    ctx.env,
    'SELECT spreadsheet_id, spreadsheet_url, status, error FROM sheets_registry WHERE user_id = ?',
    userId,
  );
  if (!data || !data.spreadsheet_id || !data.spreadsheet_url) {
    return json({ error: 'Belum ada spreadsheet untuk user ini.' }, 404);
  }
  return json({
    spreadsheet_id: data.spreadsheet_id,
    spreadsheet_url: data.spreadsheet_url,
    status: data.status,
    error: data.error,
  });
}

async function handleCreateSpreadsheet(ctx: FnContext, params: Params): Promise<Response> {
  const { user_id, email, store_name, variant } = params as Record<string, string | undefined>;
  if (!user_id) return json({ error: 'user_id wajib diisi.' }, 400);

  // Link kontinu: kalau sudah pernah dibuat, balikin yang lama.
  const existing = await queryOne(
    ctx.env,
    'SELECT spreadsheet_id, spreadsheet_url, status FROM sheets_registry WHERE user_id = ?',
    user_id,
  );
  if (existing?.spreadsheet_id && existing?.spreadsheet_url) {
    return json({
      spreadsheet_id: existing.spreadsheet_id,
      spreadsheet_url: existing.spreadsheet_url,
      created: false,
      status: existing.status,
    });
  }

  // Auto-select akun Google paling longgar (multi-akun); null = akun utama.
  const accountId = await pickLeastLoadedAccount(ctx.env);
  const { token } = await tokenForAccount(ctx.env, accountId);
  const { spreadsheetId, url } = await sheetsCreate(
    token,
    store_name ? `Laporan NUSA — ${store_name}` : 'Laporan NUSA',
    SHEETS_TABS,
  );
  await sheetsShare(token, spreadsheetId, email || '');

  await ctx.env.DB.prepare(
    `INSERT INTO sheets_registry (id, user_id, email, store_name, variant, spreadsheet_id, spreadsheet_url, account_id, status, error, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'ready', NULL, ?, ?)
     ON CONFLICT(user_id) DO UPDATE SET
       email = excluded.email, store_name = excluded.store_name, variant = excluded.variant,
       spreadsheet_id = excluded.spreadsheet_id, spreadsheet_url = excluded.spreadsheet_url,
       account_id = excluded.account_id, status = 'ready', error = NULL, updated_at = excluded.updated_at`,
  )
    .bind(uid(), user_id, email || '', store_name || '', variant || '', spreadsheetId, url, accountId, nowIso(), nowIso())
    .run();
  return json({ spreadsheet_id: spreadsheetId, spreadsheet_url: url, created: true, status: 'ready' });
}

/** Validasi kepemilikan + ambil token akun pemilik spreadsheet. */
async function ownerToken(
  ctx: FnContext,
  userId: string,
  spreadsheetId: string,
): Promise<{ token: string } | Response> {
  const data = await queryOne(
    ctx.env,
    'SELECT spreadsheet_id, account_id FROM sheets_registry WHERE user_id = ?',
    userId,
  );
  if (!data || data.spreadsheet_id !== spreadsheetId) {
    return json({ error: 'Spreadsheet bukan milik user ini.' }, 403);
  }
  const { token } = await tokenForAccount(ctx.env, (data.account_id as string | null) ?? null);
  return { token };
}

async function markReady(ctx: FnContext, userId: string): Promise<void> {
  await ctx.env.DB.prepare(
    'UPDATE sheets_registry SET status = ?, error = NULL, updated_at = ? WHERE user_id = ?',
  ).bind('ready', nowIso(), userId).run();
}

async function handleWrite(ctx: FnContext, params: Params): Promise<Response> {
  const { user_id, spreadsheet_id, tab } = params as Record<string, string | undefined>;
  if (!user_id || !spreadsheet_id || !tab) {
    return json({ error: 'user_id, spreadsheet_id, tab wajib diisi.' }, 400);
  }
  const own = await ownerToken(ctx, user_id, spreadsheet_id);
  if (own instanceof Response) return own;
  await sheetsWrite(
    own.token,
    spreadsheet_id,
    tab,
    Array.isArray(params.values) ? (params.values as any[][]) : [],
    Array.isArray(params.requests) ? (params.requests as any[]) : [],
  );
  await markReady(ctx, user_id);
  return json({ ok: true });
}

/** Live sync append — kepemilikan divalidasi sama seperti `write`. */
async function handleAppend(ctx: FnContext, params: Params): Promise<Response> {
  const { user_id, spreadsheet_id, tab } = params as Record<string, string | undefined>;
  if (!user_id || !spreadsheet_id || !tab) {
    return json({ error: 'user_id, spreadsheet_id, tab wajib diisi.' }, 400);
  }
  const own = await ownerToken(ctx, user_id, spreadsheet_id);
  if (own instanceof Response) return own;
  const { appended } = await sheetsAppend(
    own.token,
    spreadsheet_id,
    tab,
    Array.isArray(params.values) ? (params.values as any[][]) : [],
    typeof params.key_column_index === 'number' ? params.key_column_index : 0,
  );
  await markReady(ctx, user_id);
  return json({ ok: true, appended });
}

/** Data arsip untuk APP: bulan lama dibaca dari D1 (cold tier). */
async function handleGetArchives(ctx: FnContext, params: Params): Promise<Response> {
  const { user_id, bulan, tab } = params as Record<string, string | undefined>;
  if (!user_id) return json({ error: 'user_id wajib diisi.' }, 400);
  let sql = 'SELECT bulan, tab, rows, row_count FROM sheets_archive WHERE user_id = ?';
  const binds: string[] = [user_id];
  if (bulan) { sql += ' AND bulan = ?'; binds.push(bulan); }
  if (tab) { sql += ' AND tab = ?'; binds.push(tab); }
  sql += ' LIMIT 20';
  const rows = await queryAll(ctx.env, sql, ...binds);
  const archives = rows.map((r) => ({
    bulan: r.bulan,
    tab: r.tab,
    rows: typeof r.rows === 'string' ? JSON.parse(r.rows) : (r.rows ?? []),
    row_count: r.row_count,
  }));
  return json({ archives });
}

// ─── Registrasi route ───────────────────────────────────────────────
// Admin action dicek x-admin-key via ctx.isAdmin (router sudah hitung).

const ADMIN_ACTIONS: Record<string, H> = {
  oauth_status: handleOAuthStatus,
  oauth_consent_url: handleOAuthConsentUrl,
  oauth_callback: handleOAuthCallback,
  oauth_callback_account: handleOAuthCallbackAccount,
  test_credential: handleTestCredential,
  list_users: handleListUsers,
  list_accounts: handleListAccounts,
  revoke_account: handleRevokeAccount,
  archive_month: handleArchiveMonth,
  list_archives: handleListArchives,
};

const USER_ACTIONS: Record<string, H> = {
  get_link: handleGetLink,
  create_spreadsheet: handleCreateSpreadsheet,
  write: handleWrite,
  append: handleAppend,
  get_archives: handleGetArchives,
};

function guardAdmin(h: H): H {
  return async (ctx, params) => {
    if (!ctx.isAdmin) return json({ error: 'Unauthorized' }, 401);
    return h(ctx, params);
  };
}

Router.registerAll('sheets-admin', {
  ...Object.fromEntries(Object.entries(ADMIN_ACTIONS).map(([k, h]) => [k, guardAdmin(h)])),
  ...USER_ACTIONS,
});
