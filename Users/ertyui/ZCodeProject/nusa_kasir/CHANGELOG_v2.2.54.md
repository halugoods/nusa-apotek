# Changelog v2.2.54 (Build 107)

## 📞 Fitur Baru — Panggil Karyawan (Realtime)
- **Owner bisa membunyikan device kasir/staf dari jauh**: di dashboard, buka sheet
  "Hubungi Karyawan" (flip kartu stats ke sisi belakang) → tiap karyawan kini punya
  tombol **WA** dan **Panggil**.
- **Panggil** mengirim sinyal realtime (Supabase Broadcast) ke device yang sedang
  login sebagai karyawan tsb — muncul banner "… memanggil kamu" + bunyi dering +
  getar, auto-tutup 30 detik.
- Receiver global dipasang di level aplikasi, jadi bekerja di semua layar.
- Sheet daftar karyawan diperbaiki: sekarang **scrollable penuh**, menampilkan jumlah,
  avatar + nama + role tiap baris, dan tidak lagi terpotong/gamuncul saat datanya ada.

## 🔊 Fitur Baru — Suara Aplikasi
- Set lengkap efek suara: transaksi berhasil, scan barcode, produk masuk keranjang,
  presensi masuk/keluar, pesanan online baru masuk, stok menipis, PIN salah.
- Toggle **"Suara Aplikasi"** di Pengaturan untuk mematikan semuanya.

## ⚙️ Pengaturan Baru
- Dua toggle baru setelah Pengaturan Struk:
  - **Suara Aplikasi** — bunyi transaksi/scan/presensi.
  - **Fitur Panggil** — device ini bisa dibunyikan owner; toggle langsung masuk/keluar
    channel realtime tanpa restart app.

## 🪑 Salon — Pilih Stylist/Capster Saat Booking
- Kartu booking di checkout kini punya dropdown **stylist/capster** berisi karyawan
  aktif bertanda *Staf Layanan* (flag baru per karyawan di form Karyawan).
- Pilihan tersimpan ke data appointment — siap untuk laporan per-stylist berikutnya.

## 👤 Laporan & Transaksi — Nama Kasir + Filter Karyawan
- Card transaksi di menu Laporan dan Transaksi kini menampilkan **nama kasir**
  yang melayani.
- Owner bisa **memfilter laporan per karyawan** lewat dropdown "Semua Kasir" —
  lihat penjualan hanya dari kasir tertentu (ringkasan harian, metode bayar,
  produk terlaris, kategori ikut terfilter).

## 🛍️ POS & Produk
- Chip Produk/Layanan diganti **switch card selebar search bar** — lebih jelas
  posisi aktifnya.
- Suara "pop" saat barang masuk keranjang + suara error saat stok tidak cukup /
  produk tidak ditemukan.
- Salon menu Produk: tab **Layanan** kini setara dengan tab Produk — grid/list,
  filter kategori, pencarian, CRUD penuh; tombol switch jasa↔produk di card
  dihapus (pengaturan tipe lewat form).

## 🧾 Konsistensi Search Bar (20 lokasi)
- Semua search bar di seluruh varian diseragamkan ke komponen standar NUSA
  (radius, ikon, tinggi, tombol scan): Kasir, Booking salon, Pelanggan, Presensi,
  Karyawan, Pesanan Online, Print Order, Cabang, Status Laundry, Servis, Resep,
  Pembelian (2), Stok, Stok Opname, Pengaturan Pembayaran, Supplier, Toko Online,
  Transaksi, dialog pelanggan di Checkout.
- Search bar booking salon kini identik dengan Kasir.

## 🎬 Tutorial — Cloud Only
- 20 kartu teks statis dihapus. Menu Tutorial kini galeri video dari cloud
  (grid thumbnail YouTube otomatis) + empty state rapi dengan tombol coba lagi.

## 📜 Lisensi
- **Cek lisensi saat app dibuka**: lisensi yang di-cancel/suspend/expired kini
  langsung dialihkan ke layar aktivasi (sebelumnya device yang sudah aktivasi
  lolos selamanya). Offline tetap aman — cek gagal/time-out = app jalan normal.

## 🐛 Perbaikan Lain
- versionCode APK naik konsisten (pubspec lama tertinggal di build 99).
