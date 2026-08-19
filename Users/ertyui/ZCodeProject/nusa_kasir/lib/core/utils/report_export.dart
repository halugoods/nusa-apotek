import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

List<Map<String, dynamic>> parseItems(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is List) {
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
  } catch (_) {
    // ignore malformed items
  }
  return [];
}

int _itemCount(Transaction t) =>
    parseItems(t.items).fold(0, (s, it) => s + ((it['qty'] as int?) ?? 0));

/// Uang yang benar-benar masuk untuk transaksi ini (v2.2.35):
/// DP → nominal DP; hutang penuh → 0; tunai lunas → cashGiven − kembali;
/// QRIS/Transfer/EDC → total (lunas).
int paidAmount(Transaction t) {
  final dp = t.dpAmount;
  if (dp != null && dp > 0) return dp;
  if (t.debtId != null) return 0;
  final given = t.cashGiven;
  if (given != null && given > 0) {
    final ret = t.cashReturn ?? 0;
    final net = given - ret;
    return net > 0 ? net : given;
  }
  return t.total;
}

List<List<dynamic>> _buildRows(List<Transaction> list) {
  const head = [
    'Invoice',
    'Tanggal',
    'Pelanggan',
    'Metode',
    'Jml Item',
    'Total',
    'Diskon',
    'Bayar',
    'Kembali',
    'Kasir',
  ];
  final body = list.map(
    (t) => <dynamic>[
      t.invoice,
      '${t.date.day}/${t.date.month}/${t.date.year} ${t.date.hour.toString().padLeft(2, '0')}:${t.date.minute.toString().padLeft(2, '0')}',
      t.customerId == null ? 'Umum' : 'ID ${t.customerId}',
      t.paymentMethod,
      _itemCount(t),
      t.total,
      t.discount,
      paidAmount(t),
      t.cashReturn ?? 0,
      t.cashierName ?? '-',
    ],
  );
  return [head, ...body];
}

Future<File> exportCsv(List<Transaction> list, String fileName) async {
  final csv = const ListToCsvConverter().convert(_buildRows(list));
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName.csv');
  await file.writeAsString(csv);
  return file;
}

Future<File> exportExcel(List<Transaction> list, String fileName) async {
  final excel = Excel.createExcel();
  final sheet = excel.sheets[excel.getDefaultSheet()]!;
  for (final row in _buildRows(list)) {
    sheet.appendRow(row.map(_cell).toList());
  }
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName.xlsx');
  await file.writeAsBytes(excel.encode()!);
  return file;
}

CellValue _cell(dynamic v) {
  if (v is int) return IntCellValue(v);
  if (v is num) return DoubleCellValue(v.toDouble());
  return TextCellValue(v.toString());
}

// ── Export Pengeluaran (CSV / Excel) ────────────────────────────────
List<List<dynamic>> _buildExpenseRows(List<Expense> list) {
  const head = ['Tanggal', 'Kategori', 'Deskripsi', 'Jumlah'];
  final body = list
      .map(
        (e) => <dynamic>[
          '${e.date.day}/${e.date.month}/${e.date.year}',
          e.category,
          e.description,
          e.amount,
        ],
      )
      .toList();
  return [head, ...body];
}

Future<File> exportExpenseCsv(List<Expense> list, String fileName) async {
  final csv = const ListToCsvConverter().convert(_buildExpenseRows(list));
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName.csv');
  await file.writeAsString(csv);
  return file;
}

Future<File> exportExpenseExcel(List<Expense> list, String fileName) async {
  final excel = Excel.createExcel();
  final sheet = excel.sheets[excel.getDefaultSheet()]!;
  for (final row in _buildExpenseRows(list)) {
    sheet.appendRow(row.map(_cell).toList());
  }
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName.xlsx');
  await file.writeAsBytes(excel.encode()!);
  return file;
}
