# CHANGELOG v2.2.31+83 — Fix Metode Bayar Terpotong di Struk (label DINAMIS)

Tanggal rilis: 2026-08-18 · Varian: kelontong (7 varian lain menyusul)

## 📋 RINGKASAN

Putaran koreksi struk **v2.2.30** ternyata belum tuntas: saat dicetak,
keterangan metode bayar masih terpotong menjadi **"Bayar (T...."**. Akar
masalahnya bukan format kurung, tapi **batas potong statis 11 karakter** pada
kolom label di jalur cetak — "Bayar: Tunai" (12 karakter) tetap lewat batas
itu. Versi ini mengganti batas statis dengan **lebar kolom dinamis**:
label tidak pernah dipotong lagi, printer otomatis membungkus ke baris
berikutnya bila terlalu panjang, jadi tidak ada teks yang hilang.

## 🔧 PERBAIKAN

- **Label metode bayar tidak pernah terpotong lagi** — kolom label di baris
  Total / Bayar / Kembalian kini dihitung dinamis dari isi (label ambil sisa
  lebar baris, minimal 4 unit; nominal sejajar kanan tetap). Semua metode:
  Tunai, QRIS, Transfer, EDC / Kartu — tampil penuh.
- **Tidak ada lagi truncation diam-diam** — sebelumnya `fitReceipt(label, 11)`
  memotong "Bayar: Tunai" menjadi "Bayar: Tun…" sebelum dikirim ke printer.
  Sekarang teks dikirim utuh; printer (esc_pos_utils) membungkus ke baris
  berikutnya bila melebihi lebar kolom, bukan memotong.

## 🧪 TES

- **43 unit test lulus** (3 baru untuk jalur CETAK/renderBytes: label utuh di
  struktur bagian untuk 4 metode, renderBytes tidak error, dan label TIDAK
  mengandung tanda potong "…" di bytes cetak).
- Test sebelumnya hanya memeriksa jalur share teks (renderText) — itulah
  kenapa bug ini lolos di v2.2.30. Sekarang jalur print juga dites.
- `flutter analyze` 0 error.
