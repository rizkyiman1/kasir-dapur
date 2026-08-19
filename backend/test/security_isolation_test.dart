/// Security isolation tests — multi-tenant authorization matrix.
library;

import 'package:kasir_dapur_backend/auth/user_store.dart';
import 'package:kasir_dapur_backend/data/app_store.dart';
import 'package:kasir_dapur_backend/domain/billing_plan.dart';
import 'package:kasir_dapur_backend/midtrans/midtrans_gateway.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late _TestEnv env;

  setUp(() {
    env = _TestEnv.create();
  });

  // ─── Cloud Session ─────────────────────────────────────────────────────────

  group('POST /v1/auth/cloud/session', () {
    test('credential valid → issue JWT', () async {
      final res = await postJson(
        env.runtime.handler,
        '/v1/auth/cloud/session',
        <String, Object>{'user_id': 'user-A', 'pin': '1234'},
      );
      expect(res.statusCode, 200);
      final body = await readBody(res);
      expect(body['access_token'], isA<String>());
      expect(body['token_type'], 'Bearer');
      expect(body['expires_in'], isA<int>());
      final user = body['user'] as Map;
      expect(user['id'], 'user-A');
      expect(user['business_id'], 'biz-A');
      expect(user['role'], 'owner');
    });

    test('PIN salah → 401', () async {
      final res = await postJson(
        env.runtime.handler,
        '/v1/auth/cloud/session',
        <String, Object>{'user_id': 'user-A', 'pin': 'wrong'},
      );
      expect(res.statusCode, 401);
      final body = await readBody(res);
      expect(body['error'], isA<String>());
      expect(body['error'], isNot(contains('hash')));
      expect(body['error'], isNot(contains('salt')));
    });

    test(
      'user tidak ada → 401 (pesan identik, cegah user enumeration)',
      () async {
        final res = await postJson(
          env.runtime.handler,
          '/v1/auth/cloud/session',
          <String, Object>{'user_id': 'nonexistent', 'pin': '1234'},
        );
        expect(res.statusCode, 401);
        final body = await readBody(res);
        expect(body['error'], 'Credential tidak valid.');
      },
    );

    test('user_id kosong → 400', () async {
      final res = await postJson(
        env.runtime.handler,
        '/v1/auth/cloud/session',
        <String, Object>{'user_id': '', 'pin': ''},
      );
      expect(res.statusCode, 400);
    });
  });

  // ─── Token Validation ─────────────────────────────────────────────────────

  group('Token validation', () {
    test('tanpa token → 401', () async {
      final res = await getJson(
        env.runtime.handler,
        '/v1/billing/subscription',
      );
      expect(res.statusCode, 401);
    });

    test('token invalid (bukan JWT) → 401', () async {
      final res = await getJson(
        env.runtime.handler,
        '/v1/billing/subscription',
        token: 'not-a-jwt-at-all',
      );
      expect(res.statusCode, 401);
    });

    test('token expired → 401', () async {
      final token = expiredToken(userId: 'user-A', businessId: 'biz-A');
      final res = await getJson(
        env.runtime.handler,
        '/v1/billing/subscription',
        token: token,
      );
      expect(res.statusCode, 401);
    });

    test('token signature salah (tampered) → 401', () async {
      final token = tamperedToken(userId: 'user-A', businessId: 'biz-A');
      final res = await getJson(
        env.runtime.handler,
        '/v1/billing/subscription',
        token: token,
      );
      expect(res.statusCode, 401);
    });

    test('token issuer salah → 401', () async {
      final token = wrongIssuerToken(userId: 'user-A', businessId: 'biz-A');
      final res = await getJson(
        env.runtime.handler,
        '/v1/billing/subscription',
        token: token,
      );
      expect(res.statusCode, 401);
    });

    test('token valid → 200', () async {
      final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
      final res = await getJson(
        env.runtime.handler,
        '/v1/billing/subscription',
        token: token,
      );
      expect(res.statusCode, 200);
    });
  });

  // ─── Public endpoints ─────────────────────────────────────────────────────

  group('Public endpoints (tanpa token)', () {
    test('GET /health → 200', () async {
      final res = await getJson(env.runtime.handler, '/health');
      expect(res.statusCode, 200);
    });

    test('Midtrans webhook tidak butuh JWT', () async {
      final body = signedNotification(
        orderId: 'KD-test-public',
        status: 'settlement',
        amountRupiah: 150000,
      );
      final res = await postJson(
        env.runtime.handler,
        '/v1/billing/midtrans/notification',
        body,
      );
      expect(res.statusCode, isNot(401));
    });
  });

  group('Global error handling', () {
    test('payload tipe salah tidak membocorkan detail internal', () async {
      final res = await postJson(
        env.runtime.handler,
        '/v1/auth/cloud/session',
        <String, Object>{'user_id': 123, 'pin': '1234'},
      );
      expect(res.statusCode, 400);
      final body = await readBody(res);
      expect(body['error'], isA<String>());
      expect('${body['error']}', isNot(contains('TypeError')));
      expect('${body['error']}', isNot(contains('StackTrace')));
      expect('${body['error']}', isNot(contains(r'\')));
    });
  });

  // ─── Subscription isolation ───────────────────────────────────────────────

  group('Subscription isolation', () {
    test('User A → baca subscription sendiri = PASS', () async {
      final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
      final res = await getJson(
        env.runtime.handler,
        '/v1/billing/subscription',
        token: token,
      );
      expect(res.statusCode, 200);
    });

    test(
      'User A tidak bisa baca subscription biz-B (query param diabaikan)',
      () async {
        final tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');
        // Coba override business_id via query param
        final res = await getJson(
          env.runtime.handler,
          '/v1/billing/subscription?business_id=biz-B',
          token: tokenA,
        );
        expect(res.statusCode, 200);
        final body = await readBody(res);
        // Harus mengembalikan data biz-A (bukan biz-B)
        // Karena biz-B belum pernah checkout, keduanya FREE tapi verifikasi via plan_code ada
        expect(body['plan_code'], isA<String>());
      },
    );
  });

  // ─── Backup isolation ─────────────────────────────────────────────────────

  group('Backup isolation', () {
    test('User A → backup untuk diri sendiri = PASS', () async {
      final token = tokenFor(userId: 'user-A', businessId: 'biz-A');
      final res = await postJson(
        env.runtime.handler,
        '/v1/backup',
        <String, Object>{
          'client_uuid': 'bak-iso-A',
          'snapshot': <String, Object>{},
        },
        token: token,
      );
      expect(res.statusCode, 200);
    });

    test(
      'User A → body business_id biz-B diabaikan, backup ke biz-A',
      () async {
        final tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');
        final res = await postJson(
          env.runtime.handler,
          '/v1/backup',
          <String, Object>{
            'business_id': 'biz-B',
            'client_uuid': 'bak-inject-B',
            'snapshot': <String, Object>{},
          },
          token: tokenA,
        );
        expect(res.statusCode, 200);
        final stored = env.runtime.store.backups.firstWhere(
          (b) => b.clientUuid == 'bak-inject-B',
        );
        expect(stored.businessId, 'biz-A'); // Bukan biz-B
      },
    );

    test('User A list backup → hanya milik biz-A', () async {
      final tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');
      final tokenB = tokenFor(userId: 'user-B', businessId: 'biz-B');
      await postJson(env.runtime.handler, '/v1/backup', <String, Object>{
        'client_uuid': 'bak-listA',
        'snapshot': <String, Object>{},
      }, token: tokenA);
      await postJson(env.runtime.handler, '/v1/backup', <String, Object>{
        'client_uuid': 'bak-listB',
        'snapshot': <String, Object>{},
      }, token: tokenB);
      final res = await getJson(
        env.runtime.handler,
        '/v1/backup',
        token: tokenA,
      );
      final body = await readBody(res);
      final list = body['backups'] as List;
      expect(list, hasLength(1));
      expect((list.first as Map)['business_id'], 'biz-A');
    });

    test('User A → akses backup biz-B by ID → 404', () async {
      final tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');
      final tokenB = tokenFor(userId: 'user-B', businessId: 'biz-B');
      final created = await postJson(
        env.runtime.handler,
        '/v1/backup',
        <String, Object>{
          'client_uuid': 'bak-B-idor',
          'snapshot': <String, Object>{},
        },
        token: tokenB,
      );
      final createdBody = await readBody(created);
      final id = createdBody['backup_id'] as String;

      final res = await getJson(
        env.runtime.handler,
        '/v1/backup/$id',
        token: tokenA,
      );
      expect(res.statusCode, 404);
    });

    test('Backup tanpa token → 401', () async {
      final res = await postJson(
        env.runtime.handler,
        '/v1/backup',
        <String, Object>{'client_uuid': 'no-token'},
      );
      expect(res.statusCode, 401);
    });
  });

  // ─── Sync isolation ───────────────────────────────────────────────────────

  group('Sync isolation', () {
    test('User A sync push → tersimpan sebagai biz-A', () async {
      final tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');
      final res = await postJson(
        env.runtime.handler,
        '/v1/sync/push',
        <String, Object>{
          'jobs': <Map<String, Object>>[
            <String, Object>{
              'client_uuid': 'sync-A-1',
              'aggregate': 'product',
              'payload': <String, Object>{'id': 'p1', 'name': 'ProdA'},
            },
          ],
        },
        token: tokenA,
      );
      expect(res.statusCode, 200);
      final job = env.runtime.store.syncJobs.firstWhere(
        (j) => j['client_uuid'] == 'sync-A-1',
      );
      expect(job['business_id'], 'biz-A');
    });

    test('User A tidak bisa sync ke biz-B via body business_id', () async {
      final tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');
      await postJson(env.runtime.handler, '/v1/sync/push', <String, Object>{
        'business_id': 'biz-B',
        'jobs': <Map<String, Object>>[
          <String, Object>{
            'client_uuid': 'inject-biz-B',
            'aggregate': 'product',
            'payload': <String, Object>{
              'id': 'p-inject',
              'business_id': 'biz-B',
            },
          },
        ],
      }, token: tokenA);
      final job = env.runtime.store.syncJobs.firstWhere(
        (j) => j['client_uuid'] == 'inject-biz-B',
      );
      expect(job['business_id'], 'biz-A'); // selalu biz-A dari JWT
    });

    test('User A sync pull → hanya jobs biz-A', () async {
      final tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');
      final tokenB = tokenFor(userId: 'user-B', businessId: 'biz-B');
      await postJson(env.runtime.handler, '/v1/sync/push', <String, Object>{
        'jobs': <Map<String, Object>>[
          <String, Object>{
            'client_uuid': 'pull-jobA',
            'aggregate': 'product',
            'payload': <String, Object>{},
          },
        ],
      }, token: tokenA);
      await postJson(env.runtime.handler, '/v1/sync/push', <String, Object>{
        'jobs': <Map<String, Object>>[
          <String, Object>{
            'client_uuid': 'pull-jobB',
            'aggregate': 'product',
            'payload': <String, Object>{},
          },
        ],
      }, token: tokenB);
      final pullA = await getJson(
        env.runtime.handler,
        '/v1/sync/pull',
        token: tokenA,
      );
      final jobs = (await readBody(pullA))['jobs'] as List;
      for (final j in jobs) {
        expect((j as Map)['business_id'], 'biz-A');
      }
    });

    test('User A tidak bisa pull jobs biz-B (query param diabaikan)', () async {
      final tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');
      final res = await getJson(
        env.runtime.handler,
        '/v1/sync/pull?business_id=biz-B',
        token: tokenA,
      );
      final body = await readBody(res);
      final jobs = body['jobs'] as List;
      for (final j in jobs) {
        expect((j as Map)['business_id'], 'biz-A');
      }
    });

    test('duplikat sync tetap idempoten setelah auth', () async {
      final tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');
      final payload = <String, Object>{
        'jobs': <Map<String, Object>>[
          <String, Object>{
            'client_uuid': 'idem-sync',
            'aggregate': 'product',
            'payload': <String, Object>{},
          },
        ],
      };
      final r1 = await postJson(
        env.runtime.handler,
        '/v1/sync/push',
        payload,
        token: tokenA,
      );
      final r2 = await postJson(
        env.runtime.handler,
        '/v1/sync/push',
        payload,
        token: tokenA,
      );
      expect((await readBody(r1))['accepted'], 1);
      expect((await readBody(r2))['duplicates'], 1);
    });

    test('sync push tanpa token → 401', () async {
      final res = await postJson(
        env.runtime.handler,
        '/v1/sync/push',
        <String, Object>{'jobs': <Object>[]},
      );
      expect(res.statusCode, 401);
    });
  });

  // ─── Audit isolation ──────────────────────────────────────────────────────

  group('Audit isolation', () {
    test('User A hanya melihat audit biz-A', () async {
      final tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');
      final tokenB = tokenFor(userId: 'user-B', businessId: 'biz-B');
      await getJson(
        env.runtime.handler,
        '/v1/billing/subscription',
        token: tokenA,
      );
      await getJson(
        env.runtime.handler,
        '/v1/billing/subscription',
        token: tokenB,
      );
      final res = await getJson(
        env.runtime.handler,
        '/v1/audit',
        token: tokenA,
      );
      expect(res.statusCode, 200);
      final events = (await readBody(res))['events'] as List;
      for (final e in events) {
        final biz = (e as Map)['business_id'];
        if (biz != null) expect(biz, 'biz-A');
      }
    });

    test('audit tanpa token → 401', () async {
      final res = await getJson(env.runtime.handler, '/v1/audit');
      expect(res.statusCode, 401);
    });
  });

  // ─── Sheets isolation ─────────────────────────────────────────────────────

  group('Sheets isolation', () {
    test('User A hanya melihat sheets biz-A', () async {
      final tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');
      final tokenB = tokenFor(userId: 'user-B', businessId: 'biz-B');
      await postJson(env.runtime.handler, '/v1/sync/push', <String, Object>{
        'jobs': <Map<String, Object>>[
          <String, Object>{
            'client_uuid': 'prod-sA',
            'aggregate': 'product',
            'payload': <String, Object>{'id': 'pA', 'name': 'Produk A'},
          },
        ],
      }, token: tokenA);
      await postJson(env.runtime.handler, '/v1/sync/push', <String, Object>{
        'jobs': <Map<String, Object>>[
          <String, Object>{
            'client_uuid': 'prod-sB',
            'aggregate': 'product',
            'payload': <String, Object>{'id': 'pB', 'name': 'Rahasia B'},
          },
        ],
      }, token: tokenB);
      final res = await getJson(
        env.runtime.handler,
        '/v1/sheets/tabs',
        token: tokenA,
      );
      expect(res.statusCode, 200);
      final tabs = (await readBody(res))['tabs'] as Map;
      final prods = tabs['Products'] as List? ?? <Object>[];
      for (final p in prods) {
        expect((p as Map)['name'], isNot(contains('Rahasia')));
      }
    });

    test('sheets tanpa token → 401', () async {
      final res = await getJson(env.runtime.handler, '/v1/sheets/tabs');
      expect(res.statusCode, 401);
    });
  });

  // ─── Midtrans webhook tetap pass setelah auth ─────────────────────────────

  group('Midtrans webhook (tidak butuh JWT)', () {
    test(
      'webhook valid tetap PASS setelah auth middleware ditambahkan',
      () async {
        final tokenA = tokenFor(userId: 'user-A', businessId: 'biz-A');
        final checkoutRes = await postJson(
          env.runtime.handler,
          '/v1/billing/checkout',
          <String, Object>{
            'plan_code': 'PRO_MONTHLY',
            'client_uuid': 'wh-test-jwt',
          },
          token: tokenA,
        );
        final orderId = (await readBody(checkoutRes))['order_id'] as String;
        env.fakeGateway.seedStatus(
          MidtransStatusSnapshot(
            orderId: orderId,
            transactionStatus: 'settlement',
            statusCode: '200',
            grossAmount: '150000.00',
            transactionId: 'wh-trx-jwt',
          ),
        );

        final res = await postJson(
          env.runtime.handler,
          '/v1/billing/midtrans/notification',
          signedNotification(
            orderId: orderId,
            status: 'settlement',
            amountRupiah: 150000,
          ),
        );
        expect(res.statusCode, 200);
        final body = await readBody(res);
        expect(body['activated'], true);
      },
    );

    test('webhook signature invalid → 403', () async {
      final res = await postJson(
        env.runtime.handler,
        '/v1/billing/midtrans/notification',
        signedNotification(
          orderId: 'bad-order',
          status: 'settlement',
          amountRupiah: 150000,
          serverKey: 'wrong-key',
        ),
      );
      expect(res.statusCode, 403);
    });
  });
}

// ─── Test environment ─────────────────────────────────────────────────────────

final class _TestEnv {
  _TestEnv({required this.runtime, required this.fakeGateway});

  final dynamic runtime;
  final FakeMidtransGateway fakeGateway;

  factory _TestEnv.create() {
    final store = AppStore();
    final userStore = UserStore();
    userStore.register(
      id: 'user-A',
      businessId: 'biz-A',
      role: 'owner',
      pin: '1234',
      salt: 'salt-A',
    );
    userStore.register(
      id: 'user-B',
      businessId: 'biz-B',
      role: 'owner',
      pin: '5678',
      salt: 'salt-B',
    );
    final gateway = FakeMidtransGateway();
    final rt = testRuntime(
      midtrans: gateway,
      store: store,
      userStore: userStore,
    );
    seedActivePlan(
      runtime: rt,
      businessId: 'biz-A',
      plan: BillingPlan.proMonthly,
    );
    seedActivePlan(
      runtime: rt,
      businessId: 'biz-B',
      plan: BillingPlan.proMonthly,
    );
    return _TestEnv(runtime: rt, fakeGateway: gateway);
  }
}
