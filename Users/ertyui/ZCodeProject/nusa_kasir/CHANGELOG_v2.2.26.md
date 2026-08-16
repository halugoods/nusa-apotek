# CHANGELOG v2.2.26+78 — Struk Balik ke Versi Lama yang Aktual (Teks, Bukan Gambar)

Tanggal rilis: 2026-08-16 · Varian: kelontong (7 varian lain menyusul)

## 🧾 Struk Dicetak ULANG sebagai Teks ESC/POS (Cepat) — Bukan Gambar

Versi 2.2.24–2.2.25 mengubah struk menjadi **format gambar (bit-image)**.
Hasilnya tidak sesuai yang diharapkan:

- **Print lama** — setiap struk harus di-render jadi PNG dulu, lalu dikirim
  sebagai bit-image → lebih lambat.
- **Preview tidak aktual** — yang tampil di layar (slider persen) tidak
  cocok dengan hasil cetak → struk jadi "tidak sesuai / goblok".
- Ukuran header pakai **persen (1-100%)** — membingungkan dan tidak
  mencerminkan ukuran huruf sebenarnya di atas kertas.

**Versi ini mengembalikan semuanya ke sistem lama yang sudah terbukti bagus
(seperti v2.2.23)**, plus perbaikan kecil:

### ✅ Yang dikembalikan

- **Print struk = teks ESC/POS biasa (cepat)**: header, rincian item, dan
  footer semuanya teks — bukan lagi gambar. Printer murah (VSC, dll.)
  mencetak cepat dan bersih.
- **Preview struk = komponen asli (benar-benar aktual)**: yang kamu lihat
  di layar (Pengaturan Struk, sheet struk, bagikan struk dari Riwayat)
  adalah widget asli yang sama persis dengan hasil cetak.
- **Ukuran header = ukuran huruf LITERAL (px), bukan persen**: pilihan
  12 / 15 / 18 / 24 / 36 px (label Kecil/Sedang/Normal/Besar/Extra Besar).
  Header saja yang bisa diatur besar-kecilnya.
- **Logo = ukuran statis (60% lebar kertas)**: logo dicetak sebagai
  bit-image dengan ukuran tetap seperti yang pernah diatur — tidak ikut
  diubah oleh pengaturan struk.
- **Tes Cetak Kalibrasi** kembali mencetak seluruh 5 ukuran huruf
  (12/15/18/24/36 px) sekaligus dengan jumlah karakter per baris, supaya
  kamu tinggal pilih ukuran yang paling pas.

### 🧯 Pembenahan kecil

- Printer settings kembali menyinkronkan pengaturan **buka laci kasir**
  (cash drawer) — sebelumnya tersimpan tetapi tidak ikut dikirim ke
  printer.
- File renderer struk (sisa eksperimen gambar) dihapus — tidak dipakai lagi.
- Pengaturan struk tidak lagi di-reset paksa saat upgrade.

## ⚠️ Catatan

- Pengaturan struk dari versi 2.2.24–2.2.25 (persen) tidak dipakai lagi —
  di versi ini semua dikembalikan ke ukuran liter 12–36 px.
