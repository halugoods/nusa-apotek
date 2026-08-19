# CHANGELOG v2.2.36+88 — Fix Login Restore, Produk Load, DP/Hutang Rapi, Badge Notif

**Tanggal**: 2026-08-20

## RINGKASAN

Rilis untuk **8 varian** (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis). Fokus: perbaikan 4 bug kritis dari tes pengguna — **(1) login: dialog "Data Ditemukan" kini selalu muncul SEBELUM PIN** (sebelumnya fresh install langsung ke PIN pad, PIN selalu gagal sampai clear data + login ulang akun kedua), **(2) produk tidak load / kasir tidak bisa dibuka di banyak varian**, **(3) blok pembayaran DP & Hutang dirapikan (kartu atas-bawah, gaya kuning soft seragam)**, **(4) badge notifikasi tidak hilang setelah notifikasi dibuka**. Semua fix berlaku seragam di 8 varian (kode lintas varian identik, hanya `productId`/tema yang beda).

## PERUBAHAN

### 1. Login — restore cloud DIJALANKAN sebelum PIN pad (bug kritis #1)
- `ActivationScreen._goToPinOrSetup`: saat pengecekan pegawai **gagal/DB rusak** (sebelumnya error di-swallow → langsung PIN pad → PIN selalu gagal), sekarang **otomatis coba pulihkan dari cloud dulu** (`RestoreBackupFlow.runIfNeeded`). Kalau backup ditemukan → dialog "Data Ditemukan" muncul → aplikasi restart dengan data utuh. Setup hanya fallback terakhir bila memang tidak ada backup.
- `_repairPinLength` di `main.dart` dipindah **setelah** pending restore di-swap — perbaikan panjang PIN kini membaca **DB hasil restore**, bukan DB lama yang masih kosong/parsial.
- Hasil: fresh install → login Google → **dialog "Data Ditemukan" langsung muncul** → klik Buka → PIN sesuai data restore berhasil. Tidak perlu lagi hapus data aplikasi + login akun kedua.

### 2. POS — produk load & kasir selalu bisa dibuka (bug #2)
- `_loadTables`, `_loadGridColumns`, `_loadCashier` dibungkus `try/catch` — error DB/query kecil tidak lagi menggantung/me-crash `initState` (sumber "kasir gabisa dibuka").
- Grid produk kosong kini menampilkan **tombol "Muat Ulang"** — user bisa retry tanpa keluar layar.
- `_preloadProducts` sudah aman sejak v2.2.35 (fallback list kosong, tidak spinner abadi).

### 3. Checkout — DP & Hutang rapi, atas-bawah, seragam (bug #3)
- Blok **Uang Muka (DP)** dan **Hutang** kini **bertumpuk atas-bawah** (DP di atas, Hutang di bawah), masing-masing **full-width** dengan gaya **kartu kuning soft identik** (amber `0xFFFEF3C7` aktif / `0xFFFEFCE8` non-aktif, border `0xFFF59E0B`).
- Sebelumnya: sejajar kiri-kanan di HP sempit → label meluber, tidak konsisten (hanya Hutang yang berkartu).
- Toggle di dalam kartu tetap berfungsi penuh (tap kartu / switch).

### 4. Notifikasi — badge hilang setelah dibaca (bug #4)
- `NotificationService.add()` kini **mempertahankan status `read`** saat notifikasi dengan id sama diperbarui (sebelumnya selalu dibuat unread lagi → badge tidak pernah turun).
- Badge dashboard = **jumlah notifikasi belum dibaca** saja (dot update-info dihapus dari hitungan; dot hanya muncul kalau benar-benar ada notif baru belum dibaca).

### 5. Lain-lain
- `*.orig` ditambahkan ke `.gitignore` (file backup script build).
- Build number **88** — konsisten dengan tag GitHub `v2.2.36+88` (mencegah loop "Update tersedia" dari parse tag).

## TEKNIS
- **Dart/Flutter**: `flutter analyze` 0 error · `flutter test` 47/47 pass.
- **DB**: tanpa migrasi baru (skema tetap v44).
- **Rilis**: 8 varian dari source identik (HEAD `dev`).
