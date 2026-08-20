# CHANGELOG v2.2.37+89 — Fix Kritis Login Restore + Produk Load (Akar Masalah)

**Tanggal**: 2026-08-20

## RINGKASAN

Rilis untuk **8 varian** (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis). Ini perbaikan **akar masalah** (bukan sekadar gejala) dari 2 bug kritis yang masih terjadi di v2.2.36: **(1) dialog "Data Ditemukan" tidak muncul saat fresh install setelah login Google** (langsung ke PIN pad → PIN selalu gagal → harus hapus data + install ulang + login akun kedua), dan **(2) produk tidak load / kasir tidak bisa dibuka** di banyak varian. Keduanya ternyata **satu akar**: **data cloud tidak pernah berhasil di-restore ke perangkat**.

## AKAR MASALAH & PERBAIKAN

### 1. Sesi anonim Supabase TIDAK ditunggu sebelum cek backup (bug login #1)
`hasBackup()` memanggil `signInAnonymously()` **tanpa menunggu selesai**, lalu langsung `storage.list(...)`. Karena sesi anon belum ada, `storage.list` gagal → `hasBackup()` return `false` → **dialog "Data Ditemukan" tidak pernah muncul** → app langsung ke PIN pad / setup.

**Fix**: `_ensureAnonAuth()` sekarang **blocking + retry 3x (jeda 300ms)** — tunggu sampai sesi benar-benar ada sebelum cek/download backup. Ini membuat dialog "Data Ditemukan" muncul **real-time** begitu backup terdeteksi.

### 2. UID backup tidak konsisten / hilang (bug produk #2)
`_googleUserId()` hanya membaca `nusa_google_user_id` dari SecureStore. Kalau key itu hilang (aktivasi via key tanpa Google / write gagal / data ke-reset), backup tidak pernah ditemukan → DB kosong → PIN gagal + produk kosong.

**Fix**: `_googleUserId()` sekarang **fallback ke `Supabase.instance.client.auth.currentUser.id`** (UID sesi yang sama dengan upload) — backup tetap ditemukan walau key Google hilang. Upload & download kini konsisten (keduanya prefer key Google, fallback sesi).

### 3. Restore hanya menulis `.pending` + butuh restart (bug produk #2)
`restoreDirect()` menulis DB ke `nusa_kasir.sqlite.pending` lalu `Restart.restartApp()`. Kalau restart gagal diam-diam → app tetap jalan dengan DB lama yang kosong → PIN gagal + produk kosong.

**Fix**: `restoreDirect()` sekarang **swap LANGSUNG ke sqlite live** (aman karena caller menutup koneksi drift dulu) → data berlaku **seketika**, tanpa restart, tanpa jendela "DB kosong". `RestoreBackupFlow` & `_autoRestoreIfNeeded` kini tutup drift → restore → arahkan ke `/login` (bukan restart).

### 4. Koneksi drift masih terbuka saat restore (korupsi)
`RestoreBackupFlow` / `_autoRestoreIfNeeded` membuka `databaseProvider` (drift) sebelum restore → menulis live sqlite saat drift terbuka = korupsi.

**Fix**: tutup `databaseProvider` (`close()`) + `invalidate()` **sebelum** `restoreDirect()` — koneksi berikutnya membaca DB hasil restore.

### 5. `_receiveAtLaunch` memakai `.pending` yang tidak pernah di-swap
`main.dart` memanggil `_applyPendingRestore()` (swap `.pending`) **sebelum** `_receiveAtLaunch()`. Kalau `_receiveAtLaunch` stage `.pending` baru, swap sudah lewat → tidak pernah berlaku.

**Fix**: `_receiveAtLaunch` kini pakai `restoreDirect()` (live swap) — drift belum dibuka di titik ini, aman.

### 6. AutoSync conflict memakai live swap saat drift terbuka
`AutoSyncService` memegang koneksi drift yang selalu terbuka — `restoreDirect()` live swap di sana = korupsi.

**Fix**: `AutoSyncService` conflict + `settings_screen` manual **kembali ke `restoreFromCloud()`** (stage `.pending`, di-swap saat start berikutnya) — aman untuk jalur background.

## TEKNIS
- **Dart/Flutter**: `flutter analyze` 0 error · `flutter test` 47/47 pass.
- **DB**: tanpa migrasi baru (skema tetap v44).
- **Rilis**: 8 varian dari source identik (HEAD `dev`), tag `v2.2.37+89`.

## CATATAN UNTUK TES
1. **Fresh install** → login Google → **dialog "Data Ditemukan" muncul LANGSUNG** (dengan nama toko/pemilik/waktu backup) → klik "Ya, Buka Toko Ini" → **langsung masuk ke PIN** dengan data lengkap → produk tampil.
2. **Tanpa hapus data**: tutup app → buka lagi → masuk PIN → semua data (produk, karyawan, transaksi) utuh.
3. Kalau backup memang tidak ada (akun baru) → setup dari nol (wajar — tidak ada data).
