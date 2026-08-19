import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kasir_dapur/core/constants/app_constants.dart';

/// Hash PIN lokal (PBKDF2-HMAC-SHA256). Bukan password hardcoded.
/// Algoritma lama `sha256-iter` tetap dapat diverifikasi.
final class PinHasher {
  PinHasher({Random? random}) : _random = random ?? Random.secure();

  static const String algorithmPbkdf2 = 'pbkdf2-sha256';
  static const String algorithmLegacySha256 = 'sha256-iter';
  static const String currentAlgorithm = algorithmPbkdf2;

  final Random _random;

  String generateSalt() {
    final Uint8List bytes = Uint8List(16);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return base64UrlEncode(bytes);
  }

  String hash({
    required String pin,
    required String salt,
    String algorithm = currentAlgorithm,
  }) {
    if (algorithm == algorithmLegacySha256) {
      return _hashLegacy(pin: pin, salt: salt);
    }
    return _hashPbkdf2(pin: pin, salt: salt);
  }

  bool verify({
    required String pin,
    required String salt,
    required String expectedHash,
    String algorithm = currentAlgorithm,
  }) {
    final String actual = hash(pin: pin, salt: salt, algorithm: algorithm);
    if (actual.length != expectedHash.length) {
      return false;
    }
    var mismatch = 0;
    for (int i = 0; i < actual.length; i++) {
      mismatch |= actual.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return mismatch == 0;
  }

  String _hashLegacy({required String pin, required String salt}) {
    List<int> digest = utf8.encode('$salt:$pin');
    for (int i = 0; i < AppConstants.pinHashIterations; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64UrlEncode(digest);
  }

  String _hashPbkdf2({required String pin, required String salt}) {
    final List<int> dk = _pbkdf2HmacSha256(
      password: utf8.encode(pin),
      salt: utf8.encode(salt),
      iterations: AppConstants.pinHashIterations,
      length: 32,
    );
    return base64UrlEncode(dk);
  }

  List<int> _pbkdf2HmacSha256({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int length,
  }) {
    const int blockSize = 32;
    final int blockCount = (length / blockSize).ceil();
    final BytesBuilder output = BytesBuilder();
    for (int block = 1; block <= blockCount; block++) {
      final List<int> blockSalt = <int>[
        ...salt,
        (block >> 24) & 0xff,
        (block >> 16) & 0xff,
        (block >> 8) & 0xff,
        block & 0xff,
      ];
      List<int> u = Hmac(sha256, password).convert(blockSalt).bytes;
      final List<int> t = List<int>.from(u);
      for (int i = 1; i < iterations; i++) {
        u = Hmac(sha256, password).convert(u).bytes;
        for (int j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      output.add(t);
    }
    return output.toBytes().sublist(0, length);
  }
}
