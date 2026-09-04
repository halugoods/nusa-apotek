import 'package:nusa_kasir/core/cloud/cloud_gateway.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// Email + password auth via gateway /api/auth — jalur akun alternatif selain
/// Google OAuth. UID akun dipakai sebagai identitas lisensi dengan cara yang
/// SAMA persis seperti Google user ID 21-digit: disimpan ke
/// `nusa_account_uid` (secure storage) lalu dikirim sebagai `googleUserId`
/// ke edge fn `register_activation`.
class AccountAuthService {
  static const uidKey = 'nusa_account_uid';
  static const emailKey = 'nusa_account_email';

  /// Sign in with email + password. Returns the account UID on success,
  /// null on invalid credentials / network failure.
  Future<String?> signIn(String email, String password) async {
    try {
      final res = await CloudGateway.shared.invokeRaw(
        'auth',
        'login',
        body: {'email': email.trim(), 'password': password},
      );
      if (!res.ok || res.data is! Map) return null;
      final account = res.data['account'];
      final uid = account is Map ? account['id']?.toString() : null;
      final jwt = res.data['jwt'] as String?;
      if (uid == null || uid.isEmpty) return null;
      if (jwt != null && jwt.isNotEmpty) {
        await CloudGateway.shared.setSession(jwt);
      }
      await SecureStore.write(key: uidKey, value: uid);
      await SecureStore.write(key: emailKey, value: email.trim());
      return uid;
    } catch (e) {
      // ignore: avoid_print
      print('[AccountAuth] Gagal sign in: $e');
      return null;
    }
  }

  /// Register a new email + password account via gateway /api/auth.
  ///
  /// Returns one of:
  /// - `'ok'` — akun langsung aktif (JWT sudah tersimpan sebagai sesi) → uid
  ///   sudah tersimpan.
  /// - `'exists'` — email sudah terdaftar.
  /// - `'error'` — kegagalan lain (jaringan dll).
  Future<String> signUp(String email, String password) async {
    try {
      final res = await CloudGateway.shared.invokeRaw(
        'auth',
        'signup',
        body: {'email': email.trim(), 'password': password},
      );
      if (res.ok && res.data is Map) {
        final account = res.data['account'];
        final uid = account is Map ? account['id']?.toString() : null;
        final jwt = res.data['jwt'] as String?;
        if (uid != null && uid.isNotEmpty) {
          if (jwt != null && jwt.isNotEmpty) {
            await CloudGateway.shared.setSession(jwt);
          }
          await SecureStore.write(key: uidKey, value: uid);
          await SecureStore.write(key: emailKey, value: email.trim());
          return 'ok';
        }
      }
      // Server menolak — email kemungkinan sudah terdaftar.
      final data = res.data is Map ? res.data as Map : const {};
      final err = data['error']?.toString() ?? '';
      if (err.toLowerCase().contains('already registered') ||
          err.toLowerCase().contains('already been registered') ||
          err.toLowerCase().contains('sudah terdaftar') ||
          res.status == 409) {
        return 'exists';
      }
      // ignore: avoid_print
      print('[AccountAuth] Gagal sign up: $err');
      return 'error';
    } catch (e) {
      // ignore: avoid_print
      print('[AccountAuth] Gagal sign up: $e');
      return 'error';
    }
  }

  /// Kirim email reset password (link ke halaman reset di nusa-online).
  Future<bool> resetPassword(String email) async {
    try {
      final res = await CloudGateway.shared.invokeRaw(
        'auth',
        'reset_request',
        body: {'email': email.trim()},
      );
      return res.ok;
    } catch (e) {
      // ignore: avoid_print
      print('[AccountAuth] Gagal reset password: $e');
      return false;
    }
  }

  /// Sign out: putuskan sesi cloud + hapus uid akun lokal.
  Future<void> signOut() async {
    try {
      await CloudGateway.shared.signOut();
    } catch (_) {}
    await SecureStore.delete(key: uidKey);
  }

  /// Stored account UID (dari login email/password terakhir).
  static Future<String?> getStoredUid() => SecureStore.read(key: uidKey);

  /// Stored account email (dari login email/password terakhir).
  static Future<String?> getStoredEmail() => SecureStore.read(key: emailKey);

  /// True jika ada akun email/password yang tersimpan.
  static Future<bool> isLinked() async =>
      (await SecureStore.read(key: uidKey)) != null;

  static Future<void> ensureStored(String uid) async {
    await SecureStore.write(key: uidKey, value: uid);
  }

  /// "Ingat saya" — flag auto-login di pembukaan app berikutnya. UID akun
  /// tetap disimpan apa adanya (anchor backup), flag ini hanya mengontrol
  /// apakah `_initAutoSignIn` memakai UID itu untuk sign-in senyap.
  static const rememberKey = 'nusa_account_remember';
  static Future<void> saveRemember(bool v) =>
      SecureStore.write(key: rememberKey, value: v ? '1' : '0');
  static Future<bool> shouldRemember() async =>
      (await SecureStore.read(key: rememberKey)) != '0';

  /// UID dari sesi akun yang sedang aktif, jika ada (baca UID tersimpan).
  static Future<String?> currentUidAsync() => SecureStore.read(key: uidKey);
}
