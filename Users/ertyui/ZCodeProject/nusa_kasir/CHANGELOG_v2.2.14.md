# v2.2.14+66 — Batch Perbaikan Hasil Tes Kelontong

Perbaikan dari hasil tes user (kelontong). **Tanpa perubahan schema DB (tetap v40).**

## ✨ Perbaikan

### 1. Hint di semua form sheet
- **Produk**: hint di Nama Produk, SKU, Harga Beli, Harga Jual, Stok, Stok Minimum, semua field varian (nama/±harga/stok), harga grosir (min qty + harga), dan rename kategori.
- **Keuangan**: hint di 13 field — pengeluaran (keterangan/jumlah), kategori baru, gaji karyawan (periode/gaji/bonus/potongan), barang rusak (jumlah/alasan), pengeluaran rutin, dan kas (kategori/keterangan/jumlah/metode).
- **Karyawan**: hint di dialog nama role.

### 2. Stok Masuk / Keluar — sheet baru (search + scan + "+" expand)
- Masuk/Keluar stok sekarang **bottom sheet** dengan **search bar + scan barcode** di dalamnya.
- Tiap produk punya tombol **"+"** → ketuk untuk expand **- qty +** di baris itu.
- **Qty bisa diisi manual** (TextField angka), bukan sekadar badge — sama dengan pola Catat Pembelian.
- Kartu expanded: border aksen, stok saat ini, subtotal, tombol Tambah/Kurangi.

### 3. Keuangan — card status sejajar
- Label "Pengeluaran bln ini" tidak lagi "enter" ke bawah bikin card miring — label panjang wrap rapi 2 baris + ellipsis, semua card status sama tinggi & sejajar di HP sempit.

### 4. Catat Pembelian
- Switch Produk/Bahan lebih lebar dengan padding — teks tidak lagi meluber dari card.
- **Qty di stepper "- qty +" bisa diisi manual** (TextField angka) — bukan lagi teks "angka×" statis.

### 5. Toko Online — pesan error akurat
- Error "Gagal menyimpan. Cek koneksi internet." yang muncul padahal internet aman **dibedah**:
  - Fitur belum aktif di server (edge function 404) → *"Fitur online belum aktif di server. Hubungi admin NUSA."*
  - Server sibuk (5xx/timeout) → *"Server sedang sibuk. Coba beberapa saat lagi."* (dengan 1x retry otomatis)
  - Baru kalau benar-benar offline (SocketException) → *"Cek koneksi internet."*
- Perbaikan di service bersama → **berlaku di semua varian**.

### 6. Ukuran font struk — preview = print
- Slider font (Header/Rincian/Footer) di Pengaturan Struk hanya mengubah **preview**; hasil cetak butuh tombol **Simpan**.
- Tambah banner *"Preview berubah — tekan Simpan agar ukuran font tercetak."* supaya tidak bingung lagi kenapa cetak tidak berubah.
- Jalur cetak diverifikasi: semua bagian (header/rincian/footer) mengirim perintah ESC/POS `GS !` sesuai ukuran slider.

### 7. Menu Cabang — poles visual
- Hapus border kiri 4px tebal → kartu bersih ala menu lain.
- Nama cabang lebih besar & tebal (Plus Jakarta Sans 18 w800).
- Header sheet & tombol konsisten dengan menu lain.

## 🔧 Teknis
- Versi **2.2.14+66**, schema DB tetap **v40**.
- Bersihkan dead code (widget/import tak terpakai).
