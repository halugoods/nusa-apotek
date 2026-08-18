# CHANGELOG v2.2.33+85 — Fix Login/PIN Stuck di 7 Varian (Restore Data Cloud)

**Tanggal**: 2026-08-18

## RINGKASAN

Perbaikan menyeluruh untuk masalah **tidak bisa masuk ke homescreen setelah input PIN** di 7 varian (fnb, laundry, bengkel, salon, apotek, fotocopy, servis) — kelontong sudah benar sejak awal. Akar masalahnya: database lokal di varian lain bisa kosong / tidak terbaca, padahal akun Google sudah punya data tersimpan di cloud.

Sekarang aplikasi **memulihkan data dari cloud dulu** sebelum meminta PIN — data toko, produk, dan karyawan tetap aman. Layar Setup hanya muncul sebagai pilihan terakhir kalau memang tidak ada backup sama sekali.

## PERUBAHAN

- **Data dipulihkan dari cloud, bukan setup ulang**:
  - Kalau database lokal kosong (varian baru / belum pernah dipakai) dan ada backup di cloud, muncul dialog **"Data Ditemukan"** yang menampilkan nama toko, pemilik, dan waktu backup terakhir.
  - Pilih **"Ya, Buka Toko Ini"** → data diunduh, aplikasi dibuka ulang, lalu tinggal masukkan PIN seperti biasa — semua produk & pengaturan kembali.
- **Login tidak pernah stuck lagi**:
  - Layar PIN sekarang aman dari error: kalau database gagal dibaca, langsung coba pulihkan dari cloud — bukan diam tanpa getar di 6 titik penuh.
- **Pengecekan backup cloud lebih andal**:
  - Sebelum cek apakah ada backup, aplikasi memastikan koneksi aman ke server — sebelumnya cek bisa gagal diam-diam sehingga data di cloud tidak terdeteksi.
- **Backup cloud tidak menimpa data lokal yang sudah ada**:
  - Jika database lokal sudah punya karyawan, backup cloud (yang bisa berasal dari varian lain) **tidak akan menimpa** — mencegah hilangnya owner/PIN akibat restore silang antar varian.
- **Diagnosa lebih jelas**: log detail saat login gagal dibaca, supaya kalau masih ada masalah, tim bisa langsung tahu penyebabnya.

## CATATAN

- Rilis untuk **8 varian sekaligus** (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis) dengan versi sama **v2.2.33+85**.
- Untuk device yang sudah terlanjur stuck: cukup buka aplikasi versi baru ini → ikuti dialog **"Data Ditemukan"** → data lama di cloud akan dipulihkan otomatis. Tidak perlu menghapus data atau membuat toko baru.
