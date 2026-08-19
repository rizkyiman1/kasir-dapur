import 'dart:convert';
import 'dart:io';

import 'package:kasir_dapur_backend/config/backend_config.dart';

final class SnapTransaction {
  const SnapTransaction({required this.token, required this.redirectUrl});

  final String token;
  final String redirectUrl;
}

final class MidtransStatusSnapshot {
  const MidtransStatusSnapshot({
    required this.orderId,
    required this.transactionStatus,
    required this.statusCode,
    required this.grossAmount,
    this.transactionId,
  });

  final String orderId;
  final String transactionStatus;
  final String statusCode;
  final String grossAmount;
  final String? transactionId;
}

/// Klien Midtrans Server. Basic auth memakai Server Key. Tidak dipakai Flutter.
abstract class MidtransGateway {
  Future<SnapTransaction> createSnap({
    required String orderId,
    required int amountRupiah,
    required String planCode,
    required String businessId,
  });

  Future<MidtransStatusSnapshot> fetchStatus(String orderId);
}

final class HttpMidtransGateway implements MidtransGateway {
  HttpMidtransGateway({required this.config, this._client});

  final MidtransConfig config;
  final HttpClient? _client;

  @override
  Future<SnapTransaction> createSnap({
    required String orderId,
    required int amountRupiah,
    required String planCode,
    required String businessId,
  }) async {
    if (!config.isConfigured) {
      throw const HttpException('Midtrans belum dikonfigurasi di backend.');
    }
    final HttpClient client = _client ?? HttpClient();
    final bool owned = _client == null;
    try {
      final HttpClientRequest request = await client.postUrl(
        Uri.parse(config.snapTransactionsUrl),
      );
      _authorize(request);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, Object>{
          'transaction_details': <String, Object>{
            'order_id': orderId,
            'gross_amount': amountRupiah,
          },
          'item_details': <Map<String, Object>>[
            <String, Object>{
              'id': planCode,
              'price': amountRupiah,
              'quantity': 1,
              'name': 'Kasir Dapur $planCode',
            },
          ],
          'custom_field1': businessId,
          'credit_card': <String, Object>{'secure': true},
        }),
      );
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const HttpException('Midtrans menolak pembuatan transaksi.');
      }
      final Object decoded = jsonDecode(body) as Object;
      if (decoded is! Map) {
        throw const HttpException('Respons Snap Midtrans tidak valid.');
      }
      final String? token = decoded['token'] as String?;
      final String? redirect = decoded['redirect_url'] as String?;
      if (token == null || redirect == null) {
        throw const HttpException('Snap Midtrans tidak lengkap.');
      }
      return SnapTransaction(token: token, redirectUrl: redirect);
    } finally {
      if (owned) {
        client.close(force: true);
      }
    }
  }

  @override
  Future<MidtransStatusSnapshot> fetchStatus(String orderId) async {
    if (!config.isConfigured) {
      throw const HttpException('Midtrans belum dikonfigurasi di backend.');
    }
    final HttpClient client = _client ?? HttpClient();
    final bool owned = _client == null;
    try {
      final HttpClientRequest request = await client.getUrl(
        Uri.parse(config.statusUrl(orderId)),
      );
      _authorize(request);
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const HttpException('Status Midtrans tidak dapat diverifikasi.');
      }
      final Object decoded = jsonDecode(body) as Object;
      if (decoded is! Map) {
        throw const HttpException('Status Midtrans tidak valid.');
      }
      return MidtransStatusSnapshot(
        orderId: decoded['order_id'] as String? ?? orderId,
        transactionStatus: decoded['transaction_status'] as String? ?? '',
        statusCode: decoded['status_code'] as String? ?? '',
        grossAmount: decoded['gross_amount'] as String? ?? '',
        transactionId: decoded['transaction_id'] as String?,
      );
    } finally {
      if (owned) {
        client.close(force: true);
      }
    }
  }

  void _authorize(HttpClientRequest request) {
    final String basic = base64Encode(utf8.encode('${config.serverKey}:'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Basic $basic');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
  }
}

/// Gateway tes. Tidak menghubungi Midtrans dan tidak mengaktifkan paket sendiri.
final class FakeMidtransGateway implements MidtransGateway {
  FakeMidtransGateway();

  final List<String> createdOrders = <String>[];
  final Map<String, MidtransStatusSnapshot> statuses =
      <String, MidtransStatusSnapshot>{};

  @override
  Future<SnapTransaction> createSnap({
    required String orderId,
    required int amountRupiah,
    required String planCode,
    required String businessId,
  }) async {
    createdOrders.add(orderId);
    return SnapTransaction(
      token: 'snap-token-$orderId',
      redirectUrl: 'https://app.sandbox.midtrans.com/snap/v2/vtweb/$orderId',
    );
  }

  @override
  Future<MidtransStatusSnapshot> fetchStatus(String orderId) async {
    final MidtransStatusSnapshot? saved = statuses[orderId];
    if (saved != null) {
      return saved;
    }
    return MidtransStatusSnapshot(
      orderId: orderId,
      transactionStatus: 'pending',
      statusCode: '201',
      grossAmount: '0.00',
    );
  }

  void seedStatus(MidtransStatusSnapshot snapshot) {
    statuses[snapshot.orderId] = snapshot;
  }
}
