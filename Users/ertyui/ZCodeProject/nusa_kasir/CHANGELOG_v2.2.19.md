# CHANGELOG v2.2.19+71 — Koreksi Batch #13

Tanggal rilis: 2026-08-14 · Varian: kelontong (7 varian lain menyusul)

## ✨ Koreksi & Perbaikan

### Pencetak Struk
- **Pembungkus teks kini dihitung dari UKURAN FONT, bukan banyak karakter** — panjang baris struk dihitung dari lebar kertas (58/80 mm) dibagi lebar karakter pada ukuran tersebut (lebar karakter = ukuran font × 12pt dasar). Artinya: makin besar font, makin sedikit karakter per baris — mengikuti logika fisik kertas, bukan tebakan jumlah karakter per skala. Komentar & perhitungan wrap di Header, Rincian, dan Footer disesuaikan agar konsisten dengan model ini.

### Toko Online
- **Upload gambar gagal "belum login Google" padahal sudah login — DIPERBAIKI** — sebelumnya app mengecek login via sesi Supabase Auth (`currentUser`) yang selalu kosong karena login NUSA memakai Google Sign-In (Google UID tersimpan aman di SecureStore). Kini pengecekan memakai **Google UID tersimpan** (`GoogleAuthService.getStoredUserId()`), jadi produk yang sudah login Google **berhasil upload gambarnya** ke toko online, dan peringatan "belum login Google" hanya muncul jika benar-benar belum login. Berlaku untuk upload gambar produk **dan** logo toko.

### Catat Pembelian (Supplier)
- **Ikon supplier truk dikembalikan** — ikon di tombol pilih supplier kembali ke **ikon truk** (`local_shipping`) seperti menu Supplier, bukan jabat tangan.
- **Tombol di samping kolom pencarian kini SELALU menampilkan ikon supplier** — sebelumnya tombol tersebut menampilkan inisial huruf supplier terbaru (terlihat seperti foto profil); kini selalu ikon truk supplier sehingga jelas fungsinya memilih supplier.

### Sheet Biaya & Catatan — responsif penuh
- **Tombol `+` (tambah biaya) kini langsung menambah baris** dan **tombol `×` langsung menghapus baris** — tidak perlu menutup & membuka ulang sheet lagi. Penyebabnya: tombol memakai `setState` dari widget induk; kini sheet punya **state sendiri** (StatefulWidget) dan hasilnya dikirim balik saat menekan **Selesai**. Modul Biaya Tambahan dipisah jadi komponen stateless yang dipakai ulang di panel keranjang (tablet).

## 🐛 Perbaikan Teknis
- Sheet Biaya & Catatan memakai pola **local state + commit via `Navigator.pop`** — tombol merespons instan tanpa konflik rebuild dengan keyboard.
