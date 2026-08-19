import 'package:kasir_dapur_backend/config/backend_config.dart';
import 'package:kasir_dapur_backend/midtrans/midtrans_gateway.dart';
import 'package:kasir_dapur_backend/runtime.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('pricing komersial final terbaca dari konfigurasi backend', () async {
    final config = testConfig().copyWith(
      pricing: const PricingConfig(
        proMonthly: 49000,
        proYearly: 490000,
        businessMonthly: 99000,
        businessYearly: 990000,
        gracePeriodDays: 7,
      ),
    );
    final runtime = testRuntime(config: config);
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');

    final proMonthly = await readBody(
      await postJson(runtime.handler, '/v1/billing/checkout', <String, Object>{
        'plan_code': 'PRO_MONTHLY',
        'client_uuid': 'price-pro-monthly',
      }, token: token),
    );
    expect(proMonthly['amount'], 49000);

    final proYearly = await readBody(
      await postJson(runtime.handler, '/v1/billing/checkout', <String, Object>{
        'plan_code': 'PRO_YEARLY',
        'client_uuid': 'price-pro-yearly',
      }, token: token),
    );
    expect(proYearly['amount'], 490000);

    final businessMonthly = await readBody(
      await postJson(runtime.handler, '/v1/billing/checkout', <String, Object>{
        'plan_code': 'BUSINESS_MONTHLY',
        'client_uuid': 'price-biz-monthly',
      }, token: token),
    );
    expect(businessMonthly['amount'], 99000);

    final businessYearly = await readBody(
      await postJson(runtime.handler, '/v1/billing/checkout', <String, Object>{
        'plan_code': 'BUSINESS_YEARLY',
        'client_uuid': 'price-biz-yearly',
      }, token: token),
    );
    expect(businessYearly['amount'], 990000);
  });

  test('checkout tidak mengaktifkan paket', () async {
    final FakeMidtransGateway midtrans = FakeMidtransGateway();
    final runtime = testRuntime(midtrans: midtrans);
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');

    final checkout = await postJson(
      runtime.handler,
      '/v1/billing/checkout',
      <String, Object>{'plan_code': 'PRO_MONTHLY', 'client_uuid': 'client-1'},
      token: token,
    );
    expect(checkout.statusCode, 200);
    final Map<String, Object?> body = await readBody(checkout);
    expect(body['amount'], 150000);
    expect(body['plan_code'], 'PRO_MONTHLY');
    expect(body['snap_token'], isNotEmpty);
    expect('$body', isNot(contains(testServerKey)));
    expect(midtrans.createdOrders, isNotEmpty);

    final current = await getJson(
      runtime.handler,
      '/v1/billing/subscription',
      token: token,
    );
    final Map<String, Object?> sub = await readBody(current);
    expect(sub['plan_code'], 'FREE');
    expect(sub['status'], 'active');
  });

  test('harga berasal dari konfigurasi backend, bukan body klien', () async {
    final runtime = testRuntime();
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');

    final checkout = await postJson(
      runtime.handler,
      '/v1/billing/checkout',
      <String, Object>{
        'plan_code': 'PRO_MONTHLY',
        'client_uuid': 'client-2',
        'amount': 1,
      },
      token: token,
    );
    final Map<String, Object?> body = await readBody(checkout);
    expect(body['amount'], 150000);
  });

  test('checkout tanpa harga di konfigurasi ditolak', () async {
    final unpaid = BackendConfig(
      port: 0,
      publicBaseUrl: 'http://localhost',
      midtrans: testConfig().midtrans,
      pricing: const PricingConfig(
        proMonthly: null,
        proYearly: null,
        businessMonthly: null,
        businessYearly: null,
        gracePeriodDays: 7,
      ),
      jwtSecret: testJwtSecret,
      googleSheetsClientId: '',
      googleSheetsClientSecret: '',
      googleSheetsSpreadsheetId: '',
      googleSheetsAccessToken: '',
      backupBucket: '',
      billingSqlitePath: testConfig().billingSqlitePath,
      trustProxyHeaders: false,
      trustedProxyIps: const <String>{},
      enforceProductionSecrets: false,
    );
    final bare = BackendRuntime.testing(
      config: unpaid,
      midtrans: FakeMidtransGateway(),
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');

    final checkout = await postJson(
      bare.handler,
      '/v1/billing/checkout',
      <String, Object>{'plan_code': 'PRO_MONTHLY', 'client_uuid': 'client-3'},
      token: token,
    );
    expect(checkout.statusCode, 400);
    final Map<String, Object?> body = await readBody(checkout);
    expect(body['error'], contains('Harga belum ditetapkan'));
  });

  test('checkout tanpa token ditolak 401', () async {
    final runtime = testRuntime();
    final checkout = await postJson(
      runtime.handler,
      '/v1/billing/checkout',
      <String, Object>{'plan_code': 'PRO_MONTHLY', 'client_uuid': 'no-token'},
    );
    expect(checkout.statusCode, 401);
  });

  test('client tidak dapat menentukan business_id lain di checkout', () async {
    final runtime = testRuntime();
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');

    // Client mencoba checkout untuk biz-B tapi punya token biz-A
    final checkout = await postJson(
      runtime.handler,
      '/v1/billing/checkout',
      <String, Object>{
        'business_id': 'biz-B',
        'plan_code': 'PRO_MONTHLY',
        'client_uuid': 'client-isolation',
      },
      token: token,
    );
    // Harus sukses tapi untuk biz-A, bukan biz-B
    expect(checkout.statusCode, 200);
    final body = await readBody(checkout);
    // order_id tidak boleh menyebabkan aktivasi di biz-B
    final subB = await getJson(
      runtime.handler,
      '/v1/billing/subscription',
      token: tokenFor(userId: 'user-B', businessId: 'biz-B'),
    );
    final subBBody = await readBody(subB);
    // biz-B tetap FREE
    expect(subBBody['plan_code'], 'FREE');
    expect(body['amount'], 150000);
  });

  test(
    'concurrent checkout dengan client_uuid sama tetap satu payment/order',
    () async {
      final runtime = testRuntime();
      final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
      final futures = await Future.wait([
        postJson(runtime.handler, '/v1/billing/checkout', <String, Object>{
          'plan_code': 'PRO_MONTHLY',
          'client_uuid': 'dup-checkout-concurrent',
        }, token: token),
        postJson(runtime.handler, '/v1/billing/checkout', <String, Object>{
          'plan_code': 'PRO_MONTHLY',
          'client_uuid': 'dup-checkout-concurrent',
        }, token: token),
      ]);
      final bodyA = await readBody(futures[0]);
      final bodyB = await readBody(futures[1]);
      expect(bodyA['order_id'], bodyB['order_id']);

      final payments = await readBody(
        await getJson(runtime.handler, '/v1/billing/payments', token: token),
      );
      final rows = payments['payments'] as List<dynamic>;
      expect(rows, hasLength(1));
    },
  );

  test('checkout uuid sama tapi business berbeda ditolak', () async {
    final runtime = testRuntime();
    final tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final tokenB = tokenFor(userId: 'user-B', businessId: 'biz-B');
    final first = await postJson(
      runtime.handler,
      '/v1/billing/checkout',
      <String, Object>{
        'plan_code': 'PRO_MONTHLY',
        'client_uuid': 'dup-cross-biz',
      },
      token: tokenA,
    );
    expect(first.statusCode, 200);
    final second = await postJson(
      runtime.handler,
      '/v1/billing/checkout',
      <String, Object>{
        'plan_code': 'PRO_MONTHLY',
        'client_uuid': 'dup-cross-biz',
      },
      token: tokenB,
    );
    expect(second.statusCode, 400);
  });

  test(
    'checkout uuid sama tapi plan berbeda pada business sama ditolak',
    () async {
      final runtime = testRuntime();
      final tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');
      final first = await postJson(
        runtime.handler,
        '/v1/billing/checkout',
        <String, Object>{
          'plan_code': 'PRO_MONTHLY',
          'client_uuid': 'dup-plan-same-biz',
        },
        token: tokenA,
      );
      expect(first.statusCode, 200);
      final second = await postJson(
        runtime.handler,
        '/v1/billing/checkout',
        <String, Object>{
          'plan_code': 'BUSINESS_MONTHLY',
          'client_uuid': 'dup-plan-same-biz',
        },
        token: tokenA,
      );
      expect(second.statusCode, 400);
    },
  );
}
