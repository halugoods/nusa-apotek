# v2.2.57+130 — Migrasi Supabase → Cloudflare + Fix Bom Egress

Rilis gabungan: perbaikan bom egress (+129) + migrasi penuh backend ke Cloudflare Worker (+130).
Satu build, 8 varian. Urutan deploy: `wrangler deploy` → deploy ulang nusa-online → build/rilis APK.

## 🔧 Perbaikan (+129 — bom egress & OOM)
- **Isolate backup crypto**: `packFiles` + gzip + `encrypt` (dan decrypt + `unpackFiles`) dipindahkan ke `Isolate.run()` — arsip yang puluhan MB tidak lagi freeze UI
- **Arsip backup tanpa gambar**: scan `product_*/photo_*/qris_*` dihapus dari `uploadBackupNow`; setelah restore, `_relinkImagesFromCloud()` mengunduh gambar dari `nusa-images/{uid}/{productId}/products/{basename}` dan menulis ulang ke documents
- **Stop base64**: `product_form_screen` + `employees_screen` berhenti `base64Encode` saat save; kompaksi sekali per launch `UPDATE ... SET image_base64=NULL` (DB 17.6 → ~0.3 MB)
- **Debounce autosync**: 1.2 dtk → **5 menit**; flush-on-pause hanya jika ≥2 menit sejak upload terakhir
- **Bug status order**: app kirim `invoice` (bukan id lokal) di `updateOrderStatus`; worker `update_order` lookup `(store_id, invoice)`
- **appBuildNumber**: di-seed dari `PackageInfo` di `main()`; const jadi fallback
- **Dedupe upload gambar produk online**: hash (size+mtime) per filename di SecureStore → skip upload bila tidak berubah

## ☁️ Migrasi Cloudflare (+130)
### Backend (nusa-cloud, repo baru)
- **Satu Worker** route `/api/{fn}/{action}` — port 12 edge fn Supabase 1:1 (payload JSON identik): license-manager, online-store, sheets-admin, ai-assistant, midtrans, instanpay, register-activation, app-ping, tutorial-manager, license-cron, sheets-archive-cron, auth
- **D1**: port 20 tabel dari migrations (tanpa RLS — auth di worker layer) + tabel `accounts` + `reset_tokens`
- **R2**: bucket `nusa-backups`, `nusa-images`, `tutorial-thumbnails` — path `{uid}/{productId}/...`
- **Auth custom**: `/api/auth/{login,signup,anon,reset-request,reset-confirm}` — PBKDF2 (WebCrypto) + JWT HS256 30 hari; reset email via Resend
- **Realtime**: Durable Object "Room" + WebSocket hibernation — event `backup_updated`, `ring`, `order_new`/`order_updated`
- **Cron Triggers**: license-cron (harian) + sheets-archive-cron (bulanan)
- **Storefront read actions** (pengganti PostgREST langsung): `get_products`, `get_branches`, `get_promos_public`, `get_customer`, `get_orders_by_phone`, `cancel_order_by_phone`, `get_store_by_slug`

### App (nusa_kasir)
- **Hapus `supabase_flutter`** + `yet_another_json_isolate` dari pubspec
- **CloudGateway** (`lib/core/cloud/cloud_gateway.dart`): `invoke(fn, body)`, `storageUpload/Download/List/Remove/PublicUrl`, `wsChannel(name)` — pengganti `Supabase.instance.client`
- **Refactor 29 file**: activation_repository, image_storage_service, online_order_service, spreadsheet_service, update_service, ai_service, account_auth_service, main.dart init, providers.dart, realtime_sync_service, call_service, online_orders_screen, tutorial_screen, dashboard/employees/payment
- **ai_service.dart**: `functionUrl()` → `CloudGateway.baseUrl/api/ai-assistant`; semua supabaseAnon headers dihapus
- **sound_service.dart**: `_publicUrl` → `cloudBaseUrl/img/sounds/` (R2 `nusa-images/sounds/`)
- **NusaConfig**: `supabaseUrl/anon` deprecated; `cloudBaseUrl` (String.fromEnvironment, overridable per varian)

### Web (nusa-online)
- **Hapus `@supabase/supabase-js`** dari `src/` — semua via worker
- **supabase.ts**: fetch ke worker `/api/online-store/*` (produk/cabang/promo/customer/order/cancel)
- **license-manager/sheets-admin/ai-settings/tutorial-manager**: POST worker + x-admin-key only
- **sound-manager**: R2 `nusa-images/sounds/` via worker `/storage` & `/img` publik
- **pay**: instanpay create/poll → worker `/api/instanpay/{create|status}`
- **reset-password**: Supabase setSession/updateUser → worker `/api/auth/reset_confirm {token,newPassword}`

## ⚠️ Catatan migrasi
- **Data existing**: tetap aman di Supabase. Migrasi data (D1/R2) jalan setelah Supabase spend cap dibuka
- **Force-update**: `app_min_versions.min_build=130` di-set saat Supabase hidup kembali → app lama kena popup update
- **User existing**: sementara backup lokal (.nus1) di HP mereka sendiri; begitu Supabase hidup, update ke +130 dan migrasi jalan normal

## 📦 Build
- `version: 2.2.57+130` (naik dari +128)
- 8 varian: kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis
- ~108 MB per APK
