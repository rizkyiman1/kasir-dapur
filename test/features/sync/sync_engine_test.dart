import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/features/products/data/product_repository_impl.dart';
import 'package:kasir_dapur/features/products/domain/product.dart';
import 'package:kasir_dapur/features/subscription/data/memory_billing_gateway.dart';
import 'package:kasir_dapur/features/subscription/data/subscription_repository_impl.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_config.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_service.dart';
import 'package:kasir_dapur/features/sync/data/cloud_sync_gateway.dart';
import 'package:kasir_dapur/features/sync/data/sync_repository_impl.dart';
import 'package:kasir_dapur/features/sync/data/sync_snapshot_loader.dart';
import 'package:kasir_dapur/features/sync/domain/sync_engine.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:kasir_dapur/features/transactions/data/transaction_repository_impl.dart';
import 'package:kasir_dapur/features/transactions/domain/sale.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:kasir_dapur/services/settings_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/pos_fixture.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late AdjustableClock clock;
  late SqliteSyncRepository store;
  late SqliteSubscriptionRepository subscriptions;
  late SqliteProductRepository products;
  late SqliteTransactionRepository transactions;
  late SqliteSettingsRepository settings;
  late MemoryCloudSyncGateway gateway;
  late MemoryConnectivityPort connectivity;
  late SyncEngine engine;
  late String businessId;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_sync_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(tempDir.path, 'kasir_dapur.db'),
    );
    clock = AdjustableClock(DateTime(2026, 8, 18, 15));
    store = SqliteSyncRepository(database: database, clock: clock);
    subscriptions = SqliteSubscriptionRepository(
      database: database,
      clock: clock,
    );
    products = SqliteProductRepository(database: database, clock: clock);
    transactions = SqliteTransactionRepository(
      database: database,
      clock: clock,
    );
    settings = SqliteSettingsRepository(database: database, clock: clock);
    gateway = MemoryCloudSyncGateway();
    connectivity = MemoryConnectivityPort();
    businessId = await insertBusiness(await database.database, clock: clock);
    await subscriptions.upsertPlan(
      businessId: businessId,
      plan: Plan.pro,
      source: 'test',
      startsAt: clock.nowEpochMs(),
    );
    engine = SyncEngine(
      store: store,
      gateway: gateway,
      connectivity: connectivity,
      loader: SyncSnapshotLoader(database),
      subscriptions: SubscriptionService(
        store: subscriptions,
        entitlements: subscriptions,
        payments: subscriptions,
        billing: MemoryBillingGateway(),
        config: SubscriptionConfig.standard,
        clock: clock,
        guard: PermissionGuard(),
        access: () => const StaticAccessContext(),
      ),
      settings: settings,
      clock: clock,
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Sale> sellOnce({String clientUuid = 'sale-client-1'}) async {
    final Product product = await products.create(
      NewProduct(
        businessId: businessId,
        name: 'Nasi Goreng',
        costPrice: 8000,
        sellPrice: 12500,
        initialStock: 10,
      ),
    );
    return transactions.createCompletedSale(
      NewSale(
        businessId: businessId,
        clientUuid: clientUuid,
        items: <SaleItemDraft>[SaleItemDraft(productId: product.id, qty: 1)],
        payments: const <SalePaymentDraft>[
          SalePaymentDraft(method: 'cash', amount: 12500),
        ],
      ),
    );
  }

  test('offline: transaksi tersimpan, antrian pending', () async {
    connectivity.online = false;
    final Sale sale = await sellOnce();
    expect(sale.totalAmount, 12500);
    expect(await transactions.getById(sale.id), isNotNull);

    final List<SyncJob> pending = await store.pending(businessId: businessId);
    expect(
      pending.any((SyncJob job) => job.clientUuid == 'sale-client-1'),
      isTrue,
    );
    expect(
      pending.every((SyncJob job) => job.status == SyncJobStatus.pending),
      isTrue,
    );

    final SyncRunResult result = await engine.run(businessId: businessId);
    expect(result.status, SyncRunStatus.offline);
    expect(
      (await store.pending(businessId: businessId))
          .any((SyncJob job) => job.clientUuid == 'sale-client-1'),
      isTrue,
    );
    expect(await transactions.getById(sale.id), isNotNull);
  });

  test('online: antrian terkirim dan ditandai done', () async {
    await sellOnce();
    final SyncRunResult result = await engine.run(businessId: businessId);
    expect(result.status, SyncRunStatus.success);
    expect(await store.pending(businessId: businessId), isEmpty);
    expect(
      await store.countByStatus(
        businessId: businessId,
        status: SyncJobStatus.done,
      ),
      greaterThan(0),
    );
    expect(
      gateway.pushed.any(
        (CloudSyncJob job) => job.clientUuid == 'sale-client-1',
      ),
      isTrue,
    );
  });

  test('client_uuid duplikat tidak menambah baris antrian', () async {
    await store.enqueue(
      businessId: businessId,
      clientUuid: 'same-uuid',
      aggregate: 'customer',
      operation: 'upsert',
      payload: '{"id":"c1"}',
    );
    await store.enqueue(
      businessId: businessId,
      clientUuid: 'same-uuid',
      aggregate: 'customer',
      operation: 'upsert',
      payload: '{"id":"c1"}',
    );
    expect(
      (await store.pending(businessId: businessId))
          .where((SyncJob job) => job.clientUuid == 'same-uuid'),
      hasLength(1),
    );
  });

  test('retry antrian gagal', () async {
    await store.enqueue(
      businessId: businessId,
      clientUuid: 'retry-me',
      aggregate: 'customer',
      operation: 'upsert',
      payload: '{"id":"c-retry"}',
    );
    gateway.fail = true;
    final SyncRunResult failed = await engine.run(businessId: businessId);
    expect(failed.status, SyncRunStatus.failed);
    expect(
      (await store.failed(businessId: businessId))
          .any((SyncJob job) => job.clientUuid == 'retry-me'),
      isTrue,
    );

    gateway.fail = false;
    final SyncRunResult retried = await engine.run(
      businessId: businessId,
      retryFailed: true,
    );
    expect(retried.status, SyncRunStatus.success);
    expect(
      (await store.failed(businessId: businessId))
          .any((SyncJob job) => job.clientUuid == 'retry-me'),
      isFalse,
    );
  });

  test('partial sync: job gagal tidak membatalkan job lain', () async {
    await store.enqueue(
      businessId: businessId,
      clientUuid: 'ok-1',
      aggregate: 'customer',
      operation: 'upsert',
      payload: '{"id":"c-ok"}',
    );
    await store.enqueue(
      businessId: businessId,
      clientUuid: 'bad-1',
      aggregate: 'customer',
      operation: 'upsert',
      payload: '{"id":"c-bad"}',
    );
    gateway.rejectClientUuids.add('bad-1');
    final SyncRunResult result = await engine.run(businessId: businessId);
    expect(result.status, SyncRunStatus.failed);
    expect(result.failed, 1);
    expect(
      gateway.pushed.any((CloudSyncJob row) => row.clientUuid == 'ok-1'),
      isTrue,
    );
    expect(
      (await store.failed(businessId: businessId))
          .any((SyncJob row) => row.clientUuid == 'bad-1'),
      isTrue,
    );
  });

  test('exponential backoff: failed job tidak langsung dipromosikan', () async {
    await store.enqueue(
      businessId: businessId,
      clientUuid: 'backoff-1',
      aggregate: 'customer',
      operation: 'upsert',
      payload: '{"id":"c-backoff"}',
    );
    gateway.fail = true;
    await engine.run(businessId: businessId);
    gateway.fail = false;

    await engine.run(businessId: businessId);
    expect(
      gateway.pushed.any((CloudSyncJob row) => row.clientUuid == 'backoff-1'),
      isFalse,
    );

    clock.advance(const Duration(seconds: 3));
    final SyncRunResult retried = await engine.run(businessId: businessId);
    expect(retried.status, SyncRunStatus.success);
    expect(
      gateway.pushed.any((CloudSyncJob row) => row.clientUuid == 'backoff-1'),
      isTrue,
    );
  });

  test('DailyReports diantrikan dan berisi integer', () async {
    await sellOnce();
    await engine.run(businessId: businessId);
    final CloudSyncJob report = gateway.pushed.firstWhere(
      (CloudSyncJob job) =>
          job.aggregate == SyncAggregate.dailyReport.storageValue,
    );
    expect(report.payload['date'], '2026-08-18');
    expect(report.payload['omzet'], isA<int>());
    expect(report.payload['omzet'], 12500);
    expect(report.payload['transaction_count'], 1);
  });

  test('gateway mengabaikan push client_uuid yang sama', () async {
    final CloudSyncJob job = CloudSyncJob(
      clientUuid: 'dup-1',
      aggregate: 'customer',
      operation: 'upsert',
      payload: const <String, Object?>{'id': 'c1'},
    );
    final CloudSyncBatchResult first = await gateway.push(
      businessId: businessId,
      jobs: <CloudSyncJob>[job],
    );
    final CloudSyncBatchResult second = await gateway.push(
      businessId: businessId,
      jobs: <CloudSyncJob>[job],
    );
    expect(first.accepted, 1);
    expect(second.duplicates, 1);
    expect(gateway.pushed, hasLength(1));
  });
}
