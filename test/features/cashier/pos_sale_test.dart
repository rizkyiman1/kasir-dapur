import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/features/cashier/data/pos_cart_repository_impl.dart';
import 'package:kasir_dapur/features/cashier/domain/pos_cart.dart';
import 'package:kasir_dapur/features/cashier/domain/pos_checkout_service.dart';
import 'package:kasir_dapur/features/inventory/data/stock_repository_impl.dart';
import 'package:kasir_dapur/features/products/data/category_repository_impl.dart';
import 'package:kasir_dapur/features/products/data/product_repository_impl.dart';
import 'package:kasir_dapur/features/products/domain/product.dart';
import 'package:kasir_dapur/features/transactions/data/transaction_repository_impl.dart';
import 'package:kasir_dapur/features/transactions/domain/payment_method.dart';
import 'package:kasir_dapur/features/transactions/domain/sale.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/pos_fixture.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late SqliteProductRepository products;
  late SqliteStockRepository stock;
  late SqliteTransactionRepository transactions;
  late SqlitePosCartRepository carts;
  late SqliteCategoryRepository categories;
  late PosCheckoutService checkout;
  late String businessId;
  const ClockService clock = ClockService();

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_pos_');
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
    carts = SqlitePosCartRepository(database: database, clock: clock);
    categories = SqliteCategoryRepository(database: database, clock: clock);
    checkout = PosCheckoutService(transactions: transactions, carts: carts);
    businessId = await insertBusiness(await database.database, clock: clock);
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Product> addProduct({
    String name = 'Nasi Goreng',
    int price = 25000,
    int qty = 10,
    String? barcode,
    String? categoryId,
  }) async {
    final Product product = await products.create(
      NewProduct(
        businessId: businessId,
        name: name,
        sellPrice: price,
        costPrice: 8000,
        barcode: barcode,
        categoryId: categoryId,
        initialStock: qty,
      ),
    );
    return product;
  }

  Future<PosCart> cartWith(Product product, {int qty = 1}) async {
    PosCart cart = await carts.loadOrCreateOpen(businessId: businessId);
    cart = cart.addOrIncrement(
      CartLine(
        productId: product.id,
        name: product.name,
        unitPrice: product.sellPrice,
        costPrice: product.costPrice,
        qty: qty,
      ),
    );
    return carts.save(cart);
  }

  test(
    'penjualan normal atomic: item, pembayaran, stok, movement, sync',
    () async {
      final Product product = await addProduct();
      final PosCart cart = await cartWith(product);
      final CashTender cash = CashTender.fromTendered(
        total: 25000,
        tendered: 50000,
      );
      final Sale sale = await checkout.checkout(
        cart: cart,
        payments: [
          SalePaymentDraft(
            method: PaymentMethod.cash.storageValue,
            amount: cash.amount,
            tenderedAmount: cash.tenderedAmount,
            changeAmount: cash.changeAmount,
          ),
        ],
      );

      expect(sale.status, 'completed');
      expect(sale.totalAmount, 25000);
      expect(sale.items, hasLength(1));
      expect(sale.payments.single.changeAmount, 25000);
      expect(
        (await stock.getByProduct(
          businessId: businessId,
          productId: product.id,
        ))?.qty,
        9,
      );
      final db = await database.database;
      expect(
        await db.query(DatabaseConstants.tableTransactionItems),
        hasLength(1),
      );
      expect(await db.query(DatabaseConstants.tablePayments), hasLength(1));
      expect(
        await db.query(
          DatabaseConstants.tableStockMovements,
          where: 'type = ?',
          whereArgs: <Object>['sale'],
        ),
        hasLength(1),
      );
      expect(
        await db.query(
          DatabaseConstants.tableSyncQueue,
          where: "status = 'pending' AND aggregate = 'transaction'",
        ),
        hasLength(1),
      );
      expect(await carts.getById(cart.id), isNull);
    },
  );

  test('kuantitas nol ditolak', () async {
    final Product product = await addProduct();
    expect(
      () => transactions.createCompletedSale(
        NewSale(
          businessId: businessId,
          clientUuid: 'zero-qty',
          items: <SaleItemDraft>[SaleItemDraft(productId: product.id, qty: 0)],
          payments: const <SalePaymentDraft>[
            SalePaymentDraft(method: 'cash', amount: 0),
          ],
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('stok kurang membuat rollback', () async {
    final Product product = await addProduct(qty: 1);
    final PosCart cart = await cartWith(product, qty: 5);
    expect(
      () => checkout.checkout(
        cart: cart,
        payments: const <SalePaymentDraft>[
          SalePaymentDraft(method: 'cash', amount: 125000),
        ],
      ),
      throwsA(isA<InsufficientStockException>()),
    );
    expect(
      (await stock.getByProduct(
        businessId: businessId,
        productId: product.id,
      ))?.qty,
      1,
    );
    expect(await (await database.database).query('transactions'), isEmpty);
    expect(await carts.getById(cart.id), isNotNull);
  });

  test('diskon item dan transaksi mengurangi total', () async {
    final Product product = await addProduct(price: 25000);
    PosCart cart = await cartWith(product);
    cart = await carts.save(
      cart.setItemDiscount(product.id, 2000).setTransactionDiscount(3000),
    );
    expect(cart.subtotal, 23000);
    expect(cart.total, 20000);
    final Sale sale = await checkout.checkout(
      cart: cart,
      payments: const <SalePaymentDraft>[
        SalePaymentDraft(method: 'cash', amount: 20000),
      ],
    );
    expect(sale.items.single.discountAmount, 2000);
    expect(sale.discountAmount, 3000);
    expect(sale.totalAmount, 20000);
  });

  test('pembayaran tunai uang pas dan kelebihan', () async {
    final Product product = await addProduct();
    final CashTender exact = CashTender.exact(25000);
    expect(exact.tenderedAmount, 25000);
    expect(exact.changeAmount, 0);

    final Sale pas = await checkout.checkout(
      cart: await cartWith(product),
      payments: [
        SalePaymentDraft(
          method: 'cash',
          amount: exact.amount,
          tenderedAmount: exact.tenderedAmount,
          changeAmount: exact.changeAmount,
        ),
      ],
    );
    expect(pas.payments.single.changeAmount, 0);

    final Product second = await addProduct(name: 'Es Teh', barcode: '8991');
    final CashTender excess = CashTender.fromTendered(
      total: 25000,
      tendered: 50000,
    );
    final Sale lebih = await checkout.checkout(
      cart: await cartWith(second),
      payments: [
        SalePaymentDraft(
          method: 'cash',
          amount: excess.amount,
          tenderedAmount: excess.tenderedAmount,
          changeAmount: excess.changeAmount,
        ),
      ],
    );
    expect(lebih.totalAmount, 25000);
    expect(lebih.payments.single.tenderedAmount, 50000);
    expect(lebih.payments.single.changeAmount, 25000);
  });

  test('tombol bayar dobel memakai client_uuid yang sama', () async {
    final Product product = await addProduct();
    final PosCart cart = await cartWith(product);
    final List<SalePaymentDraft> payments = const <SalePaymentDraft>[
      SalePaymentDraft(method: 'cash', amount: 25000, tenderedAmount: 25000),
    ];
    final List<Sale> results = await Future.wait<Sale>(<Future<Sale>>[
      checkout.checkout(cart: cart, payments: payments),
      checkout.checkout(cart: cart, payments: payments),
    ]);
    expect(results.first.id, results.last.id);
    expect(
      (await stock.getByProduct(
        businessId: businessId,
        productId: product.id,
      ))?.qty,
      9,
    );
    expect(await (await database.database).query('transactions'), hasLength(1));
  });

  test('penjualan offline masuk antrian sinkronisasi', () async {
    final Product product = await addProduct();
    await checkout.checkout(
      cart: await cartWith(product),
      payments: const <SalePaymentDraft>[
        SalePaymentDraft(method: 'qris', amount: 25000),
      ],
    );
    final jobs = await (await database.database).query(
      DatabaseConstants.tableSyncQueue,
    );
    expect(jobs, isNotEmpty);
    expect(
      jobs.where(
        (Map<String, Object?> row) => row['aggregate'] == 'transaction',
      ),
      hasLength(1),
    );
    expect(
      jobs.every((Map<String, Object?> row) => row['status'] == 'pending'),
      isTrue,
    );
  });

  test(
    'force close: keranjang pulih, penjualan selesai tidak diduplikasi',
    () async {
      final Product product = await addProduct();
      final PosCart saved = await cartWith(product);

      final SqlitePosCartRepository restarted = SqlitePosCartRepository(
        database: database,
        clock: clock,
      );
      final PosCart restored = await restarted.loadOrCreateOpen(
        businessId: businessId,
      );
      expect(restored.lines, hasLength(1));
      expect(restored.clientUuid, saved.clientUuid);

      await transactions.createCompletedSale(
        NewSale(
          businessId: businessId,
          clientUuid: saved.clientUuid,
          items: <SaleItemDraft>[SaleItemDraft(productId: product.id, qty: 1)],
          payments: const <SalePaymentDraft>[
            SalePaymentDraft(method: 'cash', amount: 25000),
          ],
        ),
      );

      final PosCart afterCrash = await checkout.restoreOpen(
        businessId: businessId,
      );
      expect(afterCrash.lines, isEmpty);
      expect(afterCrash.clientUuid, isNot(saved.clientUuid));
      expect(
        await (await database.database).query('transactions'),
        hasLength(1),
      );
    },
  );

  test('hold dan resume tidak memotong stok', () async {
    final Product product = await addProduct();
    final PosCart cart = await cartWith(product);
    await carts.hold(cart);
    expect(
      (await stock.getByProduct(
        businessId: businessId,
        productId: product.id,
      ))?.qty,
      10,
    );
    final List<PosCart> held = await carts.listHeld(businessId: businessId);
    expect(held, hasLength(1));
    final PosCart resumed = await carts.resume(
      id: held.single.id,
      businessId: businessId,
    );
    expect(resumed.lines.single.productId, product.id);
    expect(resumed.status, PosCartStatus.open);
  });

  test('kategori dan barcode dipakai katalog kasir', () async {
    final category = await categories.create(
      businessId: businessId,
      name: 'Minuman',
    );
    final Product drink = await addProduct(
      name: 'Es Teh',
      barcode: '899123',
      categoryId: category.id,
    );
    expect(
      (await products.findByBarcode(
        businessId: businessId,
        barcode: '899123',
      ))?.id,
      drink.id,
    );
    final listed = await products.listCatalog(
      businessId: businessId,
      categoryId: category.id,
      filter: ProductListFilter.active,
    );
    expect(listed.map((ProductCatalogItem item) => item.product.id), [
      drink.id,
    ]);
  });

  test('metode non-tunai tidak boleh punya kembalian', () async {
    final Product product = await addProduct();
    final PosCart cart = await cartWith(product);
    expect(
      () => checkout.checkout(
        cart: cart,
        payments: const <SalePaymentDraft>[
          SalePaymentDraft(
            method: 'transfer',
            amount: 25000,
            changeAmount: 1000,
          ),
        ],
      ),
      throwsA(isA<ValidationException>()),
    );
  });
}
