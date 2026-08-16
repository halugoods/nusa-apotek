# CHANGELOG v2.2.18+70 — Koreksi Batch #12

Tanggal rilis: 2026-08-14 · Varian: kelontong (7 varian lain menyusul)

## ✨ Koreksi & Perbaikan

### Catat Pembelian
- **Stepper produk tidak langsung tampil** — kartu produk kini menampilkan tombol **`+ Tambah`** lebih dulu; setelah diklik, barulah stepper `− [qty] +` muncul di kartu dan **tetap tampil** selama produk ada di keranjang. Pola ini sama dengan Stok Masuk/Keluar yang sudah diperbaiki sebelumnya.
- **Sheet Biaya & Catatan responsif** — konten kini dapat di-scroll; saat keyboard terbuka, kolom Biaya Tambahan & Catatan tidak lagi terpotong di layar kecil.
- **Ikon pilih supplier diganti** — ikon di samping kolom pencarian kini memakai ikon jabat tangan (`handshake`) yang lebih jelas terbaca sebagai pilihan supplier (sebelumnya truk `local_shipping`).

### Pencetak Struk (koreksi lanjutan)
- **Struk menampilkan harga asli** — item kini dicetak dengan **harga asli sebelum diskon**, diskon tampil sebagai baris terpisah (`Diskon: -Rp…`), dan subtotal tidak lagi menghitung dua kali.
- **Pengaturan ukuran font lebih detail & fleksibel** — pengaturan ukuran kini punya slider 1x–8x **plus pilihan jenis font per bagian** (Header / Rincian / Footer: Standar Font A, Ramping Font B, atau Ikut Global) dan **batas maksimal perbesaran printer** yang tersimpan.
- **Tes Cetak Kalibrasi** ditingkatkan — mencetak semua ukuran (1x–8x) untuk Font A dan Font B sekaligus, supaya kamu tahu persis kemampuan printer-mu.
- Preview struk disesuaikan agar sama persis dengan hasil cetak (harga asli + baris diskon + ukuran sesuai batas).

### Pembayaran (Kasir)
- **Chip Uang Pas dibuat kompak** — seukuran chip nominal lainnya (tidak lagi melebar penuh).

### Toko Online
- **Foto produk gagal tidak lagi senyap** — jika upload gambar produk gagal, muncul peringatan jelas berisi nama produk yang gagal (di layar + toast), penyebabnya dilaporkan (file tidak ada di HP / koneksi / belum login Google), sehingga kamu tahu persis yang perlu diperbaiki.

## 🐛 Perbaikan Teknis
- Upload gambar produk memakai **MIME type eksplisit** per ekstensi file (jpeg/png/webp/gif) + `upsert` — memperbaiki penyebab gambar kosong di web toko online yang selama ini gagal diam-diam.
- Kode scanner kamera dikembalikan ke UI asli (dialog + overlay animasi, sekali scan per buka) — **scan berkelanjutan tetap berfungsi via scanner eksternal/HID** (ketik barcode di kolom pencarian + Enter).
