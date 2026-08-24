import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/shared/widgets/nusa_card.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tutorial — panduan cara pakai tiap menu, dibuka dari Pengaturan → Bantuan.
///
/// Struktur data sudah siap untuk video YouTube nanti: tiap [TutorialItem]
/// punya [videoUrl] (opsional) yang bisa diisi dan ditambahkan tombol tonton.
class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  /// Satu kartu panduan per fitur/menu.
  /// [key] dipakai untuk filter varian (menu tersembunyi tidak ditampilkan).
  static const List<TutorialItem> _items = [
    TutorialItem(
      key: 'kasir',
      icon: Icons.point_of_sale_rounded,
      color: NusaConfig.primaryColor,
      title: 'Kasir',
      text:
          'Pilih produk dari daftar atau scan barcode, atur jumlah, lalu tekan '
          'Bayar. Pembayaran bisa tunai, QRIS, atau transfer. Struk otomatis '
          'dicetak kalau printer sudah diatur.',
    ),
    TutorialItem(
      key: 'produk',
      icon: Icons.inventory_2_rounded,
      color: Color(0xFF6C5CE7),
      title: 'Produk',
      text:
          'Tambahkan produk baru dengan nama, harga jual, harga beli, dan '
          'minimal stok. Aktifkan "Catat supplier" untuk menghubungkan produk '
          'ke pemasok — memudahkan beli cepat saat stok menipis.',
      videoUrl: 'https://youtube.com/shorts/ElvYpqUIRpE',
    ),
    TutorialItem(
      key: 'stok',
      icon: Icons.stacked_bar_chart_rounded,
      color: Color(0xFF00B894),
      title: 'Stok',
      text:
          'Pantau stok lewat filter Stok Menipis / Stok Habis. Gunakan '
          '+ Stok Masuk saat barang datang dan - Stok Keluar untuk koreksi. '
          'Tekan "Beli" pada produk menipis untuk langsung buka catat pembelian.',
    ),
    TutorialItem(
      key: 'transaksi',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFF0984E3),
      title: 'Transaksi',
      text:
          'Lihat riwayat penjualan hari ini atau rentang tertentu. Bisa cetak '
          'ulang struk, void (batalkan) transaksi salah, atau retur barang. '
          'Semua butuh PIN Owner/Manager.',
    ),
    TutorialItem(
      key: 'pelanggan',
      icon: Icons.people_alt_rounded,
      color: Color(0xFFE17055),
      title: 'Pelanggan',
      text:
          'Simpan data pelanggan untuk penjualan kredit (piutang) dan '
          'pelanggan tetap. Cari cepat dengan kotak pencarian saat checkout '
          'atau pesanan online.',
    ),
    TutorialItem(
      key: 'pembelian',
      icon: Icons.local_shipping_rounded,
      color: Color(0xFFD63031),
      title: 'Pembelian',
      text:
          'Catat pembelian dari supplier: pilih supplier, scan atau cari '
          'produk, tambahkan biaya tambahan (ongkir/packing) supaya harga '
          'modal akurat. Stok bertambah otomatis.',
    ),
    TutorialItem(
      key: 'supplier',
      icon: Icons.factory_rounded,
      color: Color(0xFF2D3436),
      title: 'Supplier',
      text:
          'Kelola pemasok: nama, kontak, dan riwayat harga per produk. '
          'Pembelian tercatat otomatis di sini untuk membandingkan harga '
          'antar supplier.',
    ),
    TutorialItem(
      key: 'piutang',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFFB33771),
      title: 'Piutang',
      text:
          'Catat penjualan kredit dan terima pembayaran bertahap. Status '
          'tagihan terlihat jelas: belum lunas, sebagian, atau lunas.',
    ),
    TutorialItem(
      key: 'pesanan_online',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFF6AB04C),
      title: 'Pesanan Online',
      text:
          'Terima pesanan dari WhatsApp/GoFood/Grab atau pesanan manual. '
          'Update status pesanan: Baru → Diproses → Selesai. Notifikasi muncul '
          'di menu ini.',
    ),
    TutorialItem(
      key: 'laporan',
      icon: Icons.insights_rounded,
      color: Color(0xFF8E44AD),
      title: 'Laporan',
      text:
          'Lihat ringkasan penjualan, laba rugi, dan pengeluaran per periode. '
          'Tekan "Lihat Detail" untuk best seller, kategori, dan metode '
          'pembayaran. Bisa diekspor ke Excel.',
    ),
    TutorialItem(
      key: 'keuangan',
      icon: Icons.savings_rounded,
      color: Color(0xFF00CEC9),
      title: 'Keuangan',
      text:
          'Kelola pengeluaran bulanan, gaji karyawan, waste (barang rusak), '
          'langganan berulang, dan saldo kas/likuiditas dalam satu menu.',
    ),
    TutorialItem(
      key: 'presensi',
      icon: Icons.fingerprint_rounded,
      color: Color(0xFF636E72),
      title: 'Presensi',
      text:
          'Karyawan check-in / check-out dengan PIN atau sidik jari. Riwayat '
          'kehadiran dan keterlambatan tercatat otomatis.',
    ),
    TutorialItem(
      key: 'karyawan',
      icon: Icons.badge_rounded,
      color: Color(0xFFA29BFE),
      title: 'Karyawan',
      text:
          'Tambah karyawan, atur jabatan (Owner/Manager/Kasir) dan hak akses '
          'menu. Gaji dan bonus dikelola lewat menu Keuangan → Payroll.',
    ),
    TutorialItem(
      key: 'pengaturan',
      icon: Icons.settings_rounded,
      color: Color(0xFF34495E),
      title: 'Pengaturan',
      text:
          'Atur nama toko, printer thermal, format struk, dan keamanan PIN. '
          'Backup data ke Google Drive dan sinkronkan antar perangkat di sini.',
    ),
    TutorialItem(
      key: 'meja',
      icon: Icons.table_restaurant_rounded,
      color: Color(0xFFE84393),
      title: 'Meja',
      text:
          'Untuk FnB: kelola nomor meja, pindahkan pesanan antar meja, dan '
          'lihat status meja (terisi/kosong) langsung dari dashboard.',
    ),
    TutorialItem(
      key: 'laundry_status',
      icon: Icons.local_laundry_service_rounded,
      color: Color(0xFF00B894),
      title: 'Status Laundry',
      text:
          'Untuk laundry: update status cucian — Dicuci, Disetrika, Siap '
          'Ambil, Selesai. Pelanggan bisa cek status lewat WhatsApp.',
    ),
    TutorialItem(
      key: 'servis',
      icon: Icons.build_rounded,
      color: Color(0xFFE17055),
      title: 'Tiket Servis',
      text:
          'Untuk servis: buat tiket servis (HP/laptop/dll), catat kerusakan '
          'dan biaya, lalu update status perbaikan sampai diambil.',
    ),
    TutorialItem(
      key: 'booking',
      icon: Icons.event_available_rounded,
      color: Color(0xFF6C5CE7),
      title: 'Booking',
      text:
          'Untuk salon: terima janji temu pelanggan, atur durasi layanan dan '
          'jam buka. Jadwal hari ini tampil di dashboard.',
    ),
    TutorialItem(
      key: 'resep',
      icon: Icons.medication_rounded,
      color: Color(0xFF0984E3),
      title: 'Resep',
      text:
          'Untuk apotek: simpan resep dokter dan racikan. Obat langsung '
          'diproses dari resep, stok terpotong otomatis.',
    ),
    TutorialItem(
      key: 'print_order',
      icon: Icons.print_rounded,
      color: Color(0xFF8B5CF6),
      title: 'Order Cetak',
      text:
          'Untuk percetakan/fotocopy: terima order cetak, pilih jenis layanan '
          '(bisa custom), isi jumlah lembar, copy, ukuran kertas, dimensi '
          '(P×L cm) dan estimasi selesai. Update status pengerjaan: Baru → '
          'Diproses → Selesai → Diambil. Statistik hari ini tampil di '
          'dashboard, dan order otomatis tercatat saat kasir checkout produk '
          'percetakan.',
    ),
    TutorialItem(
      key: 'ai_chat',
      icon: Icons.smart_toy_rounded,
      color: Color(0xFF00CEC9),
      title: 'AI Chat',
      text:
          'Tanya apa saja tentang toko: "Berapa omzet minggu ini?" — jawaban '
          'langsung dari data toko, lengkap dengan grafik.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hidden = NusaConfig.hiddenMenus;

    return ScreenScaffold(
      'Tutorial',
      ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Panduan singkat cara pakai tiap menu. Ketuk kartu untuk '
              'membaca cara kerjanya.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark
                    ? NusaConfig.darkTextSecondary
                    : NusaConfig.textSecondary,
              ),
            ),
          ),
          ..._items
              .where((item) => !hidden.contains(item.key))
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: item.videoUrl != null
                        ? () => launchUrl(
                              Uri.parse(item.videoUrl!),
                              mode: LaunchMode.externalApplication,
                            )
                        : null,
                    child: NusaCard(
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(item.icon, size: 22, color: item.color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      if (item.videoUrl != null)
                                        Icon(
                                          Icons.play_circle_fill,
                                          size: 20,
                                          color: NusaConfig.activePrimary,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: isDark
                                          ? NusaConfig.darkTextSecondary
                                          : NusaConfig.textSecondary,
                                    ),
                                  ),
                                  if (item.videoUrl != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tonton video panduan',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: NusaConfig.activePrimary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Data satu kartu tutorial.
class TutorialItem {
  final String key;
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final String? videoUrl; // opsional — siap untuk video YouTube nanti

  const TutorialItem({
    required this.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    this.videoUrl,
  });
}
