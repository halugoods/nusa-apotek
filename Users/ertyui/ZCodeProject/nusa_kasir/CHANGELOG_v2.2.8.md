# NUSA Kasir v2.2.9+61 — Pengamanan Total Sinkronisasi Cloud

## 🚨 Perbaikan Kritis (Penyempurnaan dari v2.2.8+60)
- **Aplikasi "mati" setelah update / sinkronisasi cloud (menu tidak berfungsi, PIN selalu gagal)** — akar masalah: saat restore/sinkronisasi backup cloud, file database ditimpa **secara langsung di atas database yang sedang dipakai** aplikasi → database rusak → semua menu mati & semua PIN ditolak. Hanya terjadi di perangkat tertentu (saat backup cloud lebih baru). 
- **v2.2.8+60** sudah mencegah hal ini: backup diunduh ke file cadangan, lalu ditukar aman di peluncuran berikutnya.
- **v2.2.9+61 menutup celah terakhir**: file sisa WAL/journal SQLite (`-wal`, `-shm`) yang bisa tertinggal dari sesi sebelumnya kini ikut dibersihkan sebelum database ditukar — memastikan tidak ada data campuran yang bisa membuat menu mati / PIN gagal lagi. Verifikasi menyeluruh: **semua jalur restore (langsung, otomatis, aktivasi) sudah tidak ada yang menulis langsung ke database aktif**.

## 🧾 Struk — Diskon Kini Lengkap di Kertas
- **Diskon per item ditampilkan di struk** — tepat di bawah produk yang mendapat diskon: tampil **"Harga Normal"** dan **"Diskon: -Rp …"**.
- **Total diskon ditampilkan di bawah TOTAL** — baris "Diskon: -Rp …" muncul tepat setelah total.
- **Perbaikan ukuran header**: pilihan **Besar** sebelumnya tampil lebih kecil dari **Normal** — kini sesuai pilihan.
- **Nama item memakai lebar penuh kertas** — nama panjang wrap di baris berikutnya (tidak terpotong ~15 huruf).
- **Preview struk 2 arah**: preview ikut lebar kertas pilihan (58mm ramping / 80mm lebar) — persis hasil print.

## 🎨 Lainnya
- **Form pembelian BAHAN dirapikan** — kolom Nama, Harga beli, dan Jumlah terpisah rapi dengan tampilan kartu kedalaman.
- **Keypad PIN mendukung keyboard fisik** — tablet dengan keyboard Bluetooth/wireless bisa ketik PIN langsung.
- **Bantuan & Masukan via WhatsApp** — laporan masalah/usulan fitur terkirim ke WhatsApp tim (0897-6280-303).
- **Label font "Kompak" diganti "Ramping"** — lebih jelas artinya.

