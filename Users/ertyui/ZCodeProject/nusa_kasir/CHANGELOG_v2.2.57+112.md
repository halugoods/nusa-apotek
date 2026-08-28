# NUSA v2.2.57+112 — Login Email/Password + Redesign Total Tampilan

## 🔐 Login Email & Password (baru)
- **Login pakai email + password** di layar aktivasi — selain login Google.
  Backend pakai **Supabase Auth** beneran (bukan simulasi), aman & terhubung
  dengan lisensi yang sudah ada.
- Form login rapi: email + password, **"Ingat saya"** (otomatis login di
  pembukaan berikutnya), dan **"Lupa password?"** → email reset dikirim ke
  inbox.
- **"Belum punya akun? Daftar"** di bawah form login → form daftar
  (email + password + ulangi password). Akun baru langsung bisa aktivasi
  lisensi seperti akun Google.
- "Masuk dengan Google" tetap tersedia sebagai kartu terpisah.
- Akun email memakai UID stabil yang sama fungsinya dengan ID Google untuk
  backup cloud & lisensi — **tidak memecah jalur backup lama**.

## 🎨 Redesign Layar Aktivasi & Lisensi
- **1 aset logo konsisten** di semua layar (login, aktivasi, PIN, key lisensi,
  quick setup) — hapus semua ikon lingkaran toko/roket/gembok yang beragam.
- Subtitle "aplikasi kasir untuk..." dipertebal (medium) + kontras dinaikkan
  (palet abu-abu gelap) supaya mudah dibaca.
- Copywriting standar tanpa emoji — hilangkan "Masuk ke NUSA", "🎉", dsb.
- **Akun yang lisensinya Canceled/Suspended** sekarang balik ke layar
  "Sudah punya lisensi / Belum punya lisensi" (bukan layar perpanjangan),
  dengan pesan alasan yang jelas.
- Layar "Perpanjang / Beli Lisensi" (trial expired) didesain ulang dengan
  logo aset + info tenggang waktu tetap.

## 🏪 Layar Data Toko Baru
- Menu **Pengaturan → Data Toko**: isi informasi toko lengkap — nama toko,
  no. HP/WhatsApp, alamat (multiline), plus nama pemilik.
- Jarak antar kolom dilonggarkan (20–24px) supaya tidak berdesakan.
- Aman: kolom `store_phone` & `store_address` memang **sudah ada** di tabel
  Settings — tidak ada perubahan struktur database (restore backup lama tetap
  aman, tidak ada risiko login loop).

## 🧩 Pengaturan Didesain Ulang (Material 3)
- **Ikon 1 tone** — semua ikon menu memakai warna tema (hapus ikon
  multi-warna yang ramai).
- **Card-based grouping** — menu yang berelasi dibungkus 1 kartu, dipisah
  garis tipis (gaya Material 3).
- **Label kategori huruf kapital tebal** di atas tiap grup kartu (TOKO,
  TAMPILAN, KEAMANAN, DATA, PERANGKAT, BANTUAN, TENTANG APLIKASI).
- Subtitle/helper text dipergelap agar lebih mudah dibaca; jarak antar grup
  kartu dilebarkan.

## 🔄 Lain-lain
- Quick setup tanpa emoji/ikon dekoratif — logo konsisten + teks polos.
- Halaman web **reset-password** baru di nusa-online (user setel password
  baru setelah klik link di email) — sudah live di https://nusa-online.vercel.app/reset-password
- Versi APK naik 2.2.57+111 → 2.2.57+112 (patch tampilan & fitur, alur
  lama tidak berubah).
