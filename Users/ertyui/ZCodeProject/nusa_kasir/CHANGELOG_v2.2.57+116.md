# NUSA v2.2.57+116 — Cetak Label: Preview per-Jalur + Ukuran Font + Perbaikan UI

Versi utama tetap **2.2.57** — hanya build number naik ke **+116**. Berlaku untuk **semua 8 varian**.

## 🏷 Cetak Label Barcode — Preview Per-Jalur + Konfigurasi Ukuran Font
- **Preview muncul saat klik jalur cetak** (bukan preview generik sekali di tengah):
  - **Thermal Label (TSPL)** → preview bitmap **203 DPI** — persis yang dikirim ke printer label (Rongta/HPRT/Godex/BluePrint).
  - **Thermal Struk 58mm** → preview di atas **visual kertas struk** (label 40mm ≈ 69% lebar kertas, ada garis potong).
  - **PDF A4** → preview **lembar A4 sungguhan** (grid 4×8 label, margin 8mm, gap 4mm — layout SAMA dengan PDF hasil cetak), isi label dirender barcode/nama/harga asli.
- **Konfigurasi ukuran font** (baru): slider **Nama Produk** & **Harga** (1.0×–3.0×) — user bisa sesuaikan besar tulisan sendiri. Berlaku ke **SEMUA jalur cetak** (TSPL / struk / PDF) supaya preview = hasil cetak. Tersimpan otomatis di perangkat.
- **Tombol Cetak di dalam preview** — setiap jalur punya tombol cetaknya sendiri:
  - TSPL / Struk → langsung cetak ke printer Bluetooth tersimpan.
  - PDF A4 → buka PDF → print / simpan lewat share sheet Android (printer umum).

## 🖼 Perbaikan: Gambar Produk di Grid (2×2 dan 3+) Tidak Menciut Lagi
- Pada v2.2.57+115, gambar produk di grid ikut mengecil (dibungkus `Expanded`) supaya tombol edit/hapus tidak meluber keluar card.
- **Konsekuensi yang tidak diinginkan:** gambar produk jadi menciut — terlihat tidak proporsional.
- **Perbaikan:** ukuran gambar dikembalikan seperti semula (kotak penuh selebar card), dan **sel grid dibuat sedikit lebih tinggi** supaya konten di bawahnya (nama 2 baris, kategori, kode barcode, harga, tombol aksi) tetap muat.
- Hasil: gambar produk besar dan proporsional lagi, tombol edit/hapus tetap di dalam card (tidak meluber).

## 📏 Header Dashboard — Jarak Ikon 4px
- Jarak antar ikon di header dashboard dikurangi dari **8px → 4px** (sebelumnya terlalu renggang). Ukuran ikon tetap 44×44 (tap target nyaman).

## ☁️ Perbaikan Server: Setup Toko Online Tidak Error "Server Sibuk" Lagi
- **Bug:** user (tanpa login Google) saat setup toko online — input slug lalu klik Lanjut → muncul error **"server sibuk"**.
- **Penyebab:** edge function `upsert_store` hanya mencari row lama (by store_id) saat user_id terisi. Tanpa login Google, row lama tidak ketemu → jatuh ke INSERT yang bentrok → error 500.
- **Perbaikan:** row lama **selalu** dicari by store_id (walau tanpa user_id) → UPDATE berhasil.
- **Status:** sudah di-deploy ke server — **tidak perlu update app** untuk perbaikan ini (langsung aktif).

## 📦 Download
APK per varian ada di masing-masing repo release (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis).
