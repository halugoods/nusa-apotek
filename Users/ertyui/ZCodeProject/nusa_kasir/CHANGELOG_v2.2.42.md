# CHANGELOG v2.2.42+95 — Cegah Restore Data Varian Salah + Notifikasi Baca Semua

Tanggal rilis: 2026-08-20 · Varian: **8 varian** (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis)

## 🐛 FIX KRITIS: Restore data varian SALAH (semua varian)

**Gejala**: user membuka aplikasi fnb (v2.2.41) → login Google → dialog "Data Ditemukan" → data yang termuat adalah **produk servis** (Ganti LCD HP, Servis Laptop, dll), bukan data fnb.

**Akar masalah** (diinvestigasi via admin tool, 2026-08-20):
- Folder `nusa-fnb/backup.sqlite.enc` di cloud berisi **data servis** (4 produk kategori `Service`, `image_path` menyebut `com.nusa.servis`, user_version 44). Bukan salah path — kode restore sudah benar membaca folder per-varian. Yang salah adalah **isi folder** itu sendiri tercemar data varian lain (kemungkinan: setup aplikasi varian keliru + auto-sync yang menimpa cloud).
- Karena aplikasi lama TIDAK memverifikasi isi backup, dialog "Data Ditemukan" menawarkan apa pun yang ada di folder — termasuk data varian lain.

**Perbaikan** (berlaku SEMUA varian, semua user):
1. **Validasi isi backup** sebelum restore/sync — `hasBackup()`, `restoreDirect()`, `restoreFromCloud()`, `syncIfNewer()` kini memeriksa isi sqlite hasil decrypt:
   - `user_version` terlalu rendah (< 20) / tabel kunci (products, employees, transactions) hilang → ditolak.
   - `image_path` produk menyebut paket aplikasi yang BUKAN paket varian ini (mis. `com.nusa.servis` di dalam folder fnb) → ditolak (sinyal paling definitif).
   - Backup yang "salah varian" dianggap **TIDAK ADA** → dialog "Data Ditemukan" tidak menawarkannya → user setup dari nol untuk varian yang benar (data asli varian lain di folder masing-masing tetap aman).
2. **Metadata `variantKey`** — backup baru menulis identitas varian di `metadata.json` (path `$uid/metadata.json`, fallback baca path lama per-varian) → verifikasi varian makin akurat.
3. **Auto-sync defensif** — `syncIfNewer()` kalau menemukan backup "salah varian" di cloud cukup mengadopsi timestamp-nya (tidak menimpa lokal, tidak men-download data salah varian).

**Verifikasi**: 4 unit test baru — fnb backup berisi data servis → DITOLAK dari fnb; kelontong backup → DITERIMA; tanpa image_path → diterima bila varian cocok; DB rusak → ditolak. Total **52 test pass**.

> ⚠️ Folder cloud yang SUDAH terlanjur tercemar data varian lain TIDAK dihapus otomatis (sesuai pilihan user: "cegah rusak lagi, biarkan yang lama"). Varian dengan folder tercemar perlu setup ulang dari nol; data asli di folder varian masing-masing tetap utuh.

## ✨ FITUR: Notifikasi "Baca Semua"

- Tombol **"Baca Semua"** di header panel Notifikasi (dashboard) → tandai SEMUA notifikasi sebagai dibaca sekali ketuk.
- Badge lonceng langsung mati setelah semua dibaca; dot merah di tiap item hilang.
- (Service `markRead(null)` sudah ada — hanya UI-nya yang baru.)

## 📦 RILIS

- 8 varian dibangun + dirilis (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis).
- 52 test pass · `flutter analyze` 0 error.
