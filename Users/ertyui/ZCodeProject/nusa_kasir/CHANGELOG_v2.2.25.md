# CHANGELOG v2.2.25+77 — Struk Hybrid: Print CEPAT + Preview Real

Tanggal rilis: 2026-08-17 · Varian: kelontong (7 varian lain menyusul)

## 🖨️ STRUK HYBRID — Header & Logo Tetap Gambar, Rincian & Footer Teks

**Masalah v2.2.24 (bit-image penuh)**: seluruh struk dicetak sebagai gambar
(bit-image ESC \*) — memang semua ukuran tercetak, tapi **print jadi
LAMA** karena printer harus menggambar banyak piksel. Preview gambar juga
terasa kurang "real" dibanding widget struk dulu.

**Solusi sekarang (hybrid — gabungan keduanya)**:

- **Header + Logo** → tetap dicetak sebagai **gambar (bit-image)**, karena
  di sanalah ukuran besar/logo dibutuhkan. Ukuran diatur **persen 1–100%**
  dari lebar kertas.
- **Rincian + TOTAL + Footer** → kembali dicetak sebagai **teks ESC/POS
  biasa** → **print jauh lebih cepat**. Mode **Kecil (×1) / Besar (×2)**
  yang PASTI tercetak di semua printer (termal murah pun andal di ×1/×2).
- **Preview struk = widget asli lagi** (seperti dulu yang user suka —
  lebih real), meniru persis hasil print: logo & header mengikuti persen,
  rincian & footer mengikuti mode Kecil/Besar.
- **Bagikan/Unduh struk (WhatsApp/PDF)** tetap pakai gambar penuh satu
  renderer — identik dengan struk kertas.

### Apa yang berubah:

- Pengaturan Struk → Header pakai **slider persen 1–100%** (bukan 12–48px).
- Pengaturan Struk → Rincian & Footer pakai **pilihan Kecil (×1) / Besar
  (×2)** — tombol pilihan, bukan slider.
- **Tes Cetak Kalibrasi diperbaiki**: sekarang benar-benar mencetak
  **header sebagai gambar** sesuai persen, lalu **baris rincian Kecil dan
  Besar + footer Kecil dan Besar** — langsung terlihat di kertas ukuran
  mana yang tercetak benar.
- Preview di Pengaturan Struk, lembar struk setelah checkout, dan Bagikan
  Struk (riwayat transaksi) semuanya kembali ke **widget struk real** yang
  meniru hasil print.
- Pengaturan struk **di-reset otomatis 1×** saat upgrade ke versi ini ke
  pengaturan baru (Header 100%, Rincian Kecil, Footer Kecil, Logo 60%).

### Cara pakai:

1. Pengaturan → Struk → atur **Header** (persen) + **Rincian/Footer**
   (Kecil/Besar) + **Logo** (persen).
2. Tekan **Tes Cetak Kalibrasi** — cek ukuran header gambar + baris
   Kecil/Besar di kertas.
3. Cetak struk asli — **lebih cepat dari v2.2.24**, header tetap besar
   sesuai persen, rincian & footer sesuai mode yang dipilih.
