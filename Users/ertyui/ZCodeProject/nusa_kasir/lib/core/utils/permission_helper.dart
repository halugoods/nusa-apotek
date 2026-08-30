import 'package:permission_handler/permission_handler.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// Izin Android yang dibutuhkan aplikasi — diminta SEKALI seumur hidup app
/// saat pertama kali user membuka layar login/aktivasi (bukan saat setup).
///
/// Alur (v2.2.57+116):
/// 1. Dialog ASLI Android (permission_handler → framework dialog), berurutan
///    satu per satu oleh sistem — bukan dialog custom.
/// 2. Flag `nusa_permissions_asked` diset HANYA setelah rangkaian selesai.
///    Kalau user menolak semua, flag tetap BELUM diset → dialog bisa muncul
///    lagi di pembukaan berikutnya sampai user memberi setidaknya satu izin.
///    (Sebelumnya flag diset SEBELUM request → user yang menolak tidak pernah
///    ditanya lagi — menyulitkan yang butuh kamera untuk scan barcode.)
/// 3. User bisa mengaktifkan/menonaktifkan kapan saja lewat Pengaturan OS.
///
/// Aman dipanggil berulang: flag memastikan hanya sekali.
Future<void> requestFirstInstallPermissions() async {
  try {
    if (await SecureStore.getPermissionsAsked()) return;

    // Urutan request harus satu per satu (await) — kalau paralel, dialog
    // Android bisa tumpang tindih dan request berikutnya diabaikan.
    await Permission.camera.request();
    await Permission.notification.request();
    await Permission.storage.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();

    // Flag diset SETELAH selesai — user yang menolak semua tetap mendapat
    // kesempatan di pembukaan berikutnya (belum pernah kasih izin).
    await SecureStore.setPermissionsAsked(true);
  } catch (_) {
    // permission_handler bisa throw di platform tertentu — abaikan, jangan
    // pernah memblokir layar login karena izin gagal diminta.
  }
}

/// Minta ulang izin yang statusnya masih DENIED/PERMANENTLY_DENIED saat fitur
/// pertama kali dipakai (mis. user menolak kamera di dialog pertama lalu
/// membuka scan barcode). Tidak memunculkan dialog kalau statusnya sudah
/// GRANTED/LIMITED.
Future<PermissionStatus> ensurePermission(Permission permission) async {
  try {
    final status = await permission.status;
    if (status.isGranted || status.isLimited) return status;
    return await permission.request();
  } catch (_) {
    return PermissionStatus.denied;
  }
}
