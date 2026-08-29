# Design — Rilis Besar NUSA Kasir (Area A–J)

- Tanggal: 2026-08-28
- Status: Disetujui user (plan mode)
- Versi: `2.2.57` terkunci, build number naik (rencana `+115`)
- Repo: `nusa_kasir/` (Flutter app, 8 varian) + `nusa-online/` (Supabase edge functions + web admin)

## Ringkasan

Sepuluh area hasil brainstorming. Urutan eksekusi: A → C → E/F/G → D → J → I → B → H.
Build 8 varian + rilis GitHub = keputusan terpisah setelah semua area siap.

---

## A. Kode barcode di card produk

**Tujuan:** kasir cek kode barcode cepat tanpa buka edit produk.

- File: `nusa_kasir/lib/features/products/products_screen.dart` (`_ProductGridCard`, `_ProductListCard`), `nusa_kasir/lib/features/products/products_by_category_screen.dart` (`_ProductCard`).
- Perubahan: baris `• <kode>` (fontFamily `monospace`, fontSize 10, warna `textTertiary`/`darkTextTertiary`, maxLines 1, ellipsis) di bawah kategori. Hanya render jika `product.barcode` tidak null/kosong.
- Konsisten dengan gaya form produk (`product_form_screen.dart:1129`).
- Risiko: minimal (widget-only).

## B. Cetak label barcode

**Tujuan:** user mencetak label harga produk (nama + harga + barcode), 3 jalur, isi label dinamis.

- **Alur:** tombol "Cetak Label" di toolbar Daftar Produk → Sheet 1 pilih produk (checkbox + "Pilih Semua", item menampilkan nama+harga+barcode) → Sheet 2 pilih **isi label** (checkbox dinamis: Nama / Harga / Barcode, bebas kombinasi) → Sheet 3 pilih jalur:
  1. **Thermal Label (TSPL)** — printer label khusus (Rongta/HPRT/Godex/Blueprint). Layer **TSPL/TSPL2 generik** (kompatibel semua merk), koneksi BT via `BluetoothUtils` yang ada.
  2. **Thermal Struk 58mm** — printer struk yang sudah dimiliki: ESC/POS `GS k` (`Generator.barcode(BarcodeType.code128, height, textPos: below)`) + teks nama/harga + feed/cut per label.
  3. **PDF A4 grid** — `package:pdf` (preseden `id_card_renderer.renderBatch`): grid label (default 40×30mm, opsi lain), Share/Unduh. Satu lembar = banyak label, siap digunting.
- File baru: `lib/core/label/label_renderer.dart` (renderer + TSPL byte builder), `lib/features/products/label_print_sheet.dart` (alur 3 sheet). Setting printer label terpisah (SecureStore key baru).
- Risiko: TSPL perlu uji hardware. Mode test tanpa printer (output hex/PDF). Konfirmasi merek printer user saat implementasi.

## C. Lisensi

**Tujuan:** sederhanakan status, beri admin kontrol manual, perbaiki bug upgrade akun sama.

- **Hapus status Suspended** — dead status (tidak pernah di-SET, hanya di block-list & statistik). Dihapus dari: constraint DB (`0005_status_rename.sql:22`), `can_activate` (0005:46-49,72), `register_activation` (filter/message), `license-manager` stats (nusa-online:565, nusa_kasir:641), dashboard UI (type `LicenseStatus`, badge, stat card, filter, cancel-guard), app Flutter (main.dart:486, activation_screen:654,660, dashboard:2642,2667, settings:1441,1448). Tersisa: Generated/Trial/Active/Expired/Cancelled.
- **Action `set_status`** di `license-manager` (copy nusa-online yang ter-deploy): `{license_id, status, reason?}` → validasi status diizinkan + insert `license_events` (event `admin_set_status`, detail reason). Tombol "Ubah Status" di dashboard admin (termasuk restore key auto-revoke → Active).
- **Fix bug `can_activate`** (migration baru, DDL di SQL Editor user): urutan cek dibenahi — owner-sama boleh lanjut (perpanjang/upgrade) sebelum cek expired. Key expired tidak lagi memblokir akun yang sama.
- Backup 1-bulan: verifikasi tidak ada delete saat expired (memang tidak ada) — tanpa perubahan.
- Migration baru `0018_remove_suspended.sql` + `0019_can_activate_fix.sql` (DDL user jalankan). Edge function di-deploy CLI (otomatis).

## D. Update notification + versi asli

**Tujuan:** "versi terpasang" akurat + notif update sampai ke versi lama.

