import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/database/app_database.dart';
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
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_sale_');
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

  Future<Product> readyProduct({int qty = 10}) async {
    final Product product = await products.create(
      NewProduct(
        businessId: businessId,
        name: 'Nasi Goreng',
        sku: 'NG-01',
        barcode: '899123',
        costPrice: 8000,
        sellPrice: 12500,
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

  test(
    'penjualan atomic mengurangi stok dan menyimpan pembayaran integer',
    () async {
      final Product product = await readyProduct();
      final Sale sale = await transactions.createCompletedSale(
        NewSale(
          businessId: businessId,
          clientUuid: const Uuid().v4(),
          items: <SaleItemDraft>[SaleItemDraft(productId: product.id, qty: 2)],
          payments: const <SalePaymentDraft>[
            SalePaymentDraft(
              method: 'cash',
              amount: 25000,
              tenderedAmount: 50000,
              changeAmount: 25000,
            ),
          ],
        ),
      );

      expect(sale.totalAmount, 25000);
      expect(sale.items.single.unitPrice, 12500);
      expect(sale.payments.single.changeAmount, 25000);
      final balance = await stock.getByProduct(
        businessId: businessId,
        productId: product.id,
      );
      expect(balance?.qty, 8);
    },
  );

  test('stok kurang membuat rollback penjualan', () async {
    final Product product = await readyProduct(qty: 1);
    expect(
      () => transactions.createCompletedSale(
        NewSale(
          businessId: businessId,
          clientUuid: const Uuid().v4(),
          items: <SaleItemDraft>[SaleItemDraft(productId: product.id, qty: 5)],
          payments: const <SalePaymentDraft>[
            SalePaymentDraft(method: 'cash', amount: 62500),
          ],
        ),
      ),
      throwsA(isA<InsufficientStockException>()),
    );

    final balance = await stock.getByProduct(
      businessId: businessId,
      productId: product.id,
    );
    expect(balance?.qty, 1);
    expect(
      await transactions.findByClientUuid(
        businessId: businessId,
        clientUuid: 'unused',
      ),
      isNull,
    );
    final db = await database.database;
    final saleRows = await db.query('transactions');
    expect(saleRows, isEmpty);
  });

  test('client_uuid yang sama tidak menduplikasi transaksi', () async {
    final Product product = await readyProduct();
    const String uuid = 'sale-idempotent-1';
    final NewSale input = NewSale(
      businessId: businessId,
      clientUuid: uuid,
      items: <SaleItemDraft>[SaleItemDraft(productId: product.id, qty: 1)],
      payments: const <SalePaymentDraft>[
        SalePaymentDraft(method: 'cash', amount: 12500),
      ],
    );
    final Sale first = await transactions.createCompletedSale(input);
    final Sale second = await transactions.createCompletedSale(input);
    expect(second.id, first.id);
    final balance = await stock.getByProduct(
      businessId: businessId,
      productId: product.id,
    );
    expect(balance?.qty, 9);
  });
}
