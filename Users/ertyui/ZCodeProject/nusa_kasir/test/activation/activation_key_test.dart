import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:nusa_kasir/core/activation/activation_key.dart';

void main() {
  final alg = Ed25519();
  late KeyPair pair;
  late List<int> pubBytes;
  late String validKey;

  setUpAll(() async {
    pair = await alg.newKeyPair();
    final pub = await pair.extractPublicKey() as SimplePublicKey;
    pubBytes = pub.bytes.toList();
    final serial = ActivationKey.generateSerial();
    final sig = await alg.sign(serial.codeUnits, keyPair: pair);
    validKey = ActivationKey.format(serial, sig.bytes);
  });

  test('valid key verifies', () async {
    expect(await ActivationKey.verify(validKey, pubBytes), isTrue);
  });
  test('tampered key fails', () async {
    final bad = validKey.replaceFirst(RegExp(r'[A-Z2-9]'), 'X');
    expect(await ActivationKey.verify(bad, pubBytes), isFalse);
  });
  test('wrong public key fails', () async {
    final other = await (Ed25519().newKeyPair());
    final opub = await other.extractPublicKey();
    expect(await ActivationKey.verify(validKey, opub.bytes.toList()), isFalse);
  });
}
