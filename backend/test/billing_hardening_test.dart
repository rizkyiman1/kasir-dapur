import 'dart:io';
import 'dart:async';

import 'package:kasir_dapur_backend/billing/billing_database.dart';
import 'package:kasir_dapur_backend/billing/billing_repositories.dart';
import 'package:kasir_dapur_backend/billing/billing_state.dart';
import 'package:kasir_dapur_backend/data/app_store.dart';
import 'package:kasir_dapur_backend/midtrans/midtrans_gateway.dart';
import 'package:kasir_dapur_backend/midtrans/midtrans_signature.dart';
import 'package:kasir_dapur_backend/runtime.dart';
import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  Future<Response> postWebhookWithStatus({
    required BackendRuntime runtime,
    required String orderId,
    required String status,
    required int amountRupiah,
    String statusCode = '200',
    String transactionId = 'trx-1',
  }) {
    return postJson(
      runtime.handler,
      '/v1/billing/midtrans/notification',
      signedNotification(
        orderId: orderId,
        status: status,
        amountRupiah: amountRupiah,
        statusCode: statusCode,
        transactionId: transactionId,
      ),
    );
  }

  Future<String> createPendingCheckout({
    required BackendRuntime runtime,
    required String clientUuid,
    String planCode = 'PRO_MONTHLY',
  }) async {
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final checkout = await postJson(
      runtime.handler,
      '/v1/billing/checkout',
      <String, Object>{'plan_code': planCode, 'client_uuid': clientUuid},
      token: token,
    );
    return (await readBody(checkout))['order_id']! as String;
  }

  Future<void> runRollbackCase({
    required String dbPath,
    required BillingFaultHooks hooks,
  }) async {
    final config = testConfig().copyWith(billingSqlitePath: dbPath);
    final midtrans = FakeMidtransGateway();
    final runtime = testRuntime(
      midtrans: midtrans,
      config: config,
      billingFaultHooks: hooks,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final checkout = await postJson(
      runtime.handler,
      '/v1/billing/checkout',
      <String, Object>{
        'plan_code': 'PRO_MONTHLY',
        'client_uuid': 'rollback-case',
      },
      token: token,
    );
    final orderId = (await readBody(checkout))['order_id']! as String;
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    try {
      final response = await postJson(
        runtime.handler,
        '/v1/billing/midtrans/notification',
        signedNotification(
          orderId: orderId,
          status: 'settlement',
          amountRupiah: 150000,
        ),
      );
      expect(response.statusCode >= 500, isTrue);
    } catch (_) {
      // juga valid jika harness melempar exception server.
    }
    runtime.close();

    final runtimeRetry = testRuntime(midtrans: midtrans, config: config);
    final hook = await postJson(
      runtimeRetry.handler,
      '/v1/billing/midtrans/notification',
      signedNotification(
        orderId: orderId,
        status: 'settlement',
        amountRupiah: 150000,
      ),
    );
    final hookBody = await readBody(hook);
    expect(hookBody['activated'], isTrue);
    final sub = await readBody(
      await getJson(
        runtimeRetry.handler,
        '/v1/billing/subscription',
        token: token,
      ),
    );
    expect(sub['plan_code'], 'PRO_MONTHLY');
    runtimeRetry.close();
  }

  test('fault injection rollback setelah payment mutation', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-fi-pay-${DateTime.now().microsecondsSinceEpoch}.db';
    await runRollbackCase(
      dbPath: path,
      hooks: BillingFaultHooks(
        afterPaymentUpdate: () => throw StateError('fail-after-payment'),
      ),
    );
  });

  test('fault injection rollback setelah subscription mutation', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-fi-sub-${DateTime.now().microsecondsSinceEpoch}.db';
    await runRollbackCase(
      dbPath: path,
      hooks: BillingFaultHooks(
        afterSubscriptionUpsert: () => throw StateError('fail-after-sub'),
      ),
    );
  });

  test('fault injection rollback setelah entitlement mutation', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-fi-ent-${DateTime.now().microsecondsSinceEpoch}.db';
    await runRollbackCase(
      dbPath: path,
      hooks: BillingFaultHooks(
        afterEntitlementReplace: () => throw StateError('fail-after-ent'),
      ),
    );
  });

  test('fault injection rollback setelah audit mutation', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-fi-audit-${DateTime.now().microsecondsSinceEpoch}.db';
    await runRollbackCase(
      dbPath: path,
      hooks: BillingFaultHooks(
        afterAuditAppend: () => throw StateError('fail-after-audit'),
      ),
    );
  });

  test('fault injection rollback sebelum commit', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-fi-commit-${DateTime.now().microsecondsSinceEpoch}.db';
    await runRollbackCase(
      dbPath: path,
      hooks: BillingFaultHooks(
        beforeCommit: () => throw StateError('fail-before-commit'),
      ),
    );
  });

  test('multi-connection sqlite claim fingerprint hanya satu pemenang', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-multi-claim-${DateTime.now().microsecondsSinceEpoch}.db';
    final dbA = BillingDatabase.open(path);
    final dbB = BillingDatabase.open(path);
    final repoA = WebhookRepository(dbA.raw);
    final repoB = WebhookRepository(dbB.raw);
    final now = DateTime.now().millisecondsSinceEpoch;
    final results = await Future.wait([
      Future<bool>(() {
        return dbA.transaction<bool>(
          (_) => repoA.tryClaimFingerprint(
            id: 'a',
            fingerprint: 'fp-1',
            orderId: 'ord-1',
            processedAt: now,
            providerStatus: 'settlement',
          ),
        );
      }),
      Future<bool>(() {
        return dbB.transaction<bool>(
          (_) => repoB.tryClaimFingerprint(
            id: 'b',
            fingerprint: 'fp-1',
            orderId: 'ord-1',
            processedAt: now,
            providerStatus: 'settlement',
          ),
        );
      }),
    ]);
    expect(results.where((v) => v).length, 1);
    dbA.close();
    dbB.close();
  });

  test('reconcile concurrent aman (single activation)', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-recon-race-${DateTime.now().microsecondsSinceEpoch}.db';
    final config = testConfig().copyWith(billingSqlitePath: path);
    final midtrans = FakeMidtransGateway();
    final runtime = testRuntime(midtrans: midtrans, config: config);
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final checkout = await postJson(
      runtime.handler,
      '/v1/billing/checkout',
      <String, Object>{'plan_code': 'PRO_MONTHLY', 'client_uuid': 'recon-race'},
      token: token,
    );
    final orderId = (await readBody(checkout))['order_id']! as String;
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    await Future.wait([runtime.startupReconcile(), runtime.startupReconcile()]);
    final db = runtime.billing.db.raw;
    final acts = db.select(
      "SELECT COUNT(*) AS c FROM billing_audit_events WHERE event_type = 'subscription.activated' AND order_id = ?;",
      <Object?>[orderId],
    );
    expect(acts.first['c'], 1);
    runtime.close();
  });

  test('reconcile dan webhook settlement race tetap single activation', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-recon-webhook-race-${DateTime.now().microsecondsSinceEpoch}.db';
    final config = testConfig().copyWith(billingSqlitePath: path);
    final midtrans = FakeMidtransGateway();
    final runtime = testRuntime(midtrans: midtrans, config: config);
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final checkout = await postJson(
      runtime.handler,
      '/v1/billing/checkout',
      <String, Object>{
        'plan_code': 'PRO_MONTHLY',
        'client_uuid': 'recon-webhook-race',
      },
      token: token,
    );
    final orderId = (await readBody(checkout))['order_id']! as String;
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    await Future.wait([
      runtime.startupReconcile(),
      postJson(
        runtime.handler,
        '/v1/billing/midtrans/notification',
        signedNotification(
          orderId: orderId,
          status: 'settlement',
          amountRupiah: 150000,
        ),
      ),
    ]);
    final db = runtime.billing.db.raw;
    final acts = db.select(
      "SELECT COUNT(*) AS c FROM billing_audit_events WHERE event_type = 'subscription.activated' AND order_id = ?;",
      <Object?>[orderId],
    );
    expect(acts.first['c'], 1);
    runtime.close();
  });

  test('subscription expired fallback ke free dan entitlement ikut free', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-expire-${DateTime.now().microsecondsSinceEpoch}.db';
    final config = testConfig().copyWith(billingSqlitePath: path);
    final midtrans = FakeMidtransGateway();
    final runtime = testRuntime(midtrans: midtrans, config: config);
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final checkout = await postJson(
      runtime.handler,
      '/v1/billing/checkout',
      <String, Object>{
        'plan_code': 'PRO_MONTHLY',
        'client_uuid': 'expire-case',
      },
      token: token,
    );
    final orderId = (await readBody(checkout))['order_id']! as String;
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    await postJson(
      runtime.handler,
      '/v1/billing/midtrans/notification',
      signedNotification(
        orderId: orderId,
        status: 'settlement',
        amountRupiah: 150000,
      ),
    );
    final int past = DateTime.now().millisecondsSinceEpoch - 1000;
    runtime.billing.db.raw.execute(
      '''
      UPDATE subscriptions
      SET ends_at = ?, grace_ends_at = ?, updated_at = ?
      WHERE business_id = ?;
      ''',
      <Object?>[past, past, past, 'biz-A'],
    );
    final body = await readBody(
      await getJson(runtime.handler, '/v1/billing/subscription', token: token),
    );
    expect(body['plan_code'], 'FREE');
    final ents = body['entitlements'] as List<dynamic>;
    final businessFeature = ents.firstWhere(
      (e) => (e as Map<dynamic, dynamic>)['feature_key'] == 'business_features',
    ) as Map<dynamic, dynamic>;
    expect(businessFeature['is_enabled'], isFalse);
    runtime.close();
  });

  test('db path nested directory otomatis dibuat dan data survive reopen', () async {
    final baseDir = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-dbpath-${DateTime.now().microsecondsSinceEpoch}',
    );
    final dbPath =
        '${baseDir.path}${Platform.pathSeparator}nested${Platform.pathSeparator}billing.db';
    final config = testConfig().copyWith(billingSqlitePath: dbPath);
    final runtimeA = testRuntime(
      midtrans: FakeMidtransGateway(),
      config: config,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    await postJson(runtimeA.handler, '/v1/billing/checkout', <String, Object>{
      'plan_code': 'PRO_MONTHLY',
      'client_uuid': 'path-init',
    }, token: token);
    runtimeA.close();
    expect(File(dbPath).existsSync(), isTrue);

    final runtimeB = testRuntime(
      midtrans: FakeMidtransGateway(),
      config: config,
    );
    final payments = await readBody(
      await getJson(runtimeB.handler, '/v1/billing/payments', token: token),
    );
    final rows = payments['payments'] as List<dynamic>;
    expect(rows, hasLength(1));
    runtimeB.close();
  });

  test('pending + settlement concurrent berakhir verified/active', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-status-race-ps-${DateTime.now().microsecondsSinceEpoch}.db';
    final config = testConfig().copyWith(billingSqlitePath: path);
    final midtrans = FakeMidtransGateway();
    final runtime = testRuntime(midtrans: midtrans, config: config);
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final checkout = await postJson(
      runtime.handler,
      '/v1/billing/checkout',
      <String, Object>{
        'plan_code': 'PRO_MONTHLY',
        'client_uuid': 'status-race-ps',
      },
      token: token,
    );
    final orderId = (await readBody(checkout))['order_id']! as String;
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    await Future.wait([
      postJson(
        runtime.handler,
        '/v1/billing/midtrans/notification',
        signedNotification(
          orderId: orderId,
          status: 'pending',
          amountRupiah: 150000,
          statusCode: '201',
        ),
      ),
      postJson(
        runtime.handler,
        '/v1/billing/midtrans/notification',
        signedNotification(
          orderId: orderId,
          status: 'settlement',
          amountRupiah: 150000,
        ),
      ),
    ]);
    final sub = await readBody(
      await getJson(runtime.handler, '/v1/billing/subscription', token: token),
    );
    expect(sub['plan_code'], 'PRO_MONTHLY');
    runtime.close();
  });

  test('sqlite lock memicu busy error, rollback aman, lalu retry sukses', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-busy-${DateTime.now().microsecondsSinceEpoch}.db';
    final config = testConfig().copyWith(billingSqlitePath: path);
    final midtrans = FakeMidtransGateway();
    final runtime = testRuntime(midtrans: midtrans, config: config);
    final orderId = await createPendingCheckout(
      runtime: runtime,
      clientUuid: 'busy-lock-case',
    );
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );

    final lockDb = BillingDatabase.open(path);
    lockDb.raw.execute('BEGIN IMMEDIATE TRANSACTION;');
    lockDb.raw.execute(
      'UPDATE payments SET updated_at = updated_at WHERE order_id = ?;',
      <Object?>[orderId],
    );

    final sw = Stopwatch()..start();
    bool busyRejected = false;
    try {
      final blocked = await postWebhookWithStatus(
        runtime: runtime,
        orderId: orderId,
        status: 'settlement',
        amountRupiah: 150000,
        transactionId: 'busy-1',
      );
      busyRejected = blocked.statusCode >= 500;
    } catch (_) {
      busyRejected = true;
    }
    sw.stop();

    expect(busyRejected, isTrue);
    expect(sw.elapsedMilliseconds >= 4500, isTrue);

    final paymentBefore = runtime.billing.payments.findByOrderId(orderId)!;
    expect(paymentBefore.state.name, 'pending');
    expect(paymentBefore.midtransStatus.storageValue, 'pending');
    final subBefore = runtime.billing.subscriptions.findCurrentByBusiness(
      'biz-A',
    )!;
    expect(subBefore.planCode.storageValue, 'FREE');
    final activatedBefore = runtime.billing.db.raw.select(
      "SELECT COUNT(*) AS c FROM billing_audit_events WHERE event_type = 'subscription.activated' AND order_id = ?;",
      <Object?>[orderId],
    );
    expect(activatedBefore.first['c'], 0);

    lockDb.raw.execute('ROLLBACK;');
    lockDb.close();

    final ok = await postWebhookWithStatus(
      runtime: runtime,
      orderId: orderId,
      status: 'settlement',
      amountRupiah: 150000,
      transactionId: 'busy-2',
    );
    expect(ok.statusCode, 200);
    final body = await readBody(ok);
    expect(body['activated'], isTrue);
    expect(body['duplicate'], isFalse);
    runtime.close();
  });

  test('sqlite busy/locked melempar error dan state tetap utuh', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-busy-fail-${DateTime.now().microsecondsSinceEpoch}.db';
    final config = testConfig().copyWith(billingSqlitePath: path);
    final runtime = testRuntime(
      midtrans: FakeMidtransGateway(),
      config: config,
    );
    final orderId = await createPendingCheckout(
      runtime: runtime,
      clientUuid: 'busy-lock-fail-case',
    );

    final dbA = BillingDatabase.open(path);
    final dbB = BillingDatabase.open(path);
    dbA.raw.execute('BEGIN IMMEDIATE TRANSACTION;');
    dbA.raw.execute(
      'UPDATE payments SET updated_at = updated_at WHERE order_id = ?;',
      <Object?>[orderId],
    );
    dbB.raw.execute('PRAGMA busy_timeout = 1;');
    expect(
      () => dbB.transaction<void>((_) {
        dbB.raw.execute(
          "UPDATE payments SET state = 'verified' WHERE order_id = ?;",
          <Object?>[orderId],
        );
      }),
      throwsA(isA<SqliteException>()),
    );
    final payment = runtime.billing.payments.findByOrderId(orderId)!;
    expect(payment.state.name, 'pending');
    dbA.raw.execute('ROLLBACK;');
    dbA.close();
    dbB.close();
    runtime.close();
  });

  test('settlement lalu expire tidak mengubah activation yang sudah verified', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-settle-expire-${DateTime.now().microsecondsSinceEpoch}.db';
    final config = testConfig().copyWith(billingSqlitePath: path);
    final midtrans = FakeMidtransGateway();
    final runtime = testRuntime(midtrans: midtrans, config: config);
    final orderId = await createPendingCheckout(
      runtime: runtime,
      clientUuid: 'settle-then-expire',
    );
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    final s1 = await postWebhookWithStatus(
      runtime: runtime,
      orderId: orderId,
      status: 'settlement',
      amountRupiah: 150000,
      transactionId: 's1',
    );
    expect(s1.statusCode, 200);
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'expire',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    final s2 = await postWebhookWithStatus(
      runtime: runtime,
      orderId: orderId,
      status: 'expire',
      amountRupiah: 150000,
      transactionId: 's2',
    );
    expect(s2.statusCode, 200);

    final p = runtime.billing.payments.findByOrderId(orderId)!;
    expect(p.state.name, 'verified');
    expect(p.businessId, 'biz-A');
    expect(p.orderId, orderId);
    final sub = runtime.billing.subscriptions.findCurrentByBusiness('biz-A')!;
    expect(sub.status.storageValue, 'active');
    expect(sub.orderId, orderId);
    expect(sub.businessId, 'biz-A');
    expect(sub.startsAt <= sub.endsAt!, isTrue);
    final activated = runtime.billing.db.raw.select(
      "SELECT COUNT(*) AS c FROM billing_audit_events WHERE event_type = 'subscription.activated' AND order_id = ?;",
      <Object?>[orderId],
    );
    expect(activated.first['c'], 1);
    runtime.close();
  });

  test('expire lalu settlement mengaktifkan tepat satu kali', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-expire-settle-${DateTime.now().microsecondsSinceEpoch}.db';
    final config = testConfig().copyWith(billingSqlitePath: path);
    final midtrans = FakeMidtransGateway();
    final runtime = testRuntime(midtrans: midtrans, config: config);
    final orderId = await createPendingCheckout(
      runtime: runtime,
      clientUuid: 'expire-then-settle',
    );
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'expire',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    final e = await postWebhookWithStatus(
      runtime: runtime,
      orderId: orderId,
      status: 'expire',
      amountRupiah: 150000,
      transactionId: 'e1',
    );
    expect(e.statusCode, 200);
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    final s = await postWebhookWithStatus(
      runtime: runtime,
      orderId: orderId,
      status: 'settlement',
      amountRupiah: 150000,
      transactionId: 's1',
    );
    expect(s.statusCode, 200);
    final activated = runtime.billing.db.raw.select(
      "SELECT COUNT(*) AS c FROM billing_audit_events WHERE event_type = 'subscription.activated' AND order_id = ?;",
      <Object?>[orderId],
    );
    expect(activated.first['c'], 1);
    runtime.close();
  });

  test('cancel lalu settlement mengaktifkan tepat satu kali', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-cancel-settle-${DateTime.now().microsecondsSinceEpoch}.db';
    final config = testConfig().copyWith(billingSqlitePath: path);
    final midtrans = FakeMidtransGateway();
    final runtime = testRuntime(midtrans: midtrans, config: config);
    final orderId = await createPendingCheckout(
      runtime: runtime,
      clientUuid: 'cancel-then-settle',
    );
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'cancel',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    final c = await postWebhookWithStatus(
      runtime: runtime,
      orderId: orderId,
      status: 'cancel',
      amountRupiah: 150000,
      transactionId: 'c1',
    );
    expect(c.statusCode, 200);
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    final s = await postWebhookWithStatus(
      runtime: runtime,
      orderId: orderId,
      status: 'settlement',
      amountRupiah: 150000,
      transactionId: 's1',
    );
    expect(s.statusCode, 200);
    final activated = runtime.billing.db.raw.select(
      "SELECT COUNT(*) AS c FROM billing_audit_events WHERE event_type = 'subscription.activated' AND order_id = ?;",
      <Object?>[orderId],
    );
    expect(activated.first['c'], 1);
    runtime.close();
  });

  test('settlement lalu cancel tidak menurunkan verified state', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-settle-cancel-${DateTime.now().microsecondsSinceEpoch}.db';
    final config = testConfig().copyWith(billingSqlitePath: path);
    final midtrans = FakeMidtransGateway();
    final runtime = testRuntime(midtrans: midtrans, config: config);
    final orderId = await createPendingCheckout(
      runtime: runtime,
      clientUuid: 'settle-then-cancel',
    );
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'settlement',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    await postWebhookWithStatus(
      runtime: runtime,
      orderId: orderId,
      status: 'settlement',
      amountRupiah: 150000,
      transactionId: 's1',
    );
    midtrans.seedStatus(
      MidtransStatusSnapshot(
        orderId: orderId,
        transactionStatus: 'cancel',
        statusCode: '200',
        grossAmount: MidtransSignature.grossAmountOf(150000),
      ),
    );
    final cancel = await postWebhookWithStatus(
      runtime: runtime,
      orderId: orderId,
      status: 'cancel',
      amountRupiah: 150000,
      transactionId: 'c1',
    );
    expect(cancel.statusCode, 200);
    final p = runtime.billing.payments.findByOrderId(orderId)!;
    expect(p.state.name, 'verified');
    final activated = runtime.billing.db.raw.select(
      "SELECT COUNT(*) AS c FROM billing_audit_events WHERE event_type = 'subscription.activated' AND order_id = ?;",
      <Object?>[orderId],
    );
    expect(activated.first['c'], 1);
    runtime.close();
  });

  test('settlement + expire concurrent aman (policy existing)', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-conc-settle-expire-${DateTime.now().microsecondsSinceEpoch}.db';
    final config = testConfig().copyWith(billingSqlitePath: path);
    final midtrans = ZoneMidtransGateway();
    final runtime = testRuntime(midtrans: midtrans, config: config);
    final orderId = await createPendingCheckout(
      runtime: runtime,
      clientUuid: 'conc-settle-expire',
    );
    final List<Response> results = await Future.wait<Response>([
      runZoned(
        () => postWebhookWithStatus(
          runtime: runtime,
          orderId: orderId,
          status: 'settlement',
          amountRupiah: 150000,
          transactionId: 'z1',
        ),
        zoneValues: <Object?, Object?>{
          #midtrans_status: 'settlement',
          #midtrans_status_code: '200',
          #midtrans_gross: MidtransSignature.grossAmountOf(150000),
        },
      ),
      runZoned(
        () => postWebhookWithStatus(
          runtime: runtime,
          orderId: orderId,
          status: 'expire',
          amountRupiah: 150000,
          transactionId: 'z2',
        ),
        zoneValues: <Object?, Object?>{
          #midtrans_status: 'expire',
          #midtrans_status_code: '200',
          #midtrans_gross: MidtransSignature.grossAmountOf(150000),
        },
      ),
    ]);
    expect(results.every((r) => r.statusCode == 200), isTrue);
    final activated = runtime.billing.db.raw.select(
      "SELECT COUNT(*) AS c FROM billing_audit_events WHERE event_type = 'subscription.activated' AND order_id = ?;",
      <Object?>[orderId],
    );
    expect(activated.first['c'], 1);
    runtime.close();
  });

  test('cancel + settlement concurrent aman (policy existing)', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-conc-cancel-settle-${DateTime.now().microsecondsSinceEpoch}.db';
    final config = testConfig().copyWith(billingSqlitePath: path);
    final midtrans = ZoneMidtransGateway();
    final runtime = testRuntime(midtrans: midtrans, config: config);
    final orderId = await createPendingCheckout(
      runtime: runtime,
      clientUuid: 'conc-cancel-settle',
    );
    final List<Response> results = await Future.wait<Response>([
      runZoned(
        () => postWebhookWithStatus(
          runtime: runtime,
          orderId: orderId,
          status: 'cancel',
          amountRupiah: 150000,
          transactionId: 'z1',
        ),
        zoneValues: <Object?, Object?>{
          #midtrans_status: 'cancel',
          #midtrans_status_code: '200',
          #midtrans_gross: MidtransSignature.grossAmountOf(150000),
        },
      ),
      runZoned(
        () => postWebhookWithStatus(
          runtime: runtime,
          orderId: orderId,
          status: 'settlement',
          amountRupiah: 150000,
          transactionId: 'z2',
        ),
        zoneValues: <Object?, Object?>{
          #midtrans_status: 'settlement',
          #midtrans_status_code: '200',
          #midtrans_gross: MidtransSignature.grossAmountOf(150000),
        },
      ),
    ]);
    expect(results.every((r) => r.statusCode == 200), isTrue);
    final activated = runtime.billing.db.raw.select(
      "SELECT COUNT(*) AS c FROM billing_audit_events WHERE event_type = 'subscription.activated' AND order_id = ?;",
      <Object?>[orderId],
    );
    expect(activated.first['c'], 1);
    runtime.close();
  });

  test('ends_at boundary before/equal/after mengikuti policy existing', () async {
    final clock = AdjustableClock(2_000_000);
    final store = AppStore(clock: clock);
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-ends-boundary-${DateTime.now().microsecondsSinceEpoch}.db';
    final config = testConfig().copyWith(billingSqlitePath: path);
    final runtime = testRuntime(
      midtrans: FakeMidtransGateway(),
      config: config,
      store: store,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    runtime.billing.ensureFree(businessId: 'biz-A');
    runtime.billing.db.raw.execute(
      '''
      UPDATE subscriptions
      SET plan_code = 'PRO_MONTHLY', status = 'active',
          starts_at = ?, ends_at = ?, grace_ends_at = NULL, order_id = 'ord-boundary'
      WHERE business_id = 'biz-A';
      ''',
      <Object?>[1_999_000, 2_000_100],
    );
    runtime.billing.db.raw.execute(
      '''
      UPDATE entitlements
      SET plan_code = 'PRO_MONTHLY', is_enabled = 1, effective_until = ?
      WHERE business_id = 'biz-A';
      ''',
      <Object?>[2_000_100],
    );

    clock.now = 2_000_099;
    final before = await readBody(
      await getJson(runtime.handler, '/v1/billing/subscription', token: token),
    );
    expect(before['plan_code'], 'PRO_MONTHLY');

    clock.now = 2_000_100;
    final atBoundary = await readBody(
      await getJson(runtime.handler, '/v1/billing/subscription', token: token),
    );
    expect(atBoundary['plan_code'], 'PRO_MONTHLY');

    clock.now = 2_000_101;
    final after = await readBody(
      await getJson(runtime.handler, '/v1/billing/subscription', token: token),
    );
    expect(after['plan_code'], 'FREE');
    final count = runtime.billing.db.raw.select(
      'SELECT COUNT(*) AS c FROM subscriptions WHERE business_id = ?;',
      <Object?>['biz-A'],
    );
    expect(count.first['c'], 1);
    runtime.close();
  });

  test('grace_ends_at boundary before/equal/after mengikuti policy existing', () async {
    final clock = AdjustableClock(3_000_000);
    final store = AppStore(clock: clock);
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-grace-boundary-${DateTime.now().microsecondsSinceEpoch}.db';
    final config = testConfig().copyWith(billingSqlitePath: path);
    final runtime = testRuntime(
      midtrans: FakeMidtransGateway(),
      config: config,
      store: store,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    runtime.billing.ensureFree(businessId: 'biz-A');
    runtime.billing.db.raw.execute(
      '''
      UPDATE subscriptions
      SET plan_code = 'BUSINESS_MONTHLY', status = 'active',
          starts_at = ?, ends_at = ?, grace_ends_at = ?, order_id = 'ord-grace'
      WHERE business_id = 'biz-A';
      ''',
      <Object?>[2_900_000, 2_950_000, 3_000_100],
    );
    runtime.billing.db.raw.execute(
      '''
      UPDATE entitlements
      SET plan_code = 'BUSINESS_MONTHLY', is_enabled = 1, effective_until = ?
      WHERE business_id = 'biz-A';
      ''',
      <Object?>[3_000_100],
    );

    clock.now = 3_000_099;
    final before = await readBody(
      await getJson(runtime.handler, '/v1/billing/subscription', token: token),
    );
    expect(before['plan_code'], 'BUSINESS_MONTHLY');

    clock.now = 3_000_100;
    final atBoundary = await readBody(
      await getJson(runtime.handler, '/v1/billing/subscription', token: token),
    );
    expect(atBoundary['plan_code'], 'BUSINESS_MONTHLY');

    clock.now = 3_000_101;
    final after = await readBody(
      await getJson(runtime.handler, '/v1/billing/subscription', token: token),
    );
    expect(after['plan_code'], 'FREE');
    runtime.close();
  });
}

final class ZoneMidtransGateway implements MidtransGateway {
  ZoneMidtransGateway();

  @override
  Future<SnapTransaction> createSnap({
    required String orderId,
    required int amountRupiah,
    required String planCode,
    required String businessId,
  }) async {
    return SnapTransaction(
      token: 'snap-token-$orderId',
      redirectUrl: 'https://app.sandbox.midtrans.com/snap/v2/vtweb/$orderId',
    );
  }

  @override
  Future<MidtransStatusSnapshot> fetchStatus(String orderId) async {
    final String status =
        (Zone.current[#midtrans_status] as String?) ?? 'pending';
    final String code =
        (Zone.current[#midtrans_status_code] as String?) ?? '201';
    final String gross =
        (Zone.current[#midtrans_gross] as String?) ??
        MidtransSignature.grossAmountOf(0);
    return MidtransStatusSnapshot(
      orderId: orderId,
      transactionStatus: status,
      statusCode: code,
      grossAmount: gross,
    );
  }
}
