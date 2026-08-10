# 🚗 NUSA Bengkel v2.1.0 — Upgrade Tiket Servis Kendaraan

## ✨ Fitur Baru

### 🏍️ Tiket Servis Kendaraan (Upgrade Besar)
- **Detail kendaraan**: plat nomor, merk/model, tahun — histori servis per kendaraan tercatat
- **Kategori servis dropdown**: Servis Rutin / Ganti Oli / Ban & Kaki / Kelistrikan / AC / Body / Mesin / Lainnya
- **Nomor antrian harian** `#SRV-001` (pola booking salon)
- **Filter teknisi**: dropdown "Semua teknisi" → per teknisi, biar pembagian kerja terlihat

### 💰 Rincian Biaya (Sparepart + Jasa)
- Biaya **sparepart** dan **jasa** diinput terpisah di form
- **Total estimasi otomatis** = sparepart + jasa
- Chip warna di kartu: Sparepart (biru), Jasa (hijau), Estimasi (kuning)

### 👨‍🔧 Teknisi & Antrian
- Assign teknisi per tiket (dropdown dari teknisi yang sudah ada)
- Quick status chips: Diagnosa → Estimasi → Perbaikan → Selesai → Diambil (pola salon)
- Filter antrian per teknisi

### 📊 Dashboard Bengkel
- Kartu statistik expandable (slide animation, pola salon):
  - **Hari Ini** — kendaraan masuk
  - **Antrian** — Diagnosa + Estimasi
  - **Dikerjakan** — Perbaikan
  - **Selesai**
  - **Estimasi berjalan** — total biaya (Rp)

### 🎨 UI Lainnya
- **Search bar + contact picker** (ikon, pola salon) — cari pelanggan/kendaraan/plat atau pilih dari kontak
- Chip plat nomor kuning + merk + tahun di kartu
- Empty state ikon mobil

## 🛠️ Teknis
- DB schema v30 → v31 (7 kolom baru di `ServiceTickets`)
- Getter `isBengkelVariant` baru di NusaConfig
- `ServiceTicketRepository`: `countToday()`, `sumByStatus()`, `getNextQueue()`, `getTechnicians()`
- Varian lain (laundry/salon/fnb/servis) tidak terpengaruh — screen adaptif

## 📦 Build
- APK: v2.1.0 (build 46) — release dengan `--dart-define=NUSA_DEV=true`
