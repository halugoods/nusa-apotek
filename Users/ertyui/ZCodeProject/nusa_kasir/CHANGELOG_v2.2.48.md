# Changelog v2.2.48 (Build 101)

## 🐛 Perbaikan Kritikal — Restore Cloud

### Bug Fix #1 — PIN Gagal Setelah Restore
**Masalah:** Setelah Pulihkan Data Cloud, user tidak bisa login dengan PIN (PIN salah terus).

**Penyebab:** `_repairPinLength()` (fungsi yang memperbaiki PIN 4-digit lama ke 6-digit) tidak dipanggil setelah proses restore. User dengan backup lama (PIN 4-digit) tidak bisa login karena app expecting 6-digit PIN.

**Solusi:** `_repairPinLength()` sekarang dipanggil langsung setelah restore berhasil, SEBELUM navigasi ke layar login.

---

### Bug Fix #2 — Restore Mengangkat Data Varian Salah
**Masalah:** Install APK varian F&B tapi data yang di-restore adalah data dari varian Servis (atau sebaliknya).

**Penyebab:** `_backupBelongsToVariant()` punya null-gap — backup lama (sebelum v2.2.42) tidak punya `variantKey` di metadata. Cek variantKey di-skip, lalu fungsi turun ke sqlite inspection yang hanya cek `image_path` produk. Kalau produk tidak punya foto (image_path NULL), sqlite inspection gagal mendeteksi varian → dianggap aman → restore proceed.

**Solusi:** Backup tanpa `variantKey` (old backup) sekarang DITOLAK. Backup lama tidak bisa diverifikasi keamanannya — user disarankan upgrade dari app versi lama terlebih dahulu sebelum restore, atau setup baru.

---

## 📦 Teknis
- **Versi:** 2.2.48 (build 101)
- **Kompatibilitas:** Android 5.0+ (API 21)
- **Semua 8 varian:** kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis
