import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/backup/data/backup_gateway.dart';
import 'package:kasir_dapur/features/backup/data/backup_log_repository.dart';
import 'package:kasir_dapur/features/backup/data/backup_restorer.dart';
import 'package:kasir_dapur/features/backup/data/backup_snapshot_builder.dart';
import 'package:kasir_dapur/features/backup/domain/backup_gateway.dart';
import 'package:kasir_dapur/features/backup/domain/backup_models.dart';
import 'package:kasir_dapur/features/backup/domain/backup_service.dart';
import 'package:kasir_dapur/features/products/data/product_repository_impl.dart';
import 'package:kasir_dapur/features/products/domain/product.dart';
import 'package:kasir_dapur/features/subscription/data/memory_billing_gateway.dart';
import 'package:kasir_dapur/features/subscription/data/subscription_repository_impl.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_config.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_service.dart';
import 'package:kasir_dapur/features/sync/data/cloud_sync_gateway.dart';
import 'package:kasir_dapur/features/transactions/data/transaction_repository_impl.dart';
import 'package:kasir_dapur/features/transactions/domain/sale.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:kasir_dapur/services/settings_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/pos_fixture.dart';

final class FakeRestoreGateway implements BackupGateway {
  FakeRestoreGateway(this.payload, {required this.businessId});

  final BackupSnapshot payload;
  final String businessId;

  @override
  Future<RemoteBackupInfo> getById({
    required String businessId,
    required String backupId,
  }) async {
    return RemoteBackupInfo(
      id: backupId,
      businessId: this.businessId,
      createdAt: payload.createdAt,
      counts: payload.counts,
      snapshot: payload,
    );
  }

  @override
  Future<List<RemoteBackupInfo>> list(String businessId) async {
    return <RemoteBackupInfo>[];
  }

  @override
  Future<RemoteBackupInfo> upload({
    required String businessId,
    required String clientUuid,
    required BackupSnapshot snapshot,
  }) async {
    throw UnimplementedError();
  }
}

BackupService buildBackupService({
  required AppDatabase database,
  required ClockService clock,
  required SqliteSubscriptionRepository subscriptions,
  required MemoryBackupGateway gateway,
  required MemoryConnectivityPort connectivity,
  required AuthUser user,
}) {
  return BackupService(
    builder: BackupSnapshotBuilder(database: database, clock: clock),
    restorer: BackupRestorer(database),
    gateway: gateway,
    logs: SqliteBackupLogRepository(database: database, clock: clock),
    subscriptions: SubscriptionService(
      store: subscriptions,
      entitlements: subscriptions,
      payments: subscriptions,
      billing: MemoryBillingGateway(),
      config: SubscriptionConfig.standard,
      clock: clock,
      guard: PermissionGuard(),
      access: () => StaticAccessContext(currentUser: user),
    ),
    connectivity: connectivity,
    settings: SqliteSettingsRepository(database: database, clock: clock),
    guard: PermissionGuard(),
    access: () => StaticAccessContext(currentUser: user),
  );
}

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late AdjustableClock clock;
  late SqliteProductRepository products;
  late SqliteTransactionRepository transactions;
  late SqliteSubscriptionRepository subscriptions;
  late MemoryBackupGateway gateway;
  late MemoryConnectivityPort connectivity;
  late BackupService service;
  late String businessId;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_bak_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(tempDir.path, 'kasir_dapur.db'),
    );
    clock = AdjustableClock(DateTime(2026, 8, 18, 15));
    products = SqliteProductRepository(database: database, clock: clock);
    transactions = SqliteTransactionRepository(
      database: database,
      clock: clock,
    );
    subscriptions = SqliteSubscriptionRepository(
      database: database,
      clock: clock,
    );
    gateway = MemoryBackupGateway();
    connectivity = MemoryConnectivityPort();
    businessId = await insertBusiness(await database.database, clock: clock);
    await subscriptions.upsertPlan(
      businessId: businessId,
      plan: Plan.pro,
      source: 'test',
      startsAt: clock.nowEpochMs(),
    );
    service = buildBackupService(
      database: database,
      clock: clock,
      subscriptions: subscriptions,
      gateway: gateway,
      connectivity: connectivity,
      user: const AuthUser(id: 'o1', displayName: 'Budi', role: UserRole.owner),
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Product> addProduct({String name = 'Nasi Goreng'}) {
    return products.create(
      NewProduct(
        businessId: businessId,
        name: name,
        costPrice: 8000,
        sellPrice: 12500,
        initialStock: 10,
      ),
    );
  }

  Future<Sale> sell(Product product, {required String clientUuid}) {
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

  test('Backup Now menyalin tabel wajib', () async {
    final Product product = await addProduct();
    await sell(product, clientUuid: 'sale-1');
    final BackupRunResult result = await service.backupNow(businessId);
    expect(result.status, BackupStatus.success);
    expect(result.backupId, isNotEmpty);
    expect(result.counts[BackupTables.products], greaterThan(0));
    expect(result.counts[BackupTables.transactions], 1);
    expect(result.counts[BackupTables.transactionItems], 1);
    expect(result.counts[BackupTables.stock], greaterThan(0));
    expect(result.counts[BackupTables.stockMovements], greaterThan(0));
    expect(result.counts.keys, containsAll(BackupTables.all));
    final BackupUiSnapshot ui = await service.snapshot(businessId);
    expect(ui.lastBackupId, result.backupId);
    expect(ui.status, BackupStatus.success);
  });

  test('cadangan gagal tidak menghapus transaksi lokal', () async {
    final Product product = await addProduct();
    final Sale sale = await sell(product, clientUuid: 'sale-keep');
    gateway.fail = true;
    final BackupRunResult result = await service.backupNow(businessId);
    expect(result.status, BackupStatus.failed);
    expect(await transactions.getById(sale.id), isNotNull);
    expect(sale.totalAmount, 12500);
  });

  test('offline: backup gagal, kasir tetap punya data', () async {
    final Product product = await addProduct();
    final Sale sale = await sell(product, clientUuid: 'sale-off');
    connectivity.online = false;
    final BackupRunResult result = await service.backupNow(businessId);
    expect(result.status, BackupStatus.failed);
    expect(result.message, contains('Kasir tetap dapat digunakan'));
    expect(await transactions.getById(sale.id), isNotNull);
  });

  test('restore membutuhkan konfirmasi', () async {
    final Product product = await addProduct();
    await sell(product, clientUuid: 'sale-1');
    final BackupRunResult backup = await service.backupNow(businessId);
    expect(
      () => service.restore(
        businessId: businessId,
        backupId: backup.backupId!,
        confirmed: false,
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test(
    'restore menimpa id yang sama dan menyimpan transaksi lokal baru',
    () async {
      final Product product = await addProduct(name: 'Nasi Goreng');
      final Sale first = await sell(product, clientUuid: 'sale-old');
      final BackupRunResult backup = await service.backupNow(businessId);

      await products.update(product.copyWith(name: 'Nasi Goreng Spesial'));
      final Sale newer = await sell(product, clientUuid: 'sale-new');

      final BackupRunResult restored = await service.restore(
        businessId: businessId,
        backupId: backup.backupId!,
        confirmed: true,
      );
      expect(restored.status, BackupStatus.success);
      expect((await products.getById(product.id))?.name, 'Nasi Goreng');
      expect(await transactions.getById(first.id), isNotNull);
      expect(await transactions.getById(newer.id), isNotNull);
    },
  );

  test('duplicate restore aman dan tidak menduplikasi transaksi', () async {
    final Product product = await addProduct(name: 'Mie Goreng');
    final Sale original = await sell(product, clientUuid: 'sale-restore-dupe');
    final BackupRunResult backup = await service.backupNow(businessId);

    final BackupRunResult first = await service.restore(
      businessId: businessId,
      backupId: backup.backupId!,
      confirmed: true,
    );
    final BackupRunResult second = await service.restore(
      businessId: businessId,
      backupId: backup.backupId!,
      confirmed: true,
    );

    expect(first.status, BackupStatus.success);
    expect(second.status, BackupStatus.success);
    expect(
      await transactions.findByClientUuid(
        businessId: businessId,
        clientUuid: 'sale-restore-dupe',
      ),
      isNotNull,
    );
    expect(await transactions.getById(original.id), isNotNull);
  });

  test(
    'restore rollback total jika payload korup (duplicate client_uuid)',
    () async {
      final Product product = await addProduct(name: 'Ayam Geprek');
      final Sale existing = await sell(product, clientUuid: 'sale-safe-before');
      final BackupSnapshot corrupted = BackupSnapshot(
        businessId: businessId,
        createdAt: clock.nowEpochMs(),
        schemaVersion: 13,
        checksum: 'invalid',
        tables: <String, List<Map<String, Object?>>>{
          for (final String key in BackupTables.all)
            key: <Map<String, Object?>>[],
        },
      );
      final BackupService failing = BackupService(
        builder: BackupSnapshotBuilder(database: database, clock: clock),
        restorer: BackupRestorer(database),
        gateway: FakeRestoreGateway(corrupted, businessId: businessId),
        logs: SqliteBackupLogRepository(database: database, clock: clock),
        subscriptions: SubscriptionService(
          store: subscriptions,
          entitlements: subscriptions,
          payments: subscriptions,
          billing: MemoryBillingGateway(),
          config: SubscriptionConfig.standard,
          clock: clock,
          guard: PermissionGuard(),
          access: () => const StaticAccessContext(
            currentUser: AuthUser(
              id: 'o1',
              displayName: 'Budi',
              role: UserRole.owner,
            ),
          ),
        ),
        connectivity: connectivity,
        settings: SqliteSettingsRepository(database: database, clock: clock),
        guard: PermissionGuard(),
        access: () => const StaticAccessContext(
          currentUser: AuthUser(
            id: 'o1',
            displayName: 'Budi',
            role: UserRole.owner,
          ),
        ),
      );
      final BackupRunResult res = await failing.restore(
        businessId: businessId,
        backupId: 'bad-1',
        confirmed: true,
      );
      expect(res.status, BackupStatus.failed);
      expect(await transactions.getById(existing.id), isNotNull);
    },
  );

  test('restore menolak business berbeda', () async {
    final BackupSnapshot seed = await BackupSnapshotBuilder(
      database: database,
      clock: clock,
    ).build(businessId);
    final BackupSnapshot snapshot = BackupSnapshot(
      businessId: 'biz-OTHER',
      createdAt: seed.createdAt,
      schemaVersion: seed.schemaVersion,
      checksum: seed.checksum,
      tables: seed.tables,
    );
    final BackupService failing = BackupService(
      builder: BackupSnapshotBuilder(database: database, clock: clock),
      restorer: BackupRestorer(database),
      gateway: FakeRestoreGateway(snapshot, businessId: 'biz-OTHER'),
      logs: SqliteBackupLogRepository(database: database, clock: clock),
      subscriptions: SubscriptionService(
        store: subscriptions,
        entitlements: subscriptions,
        payments: subscriptions,
        billing: MemoryBillingGateway(),
        config: SubscriptionConfig.standard,
        clock: clock,
        guard: PermissionGuard(),
        access: () => const StaticAccessContext(
          currentUser: AuthUser(
            id: 'o1',
            displayName: 'Budi',
            role: UserRole.owner,
          ),
        ),
      ),
      connectivity: connectivity,
      settings: SqliteSettingsRepository(database: database, clock: clock),
      guard: PermissionGuard(),
      access: () => const StaticAccessContext(
        currentUser: AuthUser(
          id: 'o1',
          displayName: 'Budi',
          role: UserRole.owner,
        ),
      ),
    );
    final BackupRunResult res = await failing.restore(
      businessId: businessId,
      backupId: 'cross-1',
      confirmed: true,
    );
    expect(res.status, BackupStatus.failed);
  });

  test('kasir tidak boleh mencadangkan', () async {
    final BackupService cashier = buildBackupService(
      database: database,
      clock: clock,
      subscriptions: subscriptions,
      gateway: gateway,
      connectivity: connectivity,
      user: const AuthUser(
        id: 'c1',
        displayName: 'Cici',
        role: UserRole.cashier,
      ),
    );
    expect(
      () => cashier.backupNow(businessId),
      throwsA(isA<ForbiddenException>()),
    );
  });
}
