# NUSA v2.2.40+92 — "Data Ditemukan" muncul TANPA hapus data + ganti akun

Perbaikan akar masalah untuk komplain: **install APK → login akun yang sudah punya cloud backup → langsung PIN pad, dialog "Data Ditemukan" tidak muncul** (harus hapus data aplikasi dulu). Kali ini diperbaiki di **semua skenario**: fresh install, install di atas data lama, DAN ganti akun Google.

## Kenapa sebelumnya tidak muncul?

Alur lama: key aktivasi tersimpan per-varian (`nusa_activation_<produk>`). Saat install ulang di atas data lama / ganti akun, key masih ada → app menganggap "sudah aktivasi" → langsung PIN pad **tanpa pernah cek backup cloud akun yang baru login**. Ditambah auto-sync yang restore diam-diam saat start → dialog tidak pernah tampil.

## Perbaikan v2.2.40

### 1. Deteksi ganti akun → dialog "Data Ditemukan" muncul
- App sekarang mencatat akun Google **terakhir** yang login (`nusa_linked_account_id`).
- Kalau akun yang baru login **berbeda** dari yang terakhir tersimpan → cek backup cloud akun itu → kalau ada → dialog "Data Ditemukan" tampil **sebelum PIN pad**. User bisa pilih "Ya, Buka Toko Ini" (restore data akun itu) atau Batal.

### 2. Fresh install / DB kosong → lewat layar login Google (bukan langsung setup)
- Route awal berubah: kalau DB lokal kosong/rusak tapi sudah "teraktivasi" → sekarang ke layar **aktivasi (login Google)** dulu, bukan langsung `/setup`. Setelah login Google, dialog "Data Ditemukan" tampil kalau backup ada.
- Sebelumnya langsung `/setup` → user bikin owner baru → **data tidak keluar**. Sekarang user bisa login akun yang punya backup → restore → data keluar.

### 3. Auto-sync tidak restore diam-diam saat fresh / ganti akun
- Restore diam-diam di start hanya jalan kalau device **sudah pernah sinkron** dengan cloud (punya riwayat `lastCloudSeen`) **dan** akun masih sama. Kalau fresh install atau ganti akun → auto-sync diam (tidak menimpa) → dialog user-facing yang menawarkan.

## Verifikasi
- 47 test otomatis lulus, `flutter analyze` 0 error.
- Back up akun `djuhairsyams.sd@gmail.com` (UID 114275999320339813466): semua 8 varian ada di cloud, schema 44, produk utuh (diverifikasi langsung ke Supabase: backup fnb 269KB, download 200, `has_license: true`).
- Berlaku untuk SEMUA pengguna (bukan hanya satu akun).

## Cara tes di device
1. Install APK v2.2.40 (bisa langsung di atas versi lama — TANPA hapus data).
2. Login Google dengan akun yang cloud backupnya sudah ada.
3. **Dialog "Data Ditemukan" muncul** → "Ya, Buka Toko Ini".
4. Data restore → produk + kasir langsung jalan.
5. Coba ganti akun Google → dialog muncul lagi untuk akun baru.
