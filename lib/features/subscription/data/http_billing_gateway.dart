import 'dart:convert';
import 'dart:io';

import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_gateway.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_config.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_status.dart';

/// HTTP ke backend Kasir Dapur. Tidak mengirim dan tidak menyimpan Server Key Midtrans.
final class HttpBillingGateway implements BillingGateway {
  HttpBillingGateway({
    required this.apiBaseUrl,
    Future<String?> Function()? readAccessToken,
    HttpClient? client,
  }) : _readAccessToken = readAccessToken,
       _client = client;

  final String apiBaseUrl;
  final Future<String?> Function()? _readAccessToken;
  final HttpClient? _client;

  static const Duration _timeout = Duration(seconds: 15);

  /// Header klien. Sengaja tidak ada Server-Key / Authorization Midtrans.
  static const Map<String, String> clientHeaders = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);
  }

  @override
  Future<CheckoutSession> createCheckout(CheckoutRequest request) async {
    final Object json = await _postJson(
      SubscriptionConfig.checkoutPath,
      <String, Object>{
        'business_id': request.businessId,
        'plan_code': request.planCode.storageValue,
        'client_uuid': request.clientUuid,
      },
    );
    if (json is! Map) {
      throw const ValidationException(
        'Server pembayaran mengembalikan data tidak valid. Paket belum diaktifkan.',
      );
    }
    final Map<Object?, Object?> map = json.cast<Object?, Object?>();
    return CheckoutSession(
      orderId: _requireString(map, 'order_id'),
      planCode: BillingPlan.parse(_requireString(map, 'plan_code')),
      amountRupiah: _requireInt(map, 'amount'),
      snapToken: _optionalString(map, 'snap_token'),
      snapRedirectUrl: _optionalString(map, 'snap_redirect_url'),
    );
  }

  @override
  Future<VerifiedSubscription?> fetchVerified(String businessId) async {
    final Object? json = await _getJson(
      SubscriptionConfig.currentPath,
      <String, String>{'business_id': businessId},
    );
    if (json == null) {
      return null;
    }
    if (json is! Map) {
      throw const ValidationException(
        'Status langganan dari server tidak valid.',
      );
    }
    final Map<Object?, Object?> map = json.cast<Object?, Object?>();
    if (map.isEmpty || map['plan_code'] == null) {
      return null;
    }
    return VerifiedSubscription(
      businessId: businessId,
      planCode: BillingPlan.parse(_requireString(map, 'plan_code')),
      status: SubscriptionStatus.parse(_requireString(map, 'status')),
      startsAt: _requireInt(map, 'starts_at'),
      endsAt: _optionalInt(map, 'ends_at'),
      graceEndsAt: _optionalInt(map, 'grace_ends_at'),
      verifiedAt: _requireInt(map, 'verified_at'),
      orderId: _requireString(map, 'order_id'),
      provider:
          _optionalString(map, 'provider') ??
          SubscriptionConfig.providerBackend,
    );
  }

  Future<Object> _postJson(String path, Map<String, Object> body) async {
    final HttpClient client = _client ?? HttpClient();
    final bool owned = _client == null;
    try {
      final HttpClientRequest request = await client
          .postUrl(_uri(path))
          .timeout(_timeout);
      await _writeHeaders(request);
      request.write(jsonEncode(body));
      final HttpClientResponse response = await request.close().timeout(
        _timeout,
      );
      return await _decode(response, create: true);
    } on AppException {
      rethrow;
    } on Object {
      throw const ValidationException(
        'Tidak terhubung ke server pembayaran. Paket belum diaktifkan.',
      );
    } finally {
      if (owned) {
        client.close(force: true);
      }
    }
  }

  Future<Object?> _getJson(String path, Map<String, String> query) async {
    final HttpClient client = _client ?? HttpClient();
    final bool owned = _client == null;
    try {
      final HttpClientRequest request = await client
          .getUrl(_uri(path, query))
          .timeout(_timeout);
      await _writeHeaders(request);
      final HttpClientResponse response = await request.close().timeout(
        _timeout,
      );
      if (response.statusCode == HttpStatus.notFound) {
        await response.drain<void>();
        return null;
      }
      return await _decode(response, create: false);
    } on AppException {
      rethrow;
    } on Object {
      throw const ValidationException(
        'Tidak terhubung ke server langganan. Status lokal belum diubah.',
      );
    } finally {
      if (owned) {
        client.close(force: true);
      }
    }
  }

  Future<void> _writeHeaders(HttpClientRequest request) async {
    clientHeaders.forEach(request.headers.set);
    final String? token = await _readAccessToken?.call();
    if (token != null && token.trim().isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
  }

  Future<Object> _decode(
    HttpClientResponse response, {
    required bool create,
  }) async {
    final String text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == HttpStatus.unauthorized) {
        throw const AuthException(
          'Sesi cloud berakhir atau tidak valid. Silakan login ulang.',
        );
      }
      if (response.statusCode == HttpStatus.forbidden) {
        throw const ForbiddenException(
          'Akses paket tidak tersedia untuk akun Anda saat ini.',
        );
      }
      throw ValidationException(
        create
            ? 'Server pembayaran menolak checkout. Paket belum diaktifkan.'
            : 'Server langganan menolak permintaan status.',
      );
    }
    if (text.trim().isEmpty) {
      return <String, Object>{};
    }
    final Object? decoded = jsonDecode(text) as Object?;
    // Server mengembalikan JSON null literal — perlakukan sebagai respons kosong.
    return decoded ?? <String, Object>{};
  }

  String _requireString(Map<Object?, Object?> map, String key) {
    final Object? value = map[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw ValidationException('Kolom $key dari server tidak valid.');
  }

  String? _optionalString(Map<Object?, Object?> map, String key) {
    final Object? value = map[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  int _requireInt(Map<Object?, Object?> map, String key) {
    final Object? value = map[key];
    if (value is int) {
      return value;
    }
    throw ValidationException('Kolom $key dari server harus integer.');
  }

  int? _optionalInt(Map<Object?, Object?> map, String key) {
    final Object? value = map[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    throw ValidationException('Kolom $key dari server harus integer.');
  }
}
