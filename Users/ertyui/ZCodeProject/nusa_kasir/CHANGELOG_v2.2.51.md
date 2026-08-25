# Changelog v2.2.51 (Build 104)

## 🐛 Fix Kritikal — "Data Cloud Beda Varian" untuk SEMUA Varian

### Root Cause
`_uploadMetadata()` diam-diam GAGAL upload `metadata.json` ke cloud storage. `backup.sqlite.enc` berhasil di-upload, tapi `metadata.json` tidak ada. Fungsi ini punya `catch (_) {}` yang menelan semua error.

**Bukti:** Supabase Storage `nusa-backups` — SEMUA 8 varian HANYA punya `backup.sqlite.enc`, TIDAK ADA `metadata.json`.

### Alur Bug
1. User upload → `backup.sqlite.enc` ✅ → `metadata.json` ❌ (gagal diam-diam)
2. User reinstall → `hasBackup()` → download backup → decrypt → `_backupBelongsToVariant()`
3. `getBackupMetadata()` → download `metadata.json` → **404 NOT FOUND** → null
4. `metaVariant == null` → **return false** (v2.2.48 fix menolak backup tanpa metadata)
5. → `hasBackup()` return false → `checkBackupVariant()` → **wrongVariant**
6. → Dialog "Data Cloud Beda Varian" → suruh setup baru

### Fix
- **`_backupBelongsToVariant()`**: Kalau metadata null → **fallback ke sqlite inspection** (cek package name dari image_path). Hanya reject kalau metadata ADA tapi variantKey BEDA.
- **`_uploadMetadata()`**: Error di-log (`debugPrint`), bukan ditelan diam-diam.

---

## 📦 Teknis
- **Versi:** 2.2.51 (build 104)
- **Kompatibilitas:** Android 5.0+ (API 21)
- **Semua 8 varian:** kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis
