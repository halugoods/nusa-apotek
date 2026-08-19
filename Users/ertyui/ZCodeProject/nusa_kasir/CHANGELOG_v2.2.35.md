# CHANGELOG v2.2.35+87 — Payment Block Rapi, Order Cetak Dinamis, NUSA CS Domain, Logo Toko, Notif Pintar

**Tanggal**: 2026-08-19

## RINGKASAN

Rilis untuk **8 varian** (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis). Fokus: blok pembayaran checkout yang lebih rapi (DP & Hutang sejajar + cicilan + jatuh tempo), **pendapatan = uang yang benar-benar masuk** (DP & setoran piutang dihitung presisi), **Order Cetak (Percetakan) dengan form dinamis** per layanan + field kustom, **crop foto produk anti-force-close**, **NUSA CS pindah ke domain terpisah** (nusa-cs.vercel.app / nusa-cs.halugoods.com), **logo toko tampil di website**, notifikasi dengan navigasi per-item, dan fix blank layar Tambah Karyawan.

## PERUBAHAN

### 1. Checkout — blok pembayaran sejajar & lengkap
- Tombol quick **"Bayar dengan Hutang"** dihapus — cukup toggle, tampilan lebih bersih.
- Blok **Uang Muka (DP)** dan **Hutang** dibuat **sama gaya** (kartu amber soft, border, radius, padding seragam) dalam satu baris sejajar.
- **DP Nominal**: ketik nominal → otomatis tampil "% dari total" di bawahnya. Chip cepat 50% dihapus.
- **DP Persen**: isi % → kartu hasil **Rp besar** dihitung otomatis.
- Saat DP/Hutang aktif → **sub-toggle Cicilan** (dropdown bulan) + **form Jatuh Tempo (date picker, default +7 hari)** selalu tampil.

### 2. Piutang — cicilan & jatuh tempo
- Sheet pembayaran piutang: bisa **atur Cicilan** (ubah paket bulan) + **Jatuh Tempo** (date picker).
- Status chip menampilkan **"Cicilan 1/6 … 6/6"** (dari `(amount−remaining)/perMonth`).
- Repository baru: `setInstallmentMonths`, `setDueDate`.

### 3. Pendapatan = uang yang benar-benar masuk
- Helper `paidAmount(tx)` = `DP ?? (hutang ? 0 : tunai/uang pas/total)`.
- **Omzet, Laba-Rugi pendapatan, pemasukan harian, & laporan per metode bayar** kini menjumlahkan **uang yang benar-benar diterima** + **setoran piutang** dalam periode (dengan filter cabang bila aktif).
- Kolom `branch_id` di tabel `debt_payments` (migration v44) diisi dari session aktif.
- Dashboard omzet ikut akurat secara otomatis; ekspor CSV/Excel ikut.

### 4. Produk — preview 1:1 + crop foto ANTI-FC
- Preview foto produk kini **kotak 1:1** (bukan height tetap).
- Setelah pilih foto (sudah di-downscale ≤1024px) → langsung buka **crop 1:1**.
- Ikon **crop** muncul di preview saat foto sudah ada (bisa re-crop).
- **Anti-force-close**: crop berjalan pada file yang sudah di-downscale (mencegah OOM foto 50MP), try/catch penuh, gagal → pakai foto tanpa crop (app tetap jalan).

### 5. Order Cetak (Percetakan) — 1 tombol Kelola + form dinamis
- **Kelola Layanan + Kelola Estimasi** digabung jadi **1 tombol "Kelola"** → sheet 2 segmen [Layanan][Estimasi].
- **Form dinamis per layanan**: setiap layanan bisa diatur field-nya via checkbox — Nama Pelanggan, No Telp (dengan ikon pilih dari kontak), Jumlah Lembar, Copy, Ukuran Kertas, Panjang, Lebar, Total, Estimasi, Catatan.
- **Field kustom CRUD**: tambah/rename/hapus field sendiri per layanan; nilai tersimpan di `print_orders.custom_fields_json`.
- Status chips jadi **segmented** rapi + search bar ikut gaya pelanggan.
- DB lokal migration **v44** (`print_service_types.fields_json`, `print_orders.custom_fields_json`).
- Cloud: tabel `print_form_configs` (per store) + edge function `online-store` aksi `sync_print_form_configs`/`get_print_form_configs` — sync saat save + pull saat setup.

