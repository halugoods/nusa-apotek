# Changelog v2.2.53 (Build 106)

## 🎉 Fitur — Tab Tutorial Terhubung ke Cloud
- Menu **Pengaturan → Tutorial** (bagian BANTUAN) sekarang membuka layar daftar
  tutorial yang isinya **dikelola dari web**
  (`nusa-online.vercel.app/dashboard` → tab Tutorial).
- Kartu video statis versi lama dihapus — konten tutorial sepenuhnya dari cloud,
  admin upload sendiri (link YouTube + judul + thumbnail + pilih varian).
- App menampilkan daftar sesuai varian (`variants contains productId`);
  fallback ke daftar statis bila cloud kosong; pull-to-refresh tersedia.

## 🎨 UI — Halaman Pembayaran QRIS Light Mode
- Halaman `/pay` (InstanPay QRIS) tidak lagi dark mode — sekarang mengikuti
  **design system NUSA Kasir**: latar terang `#F7F7F9`, kartu putih rounded-xl
  dengan shadow card, aksen oranye primary, tipografi Plus Jakarta Sans.
- Logo NUSA digambar ulang sebagai lingkaran tinted (tanpa aset baru).
- Semua state (QR, countdown, sukses, kadaluarsa, error) ikut token warna
  success/error/warning design system.

## 🗑️ Hapus — Popup Chat CS Nusa (web)
- Tombol chat melayang "CS Nusa" di halaman publik web dihapus — fitur tersebut
  hanya untuk internal, bukan untuk pengunjung.

## 🐛 Fix — Ganti Akun Google di Layar Aktivasi
- **Gejala:** tombol "Ganti Akun Google" tidak memunculkan pemilih akun —
  langsung memeriksa lisensi akun yang sama, jadi ganti akun harus hapus data
  aplikasi dulu.
- **Akar masalah:** `google_sign_in.signIn()` memakai akun OS yang sudah cached
  tanpa menampilkan account picker.
- **Fix:** tombol sekarang menjalankan `signOut()` (disconnect) dulu, lalu sign-in
  ulang → picker akun Google muncul.

---

## 📦 Teknis
- **Versi:** 2.2.53 (build 106)
- **Kompatibilitas:** Android 5.0+ (API 21)
- **Semua 8 varian:** kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis
