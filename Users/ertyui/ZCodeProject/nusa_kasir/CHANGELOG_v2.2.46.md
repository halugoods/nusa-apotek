# CHANGELOG v2.2.46+99 — UI Redesign (Pinpad, Produk, Opname) + Barcode Preview + Kartu ID Draft

Tanggal rilis: 2026-08-22 · Varian: **8 varian** (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis)

---

## 🔢 1. Pinpad konsisten (semua dialog ikut UI login)
- Animasi loading NFC dihapus — ganti jadi **hint statis** "Dekatkan kartu NFC" + icon NFC selalu tampil.
- Chip barcode id-card jadi statis "Scan Barcode ID" (tidak berubah jadi "Memproses…").
- Karena semua dialog pakai komponen PinKeypad yang sama, UI-nya otomatis konsisten: login, aktivasi, presensi, konfirmasi PIN, dashboard, pengaturan, transaksi.

## 🧭 2. Menu Produk: header bersih
- Icon "Satuan" (penggaris) di kanan grid filter **dihapus** → header lebih lega.
- Filter grid digeser ke kanan, tidak lagi menempel ke 3 tab switch (Produk/Kategori/Bahan).

## 📦 3. Tab Bahan Baku (F&B): kelola satuan jadi icon kecil
- Tombol teks "Kelola Satuan" (di empty state & header list) dihapus.
- Ganti **icon pengaturan kecil di atas tombol "+ Tambah Bahan"** (FloatingActionButton kecil) — tetap bisa akses kamus satuan dari tab Bahan.

## 📋 4. Opname: stepper − qty ＋ + scan HID benar-benar masuk opname
- Baris hitung fisik di opname jadi **stepper − qty ＋** (bukan cuma isi manual) — koreksi cepat per produk.
- **FIX BUG**: scan barcode HID di tab Opname tadinya selalu jatuh ke "Stok Masuk" (akibat GlobalKey yang tidak terisi). Sekarang scan benar-benar **auto-match produk + menaikkan count fisik +1 beruntun**.
- Param `screenKey` yang tidak terpakai dihapus (dead code).

## 🏷️ 5. Toggle barcode: preview langsung muncul + konsisten semua form
- Saat toggle barcode ON, **preview barcode** (code128) + teks kode langsung muncul di bawah toggle — pola sama dengan form tambah produk.
- Diterapkan konsisten di **produk, pelanggan (member), dan karyawan**:
  - Scan kamera sejajar di dalam Row dengan field kode.
  - Tombol **"Generate Barcode"** (icon dadu) — ditambahkan juga di karyawan (format `KRY-XXXX`).
  - Perilaku toggle disamakan: ON → field kosong (user scan/ketik/generate manual), tidak auto-generate.
- Fix konflik import `Barcode` antara `mobile_scanner` dan `barcode_widget` (sempat bikin compile gagal).

## 🪪 6. Kartu ID (member & karyawan): draft — siap desain baru
- **Fitur masih dalam pengembangan** (desain kartu sedang disiapkan ulang).
- Menu **"Kartu ID"** ditambahkan di Pengaturan (bagian TOKO) — saat diklik muncul dialog **"Dalam Pengembangan"**.
- Entri cetak kartu lama di **Pelanggan** & **Karyawan** dihapus (menunggu desain final).
- Folder template kartu disiapkan (`assets/card_templates/`) untuk desain baru nanti.

---

## Catatan
- Versi ini fokus **UI redesign & konsistensi** — tanpa perubahan database (schema tetap 47).
- 86 test lulus · analyze bersih (0 error).