### 6. Notifikasi — tool-calling + baca per-item
- Tap notifikasi → **langsung navigasi** sesuai jenis: update → dialog update, online → Pesanan Online, stock → Stok, attendance → Presensi.
- Setelah dibuka → hanya notif itu yang **tandai terbaca** (bukan semua saat sheet dibuka).
- Badge = jumlah belum dibaca fresh; item belum dibaca diberi dot.

### 7. Link WhatsApp — satu helper, semua menu benar
- Helper `waLink(phone, {text})` dipakai **semua** layar: pelanggan, pesanan online (fix bug 0 di depan), dashboard, karyawan, presensi, supplier (fix `+` ganda), transaksi, toko online (fix raw).
- Struk/share tetap tanpa nomor.

### 8. Pengaturan Struk — preview di paling atas
- Urutan baru: Judul → **Preview struk live** → **Slider Ukuran Header** → **Slider Ukuran Logo** → sisanya (kertas, font, ketebalan, posisi logo, teks, toggle).

### 9. NUSA CS — domain terpisah
- Widget chat **tidak lagi nempel di setiap halaman toko online** — diganti tombol mengambang **"Chat CS"** yang membuka **nusa-cs.vercel.app** (halaman CS baru).
- Halaman CS menembak tunnel **nusa-cs.halugoods.com → server lokal port 8790** (cloudflared hermes, sudah route DNS + restart tunnel).
- Bot internal app tetap LAN 8790.

### 10. Logo toko tampil di website
- Setelah upload logo → app kirim `logo_url` di `upsertStore` → edge simpan → **website render logo** (fallback gradien "N" bila kosong).
- Migration 0014: policy SELECT publik bucket `nusa-images`.

### 11. Fix — blank layar Tambah Karyawan
- `BranchRepository.getAll()` dipindah **sebelum** buka modal sheet (hapus FutureBuilder dari modal — sumber blank pasca date picker).
- `initializeDateFormatting('id')` di `main.dart` + guard `context.mounted` setelah await.

### 12. Fix KRITIS — restore cloud real-time (setelah "Data Ditemukan" langsung bisa PIN)
- **Sebelumnya**: setelah restore "Data Ditemukan" → restart, masih nunggu beberapa saat / hapus data + login ulang baru masuk home. Penyebab: `main()` memanggil auto-sync (`_receiveAtLaunch`) **sebelum** menerapkan `.pending` restore — probe DB lama membuka koneksi + menyisakan WAL, lalu auto-sync **menimpa `.pending` yang sama** → DB hasil restore korup → PIN tidak terbaca.
- **Sekarang**: `.pending` restore di-swap **PALING AWAL** di `main()` (sebelum apa pun menyentuh DB), dan auto-sync **skip** kalau masih ada `.pending` terjadwal. Setelah "Data Ditemukan" → restart → **langsung bisa masuk PIN**.

### 13. Menu Supplier di SEMUA varian
- `supplier` dihapus dari hidden menus **fnb, laundry, salon** (sebelumnya hanya kelontong/bengkel/apotek/fotocopy/servis yang punya) — konsisten di `nusa_config.dart`, `variant_data.dart`, dan `_build_all.py`.

### 14. Fix — Kasir tidak pernah loading abadi
- `_preloadProducts` di POS: try/catch penuh — kalau DB rusak/kosong, tampilkan list kosong (bukan spinner abadi) + produk tetap bisa di-scan via barcode.

### 15. Fix — build number sinkron (anti-loop "Update tersedia")
- `appBuildNumber` di `nusa_config.dart` disinkronkan **87** = pubspec. Sebelumnya 86 → release 87 di GitHub selalu dianggap lebih baru → dialog "Update tersedia" muncul terus walau sudah versi terbaru.

## CATATAN
- Database otomatis dimigrasi ke skema **v44** (kolom DP/cicilan/debt + field form print + `branch_id` di setoran piutang) — tanpa kehilangan data.
- 47/47 test pass · `flutter analyze` 0 error.
- Rilis untuk **8 varian sekaligus** dengan versi sama **v2.2.35+87**.
- Web toko online deployed (ChatCSButton + logo) · migration 0014 + edge `online-store` deployed · `nusa-cs.vercel.app` + tunnel `nusa-cs.halugoods.com` aktif.
