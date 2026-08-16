# CHANGELOG v2.2.24+76 — Struk Dicetak sebagai Gambar (Bit-Image)!

Tanggal rilis: 2026-08-16 · Varian: kelontong (7 varian lain menyusul)

## 🖨️ STRUK DI-REBUILD DARI NOL — Cetak = Gambar (Bit-Image)

**Masalah lama (sejak dulu)**: printer termal murah hanya andal mencetak
perbesaran teks ×1 dan ×2 — ukuran ×3 ke atas diabaikan diam-diam oleh
printer. Akibatnya apa pun pengaturannya, struk selalu tercetak cuma
"2 ukuran". Sudah dicoba diperbaiki berkali-kali lewat perintah teks
printer (ESC/POS), hasilnya tetap sama.

**Solusi baru (total)**: sekarang seluruh struk — logo, nama toko, rincian
item, TOTAL, diskon, kembalian, footer, ucapan terima kasih — **dirender
jadi SATU GAMBAR (PNG) di HP**, lalu gambar itu yang dikirim ke printer
sebagai **bit-image (ESC \*)**. Printer hanya menggambar piksel, jadi
**tidak ada lagi batas 2 ukuran** — semua ukuran PASTI tercetak.

### Apa yang berubah:

- **Slider ukuran detail per bagian** (Header, Rincian, Footer): 12–48
  piksel, naik 1 per langkah. Setiap bagian bisa diatur sendiri.
- **Slider ukuran logo**: 1–100% dari lebar kertas (bukan ukuran tetap).
- **Semua preview = gambar asli yang sama dengan yang dicetak** — preview
  di Pengaturan, di lembar struk setelah checkout, dan di Bagikan Struk
  (riwayat transaksi) semuanya memakai PNG hasil renderer yang SAMA dengan
  yang dikirim ke printer. **Preview tidak mungkin beda dengan hasil cetak**
  (sebelumnya preview pakai widget tiruan — bisa beda).
- **Bagikan/Unduh struk & PDF** juga pakai gambar yang sama — struk yang
  di-share ke WhatsApp identik dengan struk kertas.
- **Tes kalibrasi** di Pengaturan → sekarang benar-benar mengirim gambar
  bit-image, bukan perintah teks — cek ukurannya di kertas langsung.
- Pengaturan struk **di-reset otomatis 1×** saat upgrade ke versi ini ke
  pengaturan baru yang bersih (Header 24px, Rincian 12px, Footer 12px,
  Logo 60%). Bisa diubah lagi kapan saja dari Pengaturan → Struk.

### Cara pakai:

1. Cetak struk tes dari Pengaturan → Struk → "Tes kalibrasi".
2. Atur ukuran Header/Rincian/Footer & logo lewat slider.
3. Cetak lagi → sekarang ukurannya benar-benar sesuai yang di-slider,
   tidak peduli printer murah apa pun.

## 🧹 Lainnya

- Struk share teks WA di Bagikan Struk diselaraskan formatnya.
- Kode renderer struk ditulis ulang bersih (satu sumber untuk
  print/preview/share/PDF) — lebih mudah dirawat ke depan.
