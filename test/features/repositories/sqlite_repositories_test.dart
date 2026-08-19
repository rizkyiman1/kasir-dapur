import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/features/cash_management/data/cash_repository_impl.dart';
import 'package:kasir_dapur/features/customers/data/customer_repository_impl.dart';
import 'package:kasir_dapur/features/customers/domain/customer.dart';
import 'package:kasir_dapur/features/expenses/data/expense_repository_impl.dart';
import 'package:kasir_dapur/features/expenses/domain/expense.dart';
import 'package:kasir_dapur/features/products/data/product_repository_impl.dart';
import 'package:kasir_dapur/features/products/domain/product.dart';
import 'package:kasir_dapur/features/subscription/data/subscription_repository_impl.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/sync/data/sync_repository_impl.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/pos_fixture.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late String businessId;
  const ClockService clock = ClockService();

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_repo_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(tempDir.path, 'kasir_dapur.db'),
    );
    businessId = await insertBusiness(await database.database, clock: clock);
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('ProductRepository mencari barcode dan soft delete', () async {
    final SqliteProductRepository repo = SqliteProductRepository(
      database: database,
      clock: clock,
    );
    final Product created = await repo.create(
      NewProduct(
        businessId: businessId,
        name: 'Es Teh',
        barcode: '88001',
        sellPrice: 5000,
        costPrice: 2000,
      ),
    );
    expect(created.sellPrice, 5000);
    expect(
      (await repo.findByBarcode(businessId: businessId, barcode: '88001'))?.id,
      created.id,
    );
    await repo.softDelete(created.id);
    expect(await repo.getById(created.id), isNull);
  });

  test(
    'CustomerRepository, ExpenseRepository, CashRepository, Sync, Subscription',
    () async {
      final SqliteCustomerRepository customers = SqliteCustomerRepository(
        database: database,
        clock: clock,
      );
      final SqliteExpenseRepository expenses = SqliteExpenseRepository(
        database: database,
        clock: clock,
      );
      final SqliteCashRepository cash = SqliteCashRepository(
        database: database,
        clock: clock,
      );
      final SqliteSyncRepository sync = SqliteSyncRepository(
        database: database,
        clock: clock,
      );
      final SqliteSubscriptionRepository subscriptions =
          SqliteSubscriptionRepository(database: database, clock: clock);

      final Customer customer = await customers.create(
        NewCustomer(businessId: businessId, name: 'Siti', phone: '0812'),
      );
      expect(
        (await customers.search(
          businessId: businessId,
          query: 'sit',
        )).single.id,
        customer.id,
      );

      await expenses.createCategory(businessId: businessId, name: 'Gas');
      await expenses.create(
        NewExpense(
          businessId: businessId,
          amount: 45000,
          spentAt: clock.nowEpochMs(),
          note: 'Gas 3 kg',
        ),
      );
      expect(
        (await expenses.list(businessId: businessId)).single.amount,
        45000,
      );
      expect(
        () => expenses.create(
          NewExpense(businessId: businessId, amount: 0, spentAt: 1),
        ),
        throwsA(isA<ValidationException>()),
      );

      final session = await cash.openSession(
        businessId: businessId,
        openingAmount: 100000,
      );
      await cash.addMovement(sessionId: session.id, type: 'out', amount: 10000);
      final closed = await cash.closeSession(
        sessionId: session.id,
        countedAmount: 90000,
      );
      expect(closed.expectedAmount, 90000);
      expect(closed.differenceAmount, 0);

      await sync.enqueue(
        businessId: businessId,
        clientUuid: 'sync-1',
        aggregate: 'customer',
        operation: 'upsert',
        payload: '{"id":"${customer.id}"}',
      );
      final List<SyncJob> pending = await sync.pending(businessId: businessId);
      expect(
        pending.where((SyncJob job) => job.clientUuid == 'sync-1'),
        hasLength(1),
      );
      expect(
        pending.where((SyncJob job) => job.aggregate == 'customer').length,
        greaterThanOrEqualTo(1),
      );

      await subscriptions.upsertPlan(
        businessId: businessId,
        plan: Plan.free,
        source: 'manual',
        startsAt: clock.nowEpochMs(),
      );
      expect(
        (await subscriptions.find(
          businessId: businessId,
          key: FeatureKey.cloudBackup,
        ))?.isEnabled,
        isFalse,
      );
      await subscriptions.upsertPlan(
        businessId: businessId,
        plan: Plan.pro,
        source: 'play_billing',
        startsAt: clock.nowEpochMs(),
      );
      expect(
        (await subscriptions.find(
          businessId: businessId,
          key: FeatureKey.cloudBackup,
        ))?.isEnabled,
        isTrue,
      );
    },
  );
}
