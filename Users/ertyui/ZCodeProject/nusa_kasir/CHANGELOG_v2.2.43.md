# CHANGELOG v2.2.43+96 — Restore Aman + Lupa PIN + F&B Bahan/Resep/HPP + Varian POS + Satuan Dinamis + Auto-Sync Online + Barcode HID Universal

Tanggal rilis: 2026-08-21 · Varian: **8 varian** (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis)

## 🛡️ Keselamatan Restore (SEMUA varian — prioritas utama)

**Komplain user**: "apotek data ditemukan tapi masuk PIN benar tetap tidak bisa masuk; salon/fnb malah disuruh setup ulang dari awal; aku mau login akun yang sudah ada data cloud tinggal restore dan bisa aman lanjut."

**Perbaikan menyeluruh**:
1. **Akun ber-cloud-data TIDAK pernah dipaksa setup dari nol.** Semua jalur login (aktivasi key, PIN, auto-restore) cek backup valid varian DULU → restore → lanjut. Setup hanya fallback terakhir kalau benar-benar belum ada data.
2. **Metadata cloud per-varian** — penulisan metadata pindah ke `$uid/{productId}/metadata.json` (bukan root). `getBackupTimestamp`/`syncIfNewer` baca `updated_at` (fallback `backupTime`). Backup antar-varian TIDAK bisa tertukar lagi.
3. **Salah-varian = dialog jelas, bukan paksa setup.** Kalau backup cloud milik varian lain, muncul dialog *"Backup ini milik varian X, bukan Y. Data Anda tidak akan rusak."* + tombol **Kembali** (tetap di PIN) / **Lanjut Setup Baru** (dengan konfirmasi). Backup tidak diunduh/ditulis.
4. **"Lupa PIN?"** — di bawah keypad PIN semua layar login: verifikasi **Google re-auth** (pemilik akun) → atur PIN baru (≥4 digit) → langsung masuk. Owner tidak perlu reset data hanya karena lupa PIN.
5. **PIN pad baca panjang PIN tersimpan** (4/5/6 digit) dari `SettingsRepository.getPinLength()` di semua 5 tempat keypad — user PIN 4 digit tidak stuck lagi.
6. **Migration schema 44→45** self-healing (`_addColumnIfMissing`/`_createTableIfMissingSafe`) untuk tabel baru F&B + seed kamus satuan `pcs`.

## 🍳 F&B: Bahan Baku + Resep + HPP (aplikasi fnb)

- **Tab ke-3 "Bahan Baku"** di menu Produk (Produk/Kategori/Bahan Baku) — khusus aplikasi fnb.
- CRUD bahan baku: nama, satuan (dari kamus satuan), stok, stok minimum, harga modal (HPP).
- Tombol **"Pembelian"** → fast track ke Catat Pembelian bahan → stok & HPP bahan ikut ter-update (HPP mengikuti harga beli terbaru).
- Tombol **"Stok Masuk"** → tambah stok cepat TANPA mengubah HPP (stok awal / hitung manual).
- **Resep/Komposisi** di form produk fnb: pilih bahan + qty per porsi → estimasi HPP live.
- **Checkout produk ber-resep** → stok bahan otomatis berkurang. Stok bahan kurang = **PERINGATAN saja** (transaksi tetap jalan), sesuai keputusan user.
- **Laporan HPP** produk ber-resep = qty × biaya resep (Σ bahan × harga modal).

## 🧮 Satuan Dinamis (CRUD) — SEMUA varian

- **Kamus satuan global** (`Units`): user tambah/rename/hapus sendiri — `pcs`, `dus`, `karton`, `botol`, `strip`, `peti`, atau bebas.
- **Konversi per produk** (`ProductUnits`): 1 satuan dasar + N satuan jual (mis. "1 dus = 12 pcs"). Produk tanpa aturan → fallback `pcs` (data lama aman).
- Form produk ada bagian **"Satuan"**: pilih satuan dasar + tambah satuan jual + tombol **"Kelola Satuan"** (CRUD kamus).
- **POS**: kasir pilih satuan jual per baris keranjang (dropdown). Stok & pengurangan pakai `qtyInBase` (qty × konversi). Tampilan: **"2 dus (24 pcs)"**.
- Struk & laporan otomatis satuan-aware (qty dasar untuk HPP/laba).
- Mode timbang (`priceType` pcs/kg = gram/kg/ml/liter) tetap terpisah — tidak tercampur kamus satuan hitung.

## 🎨 Varian Produk di POS — SEMUA varian

- Produk ber-varian (rasa/ukuran) kini bisa **dipilih di keranjang** — baris varian berbeda tidak digabung.
- Harga mengikuti varian (harga dasar + selisih), stok varian dipakai untuk pengaman stok.
- Struk menampilkan **"Nama — Varian"**; riwayat transaksi ikut menyimpan varian.

## 🔄 Auto-Sync Produk Online — SEMUA varian

- Sinkronisasi produk online **otomatis** (debounce 8 dtk setelah ada perubahan produk) — tidak perlu buka pengaturan toko online lagi.
- Edge function `sync_products` sekarang **UPSERT** per produk (key `store_id`+`product_id`) — produk yang dinonaktifkan online TIDAK dihapus, `updated_at` ter-update, `is_published` dipertahankan.
- Upload gambar dengan retry (3×) + diagnostik kegagalan per produk di layar toko online.

## 📡 Barcode HID Universal + Alfanumerik — SEMUA menu scan

- **Scanner eksternal (HID) otomatis di SEMUA menu scan** (kasir, kamera, produk, stok, pembelian, form produk) — tidak perlu tap search bar dulu.
- **Kode berhuruf & simbol didukung** (`ABC-123`, `-+/_`): normalisasi barcode = trim + UPPERCASE + strip karakter tak dikenal, dipakai konsisten di semua pencarian & pemindai.
- Listener HID **tidak membuka keyboard layar** (fokus tanpa TextInput, pola pin keypad).

## 📦 RILIS

- 8 varian dibangun + dirilis (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis).
- 69 test pass · `flutter analyze` 0 error.
- Web: migration `online_products.updated_at` + unique key `(store_id, product_id)` + edge fn `online-store` di-deploy.
