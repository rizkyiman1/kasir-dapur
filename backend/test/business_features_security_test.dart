import 'package:kasir_dapur_backend/auth/user_store.dart';
import 'package:kasir_dapur_backend/domain/billing_plan.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('cashier ditolak untuk endpoint sensitif', () async {
    final userStore = UserStore()
      ..register(
        id: 'owner-A',
        businessId: 'biz-A',
        role: 'owner',
        pin: '1234',
        salt: 'salt-owner',
      )
      ..register(
        id: 'cashier-A',
        businessId: 'biz-A',
        role: 'cashier',
        pin: '1111',
        salt: 'salt-cashier',
      );
    final runtime = testRuntime(userStore: userStore);
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.businessMonthly,
    );
    final cashierToken = tokenFor(
      userId: 'cashier-A',
      businessId: 'biz-A',
      role: 'cashier',
    );

    final audit = await getJson(
      runtime.handler,
      '/v1/audit',
      token: cashierToken,
    );
    expect(audit.statusCode, 403);
    final backup = await postJson(
      runtime.handler,
      '/v1/backup',
      <String, Object>{
        'client_uuid': 'cashier-block',
        'snapshot': <String, Object>{},
      },
      token: cashierToken,
    );
    expect(backup.statusCode, 403);
  });

  test('business plan bisa kelola device dan branch', () async {
    final runtime = testRuntime();
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.businessMonthly,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');

    final reg = await postJson(
      runtime.handler,
      '/v1/business/devices',
      <String, Object>{'device_name': 'POS-1'},
      token: token,
    );
    expect(reg.statusCode, 200);
    final list = await getJson(
      runtime.handler,
      '/v1/business/devices',
      token: token,
    );
    expect(list.statusCode, 200);
    expect((await readBody(list))['devices'], isA<List>());

    final branch = await postJson(
      runtime.handler,
      '/v1/business/branches',
      <String, Object>{'name': 'Cabang Utama'},
      token: token,
    );
    expect(branch.statusCode, 200);
    final branches = await getJson(
      runtime.handler,
      '/v1/business/branches',
      token: token,
    );
    expect(branches.statusCode, 200);
    expect((await readBody(branches))['branches'], isA<List>());
  });

  test('input validation: device_name dan role invalid ditolak', () async {
    final runtime = testRuntime();
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.businessMonthly,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');

    final longName = await postJson(
      runtime.handler,
      '/v1/business/devices',
      <String, Object>{'device_name': 'X' * 120},
      token: token,
    );
    expect(longName.statusCode, 400);

    final badRole = await postJson(
      runtime.handler,
      '/v1/business/users/user-A/role',
      <String, Object>{'role': 'OWNER<script>'},
      token: token,
    );
    expect(badRole.statusCode, 400);
  });

  test('pro plan ditolak untuk business features', () async {
    final runtime = testRuntime();
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.proMonthly,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');

    final device = await postJson(
      runtime.handler,
      '/v1/business/devices',
      <String, Object>{'device_name': 'POS-PRO'},
      token: token,
    );
    expect(device.statusCode, 403);
    final body = await readBody(device);
    expect(body['error'], 'FEATURE_NOT_AVAILABLE');
    expect(body['feature'], 'multi_device');
  });

  test('business bisa akses central dashboard dan advanced report', () async {
    final runtime = testRuntime();
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.businessMonthly,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');

    final dashboard = await getJson(
      runtime.handler,
      '/v1/business/central-dashboard',
      token: token,
    );
    expect(dashboard.statusCode, 200);
    final report = await getJson(
      runtime.handler,
      '/v1/business/advanced-report',
      token: token,
    );
    expect(report.statusCode, 200);
  });

  test('api access dan priority support coming soon', () async {
    final runtime = testRuntime();
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.businessMonthly,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');

    final api = await postJson(
      runtime.handler,
      '/v1/business/api-keys',
      <String, Object>{},
      token: token,
    );
    expect(api.statusCode, 501);
    final support = await postJson(
      runtime.handler,
      '/v1/business/priority-support',
      <String, Object>{},
      token: token,
    );
    expect(support.statusCode, 501);
  });

  test('business isolation pada resources device/branch', () async {
    final userStore = UserStore()
      ..register(
        id: 'owner-A',
        businessId: 'biz-A',
        role: 'owner',
        pin: '1234',
        salt: 'salt-owner-A',
      )
      ..register(
        id: 'owner-B',
        businessId: 'biz-B',
        role: 'owner',
        pin: '5678',
        salt: 'salt-owner-B',
      );
    final runtime = testRuntime(userStore: userStore);
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.businessMonthly,
    );
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-B',
      plan: BillingPlan.businessMonthly,
    );
    final tokenA = tokenFor(userId: 'owner-A', businessId: 'biz-A');
    final tokenB = tokenFor(userId: 'owner-B', businessId: 'biz-B');

    await postJson(runtime.handler, '/v1/business/devices', <String, Object>{
      'device_name': 'A-Only',
    }, token: tokenA);
    final listB = await getJson(
      runtime.handler,
      '/v1/business/devices',
      token: tokenB,
    );
    final devicesB = (await readBody(listB))['devices'] as List<dynamic>;
    expect(
      devicesB.where((row) => (row as Map)['device_name'] == 'A-Only'),
      isEmpty,
    );
  });
}
