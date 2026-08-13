# NUSA Kasir v2.2.11+63 — Struk Rapi, Validasi Aman, dan Semua Varian Ter-update

> Rilis ini juga membawa update yang sempat tertinggal dari v2.2.8+60 s/d v2.2.10+62
> ke **seluruh 8 varian** (kelontong, FnB, laundry, bengkel, salon, apotek, fotocopy, servis) — sekarang semuanya versi sama.

## 🧾 Struk — Baris Rincian Sama Persis dengan Preview
- **qty × harga di KIRI, subtotal di KANAN** — baris rincian item kini **persis seperti preview di layar** (checkout, riwayat, pengaturan): qty×harga menempel kiri, subtotal menempel kanan, **sejajar persis dengan nominal TOTAL** di bawahnya. Sebelumnya subtotal menggantung di tengah karena salah posisi.
- Untuk rincian **Besar (2x)**: qty×harga baris sendiri di kiri, subtotal baris sendiri di kanan.
- Apa yang dilihat di preview = apa yang keluar di kertas (konsisten semua ukuran kertas 58mm/80mm, font Standar/Ramping).

## 🛡️ Void & Retur — Validasi Bisa Pakai Fingerprint (FP) / NFC
- Konfirmasi **Void** dan **Retur** kini selain PIN juga mendukung **fingerprint (FP)** dan **kartu NFC** — sama seperti pin pad di Pengaturan.
- Kasir tidak harus hafal PIN lagi untuk void/retur: bisa tap sidik jari atau tempel kartu NFC.

## 🚨 Perbaikan Kritis (dari update tertinggal)
- **Aplikasi "mati" setelah sinkronisasi cloud** (menu tidak berfungsi, PIN selalu gagal) — akar masalah: restore backup menimpa database yang sedang dipakai. Diperbaiki: backup ditukar aman di peluncuran berikutnya + file sisa WAL/SHM dibersihkan. **Semua jalur restore diverifikasi aman.**
- **Login PIN tidak responsif** — tombol lebih besar, animasi guncangan tidak mengganggu tombol.
- **Struk printer VSC/clone murah tidak muncul rincian** — default font **Standar (Font A)** kompatibel universal.

## 🆕 Fitur dari update tertinggal
- **Jenis & Ukuran Font Struk** — Standar/Ramping + ukuran Header, Rincian, Footer per bagian.
- **Preview struk 2 arah** (58mm/80mm) di semua menu, match hasil print.
- **Diskon per item + total diskon** tampil lengkap di struk.
- **Pembelian**: harga beli opsional + autocomplete bahan + laporan pengeluaran.
- **Keypad PIN dukung keyboard fisik** (Bluetooth/wireless).
- **Bantuan & Masukan via WhatsApp** (0897-6280-303).

## Cara tes
1. Kasir → checkout beberapa produk → cek **preview struk**: qty×harga kiri, subtotal kanan, sejajar TOTAL → cetak & samakan.
2. Riwayat Transaksi → **Void** & **Retur** → konfirmasi pakai **FP** (sidik jari) atau tempel **kartu NFC**, atau PIN biasa.
3. Pengaturan → Struk → coba rincian Kecil/Besar + font Standar/Ramping.
4. Buka di semua perangkat (HP/tablet) — sinkronisasi cloud aman.
