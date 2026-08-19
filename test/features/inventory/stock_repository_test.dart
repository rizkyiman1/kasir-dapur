import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
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
  late SqliteProductRepository products;
  late SqliteStockRepository stock;
  late SqliteTransactionRepository transactions;
  late String businessId;
  const ClockService clock = ClockService();

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_stock_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(tempDir.path, 'kasir_dapur.db'),
    );
    products = SqliteProductRepository(database: database, clock: clock);
    stock = SqliteStockRepository(database: database, clock: clock);
    transactions = SqliteTransactionRepository(
      database: database,
      clock: clock,
    );
    businessId = await insertBusiness(await database.database, clock: clock);
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Product> addProduct({
    String name = 'Es Teh',
    int minStock = 0,
    int initialStock = 0,
  }) {
    return products.create(
      NewProduct(
        businessId: businessId,
        name: name,
        costPrice: 2000,
        sellPrice: 5000,
        minStock: minStock,
        initialStock: initialStock,
      ),
    );
  }

  test(
    'setiap jenis movement mengubah stok dan menulis stock_movements',
    () async {
      final Product product = await addProduct();
      expect(await stock.allowNegativeStock(businessId), isFalse);

      await stock.stockIn(
        businessId: businessId,
        productId: product.id,
        qty: 20,
      );
      await stock.purchase(
        businessId: businessId,
        productId: product.id,
        qty: 5,
      );
      await stock.stockOut(
        businessId: businessId,
        productId: product.id,
        qty: 3,
      );
      await stock.saleReturn(
        businessId: businessId,
        productId: product.id,
        qty: 1,
      );
      await stock.recordDamaged(
        businessId: businessId,
        productId: product.id,
        qty: 1,
      );
      await stock.recordExpired(
        businessId: businessId,
        productId: product.id,
        qty: 1,
      );
      await stock.transfer(
        businessId: businessId,
        productId: product.id,
        qtyDelta: -2,
        note: 'Ke cabang',
      );
      await stock.adjustTo(
        businessId: businessId,
        productId: product.id,
        countedQty: 10,
      );

      final StockBalance? balance = await stock.getByProduct(
        businessId: businessId,
        productId: product.id,
      );
      expect(balance?.qty, 10);

      final List<StockMovement> history = await stock.listHistory(
        businessId: businessId,
        productId: product.id,
      );
      expect(
        history.map((StockMovement row) => row.type).toSet(),
        containsAll(<String>[
          'stock_in',
          'purchase',
          'stock_out',
          'sale_return',
          'damaged',
          'expired',
          'transfer',
          'adjustment',
        ]),
      );
      expect(history, isNotEmpty);
      for (final StockMovement row in history) {
        expect(row.qtyAfter, row.qtyBefore + row.qty);
      }
    },
  );

  test('stok awal produk membuat movement stock_in', () async {
    final Product product = await addProduct(initialStock: 7);
    final StockBalance? balance = await stock.getByProduct(
      businessId: businessId,
      productId: product.id,
    );
    expect(balance?.qty, 7);
    final List<StockMovement> movements = await stock.listMovements(
      businessId: businessId,
      productId: product.id,
    );
    expect(movements, hasLength(1));
    expect(movements.single.type, 'stock_in');
    expect(movements.single.qty, 7);
  });

  test('default menolak stok negatif, termasuk penjualan', () async {
    final Product product = await addProduct(initialStock: 2);
    expect(
      () =>
          stock.stockOut(businessId: businessId, productId: product.id, qty: 5),
      throwsA(isA<InsufficientStockException>()),
    );
    expect(
      () => transactions.createCompletedSale(
        NewSale(
          businessId: businessId,
          clientUuid: const Uuid().v4(),
          items: <SaleItemDraft>[SaleItemDraft(productId: product.id, qty: 5)],
          payments: const <SalePaymentDraft>[
            SalePaymentDraft(method: 'cash', amount: 25000),
          ],
        ),
      ),
      throwsA(isA<InsufficientStockException>()),
    );
    expect(
      (await stock.getByProduct(
        businessId: businessId,
        productId: product.id,
      ))?.qty,
      2,
    );
  });

  test(
    'allow_negative_stock true mengizinkan penjualan melebihi stok',
    () async {
      final Product product = await addProduct(initialStock: 1);
      await stock.setAllowNegativeStock(businessId: businessId, allow: true);
      expect(await stock.allowNegativeStock(businessId), isTrue);

      await transactions.createCompletedSale(
        NewSale(
          businessId: businessId,
          clientUuid: const Uuid().v4(),
          items: <SaleItemDraft>[SaleItemDraft(productId: product.id, qty: 4)],
          payments: const <SalePaymentDraft>[
            SalePaymentDraft(method: 'cash', amount: 20000),
          ],
        ),
      );
      expect(
        (await stock.getByProduct(
          businessId: businessId,
          productId: product.id,
        ))?.qty,
        -3,
      );
      final List<StockMovement> movements = await stock.listMovements(
        businessId: businessId,
        productId: product.id,
      );
      expect(movements.any((StockMovement row) => row.type == 'sale'), isTrue);
    },
  );

  test('low stock memakai minimum stok', () async {
    final Product thin = await addProduct(
      name: 'Gula',
      minStock: 5,
      initialStock: 3,
    );
    await addProduct(name: 'Garam', minStock: 2, initialStock: 10);
    final List<StockPosition> low = await stock.listLowStock(
      businessId: businessId,
    );
    expect(low.map((StockPosition item) => item.productId), [thin.id]);
    expect(low.single.isLow, isTrue);
  });

  test('stock opname menulis adjustment dan rollback jika gagal', () async {
    final Product first = await addProduct(name: 'A', initialStock: 10);
    final Product second = await addProduct(name: 'B', initialStock: 5);

    final StockOpnameResult result = await stock.commitOpname(
      businessId: businessId,
      lines: <StockOpnameLine>[
        StockOpnameLine(productId: first.id, countedQty: 8),
        StockOpnameLine(productId: second.id, countedQty: 5),
      ],
    );
    expect(result.adjustedCount, 1);
    expect(result.unchangedCount, 1);
    expect(
      (await stock.getByProduct(
        businessId: businessId,
        productId: first.id,
      ))?.qty,
      8,
    );

    expect(
      () => stock.commitOpname(
        businessId: businessId,
        lines: <StockOpnameLine>[
          StockOpnameLine(productId: first.id, countedQty: 1),
          StockOpnameLine(productId: second.id, countedQty: -2),
        ],
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(
      (await stock.getByProduct(
        businessId: businessId,
        productId: first.id,
      ))?.qty,
      8,
    );
    final db = await database.database;
    final movements = await db.query(
      DatabaseConstants.tableStockMovements,
      where: "product_id = ? AND type = 'adjustment' AND qty = ?",
      whereArgs: <Object>[first.id, -7],
    );
    expect(movements, isEmpty);
  });

  test('penjualan multi item rollback stok jika item kedua gagal', () async {
    final Product ready = await addProduct(name: 'Siap', initialStock: 5);
    final Product short = await addProduct(name: 'Kurang', initialStock: 1);

    expect(
      () => transactions.createCompletedSale(
        NewSale(
          businessId: businessId,
          clientUuid: const Uuid().v4(),
          items: <SaleItemDraft>[
            SaleItemDraft(productId: ready.id, qty: 2),
            SaleItemDraft(productId: short.id, qty: 4),
          ],
          payments: const <SalePaymentDraft>[
            SalePaymentDraft(method: 'cash', amount: 30000),
          ],
        ),
      ),
      throwsA(isA<InsufficientStockException>()),
    );

    expect(
      (await stock.getByProduct(
        businessId: businessId,
        productId: ready.id,
      ))?.qty,
      5,
    );
    expect(
      (await stock.getByProduct(
        businessId: businessId,
        productId: short.id,
      ))?.qty,
      1,
    );
    final db = await database.database;
    expect(await db.query(DatabaseConstants.tableTransactions), isEmpty);
    expect(
      await db.query(
        DatabaseConstants.tableStockMovements,
        where: 'type = ?',
        whereArgs: <Object>['sale'],
      ),
      isEmpty,
    );
  });

  test('concurrency dua pengurangan stok hanya satu yang lolos', () async {
    final Product product = await addProduct(initialStock: 10);

    Future<Object> attempt() async {
      try {
        await stock.stockOut(
          businessId: businessId,
          productId: product.id,
          qty: 8,
        );
        return 'ok';
      } catch (error) {
        return error;
      }
    }

    final List<Object> outcomes = await Future.wait<Object>(<Future<Object>>[
      attempt(),
      attempt(),
    ]);

    expect(outcomes.where((Object item) => item == 'ok'), hasLength(1));
    expect(
      outcomes.where(
        (Object item) =>
            item is InsufficientStockException || item is ConflictException,
      ),
      hasLength(1),
    );
    expect(
      (await stock.getByProduct(
        businessId: businessId,
        productId: product.id,
      ))?.qty,
      2,
    );
  });

  test('arah movement salah ditolak', () async {
    final Product product = await addProduct(initialStock: 4);
    expect(
      () => stock.applyMovement(
        businessId: businessId,
        productId: product.id,
        type: StockMovementType.stockIn,
        qtyDelta: -1,
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => stock.applyMovement(
        businessId: businessId,
        productId: product.id,
        type: StockMovementType.sale,
        qtyDelta: 1,
      ),
      throwsA(isA<ValidationException>()),
    );
  });
}
