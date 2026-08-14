# NUSA Kasir v2.2.13+65 — Perbaikan UX dari Hasil Tes Kelontong

> Rilis **kelontong saja** — 7 varian lain (FnB, laundry, bengkel, salon, apotek,
> fotocopy, servis) ditunda sampai kamu selesai mengetes versi ini. Semua perbaikan
> di bawah berdasarkan hasil pemakaian langsung di toko.

## 🎨 Menu Produk & Karyawan — "State Baru" (slide-up drawer)
- **Tambah/Edit Produk** sekarang berupa panel geser dari bawah (slide-up drawer) dengan kartu form yang rapi — **label di ATAS field**, bukan di dalam field — konsisten dengan Tambah Pelanggan & Tambah Supplier.
- **Tambah/Edit Karyawan** ikut di-upgrade ke state yang sama (title lebih tegas, dropdown & tombol konsisten).

## 📦 Menu Stok — Ringkas & Tanpa Modal
- Filter tinggal **2 pilihan: Menipis / Habis** (mode "Semua" dihapus — sesuai permintaan).
- Tampilan produk punya **3 pilihan** seperti layar POS: list 1 kolom, grid 2 kolom, grid 3 kolom.
- **Statistik Total/Menipis/Habis dihapus semua** — layar lebih bersih.
- **Stok Masuk / Stok Keluar sekarang expand langsung di halaman** (bukan buka modal baru): pilih produk → stepper **- qty +** → simpan.
- **Aktivitas stok tanpa garis aksen kiri** — diganti ikon kecil (masuk ↑ / keluar ↓) agar tidak terkesan "AI slop".

## 🧮 Menu Keuangan
- **Hint teks kecil di bawah tab dihapus** — label tab bersih, ukuran konsisten.
- **Export Data Keuangan** mengikuti pola laporan: pilih **Excel (.xlsx) / CSV / PDF**, lalu hasilnya langsung bisa **dibagikan (share)**.
- Switch & tombol filter ukurannya seragam.

## 🏪 Menu Supplier
- **Nama supplier di kartu lebih besar & tebal** (18px, bold 800) — mudah dibaca.

## 🛒 Catat Pembelian — Mode POS (HP & Tablet)
- Switch **Produk / Bahan** hanya teks (tanpa ikon).
- **Ikon scan barcode pindah ke dalam kolom pencarian**; tempat tombol scan lama jadi **tombol pilih supplier** (inisial supplier terpilih tampil di tombol).
- Kartu produk: tombol **"+"** sekarang **expand jadi "- qty +"** — tambah/kurang qty langsung tanpa modal.
- Di HP, keranjang jadi **floating bar ala POS** (jumlah item • total • tombol Lihat) — tap untuk buka sheet keranjang.
- **Biaya tambahan** cukup ikon **"+" kecil** di samping kata "Biaya Tambahan" — tidak ada tombol besar.
- Kartu **Bahan** di-upgrade: **nama bahan tebal warna primary** + **pembatas (divider)** antara nama dan area harga/jumlah.
- **Ikon truk dihapus** dari seluruh alur pembelian — diganti ikon netral (toko).

## 🛍️ Toko Online — Tampilan Baru Siap Pakai
- **Header toko** lebih bersih: avatar + nama toko besar, status **"Buka • Online Order"** pill hijau, tombol **Bagikan Toko** untuk promosi.
- Pencarian pakai gaya input konsisten, kategori pill rapi.
- **Kartu produk** dengan bayangan halus, nama & harga font tegas, gambar dijamin tidak pernah hilang (fallback inisial gradien).
- **Keranjang** jadi **floating bar ala POS**; sheet keranjang & checkout pakai komponen yang sama dengan menu lain.
- Alur pemesanan via WhatsApp tetap dipertahankan — tanpa web pun toko bisa terima order.

---
*Schema DB tidak berubah (tetap v40).*
