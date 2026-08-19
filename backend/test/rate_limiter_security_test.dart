library;

import 'package:kasir_dapur_backend/middleware/rate_limiter.dart';
import 'package:kasir_dapur_backend/midtrans/midtrans_gateway.dart';
import 'package:kasir_dapur_backend/runtime.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  Future<Response> sendHealth(
    Handler handler, {
    String? xForwardedFor,
    String? xRealIp,
  }) {
    return Future<Response>.value(
      handler(
      Request(
        'GET',
        Uri.parse('http://localhost/health'),
        headers: <String, String>{
          if (xForwardedFor != null) 'x-forwarded-for': xForwardedFor,
          if (xRealIp != null) 'x-real-ip': xRealIp,
        },
      ),
    ),
    );
  }

  test('spoofed x-forwarded-for tidak bypass saat proxy untrusted', () async {
    final runtime = BackendRuntime.testing(
      config: testConfig(),
      midtrans: FakeMidtransGateway(),
      rateLimiter: RateLimiter(
        rules: <String, RateLimitRule>{
          '/': const RateLimitRule(maxRequests: 2, window: Duration(minutes: 1)),
        },
        trustForwardedHeaders: false,
      ),
    );
    final handler = runtime.handler;

    final r1 = await sendHealth(handler, xForwardedFor: '1.1.1.1');
    final r2 = await sendHealth(handler, xForwardedFor: '2.2.2.2');
    final r3 = await sendHealth(handler, xForwardedFor: '3.3.3.3');
    expect(r1.statusCode, 200);
    expect(r2.statusCode, 200);
    expect(r3.statusCode, 429);
  });

  test('header berbeda tidak jadi bypass quota saat proxy untrusted', () async {
    final runtime = BackendRuntime.testing(
      config: testConfig(),
      midtrans: FakeMidtransGateway(),
      rateLimiter: RateLimiter(
        rules: <String, RateLimitRule>{
          '/': const RateLimitRule(maxRequests: 1, window: Duration(minutes: 1)),
        },
        trustForwardedHeaders: false,
      ),
    );
    final handler = runtime.handler;
    final first = await sendHealth(handler, xForwardedFor: '8.8.8.8');
    final second = await sendHealth(handler, xForwardedFor: '9.9.9.9');
    expect(first.statusCode, 200);
    expect(second.statusCode, 429);
  });

  test('forwarded trusted hanya dari proxy tepercaya', () async {
    final runtime = BackendRuntime.testing(
      config: testConfig(),
      midtrans: FakeMidtransGateway(),
      rateLimiter: RateLimiter(
        rules: <String, RateLimitRule>{
          '/': const RateLimitRule(maxRequests: 1, window: Duration(minutes: 1)),
        },
        trustForwardedHeaders: true,
        trustedProxyIps: const <String>{'10.0.0.10'},
        remoteIpResolver: (_) => '10.0.0.10',
      ),
    );
    final handler = runtime.handler;
    final first = await sendHealth(handler, xForwardedFor: '101.1.1.1');
    final second = await sendHealth(handler, xForwardedFor: '102.2.2.2');
    final third = await sendHealth(handler, xForwardedFor: '101.1.1.1');
    expect(first.statusCode, 200);
    expect(second.statusCode, 200);
    expect(third.statusCode, 429);
  });

  test('forwarded malformed tidak crash', () async {
    final runtime = BackendRuntime.testing(
      config: testConfig(),
      midtrans: FakeMidtransGateway(),
      rateLimiter: RateLimiter(
        rules: <String, RateLimitRule>{
          '/': const RateLimitRule(maxRequests: 5, window: Duration(minutes: 1)),
        },
        trustForwardedHeaders: true,
        trustedProxyIps: const <String>{'10.0.0.10'},
        remoteIpResolver: (_) => '10.0.0.10',
      ),
    );
    final response = await sendHealth(
      runtime.handler,
      xForwardedFor: 'bad-ip-value, ???',
    );
    expect(response.statusCode, 200);
  });

  test('multiple forwarded IP values diparsing aman', () async {
    final runtime = BackendRuntime.testing(
      config: testConfig(),
      midtrans: FakeMidtransGateway(),
      rateLimiter: RateLimiter(
        rules: <String, RateLimitRule>{
          '/': const RateLimitRule(maxRequests: 1, window: Duration(minutes: 1)),
        },
        trustForwardedHeaders: true,
        trustedProxyIps: const <String>{'10.0.0.10'},
        remoteIpResolver: (_) => '10.0.0.10',
      ),
    );
    final handler = runtime.handler;
    final first = await sendHealth(handler, xForwardedFor: 'bad, 7.7.7.7, 8.8.8.8');
    final second = await sendHealth(handler, xForwardedFor: '7.7.7.7');
    expect(first.statusCode, 200);
    expect(second.statusCode, 429);
  });
}
