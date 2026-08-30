# NUSA v2.2.57+121 — Google Sheets Terpusat, Fix Dobel Diskon, Toko Online Sinkron

Versi utama tetap **2.2.57** — hanya build number naik ke **+121**. Berlaku untuk **semua 8 varian**.

## 📊 Google Sheets Terpusat (Company API)
- **App tidak perlu login Google lagi.** Spreadsheet dibuat & diisi oleh server NUSA (service account) — app cukup kirim data, server yang menulis ke Google Sheets.
- **Link kontinu:** 1 spreadsheet per user, dibuat sekali, dipakai terus untuk semua pembukuan. Share ke email Google user (writer) → otomatis muncul di Drive mereka, realtime.
- **Dashboard nusa-online (admin):** tab **Spreadsheet** — paste kredensial service account (sekali setup), test koneksi, dan **daftar semua akun user yang pakai fitur** + tombol buka langsung link spreadsheet mereka.
- **Template Laporan non-flat:** title bar, KPI cards berwarna (Omzet / Transaksi / Rata-rata), section Laba Rugi zebra, ranking Top 5 Produk — bukan tabel polos lagi.
- Fitur ini butuh admin mengaktifkan dulu di dashboard (sebelum aktif, app menampilkan "Fitur spreadsheet belum aktif — hubungi admin").

## 🔧 Fix Kritis: Dobel Diskon di Kasir
- **Sebelumnya:** produk berdiskon dihitung diskonnya 2x (mis. harga 87.500 diskon 37.500 jadi malah 12.500 di checkout).
- **Sekarang:** diskon produk dihitung sekali saja (sudah tercermin di harga), hanya diskon manual per item yang ditambahkan. Subtotal, checkout, dan struk semua konsisten. 5 unit test baru.

## 🤖 AI Assistant — Perbaikan Tool Calling & Riwayat Local
- Bubble streaming tidak beku lagi di token pertama.
- Tool call multi-step tidak tercampur; hanya tool call terakhir yang dieksekusi, hasil dipotong 2000 karakter supaya AI tidak mengarang angka.
- Riwayat chat kini **local-only** (tersimpan di perangkat, tidak dikirim ke cloud).

## 🛒 Kasir — Bottom Sheet Item Pakai Checkbox
- Klik item di keranjang: opsi (ubah harga, diskon, catatan, tampil di struk) kini muncul sebagai **checkbox** — form hanya tampil saat opsi diaktifkan.

## 🌐 Toko Online — Status Cloud + Sinkron Wrap-Card
- Header menampilkan **status cloud sync** (tersambung/tersinkronisasi).
- Tombol "Sinkronkan produk online" jadi **wrap-card**; abu-abu & nonaktif saat sudah sinkron.
- Info toko **auto-fill dari Data Toko** (dua arah ke cloud), rename tidak menumpuk data.

## 📦 Download
APK per varian ada di masing-masing repo release (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis).
