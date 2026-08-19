import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:kasir_dapur/features/inventory/data/stock_repository_impl.dart';
import 'package:kasir_dapur/features/inventory/domain/stock.dart';
import 'package:kasir_dapur/features/products/domain/catalog_csv.dart';
import 'package:kasir_dapur/features/products/domain/product.dart';
import 'package:kasir_dapur/features/products/domain/product_repository.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_status.dart';
import 'package:kasir_dapur/features/sync/data/sync_repository_impl.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

final class SqliteProductRepository implements ProductRepository {
  SqliteProductRepository({
    required this._database,
    required this._clock,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final ClockService _clock;
  final Uuid _uuid;

  @override
  Future<Product> create(NewProduct input) async {
    _assertName(input.name);
    _assertMoney(input.costPrice, 'HPP');
    _assertMoney(input.sellPrice, 'harga jual');
    if (input.minStock < 0) {
      throw const ValidationException('Minimum stok tidak boleh negatif');
    }
    if (input.initialStock < 0) {
      throw const ValidationException('Stok awal tidak boleh negatif');
    }
    await _assertProductQuota(input.businessId);

    final String id = _uuid.v4();
    final int now = _clock.nowEpochMs();
    final String? sku = _blankToNull(input.sku);
    final String? barcode = _blankToNull(input.barcode);
    await _database.runInTransaction((Transaction txn) async {
      await _assertUniqueCodes(
        txn,
        businessId: input.businessId,
        sku: sku,
        barcode: barcode,
      );
      await txn.insert(DatabaseConstants.tableProducts, <String, Object?>{
        'id': id,
        'business_id': input.businessId,
        'category_id': input.categoryId,
        'unit_id': input.unitId,
        'name': input.name.trim(),
        'sku': sku,
        'barcode': barcode,
        'cost_price': input.costPrice,
        'sell_price': input.sellPrice,
        'min_stock': input.minStock,
        'is_active': input.isActive ? 1 : 0,
        'image_path': input.imagePath,
        'description': _blankToNull(input.description),
        'created_at': now,
        'updated_at': now,
        'deleted_at': null,
      });
      await txn.insert(DatabaseConstants.tableStock, <String, Object>{
        'id': _uuid.v4(),
        'business_id': input.businessId,
        'product_id': id,
        'qty': 0,
        'created_at': now,
        'updated_at': now,
      });
      if (input.initialStock > 0) {
        await applyStockDelta(
          txn,
          clock: _clock,
          uuid: _uuid,
          businessId: input.businessId,
          productId: id,
          type: StockMovementType.stockIn,
          qtyDelta: input.initialStock,
          refType: 'product',
          refId: id,
          note: 'Stok awal',
        );
      }
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: input.businessId,
        aggregate: SyncAggregate.product,
        entityId: id,
      );
    });
    return (await getById(id))!;
  }

  @override
  Future<Product> update(Product product) async {
    _assertName(product.name);
    _assertMoney(product.costPrice, 'HPP');
    _assertMoney(product.sellPrice, 'harga jual');
    if (product.minStock < 0) {
      throw const ValidationException('Minimum stok tidak boleh negatif');
    }
    final String? sku = _blankToNull(product.sku);
    final String? barcode = _blankToNull(product.barcode);
    final int now = _clock.nowEpochMs();
    await _database.runInTransaction((Transaction txn) async {
      await _assertUniqueCodes(
        txn,
        businessId: product.businessId,
        sku: sku,
        barcode: barcode,
        excludeId: product.id,
      );
      final int changed = await txn.update(
        DatabaseConstants.tableProducts,
        <String, Object?>{
          'name': product.name.trim(),
          'category_id': product.categoryId,
          'unit_id': product.unitId,
          'sku': sku,
          'barcode': barcode,
          'cost_price': product.costPrice,
          'sell_price': product.sellPrice,
          'min_stock': product.minStock,
          'is_active': product.isActive ? 1 : 0,
          'image_path': product.imagePath,
          'description': _blankToNull(product.description),
          'updated_at': now,
        },
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object>[product.id],
      );
      if (changed == 0) {
        throw const NotFoundException('Produk tidak ditemukan');
      }
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: product.businessId,
        aggregate: SyncAggregate.product,
        entityId: product.id,
      );
    });
    return (await getById(product.id))!;
  }

