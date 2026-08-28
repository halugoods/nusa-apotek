import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// Email + password auth via Supabase Auth — jalur akun alternatif selain
/// Google OAuth. UID akun (UUID `auth.users`) dipakai sebagai identitas
/// lisensi dengan cara yang SAMA persis seperti Google user ID 21-digit:
/// disimpan ke `nusa_account_uid` (secure storage) lalu dikirim sebagai
/// `googleUserId` ke edge fn `register_activation`. Karena kolom
/// `licenses.google_user_id` bertipe text, UUID dan ID Google bisa hidup
/// berdampingan tanpa perubahan schema.
class AccountAuthService {
  static const uidKey = 'nusa_account_uid';
  static const emailKey = 'nusa_account_email';

  /// Sign in with email + password. Returns the Supabase user UID on success,
  /// null on invalid credentials / network failure.
  Future<String?> signIn(String email, String password) async {
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final uid = res.user?.id;
      if (uid == null) return null;
      await SecureStore.write(key: uidKey, value: uid);
      await SecureStore.write(key: emailKey, value: email.trim());
      return uid;
    } catch (e) {
      // ignore: avoid_print
      print('[AccountAuth] Gagal sign in: $e');
      return null;
    }
  }

  /// Register a new email + password account via Supabase Auth.
  ///
  /// Returns one of:
  /// - `'ok'` — session langsung ada (email confirmation dimatikan) → uid
  ///   sudah tersimpan.
  /// - `'confirm_email'` — pendaftaran berhasil tapi perlu konfirmasi email
  ///   dulu sebelum bisa login.
  /// - `'exists'` — email sudah terdaftar.
  /// - `'error'` — kegagalan lain (jaringan dll).
  Future<String> signUp(String email, String password) async {
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      final uid = res.user?.id;
      if (uid != null) {
        await SecureStore.write(key: uidKey, value: uid);
        await SecureStore.write(key: emailKey, value: email.trim());
        return res.session != null ? 'ok' : 'confirm_email';
      }
      // Supabase v2: kalau email sudah dipakai, `user` null + error.
      return 'exists';
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('already registered') ||
          e.message.toLowerCase().contains('already been registered')) {
        return 'exists';
      }
      // ignore: avoid_print
      print('[AccountAuth] Gagal sign up: ${e.message}');
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
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: '${NusaConfig.landingPageUrl}/reset-password',
      );
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('[AccountAuth] Gagal reset password: $e');
      return false;
    }
  }

  /// Sign out: putuskan sesi Supabase + hapus uid akun lokal.
  Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
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

  /// UID dari sesi Supabase yang sedang aktif, jika ada.
  static String? currentUid() =>
      Supabase.instance.client.auth.currentUser?.id;
}
