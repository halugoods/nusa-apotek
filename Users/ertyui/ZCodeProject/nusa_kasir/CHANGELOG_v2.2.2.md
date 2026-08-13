# NUSA Kasir v2.2.2+54 — Rilis Batch Fitur

## 🆕 Fitur Baru
- **Metode bayar EDC/Kartu** — kartu debit/kredit via mesin EDC, tercatat di laporan sebagai "Kartu"
- **DP / Uang Muka** — transaksi bayar sebagian (lazim 50%), sisa otomatis dicatat sebagai piutang pelanggan; struk menampilkan "Uang muka" + "Sisa piutang"
- **In-App Update** — lonceng notifikasi menampilkan badge saat ada versi baru; download + instal langsung dari aplikasi (tanpa keluar app)
- **Auto Cloud Sync** — backup otomatis ke cloud ±6 detik tanpa perlu tap; konflik diselesaikan otomatis (newest-wins) tanpa menghilangkan data
- **Pinpad Kasir Opsional** — bisa dimatikan di Pengaturan (kasir buka tanpa PIN, login tetap aman)
- **Item Manual di POS** — tambah item bebas (jasa angkut, antar-jemput, dll) langsung dari layar kasir tanpa buat produk
- **Barcode di Form Produk** — scan kamera + input manual terpusat di form produk (dialog scanner dibersihkan)
- **Izin Pertama Kali** — dialog sekali saat setup (kamera, notifikasi, storage)

## 🛠️ Perbaikan
- Pengaturan Struk: logo & footer pindah ke sini, toggle barcode dihapus
- Diskon per-item di struk menampilkan nominal Rp (bukan persen)
- Void transaksi: hanya Owner/Manager + wajib PIN re-entry
- Harga grosir otomatis aktif saat qty mencapai minimum
- Retur/refund parsial: stok kembali + uang kembali + tercatat di laporan
- Loyalty: riwayat poin per pelanggan + tier otomatis
- Feedback in-app: tombol Laporkan/Usul di Pengaturan
- Konsistensi konfigurasi 8 varian diverifikasi (hygiene test)

## 🐛 Fix Build
- Perbaikan regex `_build_all.py` (double-quote pada namespace/applicationId) — build semua varian kembali sukses
