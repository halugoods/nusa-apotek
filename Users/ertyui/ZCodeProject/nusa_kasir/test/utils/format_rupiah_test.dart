import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';

void main() {
  test('formatRupiah adds thousand separators and Rp prefix', () {
    expect(formatRupiah(0), 'Rp 0');
    expect(formatRupiah(9000), 'Rp 9.000');
    expect(formatRupiah(1250000), 'Rp 1.250.000');
    expect(formatRupiah(-5000), '-Rp 5.000');
  });
}
