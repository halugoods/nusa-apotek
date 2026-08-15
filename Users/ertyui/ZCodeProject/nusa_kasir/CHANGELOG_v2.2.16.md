# CHANGELOG v2.2.16+68 — Batch Perbaikan #10

Tanggal rilis: 2026-08-14 · Varian: kelontong (7 varian lain menyusul)

## ✨ Perbaikan & Penyempurnaan

### Stok Masuk / Keluar — Tombol Tambah ala POS
- Tombol `+` pada daftar produk kini berupa **pill "+ Tambah"** (persis tombol tambah di menu Kasir) — bukan lagi ikon extend kebawah.
- Setelah diklik, kartu tetap melebar ke bawah dan menampilkan `− [qty] +` yang **bisa diedit langsung** (ketik angka lewat keyboard layar maupun keyboard fisik) — lalu subtotal & tombol "Tambah Stok"/"Kurangi Stok" muncul.
- Pola yang sama diterapkan di **Catat Pembelian** dan **Menu Kasir (POS)**.

### Catat Pembelian — Qty Selalu Bisa Diedit
- Perbaikan: sebelumnya setelah klik `+` pada produk yang belum masuk keranjang tampil `− 0× +` yang terkunci. Sekarang produk otomatis masuk keranjang (qty 1) dan kolom qty langsung berupa kotak angka **editable**.
- Nama produk di list & grid dipotong rapi (truncate) supaya tidak meluber.

### Menu Kasir (POS) — Rasio Pintar + Margin Bawah Statis
- Grid produk kini dihitung otomatis dari lebar layar (LayoutBuilder) untuk **semua jumlah kolom** (2×2 maupun 3×3) — tombol "Tambah" tidak pernah meluber keluar kartu di HP panjang/lebar.
- **Margin bawah konsisten**: jarak tombol ke tepi bawah kartu selalu sama di semua ukuran HP.
- Kolom qty pada produk yang sudah masuk keranjang kini **editable** — bisa ketik jumlah langsung (bukan hanya tombol +/−).

### Pengaturan Struk — Header Benar-Benar Tercetak & Penuh
- **Perbaikan penting**: sebelumnya printer selalu mencetak nama toko sebagai header — teks header custom yang kamu isi TIDAK pernah tercetak. Sekarang header = **teks custom jika diisi**, fallback nama toko jika kosong.
- Ukuran header (slider) sekarang benar-benar memengaruhi hasil cetak — teks header **tidak lagi dibatasi** dan mencapai pinggir kertas seperti baris rincian (auto-fit per baris sesuai lebar kertas).
- Hasil cetak kini konsisten dengan preview di Pengaturan Struk.

### Riwayat Update — Changelog Lebih Detail
- Pratinjau menampilkan 4 baris pertama (sebelumnya 2 baris).
- Changelog lengkap kini di-render rapi: daftar bullet (`- `) tampil dengan titik •, judul bagian (`##`) ditebalkan — mudah dibaca pengguna awam.

### Toko Online — Layar Didesain Ulang (Wizard 2 Langkah)
- **Langkah 1 — Setup Alamat Toko** (paling atas, wajib): nama toko + slug (alamat website) dengan cek ketersediaan langsung + penjelasan awam.
- **Langkah 2 — Detail & Simpan**: logo, deskripsi, WhatsApp, jam buka, alamat + kartu produk (jumlah & sinkronkan) + toggle aktifkan + tombol **Simpan** (tanpa emoji).
- **Preview toko** dipindah ke paling bawah sendiri (link + Salin + Buka Website + tampilan live saat aktif) — hanya muncul setelah tersimpan.
- Status card bergradien & animasi denyut yang lebay dihapus — desain simpel mengikuti layar lain.

### Dashboard — Ikon Seragam & Akses Cabang
- Ikon lonceng, cabang, dan logout kini **hitam pekat** (putih di mode gelap) — seragam tanpa yang abu-abu.
- **Ganti cabang hanya untuk Owner & Manager** — role lain (Kasir/Gudang/Finance) tidak melihat ikon cabang; cabang mereka ditentukan saat login.

### Keuangan & Laporan
- **Keuangan**: ikon export diganti lebih tegas (solid) dengan latar bertinta warna utama — tidak flat.
- **Laporan**: tombol cepat diganti jadi **ikon bagikan + label "Bagikan"** (bukan "Export"), dan tinggi tombolnya disamakan dengan tombol "Export Laporan" supaya sejajar.

### Toko Online — Perbaikan Alur Rusak (Backend + App)
- **Toggle tidak lagi mati sendiri**: sebelumnya saat membuka ulang layar toko online, toggle selalu OFF meski sudah diaktifkan — karena server menolak membaca toko yang non-aktif. Sekarang server melayani baca toko apa adanya.
- **Sinkron produk tidak lagi "0 produk"**: sebelumnya sinkron mengirim data lalu server gagal karena tidak ada kunci unik pada tabel produk online — sekarang database punya unique index dan proses sinkron memakai insert bersih; jika gagal, app menampilkan pesan error (bukan sukses palsu).
- Semua label & notifikasi tanpa emoji.

### Foto Karyawan di Dashboard
- Perbaikan: foto karyawan di kartu statistik dashboard kadang tidak muncul setelah pindah device/restore. Sekarang jika file foto hilang, app otomatis **mengunduh ulang dari cloud** dan menampilkannya kembali (berlaku untuk kartu kasir aktif & kasir terakhir).
