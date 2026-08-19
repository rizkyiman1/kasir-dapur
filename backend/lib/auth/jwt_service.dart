import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Claims yang disimpan di dalam JWT.
final class JwtClaims {
  const JwtClaims({
    required this.sub,
    required this.businessId,
    required this.role,
    required this.iat,
    required this.exp,
  });

  /// user_id
  final String sub;

  /// business yang dimiliki user ini
  final String businessId;

  /// 'owner' | 'admin' | 'cashier'
  final String role;

  /// issued-at (Unix epoch seconds)
  final int iat;

  /// expiration (Unix epoch seconds)
  final int exp;

  factory JwtClaims.fromPayload(Map<String, Object?> payload) {
    final String? sub = payload['sub'] as String?;
    final String? businessId = payload['business_id'] as String?;
    final String? role = payload['role'] as String?;
    final int? iat = (payload['iat'] as num?)?.toInt();
    final int? exp = (payload['exp'] as num?)?.toInt();

    if (sub == null || sub.isEmpty) {
      throw const FormatException('JWT: claim sub wajib.');
    }
    if (businessId == null || businessId.isEmpty) {
      throw const FormatException('JWT: claim business_id wajib.');
    }
    if (role == null || !_validRoles.contains(role)) {
      throw const FormatException('JWT: claim role tidak valid.');
    }
    if (iat == null) {
      throw const FormatException('JWT: claim iat wajib.');
    }
    if (exp == null) {
      throw const FormatException('JWT: claim exp wajib.');
    }
    return JwtClaims(
      sub: sub,
      businessId: businessId,
      role: role,
      iat: iat,
      exp: exp,
    );
  }

  static const Set<String> _validRoles = <String>{'owner', 'admin', 'cashier'};

  Map<String, Object> toPayload() => <String, Object>{
    'sub': sub,
    'business_id': businessId,
    'role': role,
    'iat': iat,
    'exp': exp,
  };
}

/// Authenticated context yang disisipkan ke request context oleh middleware.
final class AuthenticatedUser {
  const AuthenticatedUser({
    required this.userId,
    required this.businessId,
    required this.role,
  });

  final String userId;
  final String businessId;
  final String role;

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin' || role == 'owner';
  bool get isCashier => true; // cashier, admin, owner semua punya akses POS
}

/// Service untuk sign dan verify JWT HS256.
/// Tidak boleh hardcode secret — selalu dari environment.
final class JwtService {
  JwtService({required String secret}) : _secret = secret;

  final String _secret;
  static const String issuer = 'kasir-dapur';

  /// Durasi token default: 30 hari.
  static const Duration defaultExpiry = Duration(days: 30);

  /// Sign JWT baru dengan claims yang diberikan.
  String sign({
    required String sub,
    required String businessId,
    required String role,
    Duration expiry = defaultExpiry,
  }) {
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int exp = now + expiry.inSeconds;

    final JWT jwt = JWT(<String, Object>{
      'sub': sub,
      'business_id': businessId,
      'role': role,
      'iat': now,
      'exp': exp,
    }, issuer: issuer);

    return jwt.sign(SecretKey(_secret), algorithm: JWTAlgorithm.HS256);
  }

  /// Verify dan parse JWT. Lempar [JwtException] jika tidak valid.
  /// Mengembalikan [JwtClaims] jika valid.
  JwtClaims verify(String token) {
    try {
      final JWT jwt = JWT.verify(
        token,
        SecretKey(_secret),
        checkHeaderType: true,
      );
      final Object? payload = jwt.payload;
      if (payload is! Map) {
        throw const JwtException('JWT payload bukan objek.');
      }
      final Map<String, Object?> claims = payload.map(
        (Object? k, Object? v) => MapEntry<String, Object?>(k.toString(), v),
      );
      final String? tokenIssuer = claims['iss'] as String?;
      if (tokenIssuer != issuer) {
        throw const JwtException('Issuer token tidak valid.');
      }
      return JwtClaims.fromPayload(claims);
    } on JWTExpiredException {
      throw const JwtException('Token kedaluwarsa.');
    } on JWTInvalidException catch (e) {
      throw JwtException('Token tidak valid: ${e.message}');
    } on JWTException catch (e) {
      throw JwtException('Token error: ${e.message}');
    } on FormatException catch (e) {
      throw JwtException('JWT format error: ${e.message}');
    }
  }
}

/// Exception JWT — tidak mengandung detail internal.
final class JwtException implements Exception {
  const JwtException(this.message);

  final String message;

  @override
  String toString() => 'JwtException: $message';
}
