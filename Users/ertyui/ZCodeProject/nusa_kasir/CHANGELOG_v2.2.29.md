# CHANGELOG v2.2.29+81 — SATU Mesin Struk (preview = print = share = PDF) + Scan Barcode Kontinu (device fisik)

Tanggal rilis: 2026-08-17 · Varian: kelontong (7 varian lain menyusul)

## 📋 RINGKASAN

Versi ini merombak **seluruh sistem struk** menjadi **satu mesin render** —
semua tampilan struk (Pengaturan, Struk checkout, Riwayat Transaksi, share
WhatsApp, unduh PDF, Tes Cetak) kini digambar dari **kode yang sama**, jadi
apa yang terlihat di preview pasti sama persis dengan yang tercetak.

Sekaligus memperbaiki **scan barcode beruntun dengan device fisik (HID)**:
sebelumnya setelah scan sekali, scan barcode yang sama lagi harus tap kolom
cari dulu — sekarang bisa scan terus tanpa sentuh layar.

## 🔄 SATU MESIN STRUK (refactor menyeluruh)

Sebelumnya ada 4+ kode render struk terpisah (preview Pengaturan, preview
checkout, preview Riwayat, print, share) — makanya sering tidak match.
Sekarang:

- **`ReceiptConfig`** — SATU model semua pengaturan struk (kertas 58/80mm,
  font Standar/Ramping, header 12–48px + Tipis/Sedang/Tebal, logo + ukuran +
  posisi Kiri/Tengah/Kanan, header/footer teks, 4 toggle).
- **`ReceiptData`** — SATU model data transaksi (item, diskon, total, bayar,
  kembalian, kasir, pelanggan). Transaksi lama bisa di-print ulang pakai
  data lama + pengaturan TERBARU.
- **`ReceiptRenderer`** — SATU mesin yang menghasilkan 3 output dari data +
  pengaturan yang sama: **ESC/POS** (print), **teks** (share WA), **PDF**
  (unduh struk).
- **`ReceiptPreview`** — SATU widget preview yang dipakai di Pengaturan
  Struk, Struk checkout, dan Riwayat Transaksi.

Hasilnya: **preview = print = share WA = PDF** — tidak ada lagi perbedaan
antara yang dilihat di layar dan yang keluar di kertas.

## 🖼️ PENGATURAN STRUK — tampilan baru

- Bagian **PENGATURAN KERTAS** (58mm / 80mm) dan **JENIS FONT**
  (Standar / Ramping).
- Bagian **TAMPILAN HEADER**: slider ukuran 12–48px + Tipis/Sedang/Tebal.
- Bagian **BRANDING STRUK**: upload/ganti/hapus **logo** + slider ukuran
  1–100% + **posisi Kiri/Tengah/Kanan**; teks header struk; teks footer.
- Bagian **TAMPILKAN DI STRUK**: 4 toggle (logo, kasir, invoice, tanggal).
- **PREVIEW LIVE**: setiap ubahan langsung terlihat di preview tanpa perlu
  simpan (gambar logo, posisi, ukuran, header, footer, toggle semua realtime).

## 📄 UNDUH STRUK = PDF ASLI

Tombol "Unduh Struk" di Riwayat Transaksi & Struk checkout kini menghasilkan
**file PDF asli** (sebelumnya gambar / teks). Isi PDF persis sama dengan
preview dan print. Share WhatsApp juga memakai teks dari mesin yang sama —
format konsisten di mana-mana.

## 📷 SCAN BARCODE KONTINU (device fisik / HID)

**Masalah**: scanner barcode external (yang mengetik angka + Enter seperti
keyboard) hanya berfungsi sekali — untuk scan barcode yang SAMA lagi harus
tap kolom cari dulu.

**Perbaikan** (berlaku di **Kasir/POS**, **Catat Pembelian**, **Stok**, dan
**Produk**):

- Kolom cari barcode sekarang **tetap fokus** setelah scan → bisa scan
  barcode yang sama berulang kali **tanpa menyentuh layar sama sekali**.
- Fokus juga dikembalikan otomatis setelah scan lewat kamera / dialog
  timbangan / menambah item — alur kerja terus lancar.

## 🧪 TES

- 37 unit test lulus (6 baru untuk mesin struk: format item + diskon,
  summary sejajar, toggle OFF menghilangkan baris).
- `flutter analyze` 0 error.

## 🔧 Lain-lain

- Struk checkout & Riwayat Transaksi pakai lebar kertas sesuai pengaturan
  (58mm → ramping, 80mm → lebar) — tidak lagi hardcoded.
- Baris "Anda Hemat" dihapus dari struk (digantikan format ringkas
  `Disc. (-RpX)` pada summary) sesuai keputusan spesifikasi v2.2.29.
