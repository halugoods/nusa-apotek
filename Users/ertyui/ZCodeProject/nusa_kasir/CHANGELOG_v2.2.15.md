# CHANGELOG v2.2.15+67 — Batch Perbaikan #9

Tanggal rilis: 2026-08-14 · Varian: kelontong (7 varian lain menyusul)

## ✨ Perbaikan & Penyempurnaan

### Stok Masuk / Stok Keluar
- Tombol aksi cepat **Stok Masuk** dan **Stok Keluar** kini bersih tanpa panah bawah — tampil `[+] Stok Masuk` dan `[−] Stok Keluar`.
- Tombol `+` pada kartu produk sekarang mengembang menjadi `− qty +` (pola sama seperti filter POS) — nama produk otomatis terpotong rapi (truncate) supaya tidak meluber.
- Subtotal kini langsung diperbarui saat menekan `+`/`−` di kartu stok.
- Perlakuan yang sama diterapkan di **Catat Pembelian** (supplier) agar seragam dan mudah dipakai.

### Card & Teks Meluber
- **Menu Kasir (POS)**: grid produk kini menyesuaikan rasio layar HP (dinamis) — tombol "Tambah" tidak lagi meluber keluar kartu di HP tinggi/lebar untuk grid 2×2 maupun 3×3.
- **Menu Stok**: grid/list tidak lagi meluber; nama & kategori dipotong dengan ellipsis.
- **Kategori chips**: ikon pada chip kategori dihapus (kategori custom tidak lagi menampilkan ikon bulat aneh) — teks rapi dengan ellipsis.
- Pemeriksaan menyeluruh semua layar: teks terbungkus di dalam kartu tidak meluber atau mepet.

### Pengaturan Struk — Ukuran Header Benar-Benar Tercetak
- Nama toko pada header struk kini dibungkus per baris sesuai ukuran font yang dipilih (sebelumnya terpotong di printer saat ukuran besar).
- Jarak antar baris (feed) ditambahkan setelah header, item besar, dan footer besar — huruf besar tidak lagi bertumpuk sehingga tampak "kecil".
- Tombol **Tes Cetak** baru di Pengaturan Struk — cetak contoh ukuran header/item/footer sesuai slider saat itu, tanpa harus simpan dulu.

### Riwayat Update
- Panel riwayat terbuka **instan** (tanpa menunggu data) — loading ditampilkan di dalam panel.
- Menampilkan **semua versi**, bukan hanya update terbaru.
- Ketuk sebuah versi → changelog lengkap versi tersebut terbuka (accordion).

### Toko Online — Slug Custom & Validasi
- **Slug dibuat custom oleh user** (bukan otomatis dari nama toko), dengan penjelasan "Apa itu slug?" untuk pengguna awam.
- Alamat toko baru: `nusa-online.vercel.app/toko/{varian}/{slug}` — slug unik **per varian** (tidak tabrakan antar 8 varian).
- **Validasi otomatis**: saat mengetik slug, sistem memeriksa ketersediaan secara real-time — slug yang sudah dipakai toko lain ditolak (harus ganti).
- **Warna website mengikuti tema aplikasi** (warna utama/dark/soft dikirim ke server saat simpan).

### Cabang
- Kartu cabang lebar di beranda **dipindah ke ikon di header** (di samping lonceng) — lebih ergonomis, tampilan beranda lebih bersih. Pilihan cabang tetap lewat bottom sheet geser dari bawah.

### Keuangan
- Dropdown filter cabang kini **seragam dengan dropdown waktu** (ukuran, gaya, warna sama).
- Ikon export diganti ikon **download** yang lebih jelas.

### Laporan
- Tombol export kini **seragam** di semua tab (Penjualan, Laba Rugi, Pengeluaran): tombol utama "Export Laporan" + tombol pill "Export" dengan ikon download.
- Tab **Pengeluaran** sekarang punya tombol export sendiri (CSV/Excel/PDF lengkap) — sebelumnya tidak ada.
- Semua ikon "share" diganti ikon download yang lebih cocok untuk ekspor data.

---

## ⚙️ Backend & Website (nusa-online)

- Schema `store_settings` bertambah kolom: `slug`, `variant`, `theme_id`, `primary_color`, `dark_color`, `soft_color` (unik per variant+slug).
- Edge function `online-store`: aksi baru `check_slug`, validasi slug unik (HTTP 409 `slug_taken`), lookup publik `get_store_by_variant_slug`.
- Website dirancang ulang:
  - URL baru `/toko/{variant}/{slug}` dengan tema dinamis mengikuti warna toko dari aplikasi.
  - Kategori produk dinamis dari data asli (bukan daftar kaku).
  - Link lama `/toko/{slug}` tetap diarahkan otomatis ke format baru.

## 🔧 Lainnya
- Tidak ada perubahan schema database aplikasi (schemaVersion tetap 40).
