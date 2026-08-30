# NUSA v2.2.57+115 — Rilis Besar: Barcode Label, Lisensi, AI Cloud, Autosync, Backup Aman

Versi utama tetap **2.2.57** — hanya build number naik ke **+115**. Berlaku untuk **semua 8 varian** (kelontong, F&B, laundry, bengkel, salon, apotek, fotocopy, servis).

---

## 🏷 Cetak Label Barcode (menu Produk → "Cetak Label")
- **3 jalur cetak:** Thermal Label (TSPL — kompatibel Rongta/HPRT/Godex/Blueprint), Thermal Struk 58mm (ESC/POS), PDF A4 grid (opsi ukuran label, Share/Unduh).
- Layout label dirombak: **barcode di atas (pendek & di tengah) → nama produk → harga di bawahnya**, semua center — setiap label sesuai dengan produknya (tidak ada nama produk lain menempel di barcode).
- **Preview real** sebelum cetak (render dari mesin yang sama dengan hasil cetak — persis seperti preview struk).
- Barcode di **card produk** (grid, list, per-kategori) — cek cepat tanpa buka edit.

## 🛠 Perbaikan setelah uji coba (umpan balik user)
- **Card produk grid 2×2:** icon edit/hapus tidak lagi meluber keluar card walau nama produk 2 baris.
- **Duplikat nama/harga di label struk dihapus** (sebelumnya tercetak ganda — dari teks + bitmap).
- **AI insight dihapus dari homescreen** — fitur AI belum final, kartu tidak ditampilkan dulu.
- **Spacing icon header (cloud-notif-branch-logout) diseragamkan** — semua ikon 44×44 + gap 8px.
- **Izin Android memakai dialog native sistem** (kamera, notifikasi, penyimpanan, bluetooth) — bukan dialog buatan sendiri, jadi permission benar-benar aktif di instal pertama.

## 📜 Lisensi & Aktivasi
- **Status "Suspended" dihapus** (status mati yang tidak pernah dipakai) — tersisa Generated/Trial/Active/Expired/Cancelled.
- **Action `set_status`** di license-manager (nusa-online) + tombol "Ubah Status" di dashboard admin.
- **Fix bug `can_activate`:** key expired tidak lagi memblokir upgrade akun yang sama.

## 🤖 AI Chat — Pindah Penuh ke Cloud (nusa-online)
- **Streaming SSE** saat mengetik (bukan loading diam).
- **Tool-calling data toko:** omzet, produk terlaris, stok menipis, pelanggan, piutang.
- **Provider configurable** (base_url/api_key/model) dari dashboard nusa-online (tab AI) + tombol Test.
- **Riwayat chat tersimpan di cloud** (bukan hanya perangkat) — bisa dilanjutkan dari perangkat mana pun.
- **TIDAK termasuk:** suara & saran harga (sesuai rencana).

## 🔄 Autosync & Backup
- **Unifikasi identitas** (Area I): satu canonical UID (email UUID dulu, lalu Google 21-digit) — backup dari device lama tetap bisa dipulihkan ke device baru.
- **Tolak restore backup dari versi lebih baru** (Area J): pesan jelas "Backup dari versi lebih baru — update app dulu" mencegah DB corrupt / gagal login.
- **Versi terpasang dibaca dari APK asli** (package_info_plus) — badge "Terpasang" di riwayat update akurat.
- **Teks sinkronisasi akurat:** push 1,2 dtk / coalesce 10 dtk / pull 30 dtk (bukan "±6 dtk").
- **Card transaksi:** kasir pindah ke baris bawah tanggal; ikon "100" = pembayaran tunai.
- **Header dashboard:** stats card menampilkan nama cabang aktif.

## 📱 Update & Notifikasi
- Notif update via `app_ping` (versi lama bisa tahu versi baru) + dedup by build number.

## ⚠️ Perlu Aksi User (Supabase SQL Editor)
Jalankan 2 file migration ini di SQL Editor Supabase (sekali saja):
- `0018_remove_suspended.sql` — hapus status lisensi Suspended
- `0019_ai_tables.sql` — tabel `ai_settings` & `ai_chat_history` untuk AI chat cloud

## 📦 Download
APK per varian ada di masing-masing repo release (kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis).
