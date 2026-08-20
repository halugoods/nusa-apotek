# NUSA v2.2.38+90 — Fix Restore Cloud (SEMUA 8 VARIAN)

## 🔥 Perbaikan Kritis: Restore Backup Cloud

Masalah lama: setelah install ulang / pindah perangkat, aplikasi **tidak pernah**
menampilkan dialog "Data Ditemukan" — padahal data cloud ada. User disuruh
membuat data baru dari nol (setup ulang), padahal datanya aman di cloud.
**Masalah ini kena SEMUA pengguna (bukan satu akun tertentu).**

**Akar masalah** (3 lapis):

1. **Infra Supabase**: login anonim (anon auth) dimatikan di project settings +
   bucket storage tidak punya policy baca untuk anon → aplikasi tidak bisa
   melihat/mengunduh backup apa pun dari cloud → selalu lewat ke setup.
2. **Bug path di aplikasi**: backup dienkripsi + disimpan di path
   `{GoogleUID}/{varian}/backup.sqlite.enc`, tapi kode kadang memakai UID sesi
   anonim Supabase (format UUID) untuk menunjuk path → path beda → backup
   "tidak ditemukan".
3. **Bug deteksi backup**: aplikasi memakai `storage.list()` (daftar isi folder)
   untuk mengecek apakah backup ada. Ternyata kunci anon **bisa download
   langsung** (path persis → 200) tapi **tidak bisa list folder** (404
   "Bucket not found") — sehingga `hasBackup()` selalu false untuk semua user
   → dialog "Data Ditemukan" tak pernah muncul.

**Yang diperbaiki:**

- ✅ Login anonim Supabase **diaktifkan** (project settings)
- ✅ Policy SELECT bucket storage untuk anon **dibuat** → aplikasi bisa lihat
  bucket + download
- ✅ **Deteksi backup diganti dari `list()` → probe download path persis**
  (200 = ada, 404 = tidak ada) — ini yang membuat restore jalan untuk SEMUA
  user. Berlaku di `hasBackup()`, `getBackupTimestamp()`, `syncIfNewer()`,
  dan sync gambar (`ImageStorageService.syncAll()`)
- ✅ Semua jalur baca/tulis backup & gambar **konsisten pakai Google UID**
  (bukan UID anon):
  - `ActivationRepository._googleUserId()` — hapus fallback anon
  - `_syncImagesFromCloud()` (main) — foto produk/gambar sync pakai Google UID
  - `_resolvePhoto()` (dashboard) — foto karyawan unduh dari path Google UID
  - upload foto karyawan (employees) — pakai Google UID
- ✅ Versi dinaikkan ke **v2.2.38+90**

**Hasilnya:** install baru → login Google → dialog **"Data Ditemukan"** muncul →
data (produk, transaksi, karyawan, pengaturan) kembali **persis seperti
sebelumnya**. Semua 8 varian (Kelontong, F&B, Laundry, Bengkel, Salon, Apotek,
Fotocopy, Servis) mendapat perbaikan ini.

> 💡 Data cloud TIDAK diubah/dihapus — perbaikan ini murni sisi aplikasi +
> konfigurasi server, supaya aplikasi bisa menemukan data yang memang sudah ada.
> Diverifikasi: download backup bisa dilakukan untuk **11 UID / 21 backup**
> (bukan hanya satu akun).
