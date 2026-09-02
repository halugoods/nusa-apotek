# NUSA Kasir v2.2.57+128

## 🏷 Fix Cetak Label — Barcode Kanan Terpotong & Teks Geser Kanan

### 💥 Barcode tercrop di kanan
- Cetak label via **printer struk** sebelumnya merender selebar kertas fisik (58mm = 462px), padahal printer hanya mencetak 384 dot (48mm) → **78 dot kanan dibuang printer** = bar barcode paling kanan hilang & tidak ke-scan.
- Sekarang bitmap dirender **persis selebar area cetak printer**: 384 dot (58mm) / 576 dot (80mm) → tidak ada lagi yang terbuang.

### 🎯 Nama & harga tidak lagi geser ke kanan
- Teks sebelumnya di-center pada pusat bitmap 462px, bukan pusat 384px yang benar-benar tercetak → tampak geser ±5mm ke kanan.
- Sekarang di-center pada **pusat area cetak** — benar-benar di tengah kertas.

### ↔️ Kiri-kanan simetris (permintaan "fullin sisi kanan kiri sama")
- Barcode full-width kini mengisi area cetak dengan **margin simetris kanan-kiri** — rata kiri-kanan persis.
- Skala bar uniform → rasio barcode terjaga, tetap mudah di-scan.

### ✅ Jalur printer label khusus (TSPL) tidak berubah
- Margin kanan anti-crop print head tetap dipertahankan.
- Bonus: teks & barcode TSPL ikut lebih presisi — center pada pusat area cetak, bukan pusat canvas.

### 🔧 Lainnya
- Preview struk di aplikasi = persis hasil cetak (render yang sama).
- Test regressi bitmap: 8 kasus (lebar printable, simetri barcode, centering teks) — semua terukur dari piksel render, bukan asumsi visual.

## 📦 Download
APK tersedia di release GitHub masing-masing varian (tag `v2.2.57+128`).
