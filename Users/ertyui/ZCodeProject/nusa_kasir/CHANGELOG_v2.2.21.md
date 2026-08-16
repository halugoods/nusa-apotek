# CHANGELOG v2.2.21+73 — Struk Dibuat Ulang dari Nol

Tanggal rilis: 2026-08-16 · Varian: kelontong (7 varian lain menyusul)

## 🔥 Pengaturan Struk — DIBUAT ULANG DARI NOL (prioritas tertinggi)

Masalah lama: meskipun sudah memilih 4 ukuran (12/18/24/36), struk tetap keluar **2 ukuran saja** — baik di preview maupun cetak. Penyebabnya ada **pembatasan tersembunyi** ("Maks Ukuran Printer") yang memotong ukuran 24 & 36 menjadi 18 ketika disimpan. Sudah DIBUANG TOTAL.

- **TIDAK ADA lagi "Maks Ukuran Printer"** — fitur ini yang bikin ukuran besar diam-diam dikecilkan. Semua 4 ukuran (12 / 18 / 24 / 36) sekarang **selalu dicetak apa adanya** sesuai pilihan, di semua printer.
- **TIDAK ADA lagi font terpisah per bagian** (Header/Rincian/Footer masing-masing pilih Font A/B) — cukup **satu pilihan font Standar/Kompak** untuk seluruh struk. Pengaturan jauh lebih sederhana.
- **Preview = hasil cetak, dijamin**: preview di Pengaturan, di layar checkout, dan di riwayat transaksi memakai ukuran literal yang sama persis dengan yang dikirim ke printer. Apa yang kamu lihat = apa yang keluar.
- **Nilai pengaturan lama otomatis dihapus** saat kamu menekan Simpan — perangkat yang pernah menyimpan "Maks Ukuran Printer" atau font per-bagian di versi lama tidak akan terpengaruh lagi. Tidak perlu hapus data / instal ulang.

Pengaturan struk sekarang hanya 3 hal sederhana:
1. **Jenis Font** — Standar (Font A, paling aman) atau Kompak (Font B, huruf lebih ramping).
2. **Ukuran Header** — Kecil / Normal / Besar / Extra Besar.
3. **Ukuran Rincian & Footer** — Kecil / Normal / Besar / Extra Besar.

## 🛒 Toko Online — Harga Coret (diskon)

- **Harga diskon kini tampil dengan HARGA CORET di web toko online**: harga asli (sebelum diskon) dicoret, harga setelah diskon tampil mencolok — informatif dan konsisten dengan tampilan struk & daftar harga di aplikasi.
- **Alur data dipastikan sinkron dengan aplikasi**: `original_price` = harga jual asli produk (yang dipakai sebagai "Harga" di app saat ada diskon), `price` = harga efektif setelah diskon. Web membaca dua nilai ini dari cloud — tidak ada perhitungan ulang yang bisa beda hasil.
- **Sinkronisasi produk ke web sudah diperbarui**: produk baru yang di-sync dari aplikasi otomatis membawa `original_price`. Untuk produk yang sudah pernah di-sync sebelumnya, buka Toko Online → Sinkronkan Produk sekali lagi agar harga coret muncul (data lama belum menyimpan harga aslinya).

## 🐛 Perbaikan Teknis
- `printReceipt` & `printTest` ditulis ulang bersih: satu sumber ukuran (literal 12/18/24/36), tanpa lapisan pemotongan ukuran, tanpa perbagian font.
- Ketiga preview struk (Pengaturan, Checkout, Riwayat Transaksi) memakai kalkulasi ukuran yang sama → tidak mungkin preview berbeda dari cetak.
- Nilai basi `nusa_receipt_max_mag` dan `nusa_receipt_font_*_type` dihapus otomatis saat Simpan Pengaturan Struk.
