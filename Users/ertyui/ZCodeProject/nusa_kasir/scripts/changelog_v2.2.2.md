# NUSA v2.2.2+54 — Changelog

## ✨ Peningkatan

1. **Harga Modal pada Item Manual** — saat menambah **Item Manual**
   (transaksi di luar menu produk, tombol "+" di kasir), kini ada kolom
   **"Harga Modal (Rp)"** (opsional). Cocok untuk biaya dadakan seperti
   *packaging* ekstra, ongkos bensin, atau bahan baku tambahan (lem, dll.).
   - Terdapat pratinjau **laba bersih per item** (Harga Jual − Harga Modal)
     langsung di bawah kolom, biar penjual tahu untungnya sebelum ditambah.
   - Harga modal disimpan di transaksi dan ikut dihitung dalam **Laporan
     Laba Rugi (HPP)** — laba kotor/bersih di dashboard jadi lebih presisi.

## 🔧 Teknis

- Item manual kini menyimpan `costPrice` di data transaksi; tanpa diisi,
  perilaku sama seperti sebelumnya (tidak menambah HPP).
- Tidak ada perubahan skema database — data lama aman, versi tetap skema 35.

## Cara Pasang

- Buka aplikasi → lonceng 🔔 di dashboard → **Download & Update**, atau
  unduh APK terbaru dari halaman rilis GitHub.