  @override
  Future<Product?> getById(String id) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableProducts,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return mapProduct(rows.first);
  }

  @override
  Future<Product?> findByBarcode({
    required String businessId,
    required String barcode,
  }) async {
    final String trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final rows = await (await _database.database).query(
      DatabaseConstants.tableProducts,
      where: 'business_id = ? AND barcode = ? AND deleted_at IS NULL',
      whereArgs: <Object>[businessId, trimmed],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return mapProduct(rows.first);
  }

  @override
  Future<Product?> findBySku({
    required String businessId,
    required String sku,
  }) async {
    final String trimmed = sku.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final rows = await (await _database.database).query(
      DatabaseConstants.tableProducts,
      where: 'business_id = ? AND sku = ? AND deleted_at IS NULL',
      whereArgs: <Object>[businessId, trimmed],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return mapProduct(rows.first);
  }

  @override
  Future<List<Product>> search({
    required String businessId,
    String query = '',
  }) async {
    final String trimmed = query.trim();
    final rows = await (await _database.database).query(
      DatabaseConstants.tableProducts,
      where: trimmed.isEmpty ? 'business_id = ? AND deleted_at IS NULL' : 'business_id = ? AND deleted_at IS NULL AND (name LIKE ? OR sku LIKE ? OR barcode LIKE ?)',
      whereArgs: trimmed.isEmpty
          ? <Object>[businessId]
          : <Object>[businessId, '%$trimmed%', '%$trimmed%', '%$trimmed%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(mapProduct).toList();
  }

  @override
  Future<List<ProductCatalogItem>> listCatalog({
    required String businessId,
    String query = '',
    String? categoryId,
    ProductListFilter filter = ProductListFilter.available,
  }) async {
    final String trimmed = query.trim();
    final StringBuffer sql = StringBuffer('''
SELECT p.*,
       COALESCE(s.qty, 0) AS stock_qty,
       c.name AS category_name,
       u.name AS unit_name
FROM ${DatabaseConstants.tableProducts} p
LEFT JOIN ${DatabaseConstants.tableStock} s
  ON s.product_id = p.id AND s.business_id = p.business_id
LEFT JOIN ${DatabaseConstants.tableCategories} c ON c.id = p.category_id
LEFT JOIN ${DatabaseConstants.tableUnits} u ON u.id = p.unit_id
WHERE p.business_id = ?
''');
    final List<Object> args = <Object>[businessId];
    switch (filter) {
      case ProductListFilter.available:
        sql.write(' AND p.deleted_at IS NULL');
      case ProductListFilter.active:
        sql.write(' AND p.deleted_at IS NULL AND p.is_active = 1');
      case ProductListFilter.inactive:
        sql.write(' AND p.deleted_at IS NULL AND p.is_active = 0');
      case ProductListFilter.archived:
        sql.write(' AND p.deleted_at IS NOT NULL');
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      sql.write(' AND p.category_id = ?');
      args.add(categoryId);
    }
    if (trimmed.isNotEmpty) {
      sql.write(' AND (p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ?)');
      args
        ..add('%$trimmed%')
        ..add('%$trimmed%')
        ..add('%$trimmed%');
    }
    sql.write(' ORDER BY p.name COLLATE NOCASE ASC');
    final rows = await (await _database.database).rawQuery(
      sql.toString(),
      args,
    );
    return rows
        .map(
          (Map<String, Object?> row) => ProductCatalogItem(
            product: mapProduct(row),
            stockQty: readInt(row['stock_qty'], field: 'stock_qty'),
            categoryName: readStringOrNull(row['category_name']),
            unitName: readStringOrNull(row['unit_name']),
          ),
        )
        .toList();
  }

  @override
  Future<void> softDelete(String id) async {
    final int now = _clock.nowEpochMs();
    final int changed = await (await _database.database).update(
      DatabaseConstants.tableProducts,
      <String, Object>{'deleted_at': now, 'updated_at': now, 'is_active': 0},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: <Object>[id],
    );
    if (changed == 0) {
      throw const NotFoundException('Produk tidak ditemukan');
    }
  }

  @override
  Future<void> restore(String id) async {
    final Database db = await _database.database;
    final rows = await db.query(
      DatabaseConstants.tableProducts,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const NotFoundException('Produk tidak ditemukan');
    }
    final Product product = mapProduct(rows.first);
    if (product.deletedAt == null) {
      return;
    }
    await _database.runInTransaction((Transaction txn) async {
      await _assertUniqueCodes(
        txn,
        businessId: product.businessId,
        sku: product.sku,
        barcode: product.barcode,
        excludeId: id,
      );
      final int now = _clock.nowEpochMs();
      await txn.update(
        DatabaseConstants.tableProducts,
        <String, Object?>{
          'deleted_at': null,
          'is_active': 1,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: <Object>[id],
      );
    });
  }

  @override
  Future<bool> hasTransactionHistory(String id) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableTransactionItems,
      columns: <String>['id'],
      where: 'product_id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> setStock({
    required String productId,
    required String businessId,
    required int qty,
  }) {
    if (qty < 0) {
      throw const ValidationException('Stok tidak boleh negatif');
    }
    return _database.runInTransaction((Transaction txn) async {
      final rows = await txn.query(
        DatabaseConstants.tableStock,
        where: 'business_id = ? AND product_id = ?',
        whereArgs: <Object>[businessId, productId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const NotFoundException('Stok produk tidak ditemukan');
      }
      final int current = readInt(rows.first['qty'], field: 'qty');
      final int delta = qty - current;
      if (delta == 0) {
        return;
      }
      await applyStockDelta(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: businessId,
        productId: productId,
        type: StockMovementType.adjustment,
        qtyDelta: delta,
        note: 'Set stok',
      );
    });
  }

  @override
  Future<CatalogImportResult> importCsv({
    required String businessId,
    required String csv,
  }) async {
    final List<CatalogCsvRow> rows = CatalogCsv.parse(csv);
    var created = 0;
    var updated = 0;
    var skipped = 0;
    final List<String> errors = [];
    for (final CatalogCsvRow row in rows) {
      try {
        if (row.name.trim().isEmpty) {
          skipped += 1;
          errors.add('Baris ${row.sourceLine}: nama wajib');
          continue;
        }
        if (row.costPrice < 0 || row.sellPrice < 0) {
          skipped += 1;
          errors.add('Baris ${row.sourceLine}: HPP/harga tidak boleh negatif');
          continue;
        }
        final String? sku = _blankToNull(row.sku);
        Product? existing;
        if (sku != null) {
          existing = await findBySku(businessId: businessId, sku: sku);
        }
        final String? categoryId = await _ensureNamed(
          table: DatabaseConstants.tableCategories,
          businessId: businessId,
          name: row.categoryName,
        );
        final String? unitId = await _ensureNamed(
          table: DatabaseConstants.tableUnits,
          businessId: businessId,
          name: row.unitName,
        );
        if (existing == null) {
          await create(
            NewProduct(
              businessId: businessId,
              name: row.name,
              sku: sku,
              barcode: row.barcode,
              categoryId: categoryId,
              unitId: unitId,
              costPrice: row.costPrice,
              sellPrice: row.sellPrice,
              minStock: row.minStock < 0 ? 0 : row.minStock,
              initialStock: row.stockQty < 0 ? 0 : row.stockQty,
              isActive: row.isActive,
              description: row.description,
            ),
          );
          created += 1;
        } else {
          await update(
            existing.copyWith(
              name: row.name.trim(),
              categoryId: categoryId,
              unitId: unitId,
              sku: sku,
              barcode: _blankToNull(row.barcode),
              costPrice: row.costPrice,
              sellPrice: row.sellPrice,
              minStock: row.minStock < 0 ? 0 : row.minStock,
              isActive: row.isActive,
              description: row.description,
              clearCategory: categoryId == null,
              clearUnit: unitId == null,
              clearBarcode: _blankToNull(row.barcode) == null,
              clearDescription: _blankToNull(row.description) == null,
            ),
          );
          await setStock(
            productId: existing.id,
            businessId: businessId,
            qty: row.stockQty < 0 ? 0 : row.stockQty,
          );
          updated += 1;
        }
      } on AppException catch (error) {
        skipped += 1;
        errors.add('Baris ${row.sourceLine}: ${error.message}');
      }
    }
    return CatalogImportResult(
      created: created,
      updated: updated,
      skipped: skipped,
      errors: errors,
    );
  }

  @override
  Future<String> exportCsv({required String businessId}) async {
    final List<ProductCatalogItem> items = await listCatalog(
      businessId: businessId,
    );
    return CatalogCsv.export(
      items
          .map(
            (ProductCatalogItem item) => CatalogCsvRow(
              sku: item.product.sku,
              barcode: item.product.barcode,
              name: item.product.name,
              categoryName: item.categoryName,
              unitName: item.unitName,
              costPrice: item.product.costPrice,
              sellPrice: item.product.sellPrice,
              stockQty: item.stockQty,
              minStock: item.product.minStock,
              description: item.product.description,
              isActive: item.product.isActive,
              sourceLine: 0,
            ),
          )
          .toList(),
    );
  }

  static Product mapProduct(Map<String, Object?> row) {
    return Product(
      id: readString(row['id'], field: 'id'),
      businessId: readString(row['business_id'], field: 'business_id'),
      name: readString(row['name'], field: 'name'),
      categoryId: readStringOrNull(row['category_id']),
      unitId: readStringOrNull(row['unit_id']),
      sku: readStringOrNull(row['sku']),
      barcode: readStringOrNull(row['barcode']),
      costPrice: readMoney(row['cost_price'], field: 'cost_price'),
      sellPrice: readMoney(row['sell_price'], field: 'sell_price'),
      minStock: readInt(row['min_stock'], field: 'min_stock'),
      isActive: readBoolInt(row['is_active'], field: 'is_active'),
      imagePath: readStringOrNull(row['image_path']),
      description: readStringOrNull(row['description']),
      createdAt: readInt(row['created_at'], field: 'created_at'),
      updatedAt: readInt(row['updated_at'], field: 'updated_at'),
      deletedAt: readIntOrNull(row['deleted_at']),
    );
  }

  Future<void> _assertUniqueCodes(
    DatabaseExecutor db, {
    required String businessId,
    String? sku,
    String? barcode,
    String? excludeId,
  }) async {
    if (sku != null) {
      final String where = excludeId == null
          ? 'business_id = ? AND sku = ? AND deleted_at IS NULL'
          : 'business_id = ? AND sku = ? AND deleted_at IS NULL AND id != ?';
      final List<Object> args = excludeId == null
          ? <Object>[businessId, sku]
          : <Object>[businessId, sku, excludeId];
      final rows = await db.query(
        DatabaseConstants.tableProducts,
        columns: <String>['id'],
        where: where,
        whereArgs: args,
        limit: 1,
      );
      if (rows.isNotEmpty) {
        throw const ConflictException('SKU sudah dipakai produk lain');
      }
    }
    if (barcode != null) {
      final String where = excludeId == null
          ? 'business_id = ? AND barcode = ? AND deleted_at IS NULL'
          : 'business_id = ? AND barcode = ? AND deleted_at IS NULL AND id != ?';
      final List<Object> args = excludeId == null
          ? <Object>[businessId, barcode]
          : <Object>[businessId, barcode, excludeId];
      final rows = await db.query(
        DatabaseConstants.tableProducts,
        columns: <String>['id'],
        where: where,
        whereArgs: args,
        limit: 1,
      );
      if (rows.isNotEmpty) {
        throw const ConflictException('Barcode sudah dipakai produk lain');
      }
    }
  }

  Future<String?> _ensureNamed({
    required String table,
    required String businessId,
    required String? name,
  }) async {
    final String? trimmed = _blankToNull(name);
    if (trimmed == null) {
      return null;
    }
    final Database db = await _database.database;
    final rows = await db.query(
      table,
      columns: <String>['id'],
      where: 'business_id = ? AND name = ? AND deleted_at IS NULL',
      whereArgs: <Object>[businessId, trimmed],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return rows.first['id'] as String;
    }
    final String id = _uuid.v4();
    final int now = _clock.nowEpochMs();
    await db.insert(table, <String, Object?>{
      'id': id,
      'business_id': businessId,
      'name': trimmed,
      if (table == DatabaseConstants.tableUnits) 'symbol': null,
      'created_at': now,
      'updated_at': now,
      'deleted_at': null,
    });
    return id;
  }

  Future<void> _assertProductQuota(String businessId) async {
    final Database db = await _database.database;
    final entitlementRows = await db.query(
      DatabaseConstants.tableEntitlements,
      where: 'business_id = ?',
      whereArgs: <Object>[businessId],
    );
    final subscriptionRows = await db.query(
      DatabaseConstants.tableSubscriptions,
      where:
          'business_id = ? AND status IN (${SubscriptionStatus.entitledSql})',
      whereArgs: <Object>[businessId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    final Plan plan = subscriptionRows.isEmpty
        ? Plan.free
        : Plan.parse(subscriptionRows.first['plan']! as String);
    final FeatureGate gate = FeatureGate.fromEntitlements(
      entitlementRows.map(
        (Map<String, Object?> row) => Entitlement(
          id: row['id']! as String,
          businessId: businessId,
          featureKey: row['feature_key']! as String,
          isEnabled: (row['is_enabled'] as int?) == 1,
          limitValue: row['limit_value'] as int? ?? 0,
        ),
      ),
      plan: plan,
    );
    final countRows = await db.rawQuery(
      '''
SELECT CAST(COUNT(*) AS INTEGER) AS value
FROM ${DatabaseConstants.tableProducts}
WHERE business_id = ? AND deleted_at IS NULL
''',
      <Object>[businessId],
    );
    final Object? raw = countRows.first['value'];
    final int used = raw is int ? raw : 0;
    gate.requireWithinLimit(FeatureKey.maxProducts, used);
  }

  void _assertName(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Nama produk wajib diisi');
    }
    if (trimmed.length > 120) {
      throw const ValidationException('Nama produk maksimal 120 karakter');
    }
  }

  void _assertMoney(int amount, String label) {
    if (amount < 0) {
      throw ValidationException('$label tidak boleh negatif');
    }
  }

  String? _blankToNull(String? value) {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
