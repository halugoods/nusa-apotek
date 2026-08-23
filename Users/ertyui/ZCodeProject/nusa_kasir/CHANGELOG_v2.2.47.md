# Changelog v2.2.47

## Fitur Baru & Perbaikan

### 🔐 Pinpad Dialog — Redesain Fullscreen
- Pinpad dialog (presensi/dashboard/settings/transactions) sekarang **persis sama** dengan pinpad login: fullscreen card, lock icon 72px gradient + shadow, card radius 20, title "Masuk" font 20
- Hint barcode & NFC: **vertikal** (stacked atas-bawah) biar estetik, sebelumnya horizontal terlalu sempit
- Hapus fitur "Ingat PIN selama 8 jam" dari semua dialog pinpad

### 🃏 Flip Card Stats — Redesain
- **Depan**: foto profil + nama/role/jam hadir/cabang + flip icon di kanan + 3 KPI (PENJUALAN, TRANSAKSI, JAM SHIFT)
- **Belakang non-owner** (Kasir/Manager): 2 tombol besar quick-action **Absen Masuk** & **Absen Keluar**
- **Belakang Owner**: LABA PENJUALAN (hero stat) + Penjualan + Transaksi + Selisih Laci + pending alert + tombol Hubungi Karyawan

### 📷 Foto Produk — Restore Setelah Login
- Foto produk sekarang **otomatis terestore** dari database setelah login ulang
- Fallback chain: File(imagePath) → Base64(imageBase64) → placeholder
- Fix regression: foto produk tidak muncul setelah logout/login

### 🗑️ Menu Produk — Bersihin UI
- Hapus tombol **Impor/Ekspor** dari semua tab (Produk, Kategori, Bahan Baku)
- Filter grid/list geser ke kanan, lebih jauh dari tab switch

### ⚙️ Tab Bahan Baku — Perbaikan
- Tombol "Tambah Satuan" → **icon gear** (Icons.settings)
- Dialog rename/delete → **bottom sheet** mengikuti design system

### 📊 Barcode Toggle — Konsisten
- Pelanggan & Karyawan barcode toggle: padding header 16/12, Switch SizedBox 24×44 tanpa FittedBox, Container wrapper dengan background surface2, font 13

### 📦 Opname Stok — Card Redesain
- Card produk di opname: thumbnail 36px + background surface2/inputFill + padding 12/10/12/10 + font 13/11 — copas desain dari stok masuk/keluar

### 📝 Pelanggan Form — Keyboard-Safe
- Bottom sheet tambah pelanggan: scrollable (Expanded + SingleChildScrollView) agar tidak terpotong saat keyboard muncul

### 🎬 Tutorial Video — Settings
- Menu baru **"Tutorial"** di section TOKO (Pengaturan) → link YouTube video panduan tambah produk
- URL: https://youtube.com/shorts/ElvYpqUIRpE

## Teknis
- `flutter analyze`: **0 errors** ✅
- Core design system (`NusaConfig`, NusaButton, NusaInput, NusaCard): **UTUH** — tidak ada perubahan
- Build: 8 varian APK berhasil (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis)
