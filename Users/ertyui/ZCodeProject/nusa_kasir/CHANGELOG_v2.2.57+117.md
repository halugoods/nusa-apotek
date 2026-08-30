# NUSA v2.2.57+117 — Kasir: Fokus Hasil Scan, Ubah Harga/Detail per Item, Struk Lebar Penuh

Versi utama tetap **2.2.57** — hanya build number naik ke **+117**. Berlaku untuk **semua 8 varian**.

## 🔍 Kasir: Fokus Hasil Scan (UX Scan Barcode)
- **Sebelumnya:** setelah scan barcode, produk tetap tampil semua di daftar produk — user harus mencari produk yang baru discan di antara semua.
- **Sekarang:** setelah scan, daftar produk otomatis **hanya menampilkan produk yang discan**. Ada banner "Hasil scan: <nama produk>" + tombol **"Tampilkan Semua"** untuk kembali ke daftar lengkap — kenyamanan user tidak terganggu.

## 🛒 Kasir: Klik Card Produk di Keranjang → Detail Per-Item
- Klik card produk di keranjang sekarang membuka **bottom sheet** (slide dari bawah) dengan pengaturan per item:
  - **Ubah Harga Sementara** — harga khusus untuk transaksi ini (berlaku per satuan).
  - **Ubah Diskon per Jumlah** — potongan nominal per satuan (selain diskon global).
  - **Tambah Catatan** — catatan singkat di produk (dipakai di struk / order dapur).
  - **Toggle "Informasikan di struk cetak"** — matikan untuk menyembunyikan detail & catatan item ini dari struk pembelian.
- **Nyambung penuh ke semua alur transaksi:**
  - Subtotal keranjang, checkout, dan total pembayaran ikut menghitung harga sementara & diskon.
  - Tersimpan di draft pesanan (dilanjutkan kapan saja) dengan nilai yang sama.
  - Struk cetak (thermal) mencetak diskon per item + catatan, dan menghormati toggle tampil/nyembunyi.
  - Laporan transaksi & riwayat cetak ulang struk membaca nilai yang sama.

## 🏷 Cetak Label & Struk — Ukuran Font Pecahan + Barcode Selebar Kertas
- **Font nama/harga label sekarang pakai format bit-image dengan skala pecahan** — setiap perubahan **0.1×** pada slider langsung terlihat di hasil cetak (sebelumnya 1.1×–1.3× tampak sama dengan 1×).
- **Nama produk yang mentok di barcode** otomatis dipindah **ke bawah barcode**, dan harga digeser sedikit ke bawah — tidak ada lagi nama yang menabrak barcode.
- **Struk thermal: barcode sekarang dicetak full selebar kertas struk** (58mm / 80mm) — rata kanan-kiri penuh, sesuai preview.
- Preview PDF A4: barcode tidak lagi meluber keluar kotak label.

## 📱 Dialog Izin (Permission) Pertama Kali
- Dialog izin (kamera, notifikasi, penyimpanan, bluetooth) sekarang muncul **saat pertama kali membuka aplikasi di layar login** (email/Google) — bukan menunggu sampai setup selesai.
- Dialog asli Android, berurutan satu per satu. Kalau user menolak semua, dialog akan ditanya lagi di pembukaan berikutnya (sampai memberi setidaknya satu izin).

## 📦 Download
APK per varian ada di masing-masing repo release (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis).
