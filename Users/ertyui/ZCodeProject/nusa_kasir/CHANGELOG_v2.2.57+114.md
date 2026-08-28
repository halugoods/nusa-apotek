# NUSA v2.2.57+114 — Perbaikan Login Loop (Kolom Hilang) — Self-Healing Database

## 🛠 Perbaikan Utama: Login Loop "Data Ditemukan" (untuk semua varian)
- **Akar masalah:** kolom `commission_percent` (dan `transaction_id`) ditambahkan di
  v2.2.57+110 di dalam blok migrasi `from < 48` **tanpa menaikkan schemaVersion**
  (tetap 48). Perangkat yang `user_version`-nya sudah 48 sejak v2.2.54 → upgrade ke
  v2.2.57+ → drift **melewati migrasi** (from == 48 == to) → kolom **tidak pernah
  dibuat** → aplikasi error "no such column" saat membaca data karyawan → muncul
  dialog "Data Ditemukan" berulang dan PIN tidak bisa digunakan untuk masuk.
- **Perbaikan:** saat aplikasi membuka database, sekarang **kolom yang hilang
  otomatis ditambahkan** (bukan sekadar mengisi nilai NULL). Jadi perangkat mana pun
  yang pernah melewati celah ini akan pulih sendiri tanpa perlu menginstal ulang.
- Berlaku untuk **semua varian** (kelontong, F&B, laundry, bengkel, salon, apotek,
  fotocopy, servis).

## ✨ Penjelasan untuk Akun yang Sudah Terlanjur Terkena
- Untuk akun yang backup cloud-nya sudah terlanjur cacat (contoh: percetakanrks
  "PERCETAKAN RKS", fotocopy), perbaikan data cloud sudah dilakukan dari sisi server:
  kolom `commission_percent` / `transaction_id` ditambahkan ke backup + nilai default
  diisi. Setelah membuka aplikasi dan memilih **"Ya, Buka Toko Ini"**, data akan
  dipulihkan dengan struktur yang benar dan PIN lama langsung bisa digunakan.

## ✨ Perbaikan Tampilan
- **Tombol "Masuk dengan Google" / "Daftar dengan Google"** kini memakai **logo "G" resmi Google** (sebelumnya fallback ikon generik karena aset tidak ada) + tampilan **timbul (raised/3D)** dengan shadow & latar putih — lebih jelas dan sesuai panduan Google branding.

## 🔄 Lainnya
- Tidak ada perubahan schema database. Ini murni perbaikan database (self-healing), optimasi, dan tampilan tombol Google.
