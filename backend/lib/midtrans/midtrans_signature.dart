import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Tanda tangan notifikasi Midtrans. Server Key tidak pernah dikembalikan ke klien.
abstract final class MidtransSignature {
  static String digest({
    required String orderId,
    required String statusCode,
    required String grossAmount,
    required String serverKey,
  }) {
    return sha512
        .convert(utf8.encode('$orderId$statusCode$grossAmount$serverKey'))
        .toString();
  }

  static bool matches({
    required String orderId,
    required String statusCode,
    required String grossAmount,
    required String serverKey,
    required String provided,
  }) {
    if (provided.isEmpty || serverKey.isEmpty) {
      return false;
    }
    final String expected = digest(
      orderId: orderId,
      statusCode: statusCode,
      grossAmount: grossAmount,
      serverKey: serverKey,
    );
    return _constantTimeEquals(expected, provided.toLowerCase()) ||
        _constantTimeEquals(expected, provided);
  }

  /// Nominal integer Rupiah ke string Midtrans, tanpa pecahan double.
  static String grossAmountOf(int amountRupiah) => '$amountRupiah.00';

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
