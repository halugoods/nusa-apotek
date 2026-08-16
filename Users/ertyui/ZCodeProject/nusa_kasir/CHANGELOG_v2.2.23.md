# CHANGELOG v2.2.23+75 — Rilis Besar: Fix Kritis + Toko Online Lengkap

Tanggal rilis: 2026-08-16 · Varian: kelontong (7 varian lain menyusul)

## 🔐 Fix Kritis — PIN "Salah" Setelah Restore Data (Hapus Data → Login Ulang)

- **Sebelumnya**: setelah hapus data aplikasi + login Google + dialog
  "Data Ditemukan" → restore berhasil, tapi PIN yang benar selalu ditolak
  ("PIN salah") sampai aplikasi dibuka ulang manual. User awam pasti bingung.
- **Sekarang**: aplikasi **otomatis restart sendiri** setelah restore selesai —
  database yang baru dipulihkan langsung termuat, PIN langsung bisa dipakai.
- Berlaku di semua jalur restore: dialog "Data Ditemukan" saat aktivasi,
  maupun unduh backup dari Pengaturan.

## 🧮 Fix Harga Modal Pembelian Supplier (Ongkir Dibagi Rata per Qty)

- **Sebelumnya**: biaya tambahan (misal ongkir Rp1.000) dibulatkan ke bawah
  lalu dikali qty → total item ≠ total pembelian (contoh: modal 666, riwayat
  menampilkan 1998 padahal total asli 4.000 — berantakan).
- **Sekarang**: biaya tambahan **dibagi rata ke tiap qty** (harga modal +
  ongkir/qty). Sisa pembagian yang tidak bisa dibagi rata ditambahkan ke item
  terakhir → **total item SELALU pas dengan total pembelian**.
  - Contoh: produk A qty 3 harga Rp1.000 + ongkir Rp1.000 → modal per unit
    Rp1.333 (bukan 666), total item 3.999 + 1 = Rp4.000.
  - Contoh: qty 20 + ongkir Rp10.000 → modal +Rp500/unit = pas Rp30.000.
- **Detail riwayat pembelian** kini menampilkan: `qty × harga per unit`,
  baris **"Biaya Tambahan (ongkir Rp1.000)"**, dan Total = jumlah yang
  benar (sesuai header). Harga beli produk otomatis diperbarui ke modal baru.

## 🏪 Toko Online — Rombakan Besar (Website + Aplikasi)

### 💳 Metode Bayar Dinamis
- Pemilik bisa **aktifkan/nonaktifkan metode bayar** (Tunai, QRIS, Transfer)
  di Pengaturan Toko Online — langsung tampil di website.
- **Non-tunai (QRIS/Transfer) → pesanan masuk status "Menunggu Verifikasi
  Pembeli"** (pembeli diminta kirim bukti via WhatsApp). Kasir tinggal
  konfirmasi → masuk "Online Baru". Tunai → langsung "Online Baru".

### 🚚 Tipe Pesanan + Ongkir + Jam Ambil
- Pemilik bisa atur tipe pesanan (**Ambil Sendiri / Delivery**), **ongkir**,
  dan daftar **jam ambil** yang tampil di checkout website.

### 🏢 Cabang
- Cabang yang berstatus **Aktif** otomatis di-sync ke website → pembeli
  **wajib pilih cabang** saat checkout (link WhatsApp mengarah ke WA cabang).

### 👥 Member & Poin (terinspirasi GAS — Dimsum Sewu)
- Pembeli otomatis terdaftar sebagai member saat checkout (nama + nomor WA,
  nomor dinormalisasi 08xx → **"Adi" dan "adi" tetap 1 pelanggan**).
- **Akumulasi poin & total belanja** setiap pesanan selesai (Lunas).
- **Tukar poin** di checkout: nilai tukar & poin minimal bisa diatur pemilik.

### 🤝 Program Ajak Teman (Referral)
- Link `?ref=<nomor WA>` → saat teman baru checkout pertama kali, **pemberi
  referal dapat reward poin** (persen dari belanja atau nominal tetap).

### 🎟️ Kupon / Promo Online
- Pemilik bisa buat **kupon diskon** (persen atau nominal, min. belanja,
  kuota) langsung dari aplikasi → pembeli pakai kode kupon di website.

### 👤 Profil Tersimpan Otomatis (tanpa Google Login di website)
- Pembeli isi nama + WA sekali → tersimpan otomatis → kunjungan berikutnya
  langsung terisi. Riwayat pesanan tanpa perlu ketik nomor lagi.

### 🐛 Perbaikan Teknis Toko Online
- Nomor WhatsApp di-normalisasi di semua jalur (simpan 08xx, link wa.me 628xx).
- Status baru "Menunggu Verifikasi Pembeli" + tab & badge di Pesanan Online.
- "Lunas" kini bisa di-Refund (sebelumnya ditolak server).
- `payment_settings_screen` memakai ID Google yang benar (bukan Supabase auth
  yang selalu kosong) untuk upload QRIS.

## 📦 Lainnya
- Versi aplikasi: 2.2.23+75.
- Struk share text/PDF konsisten dengan format struk baru (netto + kurung
  diskon) dari v2.2.22.
