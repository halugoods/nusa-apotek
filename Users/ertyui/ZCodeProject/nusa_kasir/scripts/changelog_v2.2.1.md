# NUSA v2.2.1+53 — Changelog

## 🐛 Perbaikan Bug

1. **Tombol "Simpan Produk" kini selalu merespons** — sebelumnya saat
   menyimpan produk baru, tombol bisa diam saja tanpa pesan. Sekarang tombol
   menampilkan status **"Menyimpan…"** saat proses berjalan, dan muncul
   notifikasi sukses/gagal. Kalau gagal (mis. database bermasalah), muncul
   pesan "Gagal menyimpan produk" dan data tidak hilang.

2. **Teks input kini terbaca di mode gelap** — sebelumnya warna teks di
   kolom isian (nama produk, harga, dll.) hitam di latar gelap sehingga
   tidak terlihat. Sekarang teks menyesuaikan tema: **putih di mode gelap**,
   hitam di mode terang.

## ✨ Peningkatan

3. **Diskon produk: Persen (%) atau Nominal (Rp)** — di form produk, kolom
   diskon kini punya pilihan **"Persen (%)"** dan **"Nominal (Rp)"**.
   Mau potong langsung mis. **Rp 10.000** tanpa hitung persen? Pilih
   "Nominal (Rp)" dan ketik angkanya. Harga setelah diskon ditampilkan
   langsung di bawah kolom. Berlaku di kasir, daftar produk, dan struk.

## 🔧 Teknis

- Ekspor/Impor CSV produk: format baru menyertakan **Tipe Diskon**; file CSV
  lama tetap bisa diimpor (dideteksi otomatis dari baris header).
- Versi database naik ke skema 35 (upgrade otomatis, data lama aman).

## Cara Pasang

- Buka aplikasi → lonceng 🔔 di dashboard → **Download & Update**, atau
  unduh APK terbaru dari halaman rilis GitHub.
