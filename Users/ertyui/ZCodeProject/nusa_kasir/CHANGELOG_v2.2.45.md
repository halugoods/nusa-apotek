# CHANGELOG v2.2.45+98 — Keyboard Form Sheet + 4 Jalur Auth Pinpad + Member Barcode + Foto Restore + Opname Scan

Tanggal rilis: 2026-08-22 · Varian: **8 varian** (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis)

---

## ⌨️ 1. Fix HID barcode: form sheet tetap bisa diketik (SEMUA menu)
- Auto-scan barcode HID **tetap jalan**, tapi sekarang listener tidak lagi mencuri fokus/input keyboard — pengguna bisa ngetik normal di semua form sheet (tambah produk, stok masuk/keluar, karyawan, member, dsb).
- Semua jalur scan HID dievaluasi ulang: POS, Produk, Stok, Opname, Kategori, Purchase, form produk, sheet adjust.

## 🔐 2. Pinpad SEMUA dialog = 4 jalur auth (bukan cuma login)
- **PIN / Fingerprint / NFC tap / Scan barcode ID** kini tersedia di SEMUA dialog pinpad (login, konfirmasi transaksi, buka kasir, kelola data, dll) — tidak lagi khusus layar login.
- Barcode karyawan jadi jalur auth setara PIN/FP/NFC di mana pun pinpad muncul.

## 💡 3. Hint pinpad ringkas
- Satu hint ringkas untuk scan barcode ID + NFC tap card (atas/bawah layar + animasi "dekatkan kartu") — konsisten di semua pinpad.

## 📦 4. Stok Opname: HID scan tidak lagi masuk stok masuk
- Scan barcode di layar Opname sekarang **auto-match produk + langsung menaikkan count fisik** (bukan membuka sheet stok masuk).
- Jalur stok masuk/keluar tetap tersedia dari tab Stok sesuai konteks.

## 📷 5. Scanner kamera Opname disamakan
- UI scanner internal Opname disamakan dengan scanner lain: animasi scan (AnimatedScannerOverlay) + pola interaksi yang sama.

## 🏷️ 6. Menu Produk: tombol satuan + filter
- Icon "tambah satuan" diganti **tombol teks**.
- 3 filter list/grid digeser ke kanan + diberi jarak dari 3 tab switch (Produk/Bahan/Kategori).

## 👤 7. Form Tambah Karyawan
- Barcode ID menjadi **toggle** (aktif → field scan barcode muncul).
- Judul sheet dipisah di atas (tidak menyatu dengan list card).

## 🧾 8. Form Tambah Produk: barcode manual
- Toggle barcode ON → field **KOSONG** (tidak lagi auto-generate barcode).
- Tombol **"Generate Barcode"** di bawah field untuk membuat barcode otomatis kalau mau.

## ⚙️ 9. Settings: urutan kartu fitur + logika F&B
- Kartu fitur di Pengaturan disusun ulang sesuai urutan pemakaian.
- Logika toggle F&B (Bahan Baku / harga timbang) diverifikasi: gated `isFnbVariant`, tidak bocor ke varian lain.

## 🎴 10. Batch 3: Member/Loyalty barcode + Kartu ID (karyawan & member)
- **Schema 47**: kolom `barcode` di tabel `customers` (member/loyalty) + kolom `photoBase64` di `employees`.
- Form member: toggle barcode + scan HID/kamera.
- Checkout: dialog pilih pelanggan punya **search bar + tombol scan kamera + auto-scan HID** → lookup member via barcode (normalisasi spasi/dash).
- **Template kartu ID siap cetak** (`id_card_renderer.dart`): format CR80 85.6×54mm, barcode code128, foto — untuk **karyawan** (termasuk barcode auth) dan **member** (barcode loyalty). Share PDF / cetak batch.

## 🖼️ 11. Foto restore setelah login ulang (produk + karyawan)
- **Akar bug**: foto produk hanya disimpan sebagai path file lokal → tidak ikut backup/restore cloud.
- Fix: foto produk disimpan **BASE64 di kolom DB** (`imageBase64`) saat save, foto profil karyawan di `photoBase64` (schema 47) — ikut serta di backup/restore.
- Setelah restore/login ulang: `hydrateImages()` + `hydratePhotos()` menulis ulang file lokal dari BASE64 → gambar tampil normal.
- Foto lama (path) tetap fallback — tidak merusak data existing.

## 🧪 12. Stabilitas restore/login
- Perbaikan tambahan pada jalur login-restore + load produk agar tidak menggantung.

---

## 📦 RILIS

- 8 varian dibangun + dirilis (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis).
- 86 test pass (termasuk test byBarcode member + hydrate foto) · `flutter analyze` 0 error.
- Schema DB naik ke **47** (customers.barcode, employees.photo_base64).
