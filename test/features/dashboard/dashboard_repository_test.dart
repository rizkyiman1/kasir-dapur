import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/features/cash_management/data/cash_repository_impl.dart';
import 'package:kasir_dapur/features/dashboard/data/dashboard_repository_impl.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_period.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:kasir_dapur/features/expenses/data/expense_repository_impl.dart';
import 'package:kasir_dapur/features/expenses/domain/expense.dart';
import 'package:kasir_dapur/features/inventory/data/stock_repository_impl.dart';
import 'package:kasir_dapur/features/inventory/domain/stock.dart';
import 'package:kasir_dapur/features/products/data/product_repository_impl.dart';
import 'package:kasir_dapur/features/products/domain/product.dart';
import 'package:kasir_dapur/features/transactions/data/transaction_repository_impl.dart';
import 'package:kasir_dapur/features/transactions/domain/sale.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/pos_fixture.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late AdjustableClock clock;
  late SqliteProductRepository products;
  late SqliteStockRepository stock;
  late SqliteTransactionRepository transactions;
  late SqliteExpenseRepository expenses;
  late SqliteCashRepository cash;
  late SqliteDashboardRepository dashboard;
  late String businessId;

  final DateTime tuesday = DateTime(2026, 8, 18, 15, 0);
  final DateTime monday = DateTime(2026, 8, 17, 11, 0);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_dash_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(tempDir.path, 'kasir_dapur.db'),
    );
    clock = AdjustableClock(tuesday);
    products = SqliteProductRepository(database: database, clock: clock);
    stock = SqliteStockRepository(database: database, clock: clock);
    transactions = SqliteTransactionRepository(
      database: database,
      clock: clock,
    );
    expenses = SqliteExpenseRepository(database: database, clock: clock);
    cash = SqliteCashRepository(database: database, clock: clock);
    dashboard = SqliteDashboardRepository(database: database);
    businessId = await insertBusiness(await database.database, clock: clock);
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Product> addProduct({
    required String name,
    int minStock = 0,
    int qty = 10,
  }) async {
    final Product product = await products.create(
      NewProduct(
        businessId: businessId,
        name: name,
        costPrice: 8000,
        sellPrice: 12500,
        minStock: minStock,
      ),
    );
    if (qty > 0) {
      await stock.applyMovement(
        businessId: businessId,
        productId: product.id,
        type: StockMovementType.stockIn,
        qtyDelta: qty,
      );
    }
    return product;
  }

  Future<void> sell(Product product, {required int qty, String? sessionId}) {
    return transactions.createCompletedSale(
      NewSale(
        businessId: businessId,
        clientUuid: const Uuid().v4(),
        cashSessionId: sessionId,
        items: <SaleItemDraft>[SaleItemDraft(productId: product.id, qty: qty)],
        payments: <SalePaymentDraft>[
          SalePaymentDraft(method: 'cash', amount: 12500 * qty),
        ],
      ),
    );
  }

  DashboardDateRange range(DashboardPeriod period) {
    return DashboardDateRange.resolve(period: period, now: clock.now());
  }

  test('tanpa usaha mengembalikan ringkasan kosong', () async {
    final Directory other = await Directory.systemTemp.createTemp('kd_empty_');
    final AppDatabase fresh = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(other.path, 'empty.db'),
    );
    final SqliteDashboardRepository repo = SqliteDashboardRepository(
      database: fresh,
    );
    final DashboardSnapshot snapshot = await repo.load(
      range: range(DashboardPeriod.today),
    );
    expect(snapshot.businessId, isNull);
    expect(snapshot.omzet, 0);
    expect(snapshot.transactionCount, 0);
    await fresh.close();
    await other.delete(recursive: true);
  });

  test('memisahkan omzet hari ini dan kemarin dari SQLite', () async {
    final Product product = await addProduct(name: 'Nasi Goreng');

    clock.setNow(monday);
    await sell(product, qty: 1);
    await expenses.create(
      NewExpense(
        businessId: businessId,
        amount: 5000,
        spentAt: clock.nowEpochMs(),
        note: 'Gas kemarin',
      ),
    );

    clock.setNow(tuesday);
    await sell(product, qty: 2);
    await expenses.create(
      NewExpense(
        businessId: businessId,
        amount: 15000,
        spentAt: clock.nowEpochMs(),
        note: 'Sayur hari ini',
      ),
    );

    final DashboardSnapshot today = await dashboard.load(
      range: range(DashboardPeriod.today),
    );
    expect(today.omzet, 25000);
    expect(today.transactionCount, 1);
    expect(today.productsSoldQty, 2);
    expect(today.grossProfit, 9000);
    expect(today.expensesTotal, 15000);
    expect(today.recentSales, hasLength(1));

    final DashboardSnapshot yesterday = await dashboard.load(
      range: range(DashboardPeriod.yesterday),
    );
    expect(yesterday.omzet, 12500);
    expect(yesterday.transactionCount, 1);
    expect(yesterday.productsSoldQty, 1);
    expect(yesterday.grossProfit, 4500);
    expect(yesterday.expensesTotal, 5000);

    final DashboardSnapshot week = await dashboard.load(
      range: range(DashboardPeriod.thisWeek),
    );
    expect(week.omzet, 37500);
    expect(week.transactionCount, 2);
    expect(week.productsSoldQty, 3);
  });

  test('stok menipis, saldo kas, dan transaksi batal tidak dihitung', () async {
    final Product thin = await addProduct(name: 'Es Teh', minStock: 5, qty: 3);
    await addProduct(name: 'Kopi', minStock: 0, qty: 0);

    final session = await cash.openSession(
      businessId: businessId,
      openingAmount: 100000,
    );
    await cash.addMovement(sessionId: session.id, type: 'in', amount: 10000);
    await cash.addMovement(sessionId: session.id, type: 'out', amount: 5000);
    await sell(thin, qty: 1, sessionId: session.id);

    final db = await database.database;
    await db.insert(DatabaseConstants.tableTransactions, <String, Object>{
      'id': 'cancelled-1',
      'client_uuid': 'cancelled-uuid',
      'business_id': businessId,
      'status': 'cancelled',
      'subtotal_amount': 99999,
      'discount_amount': 0,
      'tax_amount': 0,
      'total_amount': 99999,
      'created_at': clock.nowEpochMs(),
      'updated_at': clock.nowEpochMs(),
    });

    final DashboardSnapshot snapshot = await dashboard.load(
      range: range(DashboardPeriod.today),
    );
    expect(snapshot.omzet, 12500);
    expect(snapshot.transactionCount, 1);
    expect(snapshot.hasOpenCashSession, isTrue);
    expect(snapshot.cashBalance, 100000 + 10000 - 5000 + 12500);
    expect(snapshot.lowStock, hasLength(1));
    expect(snapshot.lowStock.single.name, 'Es Teh');
    expect(snapshot.lowStock.single.qty, 2);
  });
}
