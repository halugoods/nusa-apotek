import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_kasir/core/receipt/receipt_config.dart';
import 'package:nusa_kasir/core/receipt/receipt_data.dart';
import 'package:nusa_kasir/core/receipt/receipt_renderer.dart';

void main() {
  // renderBytes memakai CapabilityProfile.load() → butuh rootBundle
  // (asset bundle Flutter) biar test unit bisa jalan.
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('renderBytes — jalur CETAK (v2.2.31 fix)', () {
    ReceiptData withMethod(String method) => ReceiptData(
          invoiceNumber: 'INV-20260817-0001',
          dateStr: '17/08/2026  15:42',
          cashierName: 'Halu',
          items: const [
            ReceiptItem(name: 'Dimsum Original', qty: 2, price: 13500),
            ReceiptItem(name: 'Es Teh Manis', qty: 2, price: 5000),
          ],
          total: 37000,
          cashGiven: 37000,
          paymentMethod: method,
        );

    test('label bayar utuh dikirim ke parts (TIDAK di-truncate)', () {
      for (final method in const ['Tunai', 'QRIS', 'Transfer', 'EDC / Kartu']) {
        final cfg = ReceiptConfig.sample().copyWith(paperWidth: '58');
        final d = withMethod(method);
        final parts = buildReceiptParts(config: cfg, data: d, storeName: 'NUSA MART');
        final bayar = parts
            .whereType<ReceiptPartRow>()
            .where((p) => p.label.startsWith('Bayar:'))
            .firstOrNull;
        expect(bayar, isNotNull, reason: 'metode $method harus punya baris Bayar');
        expect(
          bayar!.label,
          'Bayar: $method',
          reason: 'label Bayar TIDAK boleh di-truncate (bug v2.2.30: fitReceipt 11 char)',
        );
      }
    });

    test('renderBytes tidak melempar untuk semua metode bayar (kolom valid)', () async {
      for (final method in const ['Tunai', 'QRIS', 'Transfer', 'EDC / Kartu']) {
        final cfg = ReceiptConfig.sample().copyWith(paperWidth: '58');
        final d = withMethod(method);
        final bytes = await renderBytes(config: cfg, data: d, storeName: 'NUSA MART');
        expect(bytes, isNotEmpty);
      }
    });

    test('renderBytes label bayar TIDAK mengandung truncation (…)' , () async {
      // v2.2.31: bug v2.2.30 = fitReceipt(label, 11) menghasilkan
      // "Bayar: Tuna..." di bytes cetak. Sekarang label tidak di-truncate
      // sama sekali — ellipsis "…"/"..." tidak boleh muncul pada baris label.
      for (final method in const ['Tunai', 'QRIS', 'Transfer', 'EDC / Kartu']) {
        final cfg = ReceiptConfig.sample().copyWith(paperWidth: '58');
        final d = withMethod(method);
        final bytes = await renderBytes(config: cfg, data: d, storeName: 'NUSA MART');
        // Semua char label (ASCII) harus ada di bytes — boleh terpecah antar
        // baris (wrap), TAPI tidak boleh diganti "…" / "..." (truncation).
        final label = 'Bayar: $method';
        final labelUnits = label.codeUnits;
        var idx = 0;
        for (final b in bytes) {
          if (idx < labelUnits.length && b == labelUnits[idx]) idx++;
        }
        expect(
          idx,
          labelUnits.length,
          reason: 'metode $method: karakter label $label harus semuanya ada '
              'di bytes cetak (tidak boleh di-truncate jadi "..." — bug v2.2.30)',
        );
      }
    });
  });
}
