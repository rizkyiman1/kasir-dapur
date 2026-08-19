import 'package:kasir_dapur_backend/domain/billing_plan.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('POST cadangan idempoten per client_uuid', () async {
    final runtime = testRuntime();
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.proMonthly,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');

    final Map<String, Object> snapshot = <String, Object>{
      'created_at': 1,
      'tables': <String, Object>{
        'products': <Map<String, Object>>[
          <String, Object>{'id': 'p1', 'name': 'Es Teh', 'sell_price': 5000},
        ],
        'transactions': <Map<String, Object>>[
          <String, Object>{'id': 't1', 'total_amount': 5000},
        ],
        'transaction_items': <Map<String, Object>>[
          <String, Object>{'id': 'i1', 'transaction_id': 't1'},
        ],
        'stock': <Map<String, Object>>[
          <String, Object>{'id': 's1', 'qty': 8},
        ],
        'stock_movements': <Map<String, Object>>[],
        'expenses': <Map<String, Object>>[],
        'customers': <Map<String, Object>>[],
        'settings': <Map<String, Object>>[],
      },
    };
    final first = await postJson(
      runtime.handler,
      '/v1/backup',
      <String, Object>{'client_uuid': 'bak-client-1', 'snapshot': snapshot},
      token: token,
    );
    expect(first.statusCode, 200);
    final Map<String, Object?> body = await readBody(first);
    expect(body['status'], 'stored');
    expect(body['duplicate'], false);
    expect(body['backup_id'], isNotEmpty);
    expect((body['counts'] as Map)['products'], 1);
    expect((body['counts'] as Map)['transactions'], 1);

    final second = await postJson(
      runtime.handler,
      '/v1/backup',
      <String, Object>{'client_uuid': 'bak-client-1', 'snapshot': snapshot},
      token: token,
    );
    final Map<String, Object?> dup = await readBody(second);
    expect(dup['duplicate'], true);
    expect(dup['backup_id'], body['backup_id']);
    expect(runtime.store.backups, hasLength(1));

    final listed = await getJson(runtime.handler, '/v1/backup', token: token);
    final Map<String, Object?> listBody = await readBody(listed);
    expect(listBody['note'], contains('SQLite'));
    expect(listBody['backups'], isA<List>());

    final detail = await getJson(
      runtime.handler,
      '/v1/backup/${body['backup_id']}',
      token: token,
    );
    final Map<String, Object?> detailBody = await readBody(detail);
    expect(detailBody['snapshot'], isNotNull);
  });

  test('backup tanpa token ditolak 401', () async {
    final runtime = testRuntime();
    final res = await postJson(runtime.handler, '/v1/backup', <String, Object>{
      'client_uuid': 'no-token',
    });
    expect(res.statusCode, 401);
  });

  test('backup business_id mismatch pada snapshot ditolak 403', () async {
    final runtime = testRuntime();
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.proMonthly,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
    final res = await postJson(runtime.handler, '/v1/backup', <String, Object>{
      'client_uuid': 'bak-bad-biz',
      'snapshot': <String, Object>{
        'business_id': 'biz-B',
        'created_at': 1,
        'tables': <String, Object>{},
      },
    }, token: token);
    expect(res.statusCode, 403);
  });
}
