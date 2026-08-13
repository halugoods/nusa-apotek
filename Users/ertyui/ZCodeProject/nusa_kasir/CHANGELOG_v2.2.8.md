# NUSA Kasir v2.2.8+60 — Perbaikan Kritis Stabilitas, Struk Diskon & Form Bahan Rapi

## 🚨 Perbaikan Kritis
- **Aplikasi "mati" setelah update / sinkronisasi cloud (menu tidak berfungsi, PIN selalu gagal)** — akar masalah ditemukan: saat restore/sinkronisasi backup cloud, file database ditimpa **secara langsung di atas database yang sedang dipakai** aplikasi → database rusak → semua menu mati & semua PIN ditolak. Hanya terjadi di perangkat tertentu (saat backup cloud lebih baru). **Sekarang** backup diunduh ke file cadangan, lalu ditukar aman di peluncuran berikutnya — data tidak akan pernah rusak lagi.

## 🧾 Struk — Diskon Kini Lengkap di Kertas
- **Diskon per item ditampilkan di struk** — tepat di bawah produk yang mendapat diskon: tampil **"Harga Normal"** dan **"Diskon: -Rp …"** (sebelumnya diskon hanya dihitung diam-diam).
- **Total diskon ditampilkan di bawah TOTAL** — baris "Diskon: -Rp …" muncul tepat setelah total, sehingga pelanggan melihat semua potongan.
- **Perbaikan ukuran header**: pilihan ukuran **Besar** sebelumnya malah tampil lebih kecil dari **Normal** — kini ukuran Besar/Normal/Kecil benar-benar membesar/mengecil sesuai pilihan.
- **Nama item memakai lebar penuh kertas** — item dengan nama panjang kini wrap menurun di baris berikutnya (sebelumnya terpotong ~15 huruf → kelamaan enter ke bawah).
- **Preview struk 2 arah**: preview di Pengaturan, checkout, dan Riwayat kini ikut lebar kertas pilihan (58mm ramping / 80mm lebar) — persis hasil print.

## 🎨 Lainnya
- **Form pembelian BAHAN dirapikan** — kolom Nama, Harga beli, dan Jumlah kini terpisah rapi dengan tampilan kartu kedalaman, sama seperti form Produk (sebelumnya berdesakan dalam satu baris).
- **Keypad PIN mendukung keyboard fisik** — tablet dengan keyboard Bluetooth/wireless kini bisa mengetik PIN langsung (angka, hapus, Enter).
- **Bantuan & Masukan via WhatsApp** — laporan masalah / usulan fitur kini langsung terkirim ke WhatsApp tim (0897-6280-303) sesuai teks yang diketik — tanpa perlu akun GitHub.
- **Label font "Kompak" diganti "Ramping"** — lebih jelas artinya (huruf ramping, muat banyak per baris).
