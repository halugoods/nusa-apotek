# NUSA Kasir v2.2.55+108

## 🔔 Suara Notifikasi Custom (BARU)
- **Dashboard web → tab Notifikasi**: owner bisa upload file audio sendiri (.wav/.mp3/.ogg/.m4a/.aac, maks 2 MB) untuk 8 slot suara:
  - Transaksi Sukses, Error, Scan Barcode, Keranjang, Pesanan Online, Presensi, Stok Menipis, dan Dering Panggil Karyawan
- Preview langsung di dashboard (Putar/Stop), tombol Reset untuk kembali ke suara bawaan
- Perangkat teraktivasi otomatis mengunduh suara custom di background saat aplikasi dibuka — tanpa update app

## ☁️ Backup Cloud Realtime + Indikator Status
- **Auto-sync dipercepat 6 detik → ~1.2 detik** setelah perubahan data (near-realtime)
- Perubahan yang terjadi SAAT upload berjalan tidak lagi hilang — otomatis masuk antrean upload berikutnya
- **Chip status cloud di header dashboard**: ikon awan menunjukkan kondisi sinkronisasi (mengunggah / tersinkron / gagal) + waktu backup terakhir. Tap chip untuk penjelasan — sekarang kamu tahu kapan data aman dihapus/reset

## 🛍️ Menu Produk & Layanan Diseragamkan
- Search bar menu Produk diganti komponen standar menu Kasir (pill, bayangan fokus, tombol scanner)
- Tab **Layanan** (varian jasa) sekarang memakai pipeline yang sama persis dengan tab Produk: search bar tunggal (tidak dobel lagi), filter status, urutkan, toggle grid/list, kartu dengan foto produk/layanan
- Form tambah/edit dari tab Layanan otomatis mode layanan

## 📊 Laporan & Transaksi
- Dropdown filter karyawan di menu Laporan dan Transaksi (semua varian) diubah jadi kartu full-width yang rapi — tidak lagi dropdown kecil mepet

## 🧾 Checkout Cerdas Varian Jasa
- Kartu booking/appointment di pembayaran hanya muncul jika keranjang berisi layanan. Keranjang produk saja → pembayaran bersih tanpa opsi booking

## 👥 Karyawan
- Toggle "Staf Layanan (stylist/capster)" hanya tampil di varian Salon

## 🔧 Perbaikan
- Kasus "produk/karyawan hilang setelah hapus data & login ulang": akar masalahnya sinkronisasi yang lambat dan gagal diam-diam — kini teratasi oleh auto-sync near-realtime + chip status cloud di atas
