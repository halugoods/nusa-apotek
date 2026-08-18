# CHANGELOG v2.2.33+85 — Fix Login/PIN Stuck di 7 Varian

**Tanggal**: 2026-08-18

## RINGKASAN

Perbaikan menyeluruh untuk masalah **tidak bisa masuk ke homescreen setelah input PIN** di 7 varian (fnb, laundry, bengkel, salon, apotek, fotocopy, servis) — kelontong sudah benar sejak awal. Akar masalahnya: backup cloud / data karyawan di varian lain bisa menimpa database varian ini, sehingga owner + PIN hilang dan setiap PIN ditolak ("PIN salah") tanpa jalan keluar.

Sekarang aplikasi punya **pengaman berlapis** supaya tidak pernah lagi terjebak di layar PIN tanpa bisa masuk.

## PERUBAHAN

- **Login tidak pernah stuck lagi**:
  - Kalau database gagal dibaca (rusak), tampilkan pesan jelas + saran perbaikan — bukan "PIN salah" menyesatkan.
  - Kalau tidak ada satupun karyawan/owner di database (mis. backup varian lain menimpa), aplikasi otomatis mengarahkan ke layar Setup untuk membuat Owner + PIN baru.
- **Routing pintar saat buka aplikasi**: kalau sudah teraktivasi tapi database kosong (tanpa owner), langsung ke Setup — bukan ke pinpad.
- **Backup cloud tidak lagi menimpa data lokal yang sudah ada**:
  - Di `AutoSyncService` dan saat sinkronisasi di awal aplikasi, jika database lokal sudah punya karyawan, backup cloud (yang bisa berasal dari varian lain) **tidak akan menimpa**.
  - Mencegah hilangnya owner/PIN akibat restore silang antar varian.
- **Diagnosa lebih jelas**: log detail saat login gagal dibaca, supaya kalau masih ada masalah, tim bisa langsung tahu penyebabnya.

## CATATAN

- Rilis untuk **8 varian sekaligus** (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis) dengan versi sama **v2.2.33+85**.
- Cara perbaikan tercepat untuk device yang sudah terlanjur stuck:
  1. Buka aplikasi → otomatis diarahkan ke Setup → buat nama toko + Owner + PIN baru.
  2. Atau: Hapus data aplikasi (Pengaturan Android → Aplikasi → NUSA → Hapus Data) lalu aktivasi ulang — data lama bisa dipulihkan dari backup cloud jika diinginkan.
