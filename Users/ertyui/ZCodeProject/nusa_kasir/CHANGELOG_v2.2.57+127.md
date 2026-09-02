# NUSA v2.2.57+127 — Fix Dobel Diskon Kasir, Struk 1 Baris Disc., Preview Real-Time, Order Online Lebih Andal

Versi utama tetap **2.2.57** — hanya build number naik ke **+127**. Berlaku untuk **semua 8 varian**.

## 💥 PENTING: Fix Dobel Diskon di Kasir (harga jadi SALAH)
- **Sebelumnya:** produk dengan diskon menu dihitung diskonnya **2×** — contoh: produk Rp 87.500 dengan diskon Rp 50.000 tampil total **Rp 12.500** (bukan Rp 37.500). Uang masuk tidak sesuai.
- **Sekarang:** diskon menu/grosir sudah termasuk di harga jual, **tidak dipotong lagi** saat checkout. Diskon manual ("Ubah Diskon") tetap dipotong sekali.
- Kasus lama yang tampil Rp 12.500 sekarang benar **Rp 37.500**.

## 🧾 Struk: Diskon Cukup 1 Baris
- Format struk baru per item (permintaan user):
  ```
  Nama Produk
    1 x 87.500   87.500
    Disc. (-50.000)
  ```
- Hanya **SATU baris "Disc."** gabungan (diskon produk + manual digabung) — tidak lagi 2 baris "Disc. Produk" / "Disc. Manual".
- Berlaku di semua output: **cetak thermal, share WA, PDF, dan preview struk**. Total akhir selalu konsisten dengan total keranjang.

## ⚡ Kasir: Preview Real-Time di Ubah Harga / Ubah Diskon
- Bottom sheet **Ubah Harga Sementara** dan **Ubah Diskon per Jumlah** sekarang menampilkan **preview langsung saat mengetik**:
  - **Harga jadi / Diskon → harga akhir** per item (harga lama tercoret bila lebih murah).
  - **Subtotal item** setelah diskon.
  - **Blok ringkasan di atas tombol Simpan**: "Total keranjang menjadi: Rp X" + selisih +/- terhadap total sekarang.
- Tidak perlu lagi simpan dulu untuk tahu efeknya.

## 🛒 Order Online: Pesanan Tidak Lagi Hilang Setelah Clear-Data/Reinstall
- **Akar masalah:** setelah clear-data/reinstall, aplikasi memakai activation key BARU sebagai identitas toko, sedangkan pesanan online masuk ke toko row ASLI di server → pesanan tidak pernah terlihat, dan Data Toko bisa tampil salah/slug berubah sendiri.
- **Perbaikan:**
  - Identitas toko asli **disimpan permanen di device** (aman clear-data/reinstall) — semua operasi produk/order/promo + notif realtime menunjuk toko yang benar.
  - Server tidak lagi menimpa identitas toko lama saat simpan Data Toko.
  - Ambil pesanan & ubah status otomatis **fallback ke toko asli** bila identitas baru tidak menemukan pesanan.

## 🏷 Cetak Label: Semua Produk Bisa Dicetak + Card Scrollable
- **Semua produk** (ber-barcode maupun tidak) sekarang bisa dipilih untuk dicetak label:
  - Produk **tanpa barcode** = label isi **nama + harga** saja (ada badge oranye "Tanpa barcode" — tidak crash, barcode otomatis dilewati).
  - Checkbox "Barcode" otomatis nonaktif bila semua produk terpilih tidak ber-barcode.
- **Daftar pilih produk dibungkus card statis 3D** (raised + shadow) yang **scrollable** — cuma ±5 produk terlihat, sisanya di-scroll dalam card. Aman untuk ratusan/ribuan produk (pencarian tetap jalan).

## 🔥 Preview Struk Label Real-Time
- Preview jalur **Thermal Struk 58mm** di Cetak Label sekarang **real-time**: geser slider ukuran font nama/harga → preview langsung berubah, tanpa tutup-buka card (sejajar dengan preview Thermal Label & PDF A4).

## 🔧 Lainnya
- Fix berbagai gap end-to-end alur diskon (kasir → checkout → draft → struk → split bill → laporan) — semua konsisten memakai logika baru.
- Deploy server-side edge function (order online) sudah live — perbaikan server aktif untuk semua versi app.

## 📦 Download
APK per varian ada di masing-masing repo release (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis).
