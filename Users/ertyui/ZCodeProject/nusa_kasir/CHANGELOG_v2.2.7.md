# NUSA Kasir v2.2.7+59 — Struk Lebih Andal, Login Responsif, Pembelian & Laporan Lengkap

## 🛠️ Perbaikan Utama
- **Login PIN tidak responsif** (komplain utama) — tombol PIN kadang tidak merespons saat ditekan, terutama di perangkat lambat / dark mode. Diperbaiki:
  - Tombol lebih besar (60px) + kontras lebih jelas di dark mode.
  - Animasi guncangan PIN salah kini hanya menggerakkan indikator titik, bukan seluruh keypad (sebelumnya seluruh tombol ikut rebuild tiap frame → tap tertelan).
- **Struk printer VSC / clone murah tidak muncul rincian** — akar masalah: rincian dipaksa memakai font "Kompak" (Font B) yang **tidak didukung printer murah** → rincian kosong/garbled. Sekarang default **Standar (Font A)** yang kompatibel universal.
- **Layout struk diubah sesuai permintaan**: nama item satu baris penuh, lalu di bawahnya `qty × harga` + total. (Sebelumnya: nama + qty + harga dalam satu baris → sering terpotong.)

## 🆕 Fitur Baru
- **Jenis Font Struk** — pilih **Standar** (paling kompatibel semua printer, direkomendasikan) atau **Kompak** (huruf ramping, lebih banyak per baris).
- **Ukuran Font per Bagian** — atur ukuran huruf **Header**, **Rincian**, dan **Footer** struk secara terpisah (Kecil/Normal/Besar).
- **Preview struk konsisten di semua menu** — preview di Pengaturan, Riwayat Transaksi (bagikan), dan struk checkout kini **persis dengan hasil print**: mengikuti nama toko asli + jenis & ukuran font yang dipilih. Bukan gimmick — apa yang dilihat = apa yang keluar di kertas.
- **Form Pembelian ditingkatkan**:
  - Kolom **Jumlah** & **Harga beli (opsional)** kini di **bawah nama item** (tidak lagi di samping kanan).
  - **Harga beli opsional**: kosong = pakai harga produk; **diisi = harga beli baru** — stok bertambah dan HPP/laba rugi ikut dihitung dengan harga baru (pembukuan otomatis benar).
  - Autocomplete nama **bahan** dari riwayat pembelian + tampilan kartu item lebih rapi.
- **Laporan Pengeluaran** — tab baru di menu **Laporan**: total pengeluaran periode, grafik pie + perbandingan per kategori, dan daftar pengeluaran lengkap.

## 💳 EDC / Kartu Debit — Cara Pakai
1. **Atur metode bayar**: saat checkout, pilih **"EDC / Kartu"** sebagai metode pembayaran.
2. **Saat kasir menekan EDC**, transaksi langsung dianggap **lunas penuh** (tidak perlu input nominal) — karena nominal di EDC mesin = total transaksi.
3. Struk akan menampilkan **"Bayar (EDC / Kartu)"** dengan nominal penuh; riwayat & laporan otomatis masuk ke metode **Kartu**.
4. **DP / Uang Muka** khusus metode **Tunai**: isi nominal DP → sisa otomatis dicatat sebagai **Piutang pelanggan**.
