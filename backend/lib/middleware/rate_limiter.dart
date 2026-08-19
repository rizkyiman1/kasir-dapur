import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

/// Konfigurasi rate limit per endpoint pattern.
final class RateLimitRule {
  const RateLimitRule({required this.maxRequests, required this.window});

  /// Jumlah maksimum request dalam [window].
  final int maxRequests;

  /// Jendela waktu rate limiting.
  final Duration window;
}

/// State per-IP untuk satu rule.
final class _IpState {
  _IpState({required this.windowStart}) : count = 1;

  DateTime windowStart;
  int count;
}

/// In-memory rate limiter berbasis IP.
///
/// Konfigurasi default cocok untuk aplikasi kasir:
/// - Session (login): 10 request/menit
/// - Backup: 20 request/menit
/// - Sync push: 60 request/menit (satu push per detik)
/// - Billing: 30 request/menit
/// - Default (catch-all): 120 request/menit
///
/// Gunakan [RateLimiter.middleware] sebagai Shelf middleware.
final class RateLimiter {
  RateLimiter({
    Map<String, RateLimitRule>? rules,
    bool trustForwardedHeaders = false,
    Set<String>? trustedProxyIps,
    String Function(Request request)? remoteIpResolver,
  }) : _rules = rules ?? _defaultRules,
       _trustForwardedHeaders = trustForwardedHeaders,
       _trustedProxyIps = trustedProxyIps ?? const <String>{},
       _remoteIpResolver = remoteIpResolver;

  final Map<String, RateLimitRule> _rules;
  final bool _trustForwardedHeaders;
  final Set<String> _trustedProxyIps;
  final String Function(Request request)? _remoteIpResolver;

  /// path prefix → Map<ip, state>
  final Map<String, Map<String, _IpState>> _state =
      <String, Map<String, _IpState>>{};

  static const Map<String, RateLimitRule>
  _defaultRules = <String, RateLimitRule>{
    '/v1/auth': RateLimitRule(maxRequests: 10, window: Duration(minutes: 1)),
    '/v1/backup': RateLimitRule(maxRequests: 20, window: Duration(minutes: 1)),
    '/v1/sync': RateLimitRule(maxRequests: 60, window: Duration(minutes: 1)),
    '/v1/billing': RateLimitRule(maxRequests: 30, window: Duration(minutes: 1)),
    '/v1/sheets': RateLimitRule(maxRequests: 30, window: Duration(minutes: 1)),
    '/v1/audit': RateLimitRule(maxRequests: 30, window: Duration(minutes: 1)),
    '/': RateLimitRule(maxRequests: 120, window: Duration(minutes: 1)),
  };

  /// Middleware Shelf.
  Middleware get middleware {
    return (Handler inner) {
      return (Request request) async {
        final String path = '/${request.url.path}';
        final String ip = _clientIp(request);
        final RateLimitRule rule = _ruleFor(path);

        if (_isLimited(ip: ip, path: path, rule: rule)) {
          return Response(
            429,
            body: jsonEncode(<String, Object>{
              'error':
                  'Terlalu banyak request. Coba lagi setelah beberapa saat.',
            }),
            headers: const <String, String>{
              HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
              'Retry-After': '60',
            },
          );
        }

        return inner(request);
      };
    };
  }

  RateLimitRule _ruleFor(String path) {
    for (final String prefix in _rules.keys) {
      if (prefix != '/' && path.startsWith(prefix)) {
        return _rules[prefix]!;
      }
    }
    return _rules['/']!;
  }

  bool _isLimited({
    required String ip,
    required String path,
    required RateLimitRule rule,
  }) {
    final String key = _ruleKey(path);
    _state[key] ??= <String, _IpState>{};
    final Map<String, _IpState> ipMap = _state[key]!;

    final DateTime now = DateTime.now();
    final _IpState? state = ipMap[ip];

    if (state == null) {
      ipMap[ip] = _IpState(windowStart: now);
      return false;
    }

    if (now.difference(state.windowStart) > rule.window) {
      // Reset window baru
      state.windowStart = now;
      state.count = 1;
      return false;
    }

    state.count += 1;
    return state.count > rule.maxRequests;
  }

  String _ruleKey(String path) {
    for (final String prefix in _rules.keys) {
      if (prefix != '/' && path.startsWith(prefix)) {
        return prefix;
      }
    }
    return '/';
  }

  String _clientIp(Request request) {
    final String remoteIp = (_remoteIpResolver ?? _remoteIp)(request);
    if (!_trustForwardedHeaders || !_trustedProxyIps.contains(remoteIp)) {
      return remoteIp;
    }
    final String? forwarded = request.headers['x-forwarded-for'];
    final String? parsedForwarded = _parseForwardedFor(forwarded);
    if (parsedForwarded != null) {
      return parsedForwarded;
    }
    final String? realIp = request.headers['x-real-ip'];
    final String? parsedRealIp = _normalizeIp(realIp);
    return parsedRealIp ?? remoteIp;
  }

  String _remoteIp(Request request) {
    final Object? rawConnectionInfo = request.context['shelf.io.connection_info'];
    if (rawConnectionInfo is HttpConnectionInfo) {
      final String ip = rawConnectionInfo.remoteAddress.address.trim();
      if (ip.isNotEmpty) {
        return ip;
      }
    }
    return 'unknown';
  }

  String? _parseForwardedFor(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    for (final String part in raw.split(',')) {
      final String? normalized = _normalizeIp(part);
      if (normalized != null) {
        return normalized;
      }
    }
    return null;
  }

  String? _normalizeIp(String? raw) {
    if (raw == null) {
      return null;
    }
    final String value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    final InternetAddress? address = InternetAddress.tryParse(value);
    if (address == null) {
      return null;
    }
    return address.address;
  }
}
