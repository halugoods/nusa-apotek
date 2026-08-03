import 'package:cryptography/cryptography.dart';

class ActivationKey {
  static const _prefix = 'NUSA-';
  static const _serialLen = 8;
  static final Ed25519 _alg = Ed25519();

  static String generateSerial() {
    final rnd = <int>[];
    final seed = DateTime.now().microsecondsSinceEpoch.toString().codeUnits;
    for (var i = 0; i < _serialLen; i++) {
      rnd.add(seed[i % seed.length] ^ (i * 31 + 7));
    }
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buf = StringBuffer();
    for (final b in rnd) {
      buf.write(alphabet[b % alphabet.length]);
    }
    return buf.toString();
  }

  static String format(String serial, List<int> signature) {
    final sigB32 = base32Encode(signature);
    final groups = <String>[];
    var i = 0;
    while (i < serial.length) {
      groups.add(serial.substring(i, i + 4 > serial.length ? serial.length : i + 4));
      i += 4;
    }
    i = 0;
    while (i < sigB32.length) {
      groups.add(sigB32.substring(i, i + 4 > sigB32.length ? sigB32.length : i + 4));
      i += 4;
    }
    return '$_prefix${groups.join('-')}';
  }

  static Future<bool> verify(String key, List<int> publicKeyBytes) async {
    try {
      final cleaned = key.toUpperCase().replaceAll(_prefix, '').replaceAll('-', '');
      if (cleaned.length <= _serialLen) return false;
      final serial = cleaned.substring(0, _serialLen);
      final sigB32 = cleaned.substring(_serialLen);
      final sig = base32Decode(sigB32);
      final pub = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
      final signature = Signature(sig, publicKey: pub);
      return await _alg.verify(serial.codeUnits, signature: signature);
    } catch (_) {
      // Malformed or tampered key — never throw, just fail verification.
      return false;
    }
  }

  static String base32Encode(List<int> data) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final out = StringBuffer();
    for (var i = 0; i < data.length; i += 5) {
      final chunk = data.sublist(i, i + 5 > data.length ? data.length : i + 5);
      var bits = 0, value = 0;
      for (final b in chunk) { value = (value << 8) | b; bits += 8; }
      while (bits >= 5) { bits -= 5; out.write(alphabet[(value >> bits) & 31]); }
      if (bits > 0) out.write(alphabet[(value << (5 - bits)) & 31]);
    }
    return out.toString();
  }

  static List<int> base32Decode(String s) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final map = {for (var i = 0; i < alphabet.length; i++) alphabet[i]: i};
    var bits = 0, value = 0;
    final out = <int>[];
    for (final ch in s.toUpperCase().split('')) {
      final v = map[ch];
      if (v == null) continue;
      value = (value << 5) | v; bits += 5;
      if (bits >= 8) { bits -= 8; out.add((value >> bits) & 0xff); value &= (1 << bits) - 1; }
    }
    return out;
  }
}
