import 'dart:io';

import 'package:kasir_dapur_backend/data/app_store.dart';
import 'package:kasir_dapur_backend/domain/billing_plan.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  Future<Response> backupCall(String token, dynamic runtime) {
    return postJson(runtime.handler, '/v1/backup', <String, Object>{
      'client_uuid': 'tier-check',
      'snapshot': <String, Object>{'business_id': 'biz-A'},
    }, token: token);
  }

  Future<Response> businessCall(String token, dynamic runtime) {
    return postJson(runtime.handler, '/v1/sheets/export', <String, Object>{
      'force': true,
    }, token: token);
  }

  test('FREE mencoba feature PRO ditolak 403', () async {
    final runtime = testRuntime();
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final response = await backupCall(token, runtime);
    expect(response.statusCode, 403);
    final body = await readBody(response);
    expect(body['error'], 'FEATURE_NOT_AVAILABLE');
    expect(body['feature'], 'cloud_backup');
  });

  test('FREE mencoba feature BUSINESS ditolak 403', () async {
    final config = testConfig().copyWith(
      googleSheetsClientId: 'x',
      googleSheetsClientSecret: 'y',
    );
    final runtime = testRuntime(config: config);
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final response = await businessCall(token, runtime);
    expect(response.statusCode, 403);
    final body = await readBody(response);
    expect(body['error'], 'FEATURE_NOT_AVAILABLE');
    expect(body['feature'], 'cloud_sync');
  });

  test('PRO mencoba feature PRO sukses', () async {
    final runtime = testRuntime();
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.proMonthly,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final response = await backupCall(token, runtime);
    expect(response.statusCode, 200);
  });

  test('PRO mencoba feature BUSINESS ditolak 403', () async {
    final config = testConfig().copyWith(
      googleSheetsClientId: 'x',
      googleSheetsClientSecret: 'y',
    );
    final runtime = testRuntime(config: config);
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.proMonthly,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final response = await businessCall(token, runtime);
    expect(response.statusCode, 403);
    final body = await readBody(response);
    expect(body['feature'], 'cloud_sync');
  });

  test('BUSINESS mencoba feature BUSINESS sukses', () async {
    final config = testConfig().copyWith(
      googleSheetsClientId: 'x',
      googleSheetsClientSecret: 'y',
    );
    final runtime = testRuntime(config: config);
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.businessMonthly,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final response = await businessCall(token, runtime);
    expect(response.statusCode, 200);
  });

  test('BUSINESS mencoba feature PRO sukses', () async {
    final runtime = testRuntime();
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.businessMonthly,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final response = await backupCall(token, runtime);
    expect(response.statusCode, 200);
  });

  test(
    'client tidak dapat menentukan entitlement/subscription status',
    () async {
      final runtime = testRuntime();
      final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
      final response = await postJson(
        runtime.handler,
        '/v1/billing/checkout',
        <String, Object>{
          'plan_code': 'PRO_MONTHLY',
          'client_uuid': 'tamper-1',
          'amount': 1,
          'business_id': 'biz-B',
          'state': 'verified',
        },
        token: token,
      );
      expect(response.statusCode, 200);
      final body = await readBody(response);
      expect(body['amount'], 150000);
    },
  );

  test('cross-business entitlement access ditolak', () async {
    final runtime = testRuntime();
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-B',
      plan: BillingPlan.businessMonthly,
    );
    final tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final response = await postJson(
      runtime.handler,
      '/v1/backup',
      <String, Object>{
        'client_uuid': 'cross-biz',
        'snapshot': <String, Object>{'business_id': 'biz-B'},
      },
      token: tokenA,
    );
    expect(response.statusCode, 403);
  });

  test('expired subscription tidak dapat akses premium', () async {
    final runtime = testRuntime();
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.proMonthly,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    runtime.billing.db.raw.execute(
      '''
      UPDATE subscriptions
      SET ends_at = ?, grace_ends_at = ?, updated_at = ?
      WHERE business_id = ?;
      ''',
      <Object?>[now - 2000, now - 1000, now, 'biz-A'],
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    await getJson(runtime.handler, '/v1/billing/subscription', token: token);
    final response = await backupCall(token, runtime);
    expect(response.statusCode, 403);
  });

  test('grace period masih memberi akses premium sesuai policy', () async {
    final clock = AdjustableClock(10_000_000);
    final store = AppStore(clock: clock);
    final config = testConfig();
    final runtime = testRuntime(config: config, store: store);
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.proMonthly,
    );
    runtime.billing.db.raw.execute(
      '''
      UPDATE subscriptions
      SET ends_at = ?, grace_ends_at = ?, updated_at = ?
      WHERE business_id = ?;
      ''',
      <Object?>[clock.now - 1000, clock.now + 1000, clock.now, 'biz-A'],
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final response = await backupCall(token, runtime);
    expect(response.statusCode, 200);
  });

  test('restart mempertahankan entitlement plan dari SQLite', () async {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-tier-restart-${DateTime.now().microsecondsSinceEpoch}.db';
    final config = testConfig().copyWith(
      billingSqlitePath: path,
      googleSheetsClientId: 'x',
      googleSheetsClientSecret: 'y',
    );
    final runtimeA = testRuntime(config: config);
    seedActivePlan(
      runtime: runtimeA,
      businessId: 'biz-A',
      plan: BillingPlan.businessMonthly,
    );
    runtimeA.close();

    final runtimeB = testRuntime(config: config);
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final businessOk = await businessCall(token, runtimeB);
    final proOk = await backupCall(token, runtimeB);
    expect(businessOk.statusCode, 200);
    expect(proOk.statusCode, 200);
    runtimeB.close();
  });
}
