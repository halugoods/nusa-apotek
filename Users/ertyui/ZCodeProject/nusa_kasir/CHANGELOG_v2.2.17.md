# CHANGELOG v2.2.17+69 — Batch Perbaikan #11

Tanggal rilis: 2026-08-14 · Varian: kelontong (7 varian lain menyusul)

## ✨ Perbaikan & Penyempurnaan

### Catat Pembelian — Satu Alur Utuh (Tambah Banyak Produk Sekaligus)
- Alur keranjang terpisah dihapus — kini **satu alur**: klik `+ Tambah` di kartu produk, lalu muncul stepper `− [qty] +` yang **tetap tampil** selama produk ada di keranjang (tidak pernah hilang).
- Boleh menambah **banyak produk sekaligus** — setiap kartu yang masuk keranjang menampilkan stepper-nya sendiri secara bersamaan.
- Tiap produk yang sudah di keranjang punya **ikon pensil** untuk mengatur **harga beli terbaru (opsional)** — dipakai menghitung total & modal stok, tanpa mengubah harga beli tersimpan.
- **Bar bawah (HP)**: ringkasan `N item · Total` + tombol **Biaya & Catatan** (biaya tambahan seperti packing/ongkir + catatan, dibagi rata ke tiap item) + tombol besar **Tambah Stok** — semua item dikirim **sekaligus** (batch).
- **Tablet (lebar)**: panel kanan keranjang dirapikan — baris item bersih (nama + qty + subtotal tanpa kolom harga), biaya & catatan + tombol Tambah Stok di bawah.

### Stok Masuk / Keluar — Pola Sama (Batch)
- Setelah `+`, stepper `− [qty] +` **tetap di kartu** — boleh banyak produk sekaligus.
- **Bar bawah**: total `N item` + tombol besar **Tambah Stok** (hijau) / **Kurangi Stok** — semua item diproses sekaligus.
- Stok tidak cukup (mode keluar) → peringatan per produk, item lain tetap diproses.

### Scan Barcode Berulang (Kasir & Catat Pembelian)
- Scanner barcode kini **layar penuh dan tidak menutup setelah 1 scan** — scan terus-menerus untuk beberapa produk tanpa membuka ulang.
- Hasil scan terakhir tampil sebagai chip (✓ nama produk / produk tidak ditemukan) + hitungan produk ter-scan. Tutup dengan tombol ✕.
- **Jeda anti dobel 1 detik** untuk barcode yang sama (diangkat lalu discan lagi = scan baru).

### Ukuran Font Struk — Literal 12 · 18 · 24 · 36
- Ukuran font kini berupa **ukuran huruf literal** yang benar-benar tercetak: **12 (Kecil) · 18 (Normal) · 24 (Besar) · 36 (Extra Besar)** — bukan lagi skala 1x–8x yang sering diabaikan printer murah.
- Maksimal perbesaran **4x** (24/36) — di printer yang tidak mendukung, hasilnya tetap tercetak benar tanpa space kosong.
- **Wrap teks ditentukan lebar kertas ÷ perbesaran** — hasil cetak konsisten dengan preview di Pengaturan Struk.
- **Tes Cetak Kalibrasi**: mencetak nama toko dalam 4 ukuran sekaligus supaya kamu langsung tahu ukuran mana yang didukung printer-mu.
- Peringatan dipertegas untuk **Font Ramping (B)**: beberapa printer murah mencetaknya kosong — disarankan pakai Standar.

### Ikon Pilih Supplier — Bukan Lagi "X"
- Ikon pilih supplier yang terbaca seperti huruf "X" di HP diganti **ikon truk (supplier)** di tombol pilih supplier, pill supplier mode Bahan, dan header sheet Pilih Supplier.

### Pembayaran Tunai — Uang Pas & Nominal Custom
- Tombol **"Uang Pas"**: sekali sentuh, jumlah dibayar = total tagihan tepat (kembalian 0).
- **Nominal cepat custom**: tambah pecahan sendiri (misal 15.000 untuk voucher/saldo) lewat ikon penyetelan — tersimpan permanen, bisa dihapus per item maupun semua.

### Toko Online — Peringatan Gambar Gagal
- Sebelumnya saat upload gambar produk gagal, produk tetap disinkronkan **tanpa foto secara senyap**. Sekarang muncul **peringatan jelas** (toast + banner di kartu Produk Online) berisi jumlah & nama produk yang gagal upload gambarnya — tetap tampil di website tanpa foto, dan bisa coba sinkronkan lagi.
