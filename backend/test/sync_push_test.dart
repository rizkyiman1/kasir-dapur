import 'dart:convert';

import 'package:kasir_dapur_backend/domain/billing_plan.dart';
import 'package:kasir_dapur_backend/sync/sheets_mirror.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('push batch menulis tab dan menolak duplikat client_uuid', () async {
    final runtime = testRuntime();
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.proMonthly,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');

    final Map<String, Object> transaction = <String, Object>{
      'id': 'trx-1',
      'status': 'completed',
      'subtotal_amount': 12500,
      'discount_amount': 0,
      'tax_amount': 0,
      'total_amount': 12500,
      'items': <Map<String, Object>>[
        <String, Object>{
          'id': 'item-1',
          'transaction_id': 'trx-1',
          'product_id': 'p1',
          'name_snapshot': 'Nasi Goreng',
          'qty': 1,
          'unit_price': 12500,
          'cost_price': 8000,
          'discount_amount': 0,
          'line_total': 12500,
        },
      ],
    };
    final first = await postJson(
      runtime.handler,
      '/v1/sync/push',
      <String, Object>{
        'jobs': <Map<String, Object>>[
          <String, Object>{
            'client_uuid': 'sale-1',
            'aggregate': 'transaction',
            'operation': 'upsert',
            'payload': transaction,
          },
          <String, Object>{
            'client_uuid': 'prod-1',
            'aggregate': 'product',
            'operation': 'upsert',
            'payload': <String, Object>{
              'id': 'p1',
              'name': 'Nasi Goreng',
              'sell_price': 12500,
              'cost_price': 8000,
            },
          },
          <String, Object>{
            'client_uuid': 'daily_report:biz-A:2026-08-18',
            'aggregate': 'daily_report',
            'operation': 'upsert',
            'payload': <String, Object>{
              'date': '2026-08-18',
              'omzet': 12500,
              'transaction_count': 1,
              'expenses_total': 0,
            },
          },
        ],
      },
      token: token,
    );
    expect(first.statusCode, 200);
    final Map<String, Object?> body = await readBody(first);
    expect(body['accepted'], 3);
    expect(body['duplicates'], 0);

    final Map<String, Map<String, Map<String, Object?>>> tabs = runtime
        .store
        .sheets
        .snapshot(businessId: 'biz-A');
    expect(tabs[SheetTabs.transactions], hasLength(1));
    expect(tabs[SheetTabs.transactionItems], hasLength(1));
    expect(tabs[SheetTabs.products], hasLength(1));
    expect(tabs[SheetTabs.dailyReports], hasLength(1));
    expect(tabs[SheetTabs.transactions]!.values.single['total_amount'], 12500);
    expect(tabs[SheetTabs.dailyReports]!.values.single['omzet'], 12500);

    final second = await postJson(
      runtime.handler,
      '/v1/sync/push',
      <String, Object>{
        'jobs': <Map<String, Object>>[
          <String, Object>{
            'client_uuid': 'sale-1',
            'aggregate': 'transaction',
            'operation': 'upsert',
            'payload': transaction,
          },
        ],
      },
      token: token,
    );
    final Map<String, Object?> dup = await readBody(second);
    expect(dup['accepted'], 0);
    expect(dup['duplicates'], 1);
    expect(runtime.store.sheets.rowCount(SheetTabs.transactions), 1);
    expect(runtime.store.sheets.rowCount(SheetTabs.transactionItems), 1);
  });

  test('tab stok, pengeluaran, dan pelanggan terisi', () async {
    final runtime = testRuntime();
    seedActivePlan(
      runtime: runtime,
      businessId: 'biz-A',
      plan: BillingPlan.proMonthly,
    );
    final token = tokenFor(userId: 'user-A', businessId: 'biz-A');

    final push = await postJson(
      runtime.handler,
      '/v1/sync/push',
      <String, Object>{
        'jobs': <Map<String, Object>>[
          <String, Object>{
            'client_uuid': 'mov-1',
            'aggregate': 'stock_movement',
            'operation': 'upsert',
            'payload': <String, Object>{
              'id': 'm1',
              'qty': 3,
              'qty_before': 10,
              'qty_after': 13,
            },
          },
          <String, Object>{
            'client_uuid': 'exp-1',
            'aggregate': 'expense',
            'operation': 'upsert',
            'payload': <String, Object>{
              'id': 'e1',
              'amount': 45000,
              'note': 'Gas',
            },
          },
          <String, Object>{
            'client_uuid': 'cus-1',
            'aggregate': 'customer',
            'operation': 'upsert',
            'payload': <String, Object>{'id': 'c1', 'name': 'Siti'},
          },
        ],
      },
      token: token,
    );
    expect(push.statusCode, 200);
    expect(runtime.store.sheets.rowCount(SheetTabs.stockMovements), 1);
    expect(runtime.store.sheets.rowCount(SheetTabs.expenses), 1);
    expect(runtime.store.sheets.rowCount(SheetTabs.customers), 1);
    expect(
      runtime.store.sheets
          .snapshot()[SheetTabs.expenses]!
          .values
          .single['amount'],
      45000,
    );

    final preview = await getJson(
      runtime.handler,
      '/v1/sheets/tabs',
      token: token,
    );
    final Map<String, Object?> body = await readBody(preview);
    expect(body['note'], contains('SQLite'));
    final Object? tabs = body['tabs'];
    expect(tabs, isA<Map>());
    expect(jsonEncode(tabs), contains('Customers'));
  });

  test(
    'aggregate business/settings/subscription_meta/user_account tersinkron',
    () async {
      final runtime = testRuntime();
      seedActivePlan(
        runtime: runtime,
        businessId: 'biz-A',
        plan: BillingPlan.proMonthly,
      );
      final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
      final res = await postJson(
        runtime.handler,
        '/v1/sync/push',
        <String, Object>{
          'jobs': <Map<String, Object>>[
            <String, Object>{
              'client_uuid': 'business:biz-A',
              'aggregate': 'business',
              'operation': 'upsert',
              'payload': <String, Object>{'id': 'biz-A', 'name': 'Kasir Dapur'},
            },
            <String, Object>{
              'client_uuid': 'settings:biz-A',
              'aggregate': 'settings',
              'operation': 'upsert',
              'payload': <String, Object>{'business_id': 'biz-A'},
            },
            <String, Object>{
              'client_uuid': 'users:biz-A',
              'aggregate': 'user_account',
              'operation': 'upsert',
              'payload': <String, Object>{
                'rows': <Map<String, Object>>[
                  <String, Object>{
                    'id': 'u1',
                    'display_name': 'Owner',
                    'role': 'owner',
                  },
                ],
              },
            },
            <String, Object>{
              'client_uuid': 'subscription:biz-A',
              'aggregate': 'subscription_meta',
              'operation': 'upsert',
              'payload': <String, Object>{'business_id': 'biz-A'},
            },
          ],
        },
        token: token,
      );
      expect(res.statusCode, 200);
      expect(runtime.store.sheets.rowCount(SheetTabs.businesses), 1);
      expect(runtime.store.sheets.rowCount(SheetTabs.settings), 1);
      expect(runtime.store.sheets.rowCount(SheetTabs.users), 1);
      expect(runtime.store.sheets.rowCount(SheetTabs.subscriptions), 1);
    },
  );

  test('sync push tanpa token ditolak 401', () async {
    final runtime = testRuntime();
    final res = await postJson(
      runtime.handler,
      '/v1/sync/push',
      <String, Object>{'jobs': <Object>[]},
    );
    expect(res.statusCode, 401);
  });
}
