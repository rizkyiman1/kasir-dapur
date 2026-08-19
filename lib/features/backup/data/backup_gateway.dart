import 'dart:convert';
import 'dart:io';

import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/features/backup/domain/backup_gateway.dart';
import 'package:kasir_dapur/features/backup/domain/backup_models.dart';

final class HttpBackupGateway implements BackupGateway {
  HttpBackupGateway({
    required this.apiBaseUrl,
    Future<String?> Function()? readAccessToken,
    HttpClient? client,
  }) : _readAccessToken = readAccessToken,
       _client = client;

  final String apiBaseUrl;
  final Future<String?> Function()? _readAccessToken;
  final HttpClient? _client;

  static const Duration _timeout = Duration(seconds: 45);

  @override
  Future<RemoteBackupInfo> upload({
    required String businessId,
    required String clientUuid,
    required BackupSnapshot snapshot,
  }) async {
    final Object json = await _send(
      'POST',
      '/v1/backup',
      body: <String, Object?>{
        'business_id': businessId,
        'client_uuid': clientUuid,
        'snapshot': snapshot.toJson(),
      },
    );
    return _info(json, snapshot: snapshot);
  }

  @override
  Future<List<RemoteBackupInfo>> list(String businessId) async {
    final Object json = await _send(
      'GET',
      '/v1/backup?business_id=${Uri.encodeQueryComponent(businessId)}',
    );
    if (json is! Map) {
      return const <RemoteBackupInfo>[];
    }
    final Object? rows = json['backups'];
    if (rows is! List) {
      return const <RemoteBackupInfo>[];
    }
    return rows
        .map((Object? row) => _info(row ?? const <String, Object>{}))
        .toList();
  }

  @override
  Future<RemoteBackupInfo> getById({
    required String businessId,
    required String backupId,
  }) async {
    final Object json = await _send(
      'GET',
      '/v1/backup/${Uri.encodeComponent(backupId)}'
          '?business_id=${Uri.encodeQueryComponent(businessId)}',
    );
    return _info(json);
  }

  Future<Object> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final HttpClient client = _client ?? HttpClient();
    final bool owned = _client == null;
    try {
      final Uri uri = Uri.parse('$apiBaseUrl$path');
      final HttpClientRequest request = method == 'POST'
          ? await client.postUrl(uri).timeout(_timeout)
          : await client.getUrl(uri).timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final String? token = await _readAccessToken?.call();
      if (token != null && token.trim().isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
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
            'Akses cadangan cloud tidak tersedia untuk paket Anda.',
          );
        }
        throw const ValidationException(
          'Server cadangan menolak permintaan. Data kasir tetap di SQLite.',
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
        'Tidak terhubung ke server cadangan. Transaksi lokal tetap berjalan.',
      );
    } finally {
      if (owned) {
        client.close(force: true);
      }
    }
  }

  RemoteBackupInfo _info(Object json, {BackupSnapshot? snapshot}) {
    if (json is! Map) {
      throw const ValidationException('Respons cadangan tidak valid.');
    }
    final Map<String, Object?> map = json.map(
      (Object? key, Object? value) =>
          MapEntry<String, Object?>(key.toString(), value),
    );
    final Object? rawSnapshot = map['snapshot'];
    BackupSnapshot? parsed = snapshot;
    if (rawSnapshot is Map) {
      parsed = BackupSnapshot.fromJson(
        rawSnapshot.map(
          (Object? key, Object? value) =>
              MapEntry<String, Object?>(key.toString(), value),
        ),
      );
    }
    return RemoteBackupInfo(
      id: map['backup_id'] as String? ?? map['id'] as String? ?? '',
      businessId: map['business_id'] as String? ?? parsed?.businessId ?? '',
      createdAt: map['created_at'] is int ? map['created_at']! as int : 0,
      counts: _counts(map['counts'] ?? parsed?.counts),
      snapshot: parsed,
    );
  }

  Map<String, int> _counts(Object? value) {
    if (value is! Map) {
      return const <String, int>{};
    }
    return value.map((Object? key, Object? val) {
      final int n = val is int ? val : 0;
      return MapEntry<String, int>(key.toString(), n);
    });
  }
}

final class MemoryBackupGateway implements BackupGateway {
  MemoryBackupGateway({this.fail = false});

  bool fail;
  final Map<String, RemoteBackupInfo> _byId = <String, RemoteBackupInfo>{};
  final Map<String, String> _byClient = <String, String>{};
  int _seq = 0;

  @override
  Future<RemoteBackupInfo> upload({
    required String businessId,
    required String clientUuid,
    required BackupSnapshot snapshot,
  }) async {
    if (fail) {
      throw const ValidationException(
        'Cadangan gagal. Kasir tetap dapat digunakan.',
      );
    }
    final String? existing = _byClient[clientUuid];
    if (existing != null) {
      return _byId[existing]!;
    }
    _seq += 1;
    final String id = 'bak-$_seq';
    final RemoteBackupInfo info = RemoteBackupInfo(
      id: id,
      businessId: businessId,
      createdAt: snapshot.createdAt,
      counts: snapshot.counts,
      snapshot: snapshot,
    );
    _byClient[clientUuid] = id;
    _byId[id] = info;
    return info;
  }

  @override
  Future<List<RemoteBackupInfo>> list(String businessId) async {
    if (fail) {
      throw const ValidationException(
        'Tidak terhubung ke server cadangan. Transaksi lokal tetap berjalan.',
      );
    }
    return _byId.values
        .where((RemoteBackupInfo row) => row.businessId == businessId)
        .toList();
  }

  @override
  Future<RemoteBackupInfo> getById({
    required String businessId,
    required String backupId,
  }) async {
    if (fail) {
      throw const ValidationException(
        'Tidak terhubung ke server cadangan. Transaksi lokal tetap berjalan.',
      );
    }
    final RemoteBackupInfo? row = _byId[backupId];
    if (row == null || row.businessId != businessId) {
      throw const NotFoundException('Cadangan tidak ditemukan.');
    }
    return row;
  }
}
