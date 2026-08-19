import 'dart:convert';
import 'dart:io';

import 'package:kasir_dapur/core/constants/app_constants.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/services/settings_repository.dart';

final class CloudAuthSessionService {
  CloudAuthSessionService({
    required this.apiBaseUrl,
    required SettingsRepository settings,
    HttpClient? client,
  }) : _settings = settings,
       _client = client;

  final String apiBaseUrl;
  final SettingsRepository _settings;
  final HttpClient? _client;

  static const Duration _timeout = Duration(seconds: 15);

  Future<String?> readAccessToken({String? expectedUserId}) async {
    final String? token = await _settings.read(AppConstants.settingsKeyCloudAccessToken);
    if (token == null || token.trim().isEmpty) {
      return null;
    }
    final String? storedUserId = await _settings.read(
      AppConstants.settingsKeyCloudTokenUserId,
    );
    if (expectedUserId != null &&
        storedUserId != null &&
        storedUserId != expectedUserId) {
      return null;
    }
    if (_isExpired(token)) {
      await clear();
      return null;
    }
    return token;
  }

  Future<void> issueToken({
    required String userId,
    required String pin,
  }) async {
    final HttpClient client = _client ?? HttpClient();
    final bool owned = _client == null;
    try {
      final HttpClientRequest request = await client
          .postUrl(Uri.parse('$apiBaseUrl/v1/auth/cloud/session'))
          .timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, Object>{'user_id': userId, 'pin': pin}),
      );
      final HttpClientResponse response = await request.close().timeout(_timeout);
      final String text = await response.transform(utf8.decoder).join();
      if (response.statusCode == HttpStatus.unauthorized) {
        throw const AuthException('Sesi cloud tidak valid. Silakan login ulang.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const ValidationException(
          'Tidak dapat membuat sesi cloud. Fitur server memerlukan autentikasi ulang.',
        );
      }
      final Object? decoded = text.trim().isEmpty ? null : jsonDecode(text);
      if (decoded is! Map) {
        throw const ValidationException('Respons sesi cloud tidak valid.');
      }
      final Object? tokenRaw = decoded['access_token'];
      if (tokenRaw is! String || tokenRaw.trim().isEmpty) {
        throw const ValidationException('Token cloud tidak tersedia dari server.');
      }
      await _settings.write(AppConstants.settingsKeyCloudAccessToken, tokenRaw);
      await _settings.write(AppConstants.settingsKeyCloudTokenUserId, userId);
    } on AppException {
      rethrow;
    } on Object {
      throw const ValidationException(
        'Tidak terhubung ke server autentikasi. Fitur server mungkin dibatasi sementara.',
      );
    } finally {
      if (owned) {
        client.close(force: true);
      }
    }
  }

  Future<void> clear() async {
    await _settings.write(AppConstants.settingsKeyCloudAccessToken, '');
    await _settings.write(AppConstants.settingsKeyCloudTokenUserId, '');
  }

  bool _isExpired(String token) {
    final List<String> parts = token.split('.');
    if (parts.length != 3) {
      return true;
    }
    try {
      final String normalized = base64Url.normalize(parts[1]);
      final Object? payload = jsonDecode(
        utf8.decode(base64Url.decode(normalized)),
      );
      if (payload is! Map) {
        return true;
      }
      final Object? exp = payload['exp'];
      final int? expSeconds = exp is int ? exp : (exp is num ? exp.toInt() : null);
      if (expSeconds == null) {
        return true;
      }
      final int nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return nowSeconds >= expSeconds;
    } on Object {
      return true;
    }
  }
}
