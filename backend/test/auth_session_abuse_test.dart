library;

import 'package:kasir_dapur_backend/middleware/rate_limiter.dart';
import 'package:kasir_dapur_backend/midtrans/midtrans_gateway.dart';
import 'package:kasir_dapur_backend/runtime.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('cloud session brute-force dibatasi rate limiter', () async {
    final runtime = BackendRuntime.testing(
      config: testConfig(),
      midtrans: FakeMidtransGateway(),
      rateLimiter: RateLimiter(
        rules: <String, RateLimitRule>{
          '/v1/auth': const RateLimitRule(maxRequests: 2, window: Duration(minutes: 1)),
          '/': const RateLimitRule(maxRequests: 100, window: Duration(minutes: 1)),
        },
      ),
    );

    final first = await postJson(
      runtime.handler,
      '/v1/auth/cloud/session',
      <String, Object>{'user_id': 'user-A', 'pin': 'wrong-1'},
    );
    final second = await postJson(
      runtime.handler,
      '/v1/auth/cloud/session',
      <String, Object>{'user_id': 'user-A', 'pin': 'wrong-2'},
    );
    final third = await postJson(
      runtime.handler,
      '/v1/auth/cloud/session',
      <String, Object>{'user_id': 'user-A', 'pin': 'wrong-3'},
    );

    expect(first.statusCode, 401);
    expect(second.statusCode, 401);
    expect(third.statusCode, 429);
  });
}
