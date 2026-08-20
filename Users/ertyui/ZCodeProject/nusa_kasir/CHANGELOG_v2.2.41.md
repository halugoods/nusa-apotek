# NUSA v2.2.41+94 — Data restore dari cloud sekarang BENERAN TERLOAD

Komplain setelah v2.2.40: **dialog "Data Ditemukan" sudah muncul, restore sukses ("Data berhasil dipulihkan"), tapi data tidak terload — dashboard kosong / loading terus.**

## Akar masalah (KETEMU + DIPERBAIKI)

Backup cloud lama (dibuat oleh app versi lama, contoh nyata: backup fnb 9 Agustus) punya `user_version` database = 44 — **sama** dengan versi app sekarang. Padahal beberapa kolom di backup itu bernilai **NULL**:

- `products.discount_percent` → **NULL** (bukan 0)
- `products.discount_type` → **NULL** (bukan 'persen')
- `products.price_type` → **NULL** (bukan 'pcs')
- dll.

Kolom ini dibuat oleh app versi lama **tanpa DEFAULT**, jadi semua baris lama NULL. Drift hanya menjalankan migrasi saat `user_version` **berubah**; karena backup sudah 44 = versi sekarang, migrasi di-**skip** → NULL tidak pernah diisi.

Saat app membaca produk, drift memetakan kolom non-nullable dengan `!` → NULL → **"Null check operator used on a null value"** → query `getProducts()` melempar error → dashboard tidak bisa selesai load → **data kosong / loading abadi**. Ini berlaku untuk SEMUA user yang backup cloud-nya dibuat oleh app versi lama, bukan hanya akun tertentu.

## Perbaikan v2.2.41

### 1. Repair NULL otomatis SETIAP buka database (`beforeOpen`)
- Drift punya hook `beforeOpen` yang jalan **setiap** database dibuka — bukan hanya saat migrasi.
- Sekarang setiap buka: NULL di `discount_percent` → 0, `discount_type` → 'persen', `price_type` → 'pcs', `category` → 'Lainnya', `transactions.status` → 'Normal', `employees.role`/`status`, `cashier_sessions.starting_cash`, `transactions.items` → '[]', dll. di-backfill otomatis.
- Idempoten & ringan (hanya baris yang NULL yang di-update) → aman untuk DB bersih sekaligus DB hasil restore lama.

### 2. Tabel hilang di backup lama dibuat otomatis
- Backup dari varian lain / app lama bisa kehilangan tabel (mis. `roles`, `open_tabs`, `stock_counts`). Query ke tabel yang tidak ada → "no such table" → error. Sekarang tabel-tabel ini dibuat otomatis kalau hilang (`CREATE TABLE IF NOT EXISTS`).

### 3. Verifikasi beneran (bukan asumsi)
- Test baru membuka **backup asli hasil decrypt** (fnb + kelontong) dengan drift persis seperti di device → SEMUA query dashboard (produk, transaksi, karyawan, cabang, piutang, roles) jalan tanpa error.
- Total **48 test pass**.

## Cara pakai
Install APK baru di atas versi lama → login akun → dialog "Data Ditemukan" → Ya, Buka Toko Ini → kali ini **data produk/transaksi/karyawan benar-benar keluar**.

> Setelah update, backup cloud berikutnya akan tersimpan dengan nilai default yang benar (0/'persen'/'pcs'), jadi masalah NULL ini tidak akan muncul lagi di backup baru.
