import 'package:google_sign_in/google_sign_in.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// Google Sign-In service for backup identity.
/// Reuses google_sign_in (already a dep for Google Sheets).
/// Stores the Google user ID so backups can survive app reinstall.
class GoogleAuthService {
  static const _key = 'nusa_google_user_id';

  final GoogleSignIn _signIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Sign in and store the Google user ID.
  /// Returns the user ID on success, null on cancellation/failure.
  Future<String?> signIn() async {
    try {
      final account = await _signIn.signIn();
      if (account == null) return null;
      await SecureStore.write(key: _key, value: account.id);
      return account.id;
    } catch (e) {
      // ignore: avoid_print
      print('[GoogleAuth] Gagal sign in: $e');
      return null;
    }
  }

  /// Sign out and clear stored Google ID.
  Future<void> signOut() async {
    try {
      await _signIn.disconnect();
    } catch (e) {
      // ignore: avoid_print
      print('[GoogleAuth] Gagal disconnect: $e');
    }
    await SecureStore.delete(key: _key);
  }

  /// Return the stored Google user ID, if any.
  static Future<String?> getStoredUserId() =>
      SecureStore.read(key: _key);

  /// True if a Google user ID is stored.
  static Future<bool> isLinked() async =>
      (await SecureStore.read(key: _key)) != null;

  /// Ensure a Google user ID is stored (used after signIn elsewhere).
  static Future<void> ensureStored(String userId) async {
    await SecureStore.write(key: _key, value: userId);
  }
}
