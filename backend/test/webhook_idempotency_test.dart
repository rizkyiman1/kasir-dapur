import 'package:kasir_dapur_backend/midtrans/midtrans_gateway.dart';
import 'package:kasir_dapur_backend/midtrans/midtrans_signature.dart';
import 'package:kasir_dapur_backend/runtime.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:kasir_dapur_backend/domain/billing_plan.dart';

import 'helpers.dart';

void main() {
  late FakeMidtransGateway midtrans;
  late BackendRuntime runtime;

  setUp(() {
    midtrans = FakeMidtransGateway();
    runtime = testRuntime(midtrans: midtrans);
  });

  // Checkout selalu menggunakan token biz-1
  final String token = tokenFor(userId: 'user-A', businessId: 'biz-A');

  Future<String> checkoutOrder() async {
    final Response response = await postJson(
      runtime.handler,
      '/v1/billing/checkout',
      <String, Object>{'plan_code': 'PRO_MONTHLY', 'client_uuid': 'client-pay'},
      token: token,
    );
    final Map<String, Object?> body = await readBody(response);
    return body['order_id']! as String;
  }

  test('settlement + Get Status mengaktifkan paket dan entitlement', () async {
    final String orderId = await checkoutOrder();
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    final Response hook = await postJson(
      runtime.handler,
      '/v1/billing/midtrans/notification',
      signedNotification(
        orderId: orderId,
        status: 'settlement',
        amountRupiah: 150000,
      ),
    );
    expect(hook.statusCode, 200);
    final Map<String, Object?> hookBody = await readBody(hook);
    expect(hookBody['activated'], isTrue);
    expect(hookBody['duplicate'], isFalse);

    // Verifikasi subscription — menggunakan token JWT
    final Response current = await getJson(
      runtime.handler,
      '/v1/billing/subscription',
      token: token,
    );
    final Map<String, Object?> sub = await readBody(current);
    expect(sub['plan_code'], 'PRO_MONTHLY');
    expect(sub['status'], 'active');
    expect(sub['verified_at'], isNotNull);
    final List<dynamic> entitlements = sub['entitlements']! as List<dynamic>;
    final Map<dynamic, dynamic> sheets = entitlements
        .cast<Map<dynamic, dynamic>>()
        .firstWhere(
          (Map<dynamic, dynamic> row) => row['feature_key'] == 'google_sheets',
        );
    expect(sheets['is_enabled'], isTrue);
  });

  test('webhook duplikat tidak menambah langganan kedua', () async {
    final String orderId = await checkoutOrder();
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    final Map<String, Object> payload = signedNotification(
      orderId: orderId,
      status: 'settlement',
      amountRupiah: 150000,
    );
    final Response first = await postJson(
      runtime.handler,
      '/v1/billing/midtrans/notification',
      payload,
    );
    final Response second = await postJson(
      runtime.handler,
      '/v1/billing/midtrans/notification',
      payload,
    );
    expect((await readBody(first))['activated'], isTrue);
    final Map<String, Object?> dup = await readBody(second);
    expect(dup['duplicate'], isTrue);
    expect(dup['activated'], isFalse);

    final Response payments = await getJson(
      runtime.handler,
      '/v1/billing/payments',
      token: token,
    );
    final List<dynamic> rows =
        (await readBody(payments))['payments']! as List<dynamic>;
    expect(rows, hasLength(1));
    expect((rows.first as Map<dynamic, dynamic>)['state'], 'verified');
  });

  test('pending webhook tidak mengaktifkan paket', () async {
    final String orderId = await checkoutOrder();
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'pending',
        statusCode: '201',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    final Response hook = await postJson(
      runtime.handler,
      '/v1/billing/midtrans/notification',
      signedNotification(
        orderId: orderId,
        status: 'pending',
        amountRupiah: 150000,
        statusCode: '201',
      ),
    );
    expect((await readBody(hook))['activated'], isFalse);
    final Map<String, Object?> sub = await readBody(
      await getJson(runtime.handler, '/v1/billing/subscription', token: token),
    );
    expect(sub['plan_code'], 'FREE');
  });

  test('tanda tangan salah ditolak dan paket tetap Free', () async {
    final String orderId = await checkoutOrder();
    final Map<String, Object> payload = signedNotification(
      orderId: orderId,
      status: 'settlement',
      amountRupiah: 150000,
    );
    payload['signature_key'] = '0' * 128;
    final Response hook = await postJson(
      runtime.handler,
      '/v1/billing/midtrans/notification',
      payload,
    );
    expect(hook.statusCode, 403);
    final Map<String, Object?> sub = await readBody(
      await getJson(runtime.handler, '/v1/billing/subscription', token: token),
    );
    expect(sub['plan_code'], 'FREE');
  });

  test('Get Status berbeda dari webhook tidak mengaktifkan', () async {
    final String orderId = await checkoutOrder();
    final Response hook = await postJson(
      runtime.handler,
      '/v1/billing/midtrans/notification',
      signedNotification(
        orderId: orderId,
        status: 'settlement',
        amountRupiah: 150000,
      ),
    );
    expect(hook.statusCode, 400);
    final Map<String, Object?> sub = await readBody(
      await getJson(runtime.handler, '/v1/billing/subscription', token: token),
    );
    expect(sub['plan_code'], 'FREE');
  });

  test('expire tidak mengaktifkan paket', () async {
    final String orderId = await checkoutOrder();
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'expire',
        statusCode: '202',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    final Response hook = await postJson(
      runtime.handler,
      '/v1/billing/midtrans/notification',
      signedNotification(
        orderId: orderId,
        status: 'expire',
        amountRupiah: 150000,
        statusCode: '202',
      ),
    );
    expect((await readBody(hook))['activated'], isFalse);
    final Map<String, Object?> sub = await readBody(
      await getJson(runtime.handler, '/v1/billing/subscription', token: token),
    );
    expect(sub['plan_code'], 'FREE');
  });

  test('health tidak memuat Server Key dan sheets/export butuh auth', () async {
    final Response health = await getJson(runtime.handler, '/health');
    final String text = await health.readAsString();
    expect(text, isNot(contains(testServerKey)));
    expect(text, contains('SANDBOX'));

    // Sheets export kini membutuhkan token
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.businessMonthly,
    );
    final Response sheets = await postJson(
      runtime.handler,
      '/v1/sheets/export',
      <String, Object>{},
      token: token,
    );
    expect(sheets.statusCode, 503);
  });
}
