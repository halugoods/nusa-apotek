# Changelog v2.2.47

## Fitur Baru & Perbaikan

### 🔐 Pinpad Dialog — Popup Dialog (Revisi)
- Pinpad dialog sekarang **popup dialog** (bukan fullscreen), animasi pop-up dari bawah
- Hint barcode & NFC: **vertikal** (stacked atas-bawah) biar estetik
- NFC & barcode hint selalu tampil di semua entry pinpad
- Hapus fitur "Ingat PIN selama 8 jam" dari semua dialog pinpad

### 🃏 Flip Card Stats — Revisi
- Tombol **Absen Masuk & Absen Keluar**: warna putih (tidak nabrak card gradient)
- Hapus tombol **"Ganti Pengguna"** dari sisi belakang (header logout sudah ada)
- Icon flip: ganti dari `flip_to_back/flip_to_front` → **`flip`** (persegi, lebih representatif)
- Avatar profil: **72px** (dari 60px), sejajar dengan nama + role
- Stats ikon: kotak corner (dari bulat), mengikuti design system

### 🎬 Tutorial — Preview Thumbnail YouTube
- Tutorial video dipindahkan ke section **BANTUAN** (bawah "Bantuan & Masukan")
- Tampil **preview thumbnail YouTube** (hqdefault.jpg) + overlay play button
- Tap → buka langsung di YouTube

### 👥 Menu Karyawan — Barcode Scanner
- Search bar: **icon barcode scanner** di sisi kanan (prefix search + scanner)
- Scan barcode karyawan → otomatis populate search field
- HID external scanner (keyboard mode) **auto-capture** ke search field

### 👥 Menu Pelanggan — Barcode Scanner
- Search bar: **icon barcode scanner** di sisi kanan
- Scan barcode member → otomatis populate search field
- HID external scanner **auto-capture** ke search field

### 💳 Pembayaran — EDC "Segera Hadir"
- Metode **EDC / Kartu** dihapus dari checkout (fitur belum terintegrasi hardware)
- Di halaman **Pengaturan Pembayaran**: card info "Segera Hadir" untuk EDC/Kartu Debit-Kredit

### 🗑️ Menu Produk — Bersihin UI (dari v2.2.47 awal)
- Hapus tombol **Impor/Ekspor** dari semua tab (Produk, Kategori, Bahan Baku)
- Filter grid/list geser ke kanan, lebih jauh dari tab switch

### ⚙️ Tab Bahan Baku — Perbaikan (dari v2.2.47 awal)
- Tombol "Tambah Satuan" → **icon gear** (Icons.settings)
- Dialog rename/delete → **bottom sheet** mengikuti design system

### 📊 Barcode Toggle — Konsisten (dari v2.2.47 awal)
- Pelanggan & Karyawan barcode toggle: padding header 16/12, Switch SizedBox 24×44, Container surface2, font 13

### 📦 Opname Stok — Card Redesain (dari v2.2.47 awal)
- Card produk: thumbnail 36px + background surface2/inputFill + padding 12/10/12/10 + font 13/11

### 📝 Pelanggan Form — Keyboard-Safe (dari v2.2.47 awal)
- Bottom sheet tambah pelanggan: scrollable (Expanded + SingleChildScrollView)

### 📷 Foto Produk — Restore Setelah Login (dari v2.2.47 awal)
- Foto produk otomatis terestore dari database setelah login ulang
- Fallback chain: File(imagePath) → Base64(imageBase64) → placeholder

## Teknis
- `flutter analyze`: **0 errors** ✅
- Core design system (`NusaConfig`, NusaButton, NusaInput, NusaCard): **UTUH**
- Build: 8 varian APK (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis)
