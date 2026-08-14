# NUSA Kasir v2.2.12+64 — Paket Besar: Stok, Pembelian ala POS, Laporan, dan Lainnya

> Rilis terbesar sejauh ini — **12 area** sekaligus: stok lebih pintar, catat pembelian
> kini seperti kasir POS, struk lebih hemat, laporan lebih ringkas, plus tutorial &
> riwayat update. Semua 8 varian (kelontong, FnB, laundry, bengkel, salon, apotek,
> fotocopy, servis) naik ke versi yang sama.

## 🛡️ Kasir — Cegah Jual Stok Habis
- Produk dengan **stok 0 tidak bisa masuk keranjang** — muncul peringatan langsung, baik dari grid, daftar, hasil cari, maupun scan barcode.
- Jumlah item **dibatasi sisa stok**: tidak bisa menaikkan qty melebihi stok tersedia.

## 🧾 Struk Lebih Hemat & Rapi
- Rincian item lebih ringkas: **qty × harga + subtotal dalam 1 baris** (item berdiskon: potongan ikut di baris yang sama) — struk lebih pendek, kertas hemat.
- Baris **"Anda hemat Rp …"** tepat di bawah TOTAL: total potongan transaksi langsung terlihat.
- **Ukuran font struk bisa diatur dengan slider** (1–8) per bagian: Header, Rincian, Footer — preview langsung menyesuaikan, hasil cetak match preview.

## 🛒 Catat Pembelian — Mode POS (HP & Tablet)
- **Layout ala kasir**: di HP, pencarian + scan di atas dan keranjang di bawah; di tablet/landscape, katalog produk di kiri dan keranjang tetap di kanan.
- **Gambar produk** tampil di katalog & pencarian pembelian.
- **"Tambah Produk" langsung dari catat pembelian** — produk baru otomatis masuk keranjang setelah disimpan.
- **Catat supplier di form produk** (toggle ON/OFF). Dibuka dari catat pembelian → supplier otomatis terisi.
- **Biaya tambahan** (ongkir, packing, stiker) di keranjang pembelian: dibagi rata per unit ke harga modal → HPP lebih akurat.
- **Supplier baru bisa dibuat langsung** dari catat pembelian.

## 📦 Stok — Filter & Tautan Cepat
- Filter **Stok Menipis / Stok Habis** (switch) + tampilan **grid/list**.
- Kartu stok menipis/habis punya tombol **"Beli"** → langsung buka catat pembelian ke supplier produk (produk tanpa supplier diarahkan set supplier dulu).

## 🧮 Keuangan & Laporan
- **Laporan lebih ringkas**: setiap tab mulai dari kartu ringkasan + 1 grafik utama; best seller, kategori, dan metode bayar dibuka lewat **"Lihat Detail"**.
- **Keuangan**: setiap tab punya label kecil (bulan ini / gaji / buang / langganan / kas) + kartu ringkasan yang **menyesuaikan tab aktif**.

## 🎓 Tutorial & Riwayat Update
- Menu **Tutorial** di Pengaturan → Bantuan: panduan cara pakai tiap menu (disesuaikan varian).
- Menu **Cek Update** diganti **Riwayat Update**: daftar versi & perubahan terbaru (dari GitHub, offline → tampil versi lokal).

## 🖥️ Lainnya
- **Pesanan Online**: tab menu bisa digeser (scrollable) tanpa memotong status.
- Notifikasi update tersedia langsung muncul di menu Pengaturan (tanpa popup mendadak).

## Cara tes
1. **Kasir**: scan/pilih produk stok 0 → muncul peringatan, tidak masuk keranjang. Tambah qty melebihi stok → dibatasi.
2. **Struk**: checkout beberapa produk → preview: qty×harga + subtotal 1 baris, "Anda hemat" di bawah total. Atur slider font di Pengaturan → Printer.
3. **Pembelian**: buka Catat Pembelian → pilih supplier → scan produk → tambah biaya ongkir → Simpan. Cek HPP produk = harga beli + biaya/unit.
4. **Stok**: filter Stok Menipis/Habis → tombol Beli → langsung catat pembelian dengan supplier terpilih.
5. **Pengaturan**: Bantuan → Tutorial. Menu Riwayat Update → daftar versi.
