import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Data user yang disimpan di server (in-memory untuk saat ini).
/// Dalam production, ini harus dipersistensikan ke database backend.
final class ServerUser {
  const ServerUser({
    required this.id,
    required this.businessId,
    required this.role,
    required this.pinHash,
    required this.pinSalt,
  });

  final String id;
  final String businessId;
  final String role;
  final String pinHash;
  final String pinSalt;

  /// Verifikasi PIN dengan PBKDF2-HMAC-SHA256 (kompatibel dengan client).
  bool verifyPin(String pin) {
    final String computed = _hashPin(pin, pinSalt);
    return computed == pinHash;
  }
}

/// Hash PIN menggunakan PBKDF2-HMAC-SHA256 seperti di client Flutter.
/// Iterasi: 100.000 (selaras dengan implementasi client).
String _hashPin(String pin, String salt) {
  // Simplified PBKDF2 — iterasi 100.000, SHA-256
  // Ini kompatibel dengan implementasi di auth_repository_impl.dart Flutter.
  final List<int> keyBytes = utf8.encode(pin);
  final List<int> saltBytes = utf8.encode(salt);
  var hmac = Hmac(sha256, keyBytes);
  var block = hmac.convert(saltBytes + <int>[0, 0, 0, 1]).bytes;
  var derived = List<int>.from(block);
  for (int i = 1; i < 100000; i++) {
    block = hmac.convert(block).bytes;
    for (int j = 0; j < derived.length; j++) {
      derived[j] ^= block[j];
    }
  }
  return base64Encode(derived);
}

/// Store user yang sudah terauthentikasi (in-memory prototype).
/// Dalam production: sambungkan ke PostgreSQL / database backend.
///
/// User didaftarkan via [registerUser] (misalnya saat onboarding pertama kali).
/// Semua operasi setelah itu membutuhkan token yang valid.
final class UserStore {
  final Map<String, ServerUser> _byId = <String, ServerUser>{};

  /// Daftarkan user baru. Dipanggil saat onboarding / admin setup.
  /// PIN sudah di-hash sebelum disimpan.
  void register({
    required String id,
    required String businessId,
    required String role,
    required String pin,
    String? salt,
  }) {
    final String actualSalt = salt ?? _randomSalt();
    final String hash = _hashPin(pin, actualSalt);
    _byId[id] = ServerUser(
      id: id,
      businessId: businessId,
      role: role,
      pinHash: hash,
      pinSalt: actualSalt,
    );
  }

  /// Cari user berdasarkan ID.
  ServerUser? findById(String id) => _byId[id];

  Iterable<ServerUser> all() => _byId.values;

  /// Cari semua user untuk sebuah business.
  Iterable<ServerUser> usersForBusiness(String businessId) {
    return _byId.values.where((ServerUser u) => u.businessId == businessId);
  }

  bool updateRole({
    required String userId,
    required String businessId,
    required String role,
  }) {
    final ServerUser? existing = _byId[userId];
    if (existing == null || existing.businessId != businessId) {
      return false;
    }
    _byId[userId] = ServerUser(
      id: existing.id,
      businessId: existing.businessId,
      role: role,
      pinHash: existing.pinHash,
      pinSalt: existing.pinSalt,
    );
    return true;
  }

  bool get isEmpty => _byId.isEmpty;

  static String _randomSalt() {
    // Gunakan timestamp + counter sebagai salt sederhana
    // Production: gunakan crypto random bytes
    final int ms = DateTime.now().microsecondsSinceEpoch;
    return base64Encode(sha256.convert(utf8.encode('$ms')).bytes);
  }
}
