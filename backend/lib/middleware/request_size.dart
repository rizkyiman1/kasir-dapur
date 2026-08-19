import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

/// Middleware pembatas ukuran request body.
///
/// Default:
/// - sync/backup payload: maks 10 MB (backup snapshot bisa besar)
/// - request lain: maks 1 MB
///
/// Jika body melebihi limit → HTTP 413.
Middleware requestSizeMiddleware({
  int defaultMaxBytes = 1 * 1024 * 1024, // 1 MB
  int backupSyncMaxBytes = 10 * 1024 * 1024, // 10 MB
}) {
  return (Handler inner) {
    return (Request request) async {
      final String path = '/${request.url.path}';
      final int limit = _limitFor(
        path,
        defaultMax: defaultMaxBytes,
        backupSyncMax: backupSyncMaxBytes,
      );

      // Cek Content-Length header terlebih dahulu (optimasi)
      final String? contentLength =
          request.headers[HttpHeaders.contentLengthHeader];
      if (contentLength != null) {
        final int? declared = int.tryParse(contentLength);
        if (declared != null && declared > limit) {
          return _tooLarge();
        }
      }

      // Baca body dan periksa ukuran aktual
      final List<int> bytes = await request.read().expand((c) => c).toList();
      if (bytes.length > limit) {
        return _tooLarge();
      }

      // Buat ulang request dengan body yang sudah dibaca
      final Request rebodied = request.change(body: bytes);
      return inner(rebodied);
    };
  };
}

int _limitFor(
  String path, {
  required int defaultMax,
  required int backupSyncMax,
}) {
  if (path.startsWith('/v1/backup') || path.startsWith('/v1/sync')) {
    return backupSyncMax;
  }
  return defaultMax;
}

Response _tooLarge() {
  return Response(
    413,
    body: jsonEncode(<String, Object>{
      'error': 'Ukuran request terlalu besar.',
    }),
    headers: const <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
    },
  );
}
