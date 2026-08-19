import 'dart:io';

import 'package:kasir_dapur_backend/config/backend_config.dart';
import 'package:kasir_dapur_backend/midtrans/midtrans_gateway.dart';
import 'package:kasir_dapur_backend/midtrans/midtrans_signature.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('subscription dan payment survive restart + duplicate webhook aman', () async {
    final String dbPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-restart-${DateTime.now().microsecondsSinceEpoch}.db';
    final BackendConfig config = testConfig().copyWith(
      billingSqlitePath: dbPath,
    );
    final FakeMidtransGateway midtransA = FakeMidtransGateway();
    final runtimeA = testRuntime(midtrans: midtransA, config: config);
    final String tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');

    final checkout = await postJson(
      runtimeA.handler,
      '/v1/billing/checkout',
      <String, Object>{'plan_code': 'PRO_MONTHLY', 'client_uuid': 'restart-1'},
      token: tokenA,
    );
    expect(checkout.statusCode, 200);
    final String orderId = (await readBody(checkout))['order_id']! as String;
    midtransA.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    final firstHook = await postJson(
      runtimeA.handler,
      '/v1/billing/midtrans/notification',
      signedNotification(
        orderId: orderId,
        status: 'settlement',
        amountRupiah: 150000,
      ),
    );
    expect((await readBody(firstHook))['activated'], isTrue);
    runtimeA.close();

    final FakeMidtransGateway midtransB = FakeMidtransGateway();
    midtransB.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    final runtimeB = testRuntime(midtrans: midtransB, config: config);

    final sub = await getJson(
      runtimeB.handler,
      '/v1/billing/subscription',
      token: tokenA,
    );
    final subBody = await readBody(sub);
    expect(subBody['plan_code'], 'PRO_MONTHLY');
    expect(subBody['status'], 'active');

    final payments = await getJson(
      runtimeB.handler,
      '/v1/billing/payments',
      token: tokenA,
    );
    final rows = (await readBody(payments))['payments'] as List<dynamic>;
    expect(rows, hasLength(1));
    expect((rows.first as Map<dynamic, dynamic>)['order_id'], orderId);
    expect((rows.first)['state'], 'verified');

    final dupHook = await postJson(
      runtimeB.handler,
      '/v1/billing/midtrans/notification',
      signedNotification(
        orderId: orderId,
        status: 'settlement',
        amountRupiah: 150000,
      ),
    );
    final dupBody = await readBody(dupHook);
    expect(dupBody['duplicate'], isTrue);
    expect(dupBody['activated'], isFalse);
    runtimeB.close();
  });

  test('pending payment direconcile saat startup runtime berikutnya', () async {
    final String dbPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-reconcile-${DateTime.now().microsecondsSinceEpoch}.db';
    final BackendConfig config = testConfig().copyWith(
      billingSqlitePath: dbPath,
    );
    final FakeMidtransGateway midtransA = FakeMidtransGateway();
    final runtimeA = testRuntime(midtrans: midtransA, config: config);
    final String tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');

    final checkout = await postJson(
      runtimeA.handler,
      '/v1/billing/checkout',
      <String, Object>{
        'plan_code': 'PRO_MONTHLY',
        'client_uuid': 'reconcile-1',
      },
      token: tokenA,
    );
    final String orderId = (await readBody(checkout))['order_id']! as String;
    runtimeA.close();

    final FakeMidtransGateway midtransB = FakeMidtransGateway();
    midtransB.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    final runtimeB = testRuntime(midtrans: midtransB, config: config);
    await runtimeB.startupReconcile();

    final sub = await getJson(
      runtimeB.handler,
      '/v1/billing/subscription',
      token: tokenA,
    );
    final subBody = await readBody(sub);
    expect(subBody['plan_code'], 'PRO_MONTHLY');
    expect(subBody['status'], 'active');
    runtimeB.close();
  });

  test('business monthly survive restart dengan entitlement dan order tetap', () async {
    final String dbPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-business-restart-${DateTime.now().microsecondsSinceEpoch}.db';
    final BackendConfig config = testConfig().copyWith(
      billingSqlitePath: dbPath,
    );
    final FakeMidtransGateway midtransA = FakeMidtransGateway();
    final runtimeA = testRuntime(midtrans: midtransA, config: config);
    final String tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');

    final checkout = await postJson(
      runtimeA.handler,
      '/v1/billing/checkout',
      <String, Object>{
        'plan_code': 'BUSINESS_MONTHLY',
        'client_uuid': 'business-restart-1',
      },
      token: tokenA,
    );
    final checkoutBody = await readBody(checkout);
    final String orderId = checkoutBody['order_id']! as String;
    midtransA.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(350000),
      ),
    );
    await postJson(
      runtimeA.handler,
      '/v1/billing/midtrans/notification',
      signedNotification(
        orderId: orderId,
        status: 'settlement',
        amountRupiah: 350000,
      ),
    );
    final before = await readBody(
      await getJson(
        runtimeA.handler,
        '/v1/billing/subscription',
        token: tokenA,
      ),
    );
    final int? endsBefore = before['ends_at'] as int?;
    runtimeA.close();

    final runtimeB = testRuntime(
      midtrans: FakeMidtransGateway(),
      config: config,
    );
    final after = await readBody(
      await getJson(
        runtimeB.handler,
        '/v1/billing/subscription',
        token: tokenA,
      ),
    );
    expect(after['plan_code'], 'BUSINESS_MONTHLY');
    expect(after['status'], 'active');
    expect(after['order_id'], orderId);
    expect(after['ends_at'], endsBefore);
    final ents = after['entitlements'] as List<dynamic>;
    expect(
      ents.any(
        (e) =>
            (e as Map<dynamic, dynamic>)['feature_key'] ==
                'business_features' &&
            e['is_enabled'] == true,
      ),
      isTrue,
    );
    runtimeB.close();
  });

  test('concurrent duplicate webhook hanya satu activation', () async {
    final String dbPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-webhook-concurrent-${DateTime.now().microsecondsSinceEpoch}.db';
    final BackendConfig config = testConfig().copyWith(
      billingSqlitePath: dbPath,
    );
    final FakeMidtransGateway midtrans = FakeMidtransGateway();
    final runtime = testRuntime(midtrans: midtrans, config: config);
    final String tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');

    final checkout = await postJson(
      runtime.handler,
      '/v1/billing/checkout',
      <String, Object>{
        'plan_code': 'PRO_MONTHLY',
        'client_uuid': 'webhook-concurrent-1',
      },
      token: tokenA,
    );
    final String orderId = (await readBody(checkout))['order_id']! as String;
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    final payload = signedNotification(
      orderId: orderId,
      status: 'settlement',
      amountRupiah: 150000,
    );
    final results = await Future.wait([
      postJson(runtime.handler, '/v1/billing/midtrans/notification', payload),
      postJson(runtime.handler, '/v1/billing/midtrans/notification', payload),
    ]);
    final bodyA = await readBody(results[0]);
    final bodyB = await readBody(results[1]);
    final activatedCount =
        (bodyA['activated'] == true ? 1 : 0) +
        (bodyB['activated'] == true ? 1 : 0);
    expect(activatedCount, 1);

    final payments = await readBody(
      await getJson(runtime.handler, '/v1/billing/payments', token: tokenA),
    );
    final rows = payments['payments'] as List<dynamic>;
    expect(rows, hasLength(1));
    expect((rows.first as Map<dynamic, dynamic>)['state'], 'verified');

    final db = runtime.billing.db.raw;
    final hookRows = db.select(
      'SELECT COUNT(*) AS c FROM webhook_events WHERE order_id = ?;',
      <Object?>[orderId],
    );
    expect((hookRows.first['c'] as int) >= 1, isTrue);
    final activationAudit = db.select(
      "SELECT COUNT(*) AS c FROM billing_audit_events WHERE event_type = 'subscription.activated' AND order_id = ?;",
      <Object?>[orderId],
    );
    expect(activationAudit.first['c'], 1);
    runtime.close();
  });
}
