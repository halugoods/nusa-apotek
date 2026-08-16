# CHANGELOG v2.2.20+72 — Koreksi Batch #14

Tanggal rilis: 2026-08-14 · Varian: kelontong (7 varian lain menyusul)

## ✨ Koreksi & Perbaikan

### Pengaturan Struk — DIBUAT ULANG
- **Pilihan ukuran font kini UKURAN LITERAL 12 / 18 / 24 / 36** (label Kecil / Normal / Besar / Extra Besar) — bukan lagi slider perbesaran 1x–8x yang membingungkan. Kamu memilih "seberapa besar huruf" yang benar-benar dicetak.
- **Jumlah karakter per baris dihitung dari UKURAN HURUF**: lebar kertas (58/80 mm) ÷ ukuran huruf. Makin besar huruf → makin sedikit karakter per baris — mengikuti logika fisik kertas, bukan tebakan jumlah karakter per skala.
- **Preview struk memakai ukuran literal yang sama** dengan yang dicetak (sebelumnya preview pakai `6 + perbesaran` yang tidak cocok).
- **Tes Cetak Kalibrasi dicetak dalam ukuran 12/18/24/36** (bukan 1x–8x) untuk Font A & Font B — langsung terlihat di kertas ukuran mana yang printer-mu dukung.
- **"Maks Ukuran Printer"** kini pilihan 18pt / 24pt / 36pt (batas yang benar-benar tercetak) — bagian yang diatur lebih besar dicetak sebesar batas itu, tidak ada ukuran "sampah" yang menipu.

### Toko Online — upload gambar & diskon
- **Upload gambar produk TIDAK lagi gagal "login Google diperlukan" padahal sudah login** — penyebabnya policy Supabase Storage butuh sesi Auth yang tidak pernah dibuat app (login via Google Sign-In). Policy storage kini mengizinkan upload dari app, dan pesan error diubah agar tidak menyesatkan.
- **Diskon produk kini tampil di web toko online** — harga coret (harga asli dicoret + harga diskon) muncul di kartu produk jika produk punya diskon, sama seperti di aplikasi.

### Catat Pembelian (Supplier)
- **Keyboard tidak lagi muncul otomatis** saat membuka pilih supplier — kamu ketuk kolom cari hanya jika ingin mencari.
- **Status supplier yang dipilih kini TAMPAK JELAS** — setelah memilih, muncul badge "Supplier: (nama)" di bawah kolom pencarian + tombol "Ganti". Di dalam sheet, supplier yang sedang dipilih ditandai centang + label "Dipilih".

## 🐛 Perbaikan Teknis
- Policy Supabase Storage `nusa-images`: INSERT/UPDATE/DELETE kini untuk `anon + authenticated` (upload dari app); SELECT tetap publik (web baca). Backup policy dibersihkan dari duplikat.
- Kolom `original_price` ditambahkan di `online_products` + edge function `online-store` (action `sync_products`) meneruskan nilai harga asli untuk web.
