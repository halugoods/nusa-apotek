# CHANGELOG v2.2.34+86 — Toko Online 7 Varian, DP Persen/Cicilan, Piutang Sinkron, Percetakan Polishing, Fix Migrasi

**Tanggal**: 2026-08-19

## RINGKASAN

Rilis besar untuk **8 varian sekaligus** (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis). Fokus utama: fitur **Toko Online** kini aktif penuh di 7 varian non-kelontong (sebelumnya fallback ke homescreen), pengaturan toko online **tidak hilang** saat login ulang, sistem **piutang/DP lengkap** (opsi persen/nominal + cicilan + status sinkron di riwayat), polish menyeluruh untuk **Percetakan/Fotocopy**, plus fix migrasi DB kritis.

## PERUBAHAN

### 1. Toko Online — aktif di 7 varian + persistensi setup
- **Fix fallback ke homescreen**: menu Toko Online, Pesanan Online, dan Pengaturan Toko Online kini **bisa dibuka** di laundry, bengkel, salon, fotocopy (sebelumnya redirect ke homescreen).
- **Setup tidak hilang saat login ulang**: data toko online sekarang disimpan per **akun Google + varian**, bukan per device. Hapus data / login ulang dengan akun yang sama → pengaturan toko **kembali seperti semula**, tidak perlu setup dari awal.
- **Anti rebutan slug**: slug toko unik per pemilik — toko milik akun lain tidak bisa mengambil slug yang sama, tapi setup lama tetap bisa dipakai dan diklaim kembali.

### 2. DP (Uang Muka) — opsi Persen / Nominal + Cicilan
- **Mode DP bisa dipilih**: **Nominal** (isi Rp bebas + chip cepat 50%) atau **Persen (%)** (isi angka, DP dihitung otomatis = persen × total).
- **Cicilan**: saat DP aktif, bisa nyalakan **Cicilan** dan pilih berapa bulan (1/2/3/6/12 — bisa dikonfigurasi). Sisa otomatis dibagi rata, tampil "Rp X/bulan".
- Diterapkan untuk transaksi **Tunai** (sisa dicatat sebagai piutang otomatis).
- Ringkasan di struk & laporan menampilkan DP + cicilan per bulan.

### 3. Piutang — status bayar sinkron di riwayat transaksi
- Transaksi ber-utang/DP kini **terhubung langsung** ke piutangnya.
- Di **Riwayat Transaksi**, status pembayaran ikut berubah otomatis: "Piutang Lunas ✓" / "Sisa piutang RpX" — tidak lagi selalu tertulis "Dibayar 0".
- Void transaksi otomatis membatalkan piutang terkait (tidak ada piutang yatim).

### 4. Piutang — opsi cicilan CRUD (Owner)
- Menu **Opsi Cicilan** (icon settings di layar Piutang, khusus Owner): tambah/ubah/hapus paket bulan, contoh "3× bulanan".
- Kartu hutang menampilkan **"Cicilan N× · RpX/bulan"**.
- Sheet **Bayar Cicilan**: jumlah default = 1 angsuran per bulan (bukan sisa penuh), tetap bisa diubah.

### 5. Percetakan / Fotocopy — polish
- **Kelola Layanan** dan **Kelola Estimasi** jadi tombol terpisah di atas tombol Order Baru (bukan chip campur filter).
- **Estimasi Selesai** pakai dropdown preset (1 jam, 2 jam, 3 jam, Besok 10:00/14:00, 3 hari, 1 minggu) + opsi **Kustom…** — preset bisa dikelola lewat tombol Kelola Estimasi.
- Order cetak otomatis dari kasir kini memakai **nama kategori produk** sebagai jenis layanan (mis. "Banner", "Stiker") + mengisi jumlah lembar/copy.
- **Metode pembayaran** di kasir **dibagi rata** saat 4 kartu (kanan-kiri seimbang).
- Search bar pelanggan + **tombol pilih pelanggan dari kontak HP**.

### 6. Fix Kritis: Migrasi DB Self-Healing
- **Gejala lama**: saat setup/buat PIN di 7 varian muncul error `duplicate column name: order_type` — DB hasil restore cloud/backup lama bisa punya kolom yang SUDAH ADA padahal `user_version` masih di bawah target, lalu `ALTER TABLE ... ADD COLUMN` dijalankan ulang → error.
- **Fix**: semua `ADD COLUMN` di migrasi di-guard `PRAGMA table_info` (kolom ada → dilewati), `CREATE TABLE` memakai `IF NOT EXISTS`, seed hanya saat tabel kosong. Berlaku ke semua varian — kelontong tetap identik.

### 7. UX lain
- Hapus label/badge **"Dalam Pengembangan"** pada menu Spreadsheet & AI Chat.

## CATATAN
- Database otomatis dimigrasi ke skema **v43** (kolom DP/cicilan/debt + tabel opsi cicilan & estimasi) — tanpa kehilangan data.
- 47/47 test pass · `flutter analyze` 0 error.
- Rilis untuk **8 varian sekaligus** dengan versi sama **v2.2.34+86**.
