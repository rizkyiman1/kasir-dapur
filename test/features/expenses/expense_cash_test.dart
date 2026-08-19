import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/features/cash_management/data/cash_repository_impl.dart';
import 'package:kasir_dapur/features/cash_management/domain/cash.dart';
import 'package:kasir_dapur/features/expenses/data/expense_repository_impl.dart';
import 'package:kasir_dapur/features/expenses/domain/expense.dart';
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
  late String businessId;
  late SqliteExpenseRepository expenses;
  late SqliteCashRepository cash;
  late SqliteProductRepository products;
  late SqliteTransactionRepository transactions;
  const ClockService clock = ClockService();

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_exp_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(tempDir.path, 'kasir_dapur.db'),
    );
    businessId = await insertBusiness(await database.database, clock: clock);
    expenses = SqliteExpenseRepository(database: database, clock: clock);
    cash = SqliteCashRepository(database: database, clock: clock);
    products = SqliteProductRepository(database: database, clock: clock);
    transactions = SqliteTransactionRepository(
      database: database,
      clock: clock,
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('kategori pengeluaran default lengkap dan bisa dicatat', () async {
    final List<ExpenseCategory> categories = await expenses
        .ensureDefaultCategories(businessId);
    expect(
      categories.map((ExpenseCategory row) => row.code),
      containsAll(<String>[
        ExpenseCategoryCatalog.listrik,
        ExpenseCategoryCatalog.gas,
        ExpenseCategoryCatalog.packaging,
        ExpenseCategoryCatalog.transport,
        ExpenseCategoryCatalog.gaji,
        ExpenseCategoryCatalog.sewa,
        ExpenseCategoryCatalog.internet,
        ExpenseCategoryCatalog.lainnya,
      ]),
    );
    final ExpenseCategory gas = categories.firstWhere(
      (ExpenseCategory row) => row.code == ExpenseCategoryCatalog.gas,
    );
    final Expense saved = await expenses.create(
      NewExpense(
        businessId: businessId,
        categoryId: gas.id,
        amount: 45000,
        note: 'Gas 3 kg',
        spentAt: clock.nowEpochMs(),
      ),
    );
    expect(saved.amount, 45000);
    expect(saved.categoryCode, ExpenseCategoryCatalog.gas);
    expect(
      (await expenses.list(
        businessId: businessId,
        categoryId: gas.id,
      )).single.id,
      saved.id,
    );
  });

  test(
    'expected cash tidak mencampur omzet non-tunai, closing report tersimpan',
    () async {
      final Product product = await products.create(
        NewProduct(
          businessId: businessId,
          name: 'Es Teh',
          sellPrice: 5000,
          costPrice: 2000,
          initialStock: 10,
        ),
      );
      final CashSession session = await cash.openSession(
        businessId: businessId,
        openingAmount: 100000,
      );
      await transactions.createCompletedSale(
        NewSale(
          businessId: businessId,
          clientUuid: const Uuid().v4(),
          cashSessionId: session.id,
          items: <SaleItemDraft>[SaleItemDraft(productId: product.id, qty: 2)],
          payments: const <SalePaymentDraft>[
            SalePaymentDraft(method: 'cash', amount: 10000),
          ],
        ),
      );
      await transactions.createCompletedSale(
        NewSale(
          businessId: businessId,
          clientUuid: const Uuid().v4(),
          cashSessionId: session.id,
          items: <SaleItemDraft>[SaleItemDraft(productId: product.id, qty: 1)],
          payments: const <SalePaymentDraft>[
            SalePaymentDraft(method: 'qris', amount: 5000),
          ],
        ),
      );
      await cash.addMovement(
        sessionId: session.id,
        type: CashMovementType.cashOut,
        amount: 20000,
      );

      final CashDrawerSnapshot drawer = await cash.drawer(session.id);
      expect(drawer.cashSales, 10000);
      expect(drawer.nonCashSales, 5000);
      expect(drawer.expectedAmount, 100000 + 10000 - 20000);
      expect(drawer.expectedAmount, isNot(100000 + 10000 + 5000 - 20000));

      final CashSession closed = await cash.closeSession(
        sessionId: session.id,
        countedAmount: 89000,
      );
      expect(closed.expectedAmount, 90000);
      expect(closed.differenceAmount, -1000);
      expect(closed.closingReport, isNotNull);
      expect(closed.closingReport!.cashSales, 10000);
      expect(closed.closingReport!.nonCashSales, 5000);
      expect(closed.closingReport!.actualAmount, 89000);
      expect(
        (await cash.listClosed(businessId: businessId)).single.id,
        closed.id,
      );
    },
  );
}
