# NUSA v2.1.5+51 — Changelog

> **⚠️ PENTING untuk pemakai v2.1.4+50:** rilis ini memperbaiki bug login yang
> terjadi setelah update ke v2.1.4+50 di perangkat yang sudah memiliki data.
> Instal langsung di atasnya (tidak perlu uninstall).

## 🔴 Fix Kritis

- **Login tidak bisa masuk setelah update** (PIN manual, biometrik, dan NFC
  semuanya gagal) — penyebab: migrasi database v34 memakai nama kolom yang
  salah di perintah backfill SQL. Sekarang diperbaiki, dan ditambah tes
  regresi supaya tidak terulang.

## ✨ Perbaikan Lain (ikut terbawa dari v2.1.4+50)

1. **PIN override Owner/Manager** — PIN pemilik bisa membuka layar yang
   butuh PIN saat kasir lupa, tanpa mengganti sesi.
2. **Sales per kasir** — omzet dashboard dihitung per kasir yang sedang
   aktif; ganti pengguna diblokir saat kasir masih buka.
3. **RBAC sync** — pengaturan role ikut backup/restore cloud (phone ↔ tablet
   tetap sama).
4. **Remember PIN 8 jam** — login lebih cepat, sesi aman via masa berlaku.
5. **Biometrik Face ID** — dukungan ikon/label generik untuk perangkat
   dengan Face ID (bukan hanya sidik jari).
6. **Printer** — auto-print pakai alamat tersimpan, koneksi lebih stabil
   (retry + reconnect per chunk), logo struk memakai bit-image (tidak
   rusak/terpotong).
7. **Barcode** — input manual kode barcode sebagai cadangan saat kamera
   bermasalah (di Kasir, Produk, dan Stok).
8. **Struk** — pengaturan struk tersinkron antar perangkat; logo struk
   benar-benar dihormati.

## Cara Pasang

Unduh APK varian sesuai usaha Anda, lalu **install di atas versi lama**
(File → Install, atau klik APK di HP). Data tetap aman.
