# Template Kartu ID (v2.2.46)

Folder ini khusus template kartu ID (member + karyawan) & card flip karyawan
— gaya "icon menu" (`assets/icons/`), tapi folder sendiri.

## Struktur

```
assets/card_templates/
├── id/
│   ├── front/   → template DEPAN kartu ID (member & karyawan)
│   └── back/    → template BELAKANG kartu ID
└── flip/
    ├── front/   → template card flip (8 warna per tema, ikut Tema Warna)
    └── back/
```

## Konvensi nama file

Template mengikuti pola icon menu: `{JENIS} {HEX}.png` (HEX = warna primer
tema, tanpa `#`, uppercase). Contoh:

- `id/front/ID 10B981.png` — kartu ID tema hijau (10B981)
- `flip/front/FLIP 10B981.png` — card flip tema hijau

## Cara pakai

1. User taruh PNG template di folder sesuai sisi (front/back).
2. Overlay nama/barcode/foto dilakukan di kode (posisi dari GPT prompt).
3. Daftarkan folder di `pubspec.yaml` → `assets/` (hanya kalau sudah ada file,
   folder kosong tidak bisa di-asset-kan).

## Keterangan

- Kartu fisik standar CR80: 85.6 × 54 mm (~1015 × 640 px @ 300dpi).
- Preview di app = PNG (bukan PDF) — ringan, bolak-balik.
- Cetak tetap bisa PDF bila perlu (share/cetak batch).
