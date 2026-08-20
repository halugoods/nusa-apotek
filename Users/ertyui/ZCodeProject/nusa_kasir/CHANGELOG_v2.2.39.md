# NUSA v2.2.39+91 — Fix Login Restore + Produk Load SEMUA Varian

Dua bug kritis yang bikin user harus "hapus data aplikasi dulu" baru bisa restore, dan setelah restore 6 varian lain (F&B, Laundry, Bengkel, Salon, Apotek, Servis) produknya loading terus + kasir tidak bisa dibuka. Kini diperbaiki untuk **SEMUA pengguna & SEMUA 8 varian**.

## 1. Login pertama setelah install: "Data Ditemukan" muncul TANPA hapus data

**Sebelumnya:** install APK → login Google → langsung ke PIN pad (tanpa dialog Data Ditemukan). Data baru bisa di-restore setelah user hapus data aplikasi.

**Penyebab:** saat login, app membuka koneksi database lokal yang masih kosong, lalu menimpa file database dari cloud **sambil koneksi lama masih terbuka** → file rusak/terbaca kosong → PIN pad. Karena file dianggap "sudah punya data kosong", dialog Data Ditemukan dilewati.

**Fix (v2.2.39):**
- Koneksi database lokal DITUTUP dulu sebelum restore cloud — file database ditimpa dengan aman.
- Pengecekan "Data Ditemukan" dijalankan SEBELUM PIN pad, setiap kali login.
- Auto-sync saat app start tidak lagi menimpa file saat koneksi masih terbuka.

## 2. Setelah restore: produk load + kasir bisa dibuka di SEMUA 8 varian

**Sebelumnya:** hanya Kelontong & Fotocopy yang jalan; 6 varian lain (F&B, Laundry, Bengkel, Salon, Apotek, Servis) produknya loading abadi + tombol Kasir tidak bisa diklik.

**Penyebab:** backup 6 varian tersebut tersimpan dengan skema database LAMA (versi 26-30), sedangkan aplikasi terbaru butuh kolom/tabel baru (versi 44). Saat restore, file database ditimpa tanpa menjalankan migrasi skema → query produk gagal ("kolom tidak ditemukan") → loading abadi.

**Fix (v2.2.39):**
- Setiap restore cloud kini **menjalankan migrasi skema otomatis** sampai versi terbaru — data lama langsung ditingkatkan, produk & kasir langsung terbaca.
- Migrasi aman (tidak merusak data), dan kalau database benar-benar rusak, aplikasi tidak crash — hanya menampilkan layar setup sebagai langkah terakhir.

## Verifikasi
- 47 test otomatis lulus.
- Migrasi skema diuji terhadap backup asli (ver 26 → 44): produk tetap utuh, query produk berjalan.
- Berlaku untuk SEMUA pengguna (bukan hanya satu akun) — backup 8 varian di akun Anda terbukti semua ada di cloud.
