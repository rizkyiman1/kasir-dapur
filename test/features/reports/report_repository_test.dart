import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/cash_management/data/cash_repository_impl.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_period.dart';
import 'package:kasir_dapur/features/expenses/data/expense_repository_impl.dart';
import 'package:kasir_dapur/features/expenses/domain/expense.dart';
import 'package:kasir_dapur/features/inventory/data/stock_repository_impl.dart';
import 'package:kasir_dapur/features/inventory/domain/stock.dart';
import 'package:kasir_dapur/features/products/data/category_repository_impl.dart';
import 'package:kasir_dapur/features/products/data/product_repository_impl.dart';
import 'package:kasir_dapur/features/products/domain/catalog_lookups.dart';
import 'package:kasir_dapur/features/products/domain/product.dart';
import 'package:kasir_dapur/features/reports/data/guarded_report_repository.dart';
import 'package:kasir_dapur/features/reports/data/report_repository_impl.dart';
import 'package:kasir_dapur/features/reports/domain/report_filter.dart';
import 'package:kasir_dapur/features/reports/domain/report_snapshot.dart';
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
  late SqliteCategoryRepository categories;
  late SqliteStockRepository stock;
  late SqliteTransactionRepository transactions;
  late SqliteExpenseRepository expenses;
  late SqliteCashRepository cash;
  late SqliteReportRepository reports;
  late String businessId;

  final DateTime tuesday = DateTime(2026, 8, 18, 15, 0);
  final DateTime monday = DateTime(2026, 8, 17, 11, 0);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_rpt_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(tempDir.path, 'kasir_dapur.db'),
    );
    clock = AdjustableClock(tuesday);
    products = SqliteProductRepository(database: database, clock: clock);
    categories = SqliteCategoryRepository(database: database, clock: clock);
    stock = SqliteStockRepository(database: database, clock: clock);
    transactions = SqliteTransactionRepository(
      database: database,
      clock: clock,
    );
    expenses = SqliteExpenseRepository(database: database, clock: clock);
    cash = SqliteCashRepository(database: database, clock: clock);
    reports = SqliteReportRepository(database: database);
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
    int costPrice = 8000,
    int sellPrice = 12500,
    int minStock = 0,
    int qty = 10,
    String? categoryId,
  }) async {
    final Product product = await products.create(
      NewProduct(
        businessId: businessId,
        name: name,
        costPrice: costPrice,
        sellPrice: sellPrice,
        minStock: minStock,
        categoryId: categoryId,
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

  Future<void> insertCashier(String id, String name) async {
    final int now = clock.nowEpochMs();
    final db = await database.database;
    await db.insert(DatabaseConstants.tableLocalUsers, <String, Object>{
      'id': id,
      'display_name': name,
      'role': 'cashier',
      'pin_salt': 'salt',
      'pin_hash': 'hash',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert(DatabaseConstants.tableRoles, <String, Object>{
      'id': 'role-$id',
      'business_id': businessId,
      'code': 'cashier',
      'name': 'Kasir',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert(DatabaseConstants.tableUsers, <String, Object>{
      'id': id,
      'business_id': businessId,
      'role_id': 'role-$id',
      'display_name': name,
      'status': 'active',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> sell({
    required List<SaleItemDraft> items,
    required List<SalePaymentDraft> payments,
    String? userId,
    String? sessionId,
    int discountAmount = 0,
  }) {
    return transactions.createCompletedSale(
      NewSale(
        businessId: businessId,
        clientUuid: const Uuid().v4(),
        userId: userId,
        cashSessionId: sessionId,
        discountAmount: discountAmount,
        items: items,
        payments: payments,
      ),
    );
  }

  Future<void> sellProduct(
    Product product, {
    int qty = 1,
    String method = 'cash',
    String? userId,
    String? sessionId,
  }) {
    final int amount = product.sellPrice * qty;
    return sell(
      items: <SaleItemDraft>[SaleItemDraft(productId: product.id, qty: qty)],
      payments: <SalePaymentDraft>[
        SalePaymentDraft(method: method, amount: amount),
      ],
      userId: userId,
      sessionId: sessionId,
    );
  }

  ReportQuery query({
    DashboardPeriod period = DashboardPeriod.today,
    String? productId,
    String? categoryId,
    String? cashierId,
    String? paymentMethod,
  }) {
    return ReportQuery(
      range: DashboardDateRange.resolve(period: period, now: clock.now()),
      productId: productId,
      categoryId: categoryId,
      cashierId: cashierId,
      paymentMethod: paymentMethod,
    );
  }

  test('tanpa usaha mengembalikan laporan kosong', () async {
    final Directory other = await Directory.systemTemp.createTemp('kd_rpt_e_');
    final AppDatabase fresh = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(other.path, 'empty.db'),
    );
    final ReportSnapshot snapshot = await SqliteReportRepository(
      database: fresh,
    ).load(query());
    expect(snapshot.businessId, isNull);
    expect(snapshot.omzet, 0);
    expect(snapshot.transactionCount, 0);
    expect(snapshot.grossProfit, 0);
    await fresh.close();
    await other.delete(recursive: true);
  });

  test('omzet, penjualan, dan laba kotor integer dari SQLite', () async {
    final Product product = await addProduct(name: 'Nasi Goreng');

    clock.setNow(monday);
    await sellProduct(product, qty: 1);
    await expenses.create(
      NewExpense(
        businessId: businessId,
        amount: 5000,
        spentAt: clock.nowEpochMs(),
        note: 'Gas kemarin',
      ),
    );

    clock.setNow(tuesday);
    await sellProduct(product, qty: 2);
    await expenses.create(
      NewExpense(
        businessId: businessId,
        amount: 15000,
        spentAt: clock.nowEpochMs(),
        note: 'Sayur hari ini',
      ),
    );

    final ReportSnapshot today = await reports.load(query());
    expect(today.omzet, 25000);
    expect(today.transactionCount, 1);
    expect(today.productsSoldQty, 2);
    expect(today.cogs, 16000);
    expect(today.grossProfit, 9000);
    expect(today.expensesTotal, 15000);
    expect(today.sales, hasLength(1));
    expect(today.sales.single.amount, 25000);
    expect(today.topProducts.single.name, 'Nasi Goreng');
    expect(today.topProducts.single.qty, 2);
    expect(today.topProducts.single.amount, 25000);
    expect(today.paymentMethods.single.name, 'Tunai');
    expect(today.paymentMethods.single.amount, 25000);
    expect(today.salesByCashier.single.name, 'Tanpa kasir');
    expect(today.salesByCashier.single.amount, 25000);

    final ReportSnapshot yesterday = await reports.load(
      query(period: DashboardPeriod.yesterday),
    );
    expect(yesterday.omzet, 12500);
    expect(yesterday.transactionCount, 1);
    expect(yesterday.grossProfit, 4500);
    expect(yesterday.expensesTotal, 5000);

    final ReportSnapshot week = await reports.load(
      query(period: DashboardPeriod.thisWeek),
    );
    expect(week.omzet, 37500);
    expect(week.transactionCount, 2);
    expect(week.productsSoldQty, 3);
  });

  test('dua item satu struk tidak menggandakan omzet', () async {
    final Product nasi = await addProduct(name: 'Nasi Goreng');
    final Product teh = await addProduct(
      name: 'Es Teh',
      costPrice: 2000,
      sellPrice: 5000,
    );
    await sell(
      items: <SaleItemDraft>[
        SaleItemDraft(productId: nasi.id, qty: 1),
        SaleItemDraft(productId: teh.id, qty: 1),
      ],
      payments: <SalePaymentDraft>[
        SalePaymentDraft(method: 'cash', amount: 17500),
      ],
    );

    final ReportSnapshot snapshot = await reports.load(query());
    expect(snapshot.omzet, 17500);
    expect(snapshot.transactionCount, 1);
    expect(snapshot.cogs, 10000);
    expect(snapshot.grossProfit, 7500);
    expect(snapshot.productsSoldQty, 2);
  });

  test('laba kotor = omzet header - HPP, bukan jumlah baris', () async {
    final Product product = await addProduct(name: 'Nasi Goreng');
    await sell(
      items: <SaleItemDraft>[
        SaleItemDraft(productId: product.id, qty: 2, discountAmount: 2000),
      ],
      payments: <SalePaymentDraft>[
        SalePaymentDraft(method: 'cash', amount: 20000),
      ],
      discountAmount: 3000,
    );

    final ReportSnapshot all = await reports.load(query());
    expect(all.omzet, 20000);
    expect(all.cogs, 16000);
    expect(all.grossProfit, 4000);

    final ReportSnapshot filtered = await reports.load(
      query(productId: product.id),
    );
    expect(filtered.omzet, 23000);
    expect(filtered.cogs, 16000);
    expect(filtered.grossProfit, 7000);
  });

  test('filter produk, kategori, kasir, dan metode pembayaran', () async {
    final CatalogCategory makanan = await categories.create(
      businessId: businessId,
      name: 'Makanan',
    );
    final CatalogCategory minuman = await categories.create(
      businessId: businessId,
      name: 'Minuman',
    );
    final Product nasi = await addProduct(
      name: 'Nasi Goreng',
      categoryId: makanan.id,
    );
    final Product teh = await addProduct(
      name: 'Es Teh',
      costPrice: 2000,
      sellPrice: 5000,
      categoryId: minuman.id,
    );
    await insertCashier('kasir-siti', 'Siti');
    await insertCashier('kasir-budi', 'Budi');

    await sellProduct(nasi, userId: 'kasir-siti');
    await sellProduct(teh, method: 'qris', userId: 'kasir-budi');
    await sell(
      items: <SaleItemDraft>[
        SaleItemDraft(productId: nasi.id, qty: 1),
        SaleItemDraft(productId: teh.id, qty: 1),
      ],
      payments: <SalePaymentDraft>[
        SalePaymentDraft(method: 'cash', amount: 10000),
        SalePaymentDraft(method: 'qris', amount: 7500),
      ],
      userId: 'kasir-siti',
    );

    final ReportSnapshot byProduct = await reports.load(
      query(productId: nasi.id),
    );
    expect(byProduct.transactionCount, 2);
    expect(byProduct.omzet, 25000);
    expect(byProduct.cogs, 16000);
    expect(byProduct.grossProfit, 9000);
    expect(byProduct.topProducts, hasLength(1));
    expect(byProduct.topProducts.single.name, 'Nasi Goreng');

    final ReportSnapshot byCategory = await reports.load(
      query(categoryId: minuman.id),
    );
    expect(byCategory.omzet, 10000);
    expect(byCategory.productsSoldQty, 2);
    expect(byCategory.salesByCategory.single.name, 'Minuman');

    final ReportSnapshot byCashier = await reports.load(
      query(cashierId: 'kasir-budi'),
    );
    expect(byCashier.transactionCount, 1);
    expect(byCashier.omzet, 5000);
    expect(byCashier.salesByCashier.single.name, 'Budi');

    final ReportSnapshot byCash = await reports.load(
      query(paymentMethod: 'cash'),
    );
    expect(byCash.transactionCount, 2);
    expect(byCash.omzet, 12500 + 17500);
    expect(byCash.paymentMethods, hasLength(1));
    expect(byCash.paymentMethods.single.id, 'cash');
    expect(byCash.paymentMethods.single.amount, 22500);

    final ReportSnapshot byQris = await reports.load(
      query(paymentMethod: 'qris'),
    );
    expect(byQris.transactionCount, 2);
    expect(byQris.omzet, 5000 + 17500);

    final ReportSnapshot all = await reports.load(query());
    expect(all.salesByCashier, hasLength(2));
    expect(
      all.salesByCashier.map((ReportNamedAmount r) => r.name).toList(),
      containsAll(<String>['Siti', 'Budi']),
    );
    expect(all.salesByCategory, hasLength(2));
    expect(all.topProducts.first.name, 'Nasi Goreng');
    expect(all.topProducts.first.qty, 2);
  });

  test('stok, stok menipis, kas, dan transaksi batal tidak dihitung', () async {
    final Product thin = await addProduct(name: 'Es Teh', minStock: 5, qty: 3);
    await addProduct(name: 'Kopi', minStock: 0, qty: 0);

    final session = await cash.openSession(
      businessId: businessId,
      openingAmount: 100000,
    );
    await cash.addMovement(sessionId: session.id, type: 'in', amount: 10000);
    await cash.addMovement(sessionId: session.id, type: 'out', amount: 5000);
    await sellProduct(thin, sessionId: session.id);
    await sellProduct(thin, method: 'qris', sessionId: session.id);

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

    final ReportSnapshot snapshot = await reports.load(query());
    expect(snapshot.omzet, 25000);
    expect(snapshot.transactionCount, 2);
    expect(snapshot.cash.hasOpenSession, isTrue);
    expect(snapshot.cash.currentBalance, 100000 + 10000 - 5000 + 12500);
    expect(snapshot.cash.periodCashSales, 12500);
    expect(snapshot.cash.periodNonCashSales, 12500);
    expect(snapshot.cash.periodCashIn, 10000);
    expect(snapshot.cash.periodCashOut, 5000);
    expect(snapshot.cash.periodNet, 12500 + 10000 - 5000);
    expect(snapshot.lowStock, hasLength(1));
    expect(snapshot.lowStock.single.name, 'Es Teh');
    expect(snapshot.lowStock.single.qty, 1);
    expect(snapshot.stock.length, greaterThanOrEqualTo(2));
  });

  test('kasir tidak boleh memuat laporan', () async {
    final GuardedReportRepository guarded = GuardedReportRepository(
      inner: reports,
      guard: PermissionGuard(),
      access: () => const StaticAccessContext(
        currentUser: AuthUser(
          id: 'c1',
          displayName: 'Cici',
          role: UserRole.cashier,
        ),
      ),
    );
    expect(() => guarded.load(query()), throwsA(isA<ForbiddenException>()));
    expect(() => guarded.filterOptions(), throwsA(isA<ForbiddenException>()));
  });
}
