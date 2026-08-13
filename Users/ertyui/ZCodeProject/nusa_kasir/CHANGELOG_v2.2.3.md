# NUSA Kasir v2.2.3+55 — Rilis Batch Perbaikan

## 🆕 Fitur Baru
- **Pembelian Supplier (Restok)** — catat pembelian barang dari supplier: pilih supplier + produk + qty, total otomatis. Saat dicatat: **stok produk langsung masuk** + **harga modal (buyPrice) otomatis diperbarui** ke harga beli terbaru → laporan HPP/laba rugi jadi presisi. Riwayat pembelian tersimpan (invoice PB-…), bisa dibuka detail per item. Menu di Dashboard: **Pembelian** (di samping Supplier; akses Owner/Manager/Gudang/Finance, Owner-only). Ada tombol pintasan **Beli** di halaman Supplier.

## 🛠️ Perbaikan
- **Filter Laporan "Hari Ini"** — transaksi kemarin tidak lagi ikut terhitung (batas hari dihitung dari tengah malam, bukan 24 jam ke belakang)
- **Printer Bluetooth tidak lagi salah sambung** — auto-connect hanya ke printer yang sudah disimpan di Pengaturan (sebelumnya bisa nyambung ke TWS/earphone atau perangkat Bluetooth lain)
- **Struk ESC/POS** — item yang dapat diskon kini menampilkan **Harga Normal + potongan (Diskon: -Rp…)** sehingga struk transparan
- **Scanner barcode fisik (HID)** — menekan Enter setelah scan langsung mencari produk + masuk keranjang (tanpa perlu tap tombol cari)
