# CHANGELOG v2.2.10+62 — Rilis 2026-08-14

## Struk: rincian item rata kanan (sejajar kolom TOTAL)

- **qty×harga + subtotal kini rata kanan** — baris rincian (Kecil) menempel
  ke tepi kanan kertas, sehingga **subtotal sejajar persis dengan nominal
  TOTAL** di bawahnya. Sebelumnya rincian rata kiri sehingga subtotal
  menggantung di tengah dan tidak nyambung dengan kolom TOTAL.
- Untuk rincian **Besar (2x)**, baris qty×harga dan baris subtotal sama-sama
  rata kanan — keduanya ikut geser kanan sebagai satu pasangan.
- Preview di layar (checkout, riwayat, pengaturan struk) sudah match dengan
  hasil cetak.

## Cara tes

1. Buka Kasir → pilih beberapa produk → checkout.
2. Cek preview struk: subtotal tiap item rata kanan, sejajar dengan nominal
   TOTAL.
3. Cetak struk (bluetooth/USB) → pastikan hasil print sama.
4. Pengaturan → Struk → coba rincian **Kecil** dan **Besar** + jenis font
   **Standar / Ramping**.
