## v1.7.2-dev (Build 25)

### 🔧 PRINT FIX — Semua jalur cetak sekarang cek permission Bluetooth
- Tambah `ReceiptPrinter.ensureBluetoothReady()` — handles Android 12+ runtime BT permissions + Bluetooth state
- Fix di semua jalur: auto-print, manual print, kitchen print, split bill, test print, reprint
- Sebelumnya: semua jalur cetak gagal diam-diam karena permission gak pernah dicek

### 🎨 MEJA GRID — Warna blok aja, tanpa centang ijo
- Hapus icon status + teks status di grid cells
- Border + shadow pakai warna status (hijau Kosong, kuning Dipesan, abu Tutup)
- Tampilan lebih bersih, cukup blok warna untuk indikasi

### 🔀 CART / CHECKOUT UNIFICATION
- Semua field checkout SEKARANG ada di cart panel POS — gak ada lagi duplikasi
- Customer picker dialog (bukan cuma phone lookup)
- Promo apply/clear dengan validasi database
- Manual discount + points redemption
- Cash input + denominasi chips + kembalian
- QRIS display + Transfer bank info
- Bayar langsung dari cart panel — gak navigasi ke screen terpisah
- Receipt tetap muncul sebagai dialog
- Split Bill tetap ada di cart panel

### 📋 TABLE SELECTOR — Dropdown premium
- Ganti horizontal chips jadi dropdown button rounded dengan shadow
- Tap untuk pilih meja dari popup menu
- Setiap item: icon + nama meja + badge kapasitas + centang active

### 📦 Dev APK
- Dibuild dengan `--dart-define=NUSA_DEV=true` — variant picker work
- Database default FnB (produk Makanan/Minuman/Snack)
