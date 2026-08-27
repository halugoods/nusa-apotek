# NUSA v2.2.57+111 — Perbaikan Data Cloud + Istilah "Stylist"

## 🛠 Perbaikan Data Cloud (untuk akun yang restore backup)
- Backup cloud lama (`user_version=48`) tapi kolom v2.2.57 belum dibuat di DB →
  query `employees.commission_percent` / `appointments.transaction_id` error
  "no such column" → login loop "Data Ditemukan". Sekarang sebelum install
  versi baru di HP, app akan menemukan kolom yang sudah ditambah di backup.
- **Aman untuk backup baru**: kolom langsung ditambah saat app pertama buka
  dengan v2.2.57+ (migration from<48 berjalan). Hanya akun yang restore dari
  backup **lama** (schemaVersion=48 tapi kolom hilang) yang perlu perbaikan
  data cloud seperti yang sudah dilakukan untuk `djuhairsyams.sd@gmail.com`
  (salon) via tools admin.

## ✍️ Istilah "Stylist" Menggantikan "Capster"
- Istilah "capster" terlalu maskulin untuk salon cewek. App sekarang
  menampilkan **"Stylist"** di seluruh laporan & booking:
  - **Laporan Kinerja Stylist** (sebelumnya "Kinerja Capster") — omset &
    komisi per stylist.
  - **Detail per Stylist** — drilldown transaksi.
  - **Bayar Komisi** — tandai komisi stylist yang sudah dibayar.
  - **Pendapatan Saya** — stylist lihat omset & komisi sendiri.
- Role karyawan lama "Capster" **otomatis diganti** jadi "Stylist" oleh app
  pada saat restore dari backup cloud.
- Path route: `/laporan/stylist` (sebelumnya `/laporan/capster`).
- File internal: `stylist_report_repository.dart`,
  `stylist_reports_screen.dart`.

## 📦 Lain-lain
- Versi APK naik dari 2.2.57+110 → 2.2.57+111 (cuma patch istilah + versi,
  tidak ada perubahan alur).
