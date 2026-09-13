# Changelog v2.2.57+143

## Fitur Baru

### 1. Pure Realtime Sync 1-Jalur (Direct WS Delta Broadcast)
- **Zero-roundtrip D1**: Perubahan data kasir langsung dibroadcast ke peer socket WebSocket RoomDO (`delta_broadcast`).
- **Latensi <50ms**: Device peer langsung mengeksekusi `applyDirectDeltas` ke SQLite lokal tanpa menunggu HTTP pull dari D1.
- **Konservasi Kuota Cloudflare Free Tier**: Komunikasi peer-to-peer lewat WebSocket Hibernation mengonsumsi 0 HTTP request ke Worker, menjaga batas 100.000 req/hari tetap aman.
- **Anti-Echo & Idempotensi**: Eksekusi direct deltas dibungkus `setSyncMuted` untuk mencegah trigger SQLite memantulkan kembali data ke outbox. D1 tetap disimpan secara asinkron sebagai persistent event store untuk device offline.

### 2. Studio Desain Promosi (Canva Mini)
- **Menu Pengaturan -> TOKO -> Studio Desain Promosi** (tersedia untuk NUSA Pro & NUSA Lite).
- **Integrasi Produk Lokal**: Memilih produk langsung dari SQLite (`ProductRepository`), otomatis mengisi nama, foto produk, harga normal, harga diskon coret, dan nama toko.
- **Touch Canvas Interaktif**:
  - Pilihan rasio: 1:1 Feed (persegi) & 9:16 Story (tegak).
  - Pilihan preset tema: *Clean Modern*, *Diskon Heboh*, *Pastel Aesthetic*, *Dark Premium*.
  - Gestur interaktif drag-and-drop untuk memindahkan posisi elemen bebas di atas kanvas.
  - Penyesuaian tipografi (Poppins, Roboto, Inter, Courier), ukuran teks, dan skala foto produk.
- **Ekspor & Publikasi**:
  - Simpan gambar resolusi tinggi (pixel ratio 3.5x) via `RenderRepaintBoundary` ke galeri lokal.
  - Bagikan (Share) langsung via native sheet (`SharePlus`) ke WhatsApp, Instagram, atau Telegram.

## Redesign & Perbaikan UI

### 1. Redesign Screen Aktivasi (Pro & Lite)
- **Visual Bersih & Modern**: Menghapus seluruh emoji dan icon AI-slop; menggunakan flat logo resmi varian (`splashLogoPath()`).
- **Komparasi Paket Pro vs Lite**: Kartu perbandingan paket terstruktur (Pro: multi-device realtime, backup cloud, toko online; Lite: offline mandiri, single-device cepat).
- **Placeholder Payment Gateway**: Bottom sheet placeholder bersih (`@paymentgateway`) siap disambungkan ke gateway pembayaran.
- **Fix Ganti Akun Google**: Menambahkan `_signIn.signOut()` dan pembersihan secure cache sebelum membuka native Google Account Picker, menyelesaikan issue fallback loop akun yang sama.

### 2. Refactor Logika Absen Masuk & Presensi
- **Pemisahan Validasi Role vs Absen Masuk**: Menghapus auto-check-in dari validasi PIN login, lockscreen, setup completion, dan menu dashboard. PIN murni memvalidasi sesi role (`EmployeeSession`).
- **Pencegahan Bentrok Kas Awal/Akhir**: Absen masuk resmi dan input modal kas awal tetap terlindungi di modul Presensi.
- **Fix Tombol Absen Terpotong**: Menaikkan tinggi tombol dari 44px ke 48px dan menstandarkan padding vertikal di `attendance_screen.dart`, memastikan teks "Absen Masuk" dan "Absen Pulang" tidak terpotong bagian bawahnya.

## File Berubah
- `pubspec.yaml` — bump versi ke 2.2.57+143
- `lib/core/services/realtime_sync_service.dart` — direct delta broadcast & listener di WebSocket RoomDO
- `lib/core/services/delta_sync_service.dart` — direct deltas dispatch & apply via `applyDirectDeltas`
- `lib/core/activation/activation_screen.dart` — redesign layar aktivasi, Pro vs Lite cards, lepas auto check-in
- `lib/core/services/google_auth_service.dart` — panggil `signOut()` native & clear cache Google
- `lib/features/design_studio/promo_design_studio_screen.dart` — kanvas interaktif Studio Desain Promosi
- `lib/features/attendance/attendance_screen.dart` — perbaikan tinggi tombol & padding vertikal presensi
- `lib/features/dashboard/dashboard_screen.dart` — lepas auto check-in dari PIN pad switch role
- `lib/features/setup/setup_screen.dart` — lepas auto check-in pasca registrasi awal
- `lib/features/settings/settings_screen.dart` — navigasi menu Studio Desain Promosi
- `lib/app.dart` — routing `/desain_promosi`

## Verifikasi
- 105/105 Flutter unit tests lolos (0 failed).
