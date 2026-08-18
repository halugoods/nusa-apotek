# CHANGELOG v2.2.34+86 — Fix Migrasi "Duplicate Column order_type" + Hapus Label "Dalam Pengembangan"

## 🐛 Fix Kritis: Migrasi DB Self-Healing

**Gejala**: saat setup/buat PIN di 7 varian muncul error
`SqliteException: duplicate column name: order_type ... ALTER TABLE "transactions" ADD COLUMN "order_type"`.

**Akar masalah**: DB yang dibawa device (hasil restore cloud / backup lama) bisa
punya struktur kolom yang SUDAH ADA (mis. `order_type`) padahal `user_version`
masih di bawah target. Drift lalu menjalankan `ALTER TABLE ... ADD COLUMN` lagi
→ error duplicate column → migrasi gagal → aplikasi tidak bisa dipakai.

**Fix**:
- Semua `ADD COLUMN` di migrasi kini di-guard dengan `PRAGMA table_info`:
  kolom sudah ada → dilewati; belum ada → ditambahkan (idempoten, tidak
  menyentuh data).
- Semua `CREATE TABLE` kini memakai `IF NOT EXISTS`.
- Seed `print_service_types` hanya berjalan saat tabel kosong (tidak dobel).
- Berlaku ke **semua 8 varian** — kelontong tetap identik.

## ✨ Perubahan UX

- Hapus label/badge **"Dalam Pengembangan"** pada menu Spreadsheet & AI Chat
  (dashboard, Kelola Fitur, dan layar pembuka) — fitur dibuka normal tanpa
  status pengembangan.

## 🧪 Testing

- 47/47 test pass (4 test baru: regresi self-healing migrasi).
- `flutter analyze` 0 error.
