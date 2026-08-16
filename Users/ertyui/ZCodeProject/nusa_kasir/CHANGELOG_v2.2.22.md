# CHANGELOG v2.2.22+74 — Ukuran Struk Baru (15pt) + Diskon Subtotal & Font Kompak

Tanggal rilis: 2026-08-16 · Varian: kelontong (7 varian lain menyusul)

## 🔤 Ukuran Struk — Ada Ukuran "Sedang" Baru (15pt) + Perbaikan Cetak

- **Ukuran 15pt (label "Sedang") ditambahkan** — untuk header/nama toko yang
  panjang seperti **"Jatibarang Helmet"** (17 huruf): 12pt terlalu kecil, 18pt
  huruf "t" tidak muat dan turun ke baris bawah. 15pt dicetak sebagai font
  kompak ×2 yang ukurannya **tepat di antara 12 dan 18** — muat di satu baris
  dan tetap lebih besar dari 12pt.
- **Pengaturan struk kini punya 5 pilihan ukuran**: 12 (Kecil) · 15 (Sedang) ·
  18 (Normal) · 24 (Besar) · 36 (Extra Besar) — untuk Header, Rincian, dan
  Footer. Tes Cetak kalibrasi ikut mencetak 5 ukuran sekaligus.
- **Perbaikan cetak**: printer yang sebelumnya hanya mencetak 2 ukuran (batas
  perbesaran printer) kini tetap mendapat ukuran yang benar — setiap ukuran
  dicetak apa adanya sesuai pilihan, tanpa pemotongan diam-diam.
- **Printer otomatis dikembalikan ke Font Standar di akhir setiap struk** —
  mencegah struk berikutnya ikut berubah font.

## 🖨️ Font Kompak (Ramping) — Kini Aman di Semua Printer

- **Penyebab lama**: font kompak dikirim dengan perintah `ESC M 1` yang tidak
  diimplementasikan benar oleh banyak printer termal murah → hasil struk
  kosong/garbled di printer tertentu.
- **Sekarang**: struk selalu diakhiri dengan reset ke Font Standar, dan font
  kompak dipakai hanya jika benar-benar diperlukan (ukuran 15pt). Hasilnya
  **tidak ada lagi struk kosong/garbled** di printer clone mana pun.

## 🧾 Diskon Struk — Subtotal Sudah Dipotong + Diskon dalam Kurung

- **Subtotal per item kini menampilkan JUMLAH YANG SUDAH DIKURANGI DISKON**
  (qty × harga setelah diskon) — bukan lagi harga kotor sebelum dipotong.
  Konsisten dengan TOTAL di bawah.
- **Diskon ditampilkan dalam KURUNG di samping subtotal**, misal:
  ```
  Indomie Goreng
  2 x Rp3.500   ( -Rp1.000 )   Rp7.000
  ```
  Potongan jadi terlihat jelas oleh customer, tanpa baris tambahan yang
  membuat struk panjang.
- Berlaku di **semua tampilan**: cetak printer, preview struk di checkout,
  riwayat transaksi, pengaturan struk, serta teks share/PDF struk.

## 🐛 Perbaikan Teknis
- Konversi ukuran literal ditulis ulang: `literalSizes` = 12/15/18/24/36,
  `literalSpec` (perbesaran + font rekomendasi), `receiptPreviewSize` (ukuran
  preview yang match cetak — 15pt selalu 15px apa adanya).
- `magnificationToLiteral`/`literalToMagnification` diperluas ke 1-5x.
- Penjelasan pengaturan struk diperbarui (5 ukuran, preview = print).
