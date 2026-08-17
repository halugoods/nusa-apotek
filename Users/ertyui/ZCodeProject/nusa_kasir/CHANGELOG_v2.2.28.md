# CHANGELOG v2.2.28+80 — Koreksi Struk (diskon urut, 1 ukuran, header tipis/tebal, Anda Hemat) + Pesanan Online Realtime + Level Member

Tanggal rilis: 2026-08-17 · Varian: kelontong (7 varian lain menyusul)

## 🧾 STRUK — Koreksi 4 Poin dari Feedback User

**1. Format diskon urutan BENAR**

Sebelumnya: `qty × harga asli` lalu subtotal, diskon di belakang —
membingungkan. Sekarang persis yang diminta:

```
2xRp10.000  ( -Rp2.000 )  Rp18.000
```

Urutan: **qty × harga ASLI → diskon (kurung) → subtotal NETTO** — berlaku
di print, preview, share WhatsApp, dan PDF (satu format di mana-mana).

**2. Rincian & Footer SATU ukuran saja (Kecil ×1)**

Pilihan "Besar (×2)" dihapus — user minta satu ukuran, pakai yang kecil.
Print jadi lebih cepat dan lebih banyak baris muat per lembar. (Pengaturan
Struk: bagian Rincian & Footer kini menampilkan label "Kecil (×1)" statis.)

**3. Header — setting ketebalan Thin / Medium / Bold**

Header tetap dicetak sebagai gambar (bit-image) dengan slider 12–48 px,
ditambah pilihan **Tipis / Sedang / Tebal** di Pengaturan Struk. Default
**Sedang** (tegas tapi tidak dominan).

**4. Baris "Anda Hemat: -RpX" di bawah TOTAL**

Tepat di bawah TOTAL struk sekarang ada baris **Anda Hemat** berisi total
diskon = potongan item (harga asli − harga jual × qty) + diskon transaksi.
Pembeli langsung sadar berapa yang dihemat. Tampil di print, preview,
share WA, dan PDF.

**5. Invoice/Tanggal/Kasir TIDAK lagi ikut gambar**

Sebelumnya invoice, tanggal, kasir, pelanggan ikut dirender ke dalam
gambar header → print lama dan hurufnya terlalu kecil. Sekarang **hanya
nama toko / header custom** yang jadi gambar; invoice, tanggal, kasir,
pelanggan, tipe pesanan dicetak sebagai **teks ESC/POS biasa** — print
cepat, huruf normal, tetap sama di preview.

## 🛒 PESANAN ONLINE — Realtime + Status Sesuai Flow

**Notif order baru realtime (bukan delay 2 menit)**

Akar masalahnya: order masuk ke Supabase tapi tidak langsung disimpan ke
database lokal — baru masuk lewat polling berkala (±2 menit), makanya
notifnya telat. Sekarang:

- Subscription realtime **INSERT** langsung **menyimpan order ke database
  lokal** + **refresh daftar seketika** (anti-duplikat by invoice).
- Muncul **toast "🛒 Pesanan baru dari … masuk!"** + getar haptic saat
  order masuk dan sedang di layar Pesanan Online.
- Update status tetap realtime via subscription UPDATE (refresh list).

**Status order = flow pemesanan online (label tab dibenarkan)**

Label tab sebelumnya "Verifikasi" / "Baru" tidak cocok dengan status
asli sehingga dua tab itu **tidak menampilkan apa pun**. Sekarang tab
memakai status aktual:

`Semua · Menunggu Verifikasi Pembeli · Online Baru · Disiapkan · Siap
Diambil · Lunas · Direfund`

Alur: pembeli non-tunai → **Menunggu Verifikasi Pembeli** (kasir Terima
& Proses → Online Baru / Tolak); pembeli tunai → langsung **Online Baru**
→ Disiapkan → Siap Diambil → Lunas (stok otomatis berkurang + transaksi
tercatat). Badge jumlah per tab ikut dikoreksi.

## 👥 PELANGGAN — Level Member Konsisten Silver/Gold/Platinum

App sebelumnya menampilkan **Regular** untuk level Silver, sedangkan web
toko online memakai **Silver/Gold/Platinum** — beda nama, membingungkan.
Sekarang semuanya **Silver** (sama dengan web):

- Filter level: Semua / Silver / Gold / Platinum
- Badge level pelanggan menampilkan "Silver" (bukan "Regular")

## 🔧 Lain-lain

- Preview struk (Riwayat Transaksi, Struk, Pengaturan) disinkronkan:
  ukuran rincian selalu ×1, diskon urut, baris Anda Hemat, header sesuai
  ketebalan pilihan.
- `nusa_receipt_header_weight` (thin/medium/bold) — key baru di
  SecureStore, default `medium`.