- **Bug +114:** versi terpasang dibaca dari konstanta build (`NusaConfig.appBuildNumber`) bukan APK asli → app berbohong.
- Fix: tambah `package_info_plus` → baca versi APK beneran → badge "Terpasang" di riwayat update (`settings_screen.dart` `_UpdateHistorySheet`, `isCurrent` compare).
- **Notif update via `app_ping`**: versi lama dapat tahu versi baru (edge function `app_ping` diperluas: return `latest_version` per product) + dedup notif by build number.
- Risiko: dependency baru → `flutter pub get` semua varian saat build.

## E. Teks sinkronisasi

- `settings_screen.dart:655-657`: "±6 dtk" → angka asli dari `auto_sync_service.dart`: push **1,2s** (debounce, burst) / **10s** (coalesce) / pull **30s**.
- Tanpa perubahan perilaku.

## F. Card transaksi

- `transactions_screen.dart`: kasir dipindah ke baris baru **di bawah tanggal**. Pisah string `'$relDate • ${tx.paymentMethod}'` menjadi: baris 1 = tanggal, baris 2 = metode + kasir (ikonic person).
- Ikon "100" = `Icons.money_rounded` (uang kertas, penanda Tunai) — **bukan bug**, didokumentasikan, tidak diubah.

## G. Header dashboard

- `dashboard_header.dart`: seragamkan spacing icon header menjadi **8px** (cloud chip, bell, branch icon, logout). Saat ini tidak konsisten (padding 6 / gap 0 / 4 / 4).
- `dashboard_screen.dart` + `profile_stats_card.dart`: **stats card tampilkan nama cabang yang dipilih** ("Cabang: <nama>" / "Semua Cabang"). Data sudah di-scope per cabang, hanya label yang kurang.

## H. AI Chat (besar)

**Tujuan:** pindah penuh ke cloud Supabase, AI paham data toko, admin kontrol provider, riwayat cloud, insight proaktif.

- **Keputusan:** hapus dependensi server lokal Nusa CS (repo dipertahankan, tidak dipakai). Model dibayar dari API key developer (server Supabase), admin tetap bisa ganti provider via dashboard.
- **Edge function `ai-assistant` di-upgrade** (nusa-online copy, yang ter-deploy):
  - **Streaming SSE** (respons bertahap).
  - **Tool-calling data toko** — tools: omzet hari ini/bulan ini, top produk, stok menipis, daftar produk, pelanggan, piutang. Jawaban berdasar data beneran (service role). Tool registry app sudah 60% ada (`lib/core/agent/agent_tools.dart`) tapi mati — diaktifkan/dipindah.
  - **Provider configurable** dari tabel baru `ai_settings` (`base_url`, `api_key`, `model`, `enabled`). Default = key developer. Fallback rule-based saat AI gagal.
- **Tab "AI" baru di dashboard nusa-online** — set base URL/API key/model + tombol Test (kirim ping, tampilkan respons).
- **App Flutter:** streaming UI, **riwayat chat cloud** (per akun, nyambung antar device — sekarang lokal SQLite), **insight proaktif** (kartu saran dashboard + **rangkuman harian otomatis** → notif; generate via scheduled trigger).
- **TIDAK termasuk:** suara, saran harga.
- Risiko: terbesar. Perlu endpoint test + batas pemakaian.

## I. Autosync unify

**Tujuan:** antar device beda role login tetap sync.

- **Root cause (audit):** login Google (UID 21-digit) vs email Supabase (UID UUID) = dua identitas → dua path backup → tidak nyambung.
- Fix: **satu canonical UID** saat login + **migrasi path backup lama** ke path baru kalau beda.
- Risiko: migrasi path hati-hati (jangan dobel/kehilangan backup). Uji manual dua device beda role.

## J. Kompatibilitas backup antar versi (prioritas tinggi)

**Tujuan:** cegah "ga bisa login pin" karena backup dari versi lebih baru.

- Backup dari versi **lebih baru** ditolak saat restore dengan pesan jelas ("Backup dari versi lebih baru, update app dulu").
- Pakai metadata `appVersion` embedded (sudah ada di arsip NUS1, `metadata.json` → `appVersion: 2.2.57+114`).
- Berlaku di `restoreDirect()` (`activation_repository.dart`) + jalur restore lainnya.

---

## Di luar scope
- Build 8 varian + rilis GitHub (keputusan terpisah).
- Suara & saran harga AI.
- Server lokal Nusa CS (dipertahankan repo-nya, tidak dipakai).

## Yang butuh aksi user
1. Jalankan migration DDL di Supabase SQL Editor (saya buatkan .sql) — area C & H.
2. Deploy edge function via CLI (otomatis, saya jalankan).
3. Konfirmasi merek/model printer label saat area B (uji TSPL).
4. Uji AI setelah deploy (endpoint test).
