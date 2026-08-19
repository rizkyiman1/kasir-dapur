import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/security/pin_hasher.dart';

void main() {
  test('hash PIN tidak menyimpan PIN asli dan dapat diverifikasi', () {
    final PinHasher hasher = PinHasher();
    const String pin = '123456';
    final String salt = hasher.generateSalt();
    final String hash = hasher.hash(pin: pin, salt: salt);

    expect(hash, isNot(contains(pin)));
    expect(hasher.verify(pin: pin, salt: salt, expectedHash: hash), isTrue);
    expect(
      hasher.verify(pin: '654321', salt: salt, expectedHash: hash),
      isFalse,
    );
    expect(hash, isNot(equals(pin)));
  });

  test('salt berbeda menghasilkan hash berbeda untuk PIN yang sama', () {
    final PinHasher hasher = PinHasher();
    final String first = hasher.hash(
      pin: '123456',
      salt: hasher.generateSalt(),
    );
    final String second = hasher.hash(
      pin: '123456',
      salt: hasher.generateSalt(),
    );
    expect(first, isNot(second));
  });

  test('algoritma lama sha256-iter tetap dapat diverifikasi', () {
    final PinHasher hasher = PinHasher();
    const String pin = '123456';
    const String salt = 'test-salt';
    final String legacy = hasher.hash(
      pin: pin,
      salt: salt,
      algorithm: PinHasher.algorithmLegacySha256,
    );
    final String current = hasher.hash(pin: pin, salt: salt);
    expect(legacy, isNot(current));
    expect(
      hasher.verify(
        pin: pin,
        salt: salt,
        expectedHash: legacy,
        algorithm: PinHasher.algorithmLegacySha256,
      ),
      isTrue,
    );
    expect(hasher.verify(pin: pin, salt: salt, expectedHash: legacy), isFalse);
  });
}
