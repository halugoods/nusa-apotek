# Changelog v2.2.49 (Build 102)

## 🐛 Perbaikan Kritikal — Restore Cloud

### Bug Fix #1 — PIN Gagal Setelah Restore
**Masalah:** Setelah klik "Ya, Buka Toko Ini" di dialog "Data Ditemukan", user tidak bisa login dengan PIN (PIN salah terus).

**Penyebab:** Fungsi `_repairPinLength()` (memperbaiki PIN 4-digit lama ke 6-digit) TIDAK dipanggil setelah proses restore. Backup lama dari versi sebelum v2.2.46 punya PIN 4-digit, tapi app expecting 6-digit PIN.

**Solusi:** `_repairPinLengthAfterRestore()` sekarang dipanggil langsung setelah `restoreDirect()` berhasil, SEBELUM navigasi ke layar login. Semua employee PIN diperbaiki ke 6-digit + setting PIN length dikunci ke 6.

---

### Bug Fix #2 — Restore Mengangkat Data Varian Salah
**Masalah:** Install APK varian F&B tapi data yang di-restore adalah data dari varian Servis (atau sebaliknya).

**Penyebab:** `_backupBelongsToVariant()` punya null-gap — backup lama (sebelum v2.2.42) tidak punya `variantKey` di metadata.json. Cek variantKey di-skip, lalu fungsi turun ke sqlite inspection yang hanya cek `image_path` produk. Kalau produk tidak punya foto (image_path NULL semua), sqlite inspection gagal mendeteksi varian → dianggap aman → restore proceed dengan data varian lain.

**Solusi:** Backup tanpa `variantKey` (old backup pre-v2.2.42) sekarang DITOLAK. Tidak bisa diverifikasi keamanannya — user disarankan upgrade dari app versi lama terlebih dahulu sebelum restore, atau setup baru.

---

## 📦 Teknis
- **Versi:** 2.2.49 (build 102)
- **Kompatibilitas:** Android 5.0+ (API 21)
- **Semua 8 varian:** kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis
