import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_kasir/core/receipt/receipt_config.dart';
import 'package:nusa_kasir/core/receipt/receipt_data.dart';
import 'package:nusa_kasir/core/receipt/receipt_renderer.dart';

void main() {
  group('renderText — SATU renderer (preview = print = share)', () {
    final config = ReceiptConfig.sample();
    final data = ReceiptData.sample();

    test('sample spec W: TOTAL 112.300, Disc. 5.700, Tunai 120.000, Kembali 7.700', () {
      expect(data.total, 112300);
      // 2 item berdiskon: (15000-13500)*2 + (18000-17100)*3 = 3000 + 2700
      expect(data.totalDiscount, 5700);
      expect(data.cashGiven, 120000);
      expect(data.cashReturn, 7700);
    });

    test('item berdiskon memuat harga ASLI + baris Disc. (-RpX)', () {
      final text = renderText(config: config, data: data, storeName: 'NUSA MART');
      // Item pertama: Dimsum Original — harga asli 15.000
      expect(text, contains('Dimsum Original'));
      expect(text, contains('2 x 15.000'));
      // Subtotal netto (qty × harga final): 2 × 13.500 = 27.000
      expect(text, contains('27.000'));
      // Diskonto total item pertama: (15000-13500) × 2 = 3.000
      expect(text, contains('(-3.000)'));
    });

    test('summary: Disc. (-RpX) total = diskon item + diskon transaksi', () {
      final text = renderText(config: config, data: data, storeName: 'NUSA MART');
      expect(text, contains('Disc.'));
      expect(text, contains('(-5.700)'));
    });

    test('summary Total/Bayar/Kembalian sejajar (renderer output)', () {
      final text = renderText(config: config, data: data, storeName: 'NUSA MART');
      expect(text, contains('Total'));
      // v2.2.30: label bayar ringkas "Bayar: Tunai" (metode penuh tidak
      // terpotong di kolom 58mm)
      expect(text, contains('Bayar: Tunai'));
      expect(text, contains('120.000'));
      expect(text, contains('Kembali'));
      expect(text, contains('7.700'));
    });

    test('item tanpa diskon TIDAK memuat baris Disc.', () {
      final plain = ReceiptData(
        invoiceNumber: 'INV-001',
        dateStr: '17/08/2026 15:42',
        items: [
          const ReceiptItem(name: 'Es Teh Manis', qty: 2, price: 5000),
        ],
        total: 10000,
        paymentMethod: 'Tunai',
        cashGiven: 10000,
        cashReturn: 0,
      );
      final text = renderText(config: config, data: plain, storeName: 'NUSA MART');
      expect(text, isNot(contains('Disc. (-')));
      expect(text, contains('10.000'));
    });

    test('toggle OFF menghilangkan baris (showInvoice/showDate/showCashier)', () {
      final cfg = config.copyWith(
        showInvoice: false,
        showDate: false,
        showCashier: false,
      );
      final text = renderText(config: cfg, data: data, storeName: 'NUSA MART');
      expect(text, isNot(contains('INV-20260817-0001')));
      expect(text, isNot(contains('17/08/2026')));
      expect(text, isNot(contains('Kasir')));
      // Item & summary TETAP ada
      expect(text, contains('Dimsum Original'));
      expect(text, contains('Total'));
    });

    test('v2.2.30: sub-header (alamat) dirender di bawah header', () {
      final cfg = config.copyWith(subHeader: 'Jl. Merdeka No. 1, Jakarta');
      final text = renderText(config: cfg, data: data, storeName: 'NUSA MART');
      expect(text, contains('Jl. Merdeka No. 1, Jakarta'));
      // Sub-header kosong → tidak ada baris
      final text2 = renderText(
        config: config.copyWith(subHeader: ''),
        data: data,
        storeName: 'NUSA MART',
      );
      expect(text2, isNot(contains('Jl. Merdeka No. 1, Jakarta')));
    });

    test('v2.2.30: footer = isi USER saja (hardcode Terima Kasih + nama toko dihapus)', () {
      final cfg = config.copyWith(footer: 'Terima kasih, ditunggu pesanan selanjutnya!');
      final text = renderText(config: cfg, data: data, storeName: 'NUSA MART');
      expect(text, contains('Terima kasih, ditunggu pesanan selanjutnya!'));
      // Nama toko hanya muncul di HEADER (baris pertama) — TIDAK boleh
      // diulang di footer (keputusan user: footer = isi user saja)
      final headerOnly = text.split('\n').first;
      expect(headerOnly, contains('NUSA MART'));
      expect(
        text.split('\n').skip(1).join('\n'),
        isNot(contains('NUSA MART')),
      );
      // Footer kosong → footer benar-benar kosong (tanpa fallback hardcode)
      final text2 = renderText(
        config: config.copyWith(footer: ''),
        data: data,
        storeName: 'NUSA MART',
      );
      expect(text2, isNot(contains('Terima Kasih!')));
    });

    test('v2.2.30: label bayar ringkas — metode EDC / Kartu TIDAK terpotong', () {
      final edc = ReceiptData(
        invoiceNumber: 'INV-002',
        dateStr: '17/08/2026 15:42',
        items: [
          const ReceiptItem(name: 'Dimsum Original', qty: 2, price: 13500),
        ],
        total: 27000,
        paymentMethod: 'EDC / Kartu',
        cashGiven: 27000,
      );
      final text = renderText(config: config, data: edc, storeName: 'NUSA MART');
      expect(text, contains('Bayar: EDC / Kartu'));
      expect(text, isNot(contains('Bayar (EDC')));
    });
  });
}
