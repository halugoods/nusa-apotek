# Changelog v2.2.50 (Build 103)

## 🔐 "Lupa PIN?" di Semua Layar (A5)

**Masalah:** "Lupa PIN?" hanya ada di login_screen. Di activation, dashboard, dan settings, user yang lupa PIN tidak bisa recover.

**Solusi:** "Lupa PIN?" sekarang ada di 5 tempat:

1. **login_screen** — sudah ada dari v2.2.43
2. **activation_screen** — tombol "Lupa PIN?" di bawah PinKeypad → Google re-auth → PIN baru
3. **pin_dialog** — parameter `onForgotPin` baru → tombol "Lupa PIN?" muncul otomatis di dialog
4. **dashboard_screen** — 2x PinDialog.show → `onForgotPin` → Google re-auth → PIN baru
5. **settings_screen** — PinDialog.show → `onForgotPin` → Google re-auth → PIN baru

Semua flow: Konfirmasi → Google re-auth (cek akun pemilik) → PIN baru (4-6 digit) → sukses.

## 🎥 Tutorial Video di Menu Tutorial

- Kartu "Produk" di TutorialScreen sekarang ada badge play icon
- Tap kartu → buka video YouTube (https://youtube.com/shorts/ElvYpqUIRpE)
- Lainnya nyusul

## 📦 Ringkasan Semua Fix (v2.2.48–v2.2.50)

| Fix | File | Sejak |
|-----|------|-------|
| PIN repair setelah restore | restore_backup_flow.dart | v2.2.48 |
| Reject old backup tanpa variantKey | activation_repository.dart | v2.2.48 |
| "Lupa PIN?" 5 tempat | pin_dialog + activation + dashboard + settings | v2.2.50 |
| Tutorial produk video | tutorial_screen.dart | v2.2.49 |

## 📦 Teknis
- **Versi:** 2.2.50 (build 103)
- **Kompatibilitas:** Android 5.0+ (API 21)
- **Semua 8 varian:** kelontong, fnb, laundry, bengkel, salon, apotek, fotocopy, servis
