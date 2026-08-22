import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/data/repositories/attendance_repository.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/shared/services/biometric_service.dart';
import 'package:nusa_kasir/shared/services/nfc_tag_service.dart';

/// Helper jalur auth alternatif (B8) yang dipakai SEMUA dialog pinpad.
///
/// Tujuan: setiap dialog PIN (login, presensi, void, keuangan, pengaturan
/// keamanan, dll) bisa menerima 4 jalur — PIN / fingerprint / NFC tap /
/// barcode ID — dengan verifikasi yang KONSISTEN:
///
/// - **Barcode**: scan id-card karyawan → `getByBarcode` (status Aktif) →
///   kalau `expectedEmployeeId` diberikan, hasil harus SAMA dengan karyawan
///   yang sedang digate (hindari scan kartu orang lain untuk void, dll).
/// - **NFC**: `readEmployeeTag()` → id karyawan → kalau `expectedEmployeeId`
///   diberikan, harus cocok.
/// - **Fingerprint**: `BiometricService.authenticate` (verifikasi OS).
///
/// Semua fungsi mengembalikan `Future<String?>` — non-null = sukses (nilainya
/// employee id sebagai String, dipakai PinDialog untuk auto-pop), null = gagal/
/// batal. Kalau `expectedEmployeeId` null (mis. dialog "siapa pun yang punya
/// hak"), barcode/NFC cukup terdaftar & Aktif.
class AuthMethods {
  /// Barcode karyawan: `onBarcode` untuk PinDialog.
  /// `expectedEmployeeId` (opsional): kalau diisi, hasil scan harus karyawan
  /// yang sama — mencegah scan kartu karyawan lain untuk aksi yang di-gate.
  static Future<String?> Function(String code) barcode(
    WidgetRef ref, {
    int? expectedEmployeeId,
  }) {
    return (String code) async {
      final norm = ProductRepository.normalizeBarcode(code);
      if (norm.isEmpty) return null;
      final repo = AttendanceRepository(ref.read(databaseProvider));
      final emp = await repo.getByBarcode(norm, status: 'Aktif');
      if (emp == null) return null;
      if (expectedEmployeeId != null && emp.id != expectedEmployeeId) {
        return null; // barcode karyawan lain — tolak
      }
      return '${emp.id}';
    };
  }

  /// NFC tap: `onNfc` untuk PinDialog.
  /// `expectedEmployeeId` (opsional): hasil tap harus karyawan yang sama.
  static Future<String?> Function() nfc(WidgetRef ref, {int? expectedEmployeeId}) {
    return () async {
      final id = await NfcTagService.readEmployeeTag();
      if (id == null) return null;
      if (expectedEmployeeId != null && id != expectedEmployeeId) {
        return null; // tag karyawan lain — tolak
      }
      return '$id';
    };
  }

  /// Fingerprint: `onFingerprint` untuk PinDialog.
  static Future<bool> Function() fingerprint() {
    return () => BiometricService.authenticate(
          reason: 'Verifikasi biometrik untuk melanjutkan',
        );
  }
}
