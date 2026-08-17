# CHANGELOG v2.2.30+82 — Koreksi Struk Terakhir (6 poin) + Sub-header Alamat

Tanggal rilis: 2026-08-17 · Varian: kelontong (7 varian lain menyusul)

## 📋 RINGKASAN

Putaran koreksi struk ini menuntaskan **6 poin backlog** yang tersisa dari
v2.2.29, termasuk pembaruan skema database (41) untuk **sub-header alamat
toko** yang dicetak di bawah nama toko. Ini adalah **test terakhir untuk
sistem struk** — setelah ini 7 varian lain menyusul dengan state yang sama.

## 🔧 6 KOREKSI STRUK

1. **Metode bayar tidak terpotong lagi** — keterangan `Bayar (Tunai/QRIS/
   Transfer/EDC)` sebelumnya terpotong di kertas 58mm (misalnya "Bayar (EDC"
   tanpa kurung tutup). Sekarang ringkas: `Bayar: EDC` — metode penuh tetap
   tampil, tidak ada yang hilang.

2. **Sub-header Alamat (fitur baru)** — field baru **Sub-header** di
   Pengaturan Struk (di antara Header Struk dan Footer Struk), biasanya untuk
   alamat toko. Dicetak sebagai baris teks di bawah header/nama toko,
   sebelum nomor invoice & tanggal. Bisa 2 baris.

3. **Kasir sejajar di tengah** — baris `Kasir: …` kini center, sama
   posisinya dengan nomor invoice dan tanggal (sebelumnya rata kiri).

4. **Footer = isi USER saja** — teks "Terima Kasih!" dan nama toko paling
   bawah yang di-hardcode dihapus. Footer struk sekarang **murni** isi kolom
   Footer Struk di pengaturan — kosong berarti tidak ada baris apa pun.

5. **Logo tidak membesar saat dicetak** — jika file logo ukurannya kecil
   (mis. 50px), preview sebelumnya membesarkannya (upscale) tapi printer
   termal tetap mencetak ukuran asli — preview ≠ print. Sekarang preview
   dibatasi ke ukuran asli logo, jadi **persen = ukuran asli**, tidak
   menambah ukuran real saat dicetak.

6. **Header Tipis/Sedang/Tebal lebih tegas** — ketebalan font header
   dinaikkan: **Tipis** kini w200 (lebih ringan) dan **Tebal** kini w800
   (jauh lebih tebal) — perbedaan antar mode sekarang terlihat jelas.

## 🧪 TES

- 41 unit test lulus (4 baru: sub-header dirender, footer = isi user saja,
  label bayar ringkas tidak terpotong, + penyesuaian test summary).
- `flutter analyze` 0 error.

## 🗄️ DATABASE

- Skema **40 → 41**: kolom baru `receiptSubHeader` di tabel Settings
  (otomatis dimigrasi saat upgrade — tidak perlu uninstall).
