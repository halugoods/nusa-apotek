# CHANGELOG v2.2.32+84 — Audit 7 Varian = Kelontong + Piutang + Kasir Hutang + Fotocopy → Percetakan

Tanggal rilis: 2026-08-18 · Varian: **8 varian sekaligus** (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis)

## 📋 RINGKASAN

Paket besar penyelarasan **semua varian = kelontong** + fitur piutang menyeluruh
+ upgrade **fotocopy → percetakan**. Akar masalah login/PIN di 7 varian
(aktivasi lisensi terikat per-produk) sudah diperbaiki di sisi server: **satu
lisensi kini berlaku untuk semua varian** — akun Google yang sudah terdaftar
bisa langsung masuk tanpa harus bikin lisensi baru, dan PIN tidak dilompati
saat buka ulang. Menu **Piutang** kini tampil di semua varian, kasir punya opsi
**Hutang** (total jadi piutang pelanggan, otomatis masuk menu Piutang), dan
Order Cetak fotocopy dirombak jadi manajemen **percetakan lengkap**.

## ✨ FITUR BARU

- **Piutang di semua varian** — menu Piutang kini tampil di fnb, laundry,
  salon, apotek, fotocopy (sebelumnya disembunyikan). Kelola piutang &
  pelunasan bisa dipakai semua jenis usaha.
- **Kasir: opsi "Hutang"** — di pembayaran kasir, selain DP (bayar sebagian),
  ada mode **Hutang**: wajib pilih pelanggan, nominal bayar 0, **seluruh
  total tercatat otomatis ke menu Piutang** dengan deskripsi "Hutang transaksi
  INV …". Struk menampilkan baris Hutang saat mode ini dipakai.
- **Order Cetak → Percetakan** (varian fotocopy):
  - **Jenis layanan CRUD** — 6 layanan bawaan (Fotocopy, Print Warna, Print
    B/W, Jilid, Laminating, Scan) + bisa **tambah/ubah/hapus layanan custom**.
  - **Tanpa icon bulat** — layanan custom tampil sebagai label teks polos,
    bukan ikon bulat.
  - **Dimensi cetak (P×L cm)** + **estimasi selesai** per order (opsional).
  - **Kategori percetakan**: Print 🖨️, Banner & Spanduk 🪧, Kartu Nama &
    Undangan 💌, Stiker & Label 🏷️, Jilid & Laminating 📚, ATK ✏️, Lainnya 📦.
  - **Dashboard stats Order Cetak** — kartu Hari Ini / Diproses / Selesai /
    Diambil (ala laundry & salon).
  - **Auto-order dari kasir** — checkout produk kategori percetakan otomatis
    membuat Order Cetak (status Baru).
- **UI mengikuti design system** — kartu metode bayar (Tunai/QRIS/Transfer/
  EDC…) kini **scrollable horizontal** kalau lebih dari 4 item, tidak overflow.
- **Spreadsheet & AI Chat berlabel "Dalam Pengembangan"** — badge di dashboard,
  keterangan di Kelola Fitur, dan banner di layar fitur (tetap berfungsi).

## 🔧 PERBAIKAN

- **Login/PIN di 7 varian (server)** — edge `register_activation` sekarang
  multi-produk: CHECK mengambil lisensi valid pertama milik akun tanpa memfilter
  product, ACTIVATE otomatis memigrasi product lisensi. Satu lisensi = semua
  varian, PIN tidak skip saat buka ulang.
- **Sinkron config hidden menus** — `_build_all.py`, `nusa_config.dart`, dan
  `variant_data.dart` kini 100% sinkron untuk menu Piutang (dev mode ikut).
- **Migrasi schema 42** — PrintOrders + kolom dimensi/estimasi + tabel
  PrintServiceTypes + seed 6 layanan (aman untuk database lama, tanpa reset).

## 🧪 TES

- **43 unit test lulus** · `flutter analyze` 0 error.
- Build APK 8 varian diverifikasi (fotocopy dicoba lebih dulu: 106 MB).
