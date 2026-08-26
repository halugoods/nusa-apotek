# NUSA v2.2.57+110 — Sinkronisasi Realtime + Komisi Capster + Update Wajib

## 🔄 Perbaikan Sinkronisasi Antar Device (paling penting)
- **AUTOSYNC DIPERBAIKI TOTAL** — akar masalah chip amber selalu menyala & data tidak
  terbackup otomatis sudah ditemukan dan dibereskan:
  - Metadata backup sekarang disimpan DI DALAM file backup terenkripsi (tidak bisa
    gagal senyap lagi).
  - Kalau cloud tidak bisa dibaca, app TIDAK menganggap "cloud lebih baru" —
    konflik tidak lagi menumpuk.
  - Semua jalur sync kini punya batas waktu 60 detik + status jelas
    (aman / gagal / sedang upload) — tidak ada lagi mode "menggantung selamanya".
- **Sinkron mendekati realtime antar device**: perubahan data di device A otomatis
  memberi tahu device B lewat push realtime (tanpa menunggu buka-tutup app).
  App juga menarik data terbaru tiap 30 detik + saat app dibuka kembali.
- Pesan konflik diperjelas: "Ada X cadangan otomatis lama tersimpan… aman dihapus".
- Copy UX "tunggu icon hijau sebelum hapus data" dihilangkan dari layar user.

## ✨ Fitur Baru Salon: Komisi Capster/Stylist
- **Komisi % per staf layanan** (default 10%) — diatur di form Karyawan.
- **Booking otomatis tercatat atas nama capster yang login** — transaksi layanan
  langsung teratribusi ke stylist yang melayani, siapa pun yang input.
- 4 laporan baru (menu Laporan → kartu "Kinerja Capster"):
  1. **Kinerja Capster** — omset, komisi, jumlah transaksi per capster + pilih periode.
  2. **Detail per Capster** — rincian tiap transaksi yang ditangani.
  3. **Bayar Komisi** — tandai komisi yang sudah dibayar (tidak muncul dobel).
  4. **Pendapatan Saya** — capster melihat omset & komisi sendiri (kartu di menu Presensi).

## 🧹 Perbaikan Lain
- Dropdown filter karyawan di Laporan & Transaksi dibuat pipih (sejajar card switch).
- Field Stok/Kadaluarsa disembunyikan di form Layanan (tab Layanan).
- Notifikasi update lonceng: tombol download langsung membuka browser.

## 📢 Sistem Update Wajib (untuk admin)
- Dashboard web: lihat versi app tiap user + badge "Stale" (>7 hari offline).
- Dashboard web: set versi minimum per produk → app di bawah versi itu diblokir
  dengan popup update wajib (download via browser eksternal).

> Catatan aktivasi server: jalankan migration `0017_app_version_tracking.sql`
> di Supabase SQL Editor agar fitur tracking versi aktif.
