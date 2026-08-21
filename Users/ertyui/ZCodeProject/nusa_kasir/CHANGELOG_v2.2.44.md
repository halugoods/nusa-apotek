# CHANGELOG v2.2.44+97 — Batch Besar: Lisensi End-to-End + Perbaikan App + Tab Layanan + Satuan + Barcode Karyawan

Tanggal rilis: 2026-08-21 · Varian: **8 varian** (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis)

---

## 🛡️ BATCH 2 — Sistem Lisensi End-to-End (SEMUA varian)

### L1. Auto-revoke + tier fix '1month' (server)
- **Cron auto-revoke**: edge function `license-cron` (deploy per jam) menandai lisensi `expires_at < now()` dari status `Trial`/`Active` → `Expired`, lalu `Expired` lewat 7 hari → `Cancelled` (dicabut permanen). Semua perubahan dicatat di tabel audit `license_events`.
- **Fix tier 1 bulan**: insert lisensi dari pembayaran sekarang set `tier='1month'` (sebelumnya omit → DB default 'lifetime' yang salah). Paket UI `1bulan` dipetakan ke `1month` sesuai check constraint.
- **register_activation CHECK sekarang memblokir Active yang kedaluwarsa** (sebelumnya hanya Trial) — user yang sudah aktivasi pun terkunci kalau lisensi berbayar habis masa.
- Trial narrative diganti "30 hari" → "3 hari" (sesuai kebijakan trial 3 hari).
- Migration `0013_license_lifecycle.sql`: formalisasi tabel `payments` (sebelumnya ad-hoc), kolom `order_id`/`expires_at`/`tier`/`payment_provider`/`payment_url` di `licenses`, tabel audit `license_events`, backfill `expires_at` dari payments/tier.

### L2. Grace 7 hari — langsung terkunci
- `_checkLicenseStatus` sekarang **SELALU cek cloud** (sekali per session) — bukan hanya saat belum aktivasi. Sebelumnya `isActivated` early-return berarti user yang sudah aktivasi TIDAK PERNAH diblokir.
- `expires_at` lewat → app LANGSUNG terkunci (layar blokir), grace 7 hari = waktu untuk bayar sebelum key di-revoke sistem.

### L3. Notif perpanjang + countdown
- **Banner dashboard** "Lisensi Segera Berakhir / Perlu Perpanjangan" muncul H-7 sebelum habis; kalau sudah habis → banner merah wajib + tombol perpanjang.
- **Layar blokir** saat kedaluwarsa menampilkan countdown grace 7 hari (sisa hari) + tombol **"Perpanjang / Beli Lisensi"**.

### L4. Pembayaran abstrak
- App cukup buka `/pay` (Vercel) — gateway bisa diganti di web tanpa menyentuh app. Tombol perpanjang/beli di banner dashboard, layar blokir, dan settings semuanya buka `/pay`.
- Narasi "Pembayaran aman via Midtrans" dihilangkan dari UI baru.

### L5. UI lisensi di settings
- Sheet "Lisensi" di Pengaturan sekarang menampilkan **status nyata** (Aktif / Kedaluwarsa / Dibatalkan / Dinonaktifkan), **paket** (Trial / 1 Bulan / Lifetime), dan **berlaku sampai** (tanggal nyata / seumur hidup) — bukan hardcoded "Status: Aktif".
- Tombol **Perpanjang / Beli** muncul kalau status bermasalah atau mendekati habis (H-7).
- Metadata lisensi disimpan per-varian di SecureStore (`nusa_license_info_<productId>`) saat login.

### L6. Bersihin narasi "gratis NFC card"
- `payment_sheet.dart`: "Akses seumur hidup + FREE Kartu NFC 2pcs" → "Akses seumur hidup".
- Web `/pay`: durasi lifetime "Akses seumur hidup + FREE NFC 2pcs" → "Akses seumur hidup".
- `SHOPEE_LISTINGS.md` + `SHOPEE_LISTINGS_PLAIN.txt`: semua klaim bonus Kartu NFC (variasi harga, pengiriman, BONUS block, checklist) dihapus.

### L7. Template email per tier + harga Rp 249K
- Email aktivasi sudah dibedakan per tier (subject + body + notice trial/1bulan/lifetime).
- **Fix harga**: lifetime "Rp 199K" → **"Rp 249K"** (harga real) di semua tempat email (badge, trial notice, upgrade notice) — di dua copy edge function (`nusa-online` + `nusa_kasir/supabase`).

