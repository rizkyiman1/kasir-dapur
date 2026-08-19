import 'dart:convert';
import 'dart:io';

import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/features/sync/domain/cloud_sync_gateway.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';

final class HttpCloudSyncGateway implements CloudSyncGateway {
  HttpCloudSyncGateway({
    required this.apiBaseUrl,
    Future<String?> Function()? readAccessToken,
    HttpClient? client,
  }) : _readAccessToken = readAccessToken,
       _client = client;

  final String apiBaseUrl;
  final Future<String?> Function()? _readAccessToken;
  final HttpClient? _client;

  static const Duration _timeout = Duration(seconds: 20);

  @override
  Future<CloudSyncBatchResult> push({
    required String businessId,
    required List<CloudSyncJob> jobs,
  }) async {
    final Object json = await _post('/v1/sync/push', <String, Object>{
      'business_id': businessId,
      'jobs': jobs.map((CloudSyncJob job) => job.toJson()).toList(),
    });
    if (json is! Map) {
      throw const ValidationException('Respons sinkronisasi tidak valid.');
    }
    final Map<Object?, Object?> map = json.cast<Object?, Object?>();
    return CloudSyncBatchResult(
      accepted: _intOf(map['accepted']),
      duplicates: _intOf(map['duplicates']),
      failedClientUuids: _stringList(map['failed_client_uuids']),
    );
  }

  Future<Object> _post(String path, Map<String, Object> body) async {
    final HttpClient client = _client ?? HttpClient();
    final bool owned = _client == null;
    try {
      final HttpClientRequest request = await client
          .postUrl(Uri.parse('$apiBaseUrl$path'))
          .timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final String? token = await _readAccessToken?.call();
      if (token != null && token.trim().isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final HttpClientResponse response = await request.close().timeout(
        _timeout,
      );
      final String text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == HttpStatus.unauthorized) {
          throw const AuthException(
            'Sesi cloud berakhir atau tidak valid. Silakan login ulang.',
          );
        }
        if (response.statusCode == HttpStatus.forbidden) {
          throw const ForbiddenException(
            'Akses sinkronisasi cloud tidak tersedia untuk paket Anda.',
          );
        }
        throw const ValidationException(
          'Server sinkronisasi menolak antrian. Data lokal tetap aman.',
        );
      }
      if (text.trim().isEmpty) {
        return <String, Object>{};
      }
      return jsonDecode(text) as Object;
    } on AppException {
      rethrow;
    } on Object {
      throw const ValidationException(
        'Tidak terhubung ke server sinkronisasi. Transaksi lokal tetap berjalan.',
      );
    } finally {
      if (owned) {
        client.close(force: true);
      }
    }
  }

  int _intOf(Object? value) {
    if (value is int) {
      return value;
    }
    return 0;
  }

  List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value.whereType<String>().toList();
  }
}

final class HttpConnectivityPort implements ConnectivityPort {
  HttpConnectivityPort({required this.apiBaseUrl});

  final String apiBaseUrl;

  @override
  Future<bool> isOnline() async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client
          .getUrl(Uri.parse('$apiBaseUrl/health'))
          .timeout(const Duration(seconds: 3));
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 500;
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}

final class MemoryCloudSyncGateway implements CloudSyncGateway {
  MemoryCloudSyncGateway({this.fail = false});

  bool fail;
  final Set<String> rejectClientUuids = <String>{};
  final List<CloudSyncJob> pushed = <CloudSyncJob>[];
  final Set<String> _seen = <String>{};

  @override
  Future<CloudSyncBatchResult> push({
    required String businessId,
    required List<CloudSyncJob> jobs,
  }) async {
    if (fail) {
      throw const ValidationException('Offline atau server tidak tersedia.');
    }
    int duplicates = 0;
    int accepted = 0;
    final List<String> failed = <String>[];
    for (final CloudSyncJob job in jobs) {
      if (rejectClientUuids.contains(job.clientUuid)) {
        failed.add(job.clientUuid);
        continue;
      }
      if (_seen.contains(job.clientUuid)) {
        duplicates += 1;
        continue;
      }
      _seen.add(job.clientUuid);
      pushed.add(job);
      accepted += 1;
    }
    return CloudSyncBatchResult(
      accepted: accepted,
      duplicates: duplicates,
      failedClientUuids: failed,
    );
  }
}

final class MemoryConnectivityPort implements ConnectivityPort {
  MemoryConnectivityPort({this.online = true});

  bool online;

  @override
  Future<bool> isOnline() async => online;
}
