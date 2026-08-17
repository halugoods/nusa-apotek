# CHANGELOG v2.2.27+79 — Struk 2 Pilihan + Header Gambar 12–48px + Member Web + Jam Ambil CRUD

Tanggal rilis: 2026-08-17 · Varian: kelontong (7 varian lain menyusul)

## 🧾 STRUK — Kembali ke 2 Pilihan (Kecil/Besar) + Header jadi Gambar

**Masalah v2.2.24–26**: ukuran huruf struk diubah menjadi banyak pilihan /
format gambar penuh — hasilnya **print lama**, **preview tidak aktual**,
dan pilihan ukuran yang **tidak tercetak benar** di printer termal murah.

**Solusi versi ini (gabungan yang paling aman)**:

- **Rincian & Footer kembali ke 2 pilihan saja — Kecil (×1) / Besar (×2)**.
  Mode ini PASTI tercetak rapi di semua printer termal (VSC, murah,
  maupun branded) — tidak ada lagi ukuran yang diabaikan printer.
- **Header struk dicetak sebagai GAMBAR (bit-image)** — nama toko, invoice,
  tanggal, kasir, dan pelanggan jadi satu gambar. Ukuran diatur **slider
  12–48 px (naik 1 per langkah)**, supaya besar huruf header benar-benar
  terlihat di atas kertas.
- **Preview struk = hasil render yang SAMA dengan cetakan** (satu
  renderer): yang kamu lihat di layar = yang keluar di kertas.
- **Tes Cetak** kembali SIMPLE: satu struk uji "TEST PRINT" — bukan lagi
  kalibrasi 5 ukuran.

### 🧾 Format diskon struk (pasti benar)

Untuk item yang dapat diskon, struk menampilkan **harga ASLI sebelum
diskon**, lalu **potongan dalam kurung**, lalu **subtotal netto**:

```
2 × Rp10.000 ( -Rp2.000 )  Rp18.000
```

Berlaku di cetak kertas, preview, WhatsApp, dan PDF.

## 🌐 WEB TOKO ONLINE — Menu Member + Diskon Tier Otomatis

- **Navbar toko online jadi 4 tab**: Beranda, Favorit, **Riwayat**, dan
  **Member** (baru).
- **Tab Member** (mirip GAS):
  - Kartu profil: poin, **level member (Silver/Gold/Platinum)**, dan
    progress menuju tier berikutnya.
  - **Kupon saya**: daftar kupon yang berlaku + yang sudah dipakai.
  - **Ajak teman**: link `?ref=<nomor WA>` + tombol salin.
- **Diskon tier otomatis di checkout**: member Gold dapat **-2%**,
  Platinum **-5%** dari total pesanan (baris "Diskon Member" muncul di
  ringkasan). Ambang poin & persen diskon dikonfigurasi dari aplikasi.

## ⚙️ APLIKASI — Konfigurasi Member + Jam Ambil CRUD

- **Panel Member** (Pengaturan Toko Online): tambah **Gold min poin**,
  **Platinum min poin**, **Gold diskon %**, **Platinum diskon %** — semua
  bisa diatur toko (default 1000 / 5000 poin, 2% / 5%).
- **Jam Ambil kini CRUD penuh**:
  - "+ Tambah Jam" → tulis teks bebas (mis. *Segera*, *30 Menit*, *14:00*).
  - Setiap jam bisa **diedit** (ikon pensil) atau **dihapus** (ikon sampah,
    dengan konfirmasi).
  - Switch tetap bisa mematikan/menyalakan jam tanpa menghapus.
