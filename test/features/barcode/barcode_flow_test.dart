import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/features/barcode/domain/barcode_code.dart';
import 'package:kasir_dapur/features/barcode/domain/barcode_lookup_service.dart';
import 'package:kasir_dapur/features/cashier/data/pos_cart_repository_impl.dart';
import 'package:kasir_dapur/features/cashier/domain/pos_cart.dart';
import 'package:kasir_dapur/features/products/data/product_repository_impl.dart';
import 'package:kasir_dapur/features/products/domain/product.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/pos_fixture.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late SqliteProductRepository products;
  late SqlitePosCartRepository carts;
  late BarcodeLookupService lookup;
  late String businessId;
  const ClockService clock = ClockService();

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_barcode_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(tempDir.path, 'kasir_dapur.db'),
    );
    products = SqliteProductRepository(database: database, clock: clock);
    carts = SqlitePosCartRepository(database: database, clock: clock);
    lookup = BarcodeLookupService(products: products);
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
    String? barcode,
    String? sku,
    int price = 5000,
  }) {
    return products.create(
      NewProduct(
        businessId: businessId,
        name: name,
        barcode: barcode,
        sku: sku,
        sellPrice: price,
        initialStock: 5,
      ),
    );
  }

  test('scan EAN-13 menemukan produk lalu masuk keranjang', () async {
    final Product tea = await addProduct(
      name: 'Es Teh',
      barcode: '8991002100004',
    );
    final BarcodeLookupResult result = await lookup.lookup(
      businessId: businessId,
      raw: '8991002100004',
      symbology: BarcodeSymbology.ean13,
    );
    expect(result.found, isTrue);
    expect(result.product?.id, tea.id);

    PosCart cart = await carts.loadOrCreateOpen(businessId: businessId);
    cart = cart.addOrIncrement(
      CartLine(
        productId: tea.id,
        name: tea.name,
        unitPrice: tea.sellPrice,
        costPrice: tea.costPrice,
        qty: 1,
        barcode: tea.barcode,
      ),
    );
    cart = await carts.save(cart);
    expect(cart.lines.single.productId, tea.id);
    expect(cart.lines.single.qty, 1);
  });

  test('UPC-A menemukan produk yang tersimpan sebagai EAN-13', () async {
    await addProduct(name: 'Gula', barcode: '0123456789051');
    final BarcodeLookupResult result = await lookup.lookup(
      businessId: businessId,
      raw: '123456789051',
      symbology: BarcodeSymbology.upcA,
    );
    expect(result.found, isTrue);
    expect(result.product?.name, 'Gula');
  });

  test('Code 128 / QR relevan mencari SKU jika barcode kosong', () async {
    await addProduct(name: 'Kopi', sku: 'KD-KOPI-01');
    final BarcodeLookupResult result = await lookup.lookup(
      businessId: businessId,
      raw: 'KD-KOPI-01',
      symbology: BarcodeSymbology.code128,
    );
    expect(result.found, isTrue);
    expect(result.product?.name, 'Kopi');
  });

  test(
    'barcode tidak ditemukan siap untuk pilihan tambah/cari/batal',
    () async {
      final BarcodeLookupResult result = await lookup.lookup(
        businessId: businessId,
        raw: '8990000000000',
      );
      expect(result.found, isFalse);
      expect(result.displayCode, '8990000000000');
    },
  );

  test('barcode kosong tidak melempar', () async {
    final BarcodeLookupResult result = await lookup.lookup(
      businessId: businessId,
      raw: '  ',
    );
    expect(result.found, isFalse);
  });
}
