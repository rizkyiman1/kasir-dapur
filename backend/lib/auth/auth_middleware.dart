import 'dart:convert';
import 'dart:io';

import 'package:kasir_dapur_backend/auth/jwt_service.dart';
import 'package:shelf/shelf.dart';

/// Key untuk menyimpan [AuthenticatedUser] di context Shelf.
const _kAuthKey = 'authenticated_user';

/// Endpoint yang boleh diakses tanpa token.
const Set<String> publicPaths = <String>{
  '/health',
  '/v1/auth/cloud/session',
  '/v1/billing/midtrans/notification',
};

/// Middleware autentikasi JWT.
///
/// - Mengizinkan request ke [publicPaths] tanpa token.
/// - Semua endpoint lain wajib `Authorization: Bearer <JWT>`.
/// - Token invalid / expired → HTTP 401 (tanpa detail internal).
/// - Token valid → menyimpan [AuthenticatedUser] di context.
Middleware jwtAuthMiddleware(JwtService jwtService) {
  return (Handler inner) {
    return (Request request) async {
      final String path = '/${request.url.path}';

      if (publicPaths.contains(path)) {
        return inner(request);
      }

      final String? authHeader =
          request.headers[HttpHeaders.authorizationHeader];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return _unauthorized();
      }

      final String token = authHeader.substring(7);
      if (token.isEmpty) {
        return _unauthorized();
      }

      try {
        final JwtClaims claims = jwtService.verify(token);
        final AuthenticatedUser user = AuthenticatedUser(
          userId: claims.sub,
          businessId: claims.businessId,
          role: claims.role,
        );
        final Request updated = request.change(
          context: <String, Object>{..._inherit(request), _kAuthKey: user},
        );
        return await inner(updated);
      } on JwtException {
        // Jangan bocorkan detail error JWT ke client
        return _unauthorized();
      }
    };
  };
}

/// Ambil [AuthenticatedUser] dari context request.
/// Throws [StateError] jika middleware tidak dipasang.
AuthenticatedUser requireAuth(Request request) {
  final Object? user = request.context[_kAuthKey];
  if (user is AuthenticatedUser) {
    return user;
  }
  throw StateError('jwtAuthMiddleware tidak dipasang untuk endpoint ini.');
}

Response _unauthorized([String message = 'Autentikasi diperlukan.']) {
  return Response(
    401,
    body: jsonEncode(<String, Object>{'error': message}),
    headers: const <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
      HttpHeaders.wwwAuthenticateHeader: 'Bearer realm="Kasir Dapur"',
    },
  );
}

Map<String, Object> _inherit(Request request) {
  return request.context.map(
    (String k, Object? v) => MapEntry<String, Object>(k, v ?? const Object()),
  );
}