---

## ⚙️ BATCH 1 — Perbaikan yang langsung dirasakan user (SEMUA varian)

### B1. Restore cloud bawa GAMBAR produk (BASE64)
- Foto produk disimpan sebagai **BASE64 di kolom produk** → otomatis ikut backup/restore cloud. Kalau `imageBase64` ada → ditampilkan; fallback path lama.

### B2. Hint per varian
- `variant_data.dart`: kamus hint per varian (8 entri) — hint Nama Produk / Kategori / SKU / Harga / Stok / Barcode sesuai industri varian (mis. salon tidak dikasih contoh "Indomie").
- Form produk + screen lain memakai `NusaConfig.currentVariant?.hints[...]` — tidak ada hardcoded "Cth: Indomie" lagi.

### B3. UI Bahan Baku ikut pola existing (F&B)
- Tab Bahan Baku: tap baris → **sheet detail** (Stok saat ini / Stok minimal / Harga modal + aksi Edit / Pembelian / Stok Masuk / Hapus) — bukan popup menu.
- Form sheet pakai pola `_sectionCard` + drag-handle + `viewInsets` (konsisten dengan checkout).

### B4. Kelola Satuan reusable
- `UnitManagerSheet` diekstrak jadi widget publik — akses CRUD kamus satuan dari **3 tempat**: form produk (toggle Satuan), tab Produk (header icon), tab Bahan Baku (header + empty state).

### B5. Grosir: harga balik normal saat qty turun
- **Akar bug**: `+` hitung ulang grosir, `-`/qty editable TIDAK → harga "beku". Sekarang semua jalur decrement + set qty menghitung ulang `wholesalePriceFor(newQty)` + update `originalPrice`.
- Ganti varian tidak lagi me-reset harga grosir; ambang grosir pakai `qtyInBase` (1 dus = 12 pcs dengan ambang 10).
- Unit test grosir (qty turun di bawah ambang → balik normal).

### B6. Auto-scan barcode HID universal + kamera
- **Tambah Produk form**: wrap `HidBarcodeListener` → scan isi field barcode + auto-set toggle (tanpa buka keyboard layar).
- **Sheet Stok Masuk/Keluar** (`_AdjustSheet`): scan HID auto-capture di sheet.
- **Stok tab**: scan HID → jalur 'in'/'out' sesuai konteks.
- **Kategori tab**: scan HID → cari kategori → buka/highlight.
- **Opname**: scan dari NOL (HID + ikon kamera + `AnimatedScannerOverlay` di search bar) → auto-match produk + naikkan physical count.

### B7. Simpan Pesanan — SEMUA varian
- Tombol "Simpan Pesanan" tidak lagi khusus F&B — semua varian bisa simpan keranjang → restore nanti (dipakai juga sebagai draft antrian di varian jasa).

### B8. Barcode custom KARYAWAN (4 jalur auth: PIN / fingerprint / NFC / barcode)
- Tabel Employees + kolom `barcode` (nullable, unique).
- Form karyawan: field barcode (manual + scan HID).
- `PinKeypad` + `PinDialog` + login: **scan barcode karyawan** = jalur auth ke-4 (setara PIN/FP/NFC).

### B9. Kategori CRUD di tab
- Tab Kategori: tambah/rename/hapus langsung di tab (FAB → dialog langsung, long-press → sheet aksi), bukan pindah layar `/produk/kategori`.
- Filter A-Z/Terbanyak yang boros dirapikan.

### B10. Tab Layanan di varian jasa (`isService`)
- Model produk + flag `isService` (produk jasa = tanpa stok/barcode wajib; barcode TETAP boleh).
- POS: segment `Produk | Layanan` → filter produk, bisa 1 transaksi campur.
- Tab Layanan di menu Produk (varian jasa: salon, bengkel, servis, laundry, fotocopy): daftar layanan + CRUD.
- Varian barang (kelontong, fnb, apotek): tab Layanan opsional/hidden jika tidak dipakai.
- Alur bayar-setelah-selesai (antrian bengkel) terhubung ke Simpan Pesanan (B7).

---

## 📦 RILIS

- 8 varian dibangun + dirilis (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis).
- 82 test pass · `flutter analyze` 0 error.
- Web: migration `0013_license_lifecycle.sql` + edge function `license-cron` + deploy `register_activation`/`midtrans`/`license-manager` (price 249K).
