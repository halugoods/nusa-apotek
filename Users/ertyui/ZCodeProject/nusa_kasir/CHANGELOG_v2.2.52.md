# Changelog v2.2.52 (Build 105)

## 🎉 Fitur Baru — Menu Tutorial Cloud (per Varian)
- Menu **Bantuan → Tutorial** sekarang menjadi menu yang bisa dibuka, berisi
  daftar tutorial video yang **sesuai dengan varian aplikasi** yang dipilih.
- Tutorial dikelola dari dashboard admin (`nusa-online.vercel.app/dashboard`
  → tab Tutorial): admin upload link YouTube + judul + thumbnail + centang
  varian (8 varian) mana yang menampilkannya.
- App menarik daftar tutorial langsung dari Supabase (bucket `tutorial-thumbnails`),
  filter `variants contains productId`. Jika belum ada data, menampilkan tutorial
  statis bawaan.
- Tiap item bisa **dibuka** (buka YouTube), thumbnail tampil, dan ada pull-to-refresh.

## 🐛 Fix — Foto Kartu Profil (Flip Card)
- **Gejala:** setelah karyawan mengganti foto (atau setelah restore device), kartu
  profil di dashboard masih menampilkan inisial, bukan foto baru.
- **Akar masalah:** foto kartu ditangkap sekali saat dashboard pertama dibuka dan
  tidak ikut di-refresh saat pull-to-refresh (`_load()`), sehingga menyimpan path
  lama/missing dan `existsSync()` gagal → fallback ke inisial.
- **Fix:** `_load()` sekarang me-resolve ulang foto pengguna aktif dari daftar
  karyawan yang sudah diperbarui, sehingga foto baru langsung muncul.

## 🐛 Fix — Tampilan Versi di Pengaturan
- **Gejala:** baris "Riwayat Update" di menu Pengaturan menampilkan versi yang
  lagging (mis. tertulis 2.2.46 padahal app terpasang 2.2.5x), karena membaca
  versi terbaru dari release GitHub yang bisa tertinggal.
- **Fix:** subtitle sekarang selalu menampilkan **versi yang terpasang**
  (`Terpasang v2.2.52+105`) selain info update bila ada.

## 🔄 Integrasi Pembayaran InstanPay (QRIS) — pengganti Midtrans
- Gateway pembayaran lisensi diganti ke **InstanPay (QRIS)** — tanpa KTP/NPWP.
- Halaman `/pay` menampilkan QRIS untuk discan (e-wallet / m-banking), lengkap
  dengan nominal + countdown, dan mengecek status secara otomatis.
- Edge function `instanpay` membuat invoice & mem-*generate* lisensi saat lunas.
  (Berjalan di sisi web/backend — tidak mengubah kode aplikasi.)

---

## 📦 Teknis
- **Versi:** 2.2.52 (build 105)
- **Kompatibilitas:** Android 5.0+ (API 21)
- **Semua 8 varian:** kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis