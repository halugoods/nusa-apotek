# NUSA Cloud — Cloudflare Workers backend

Pengganti Supabase untuk NUSA Kasir (rilis v2.2.57+130). Satu Worker, satu
D1 database, tiga bucket R2, satu Durable Object (realtime), dua cron.

## Arsitektur

```
┌────────────┐  POST /api/{fn}/{action}   ┌─────────────────────────────┐
│ App Flutter│ ──────────────────────────▶ │ Worker                      │
│ Dashboard  │  POST /api/auth/* (JWT)     │  ├ router.ts (route table)  │
│ Storefront │  GET  /img/{uid}/{productId}/... │ ├ auth.ts (JWT/PBKDF2) │
└────────────┘  WS   /ws/{channel}        │  ├ fn/* (11 port edge fn)   │
                                          │  ├ RoomDO (WS hibernation)  │
                                          │  └ cron.ts (2 trigger)      │
                                          ├─ D1  (SQL, 20 tabel)        │
                                          ├─ R2  nusa-backups/nusa-images/tutorial-thumbnails
                                          └─ Secrets (JWT_SECRET, NUSA_ADMIN_KEY, …)
```

## Konvensi payload — 1:1 dengan edge fn Supabase

Semua endpoint lama `functions.invoke('license-manager', body)` di app
menjadi `POST {CLOUD_BASE}/api/license-manager/{action}` dengan JSON body
yang **identik**. Worker tidak menuntut auth Supabase; identitas dikirim
via `Authorization: Bearer <JWT>` (akun email) atau field `googleUserId`
(Google Sign-In native — trust model sama seperti sebelumnya).

## Layout

```
src/
  index.ts        — entry: fetch handler + WS upgrade + scheduled()
  router.ts       — /api/{fn}/{action} dispatch + CORS
  auth.ts         — JWT HS256 sign/verify + PBKDF2 + reset tokens
  room.ts         — Durable Object (backup_updated / ring / order_*)
  cron.ts         — license-cron + sheets-archive-cron
  fn/             — port 1:1 per edge fn (payload identik)
    license_manager.ts
    online_store.ts
    register_activation.ts
    sheets_admin.ts
    ai_assistant.ts
    midtrans.ts
    instanpay.ts
    app_ping.ts
    tutorial_manager.ts
    license_cron.ts
    sheets_archive_cron.ts
schema.sql        — D1 schema (dibuat manual via wrangler d1 execute)
wrangler.toml     — bindings: D1, R2×3, DO, cron
```

## Deploy

```bash
npm i -g wrangler
wrangler login
wrangler d1 create nusa-db          # → isi database_id di wrangler.toml
wrangler r2 bucket create nusa-backups
wrangler r2 bucket create nusa-images
wrangler r2 bucket create nusa-tutorial-thumbnails
wrangler d1 execute nusa-db --file=schema.sql --remote
wrangler secret put NUSA_ADMIN_KEY  # dst — lihat daftar di bawah
wrangler deploy
```

## Secrets (wajib)

| Secret                | Nilai                                      |
|-----------------------|--------------------------------------------|
| NUSA_ADMIN_KEY        | `280303` (dashboard/app kirim via x-admin-key) |
| NUSA_CRON_KEY         | rahasia cron trigger                       |
| NUSA_PRIVATE_KEY      | hex Ed25519 (sama dgn Supabase — keygen)   |
| NUSA_PUBLIC_KEY       | hex publiknya                              |
| JWT_SECRET            | acak ≥32 byte (HS256)                      |
| MIDTRANS_SERVER_KEY   | dari Midtrans                              |
| MIDTRANS_CLIENT_KEY   | dari Midtrans                              |
| INSTANPAY_API_KEY     | dari InstanPay                             |
| OPENROUTER_API_KEY    | untuk ai-assistant                         |
| RESEND_API_KEY        | reset password email                       |
| RESEND_FROM_EMAIL     | `nusa@halugoods.com`                       |
| GOOGLE_OAUTH_CLIENT_ID/SECRET | Sheets OAuth per-akun              |

## Migrasi data

`.tools/export_supabase_to_cf.py` — dump PostgREST → seed D1.
R2 copy via rclone (`rclone copy supabase:nusa-images r2:nusa-images`).
