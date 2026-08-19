import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:kasir_dapur/features/inventory/domain/stock.dart';
import 'package:kasir_dapur/features/inventory/domain/stock_repository.dart';
import 'package:kasir_dapur/features/sync/data/sync_repository_impl.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

Future<bool> readAllowNegativeStock(
  DatabaseExecutor executor,
  String businessId,
) async {
  final rows = await executor.query(
    DatabaseConstants.tableBusinessSettings,
    columns: <String>['allow_negative_stock'],
    where: 'business_id = ?',
    whereArgs: <Object>[businessId],
    limit: 1,
  );
  if (rows.isEmpty) {
    return false;
  }
  final Object? value = rows.first['allow_negative_stock'];
  if (value == null) {
    return false;
  }
  return readInt(value, field: 'allow_negative_stock') == 1;
}

void assertStockDelta(StockMovementType type, int qtyDelta) {
  if (qtyDelta == 0) {
    throw const ValidationException('Perubahan stok tidak boleh nol');
  }
  switch (type) {
    case StockMovementType.stockIn:
    case StockMovementType.purchase:
    case StockMovementType.saleReturn:
      if (qtyDelta < 0) {
        throw ValidationException('${type.label} harus menambah stok');
      }
    case StockMovementType.stockOut:
    case StockMovementType.sale:
    case StockMovementType.damaged:
    case StockMovementType.expired:
      if (qtyDelta > 0) {
        throw ValidationException('${type.label} harus mengurangi stok');
      }
    case StockMovementType.adjustment:
    case StockMovementType.transfer:
      break;
  }
}

Future<StockBalance> applyStockDelta(
  DatabaseExecutor executor, {
  required ClockService clock,
  required Uuid uuid,
  required String businessId,
  required String productId,
  required StockMovementType type,
  required int qtyDelta,
  String? refType,
  String? refId,
  String? note,
}) async {
  assertStockDelta(type, qtyDelta);
  final rows = await executor.query(
    DatabaseConstants.tableStock,
    where: 'business_id = ? AND product_id = ?',
    whereArgs: <Object>[businessId, productId],
    limit: 1,
  );
  if (rows.isEmpty) {
    throw const NotFoundException('Stok produk tidak ditemukan');
  }
  final Map<String, Object?> row = rows.first;
  final int qtyBefore = readInt(row['qty'], field: 'qty');
  final int qtyAfter = qtyBefore + qtyDelta;
  final bool allowNegative = await readAllowNegativeStock(executor, businessId);
  if (qtyAfter < 0 && !allowNegative) {
    throw const InsufficientStockException();
  }
  final int now = clock.nowEpochMs();
  final String stockId = readString(row['id'], field: 'id');
  final int changed = await executor.update(
    DatabaseConstants.tableStock,
    <String, Object>{'qty': qtyAfter, 'updated_at': now},
    where: 'id = ? AND qty = ?',
    whereArgs: <Object>[stockId, qtyBefore],
  );
  if (changed == 0) {
    throw const ConflictException(
      'Stok berubah oleh proses lain. Silakan coba lagi.',
    );
  }
  final String movementId = uuid.v4();
  await executor.insert(
    DatabaseConstants.tableStockMovements,
    <String, Object?>{
      'id': movementId,
      'business_id': businessId,
      'product_id': productId,
      'type': type.storageValue,
      'qty': qtyDelta,
      'qty_before': qtyBefore,
      'qty_after': qtyAfter,
      'ref_type': refType,
      'ref_id': refId,
      'note': note,
      'created_at': now,
      'updated_at': now,
    },
  );
  await enqueueEntity(
    executor,
    clock: clock,
    uuid: uuid,
    businessId: businessId,
    aggregate: SyncAggregate.stockMovement,
    entityId: movementId,
  );
  await enqueueEntity(
    executor,
    clock: clock,
    uuid: uuid,
    businessId: businessId,
    aggregate: SyncAggregate.inventory,
    entityId: productId,
  );
  return StockBalance(
    id: stockId,
    businessId: businessId,
    productId: productId,
    qty: qtyAfter,
    createdAt: readInt(row['created_at'], field: 'created_at'),
    updatedAt: now,
  );
}

StockMovement mapStockMovement(
  Map<String, Object?> row, {
  String? productName,
}) {
  return StockMovement(
    id: readString(row['id'], field: 'id'),
    businessId: readString(row['business_id'], field: 'business_id'),
    productId: readString(row['product_id'], field: 'product_id'),
    type: readString(row['type'], field: 'type'),
    qty: readInt(row['qty'], field: 'qty'),
    qtyBefore: readInt(row['qty_before'], field: 'qty_before'),
    qtyAfter: readInt(row['qty_after'], field: 'qty_after'),
    refType: readStringOrNull(row['ref_type']),
    refId: readStringOrNull(row['ref_id']),
    note: readStringOrNull(row['note']),
    createdAt: readInt(row['created_at'], field: 'created_at'),
    productName: productName ?? readStringOrNull(row['product_name']),
  );
}

final class SqliteStockRepository implements StockRepository {
  SqliteStockRepository({
    required this._database,
    required this._clock,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final ClockService _clock;
  final Uuid _uuid;

  @override
  Future<StockBalance?> getByProduct({
    required String businessId,
    required String productId,
  }) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableStock,
      where: 'business_id = ? AND product_id = ?',
      whereArgs: <Object>[businessId, productId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final Map<String, Object?> row = rows.first;
    return StockBalance(
      id: readString(row['id'], field: 'id'),
      businessId: readString(row['business_id'], field: 'business_id'),
      productId: readString(row['product_id'], field: 'product_id'),
      qty: readInt(row['qty'], field: 'qty'),
      createdAt: readInt(row['created_at'], field: 'created_at'),
      updatedAt: readInt(row['updated_at'], field: 'updated_at'),
    );
  }

  @override
  Future<StockBalance> applyMovement({
    required String businessId,
    required String productId,
    required StockMovementType type,
    required int qtyDelta,
    String? refType,
    String? refId,
    String? note,
  }) {
    return _database.runInTransaction((Transaction txn) {
      return applyStockDelta(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: businessId,
        productId: productId,
        type: type,
        qtyDelta: qtyDelta,
        refType: refType,
        refId: refId,
        note: note,
      );
    });
  }

  @override
  Future<StockBalance> stockIn({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
    String? refType,
    String? refId,
  }) {
    _assertPositiveQty(qty);
    return applyMovement(
      businessId: businessId,
      productId: productId,
      type: StockMovementType.stockIn,
      qtyDelta: qty,
      note: note,
      refType: refType,
      refId: refId,
    );
  }

  @override
  Future<StockBalance> stockOut({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
    String? refType,
    String? refId,
  }) {
    _assertPositiveQty(qty);
    return applyMovement(
      businessId: businessId,
      productId: productId,
      type: StockMovementType.stockOut,
      qtyDelta: -qty,
      note: note,
      refType: refType,
      refId: refId,
    );
  }

  @override
  Future<StockBalance> purchase({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
  }) {
    _assertPositiveQty(qty);
    return applyMovement(
      businessId: businessId,
      productId: productId,
      type: StockMovementType.purchase,
      qtyDelta: qty,
      note: note,
      refType: 'purchase',
    );
  }

  @override
  Future<StockBalance> saleReturn({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
    String? refType,
    String? refId,
  }) {
    _assertPositiveQty(qty);
    return applyMovement(
      businessId: businessId,
      productId: productId,
      type: StockMovementType.saleReturn,
      qtyDelta: qty,
      note: note,
      refType: refType ?? 'sale_return',
      refId: refId,
    );
  }

  @override
  Future<StockBalance> recordDamaged({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
  }) {
    _assertPositiveQty(qty);
    return applyMovement(
      businessId: businessId,
      productId: productId,
      type: StockMovementType.damaged,
      qtyDelta: -qty,
      note: note,
    );
  }

  @override
  Future<StockBalance> recordExpired({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
  }) {
    _assertPositiveQty(qty);
    return applyMovement(
      businessId: businessId,
      productId: productId,
      type: StockMovementType.expired,
      qtyDelta: -qty,
      note: note,
    );
  }

  @override
  Future<StockBalance> transfer({
    required String businessId,
    required String productId,
    required int qtyDelta,
    String? note,
  }) {
    return applyMovement(
      businessId: businessId,
      productId: productId,
      type: StockMovementType.transfer,
      qtyDelta: qtyDelta,
      note: note,
      refType: 'transfer',
    );
  }

  @override
  Future<StockBalance> adjustTo({
    required String businessId,
    required String productId,
    required int countedQty,
    String? note,
  }) {
    if (countedQty < 0) {
      throw const ValidationException('Stok fisik tidak boleh negatif');
    }
    return _database.runInTransaction((Transaction txn) {
      return _adjustTo(
        txn,
        businessId: businessId,
        productId: productId,
        countedQty: countedQty,
        note: note ?? 'Penyesuaian stok',
      );
    });
  }

  @override
  Future<List<StockMovement>> listMovements({
    required String businessId,
    required String productId,
  }) {
    return listHistory(
      businessId: businessId,
      productId: productId,
      limit: 500,
    );
  }

  @override
  Future<List<StockMovement>> listHistory({
    required String businessId,
    String? productId,
    StockMovementType? type,
    int limit = 200,
  }) async {
    final StringBuffer sql = StringBuffer('''
SELECT m.*, p.name AS product_name
FROM ${DatabaseConstants.tableStockMovements} m
INNER JOIN ${DatabaseConstants.tableProducts} p ON p.id = m.product_id
WHERE m.business_id = ?
''');
    final List<Object> args = <Object>[businessId];
    if (productId != null) {
      sql.write(' AND m.product_id = ?');
      args.add(productId);
    }
    if (type != null) {
      sql.write(' AND m.type = ?');
      args.add(type.storageValue);
    }
    sql.write(' ORDER BY m.created_at DESC, m.id DESC LIMIT ?');
    args.add(limit);
    final rows = await (await _database.database).rawQuery(
      sql.toString(),
      args,
    );
    return rows.map(mapStockMovement).toList();
  }

  @override
  Future<List<StockPosition>> listPositions({
    required String businessId,
    String query = '',
    bool lowStockOnly = false,
  }) async {
    final String trimmed = query.trim();
    final StringBuffer sql = StringBuffer('''
SELECT p.id AS product_id,
       p.business_id AS business_id,
       p.name AS name,
       p.sku AS sku,
       p.barcode AS barcode,
       COALESCE(s.qty, 0) AS qty,
       p.min_stock AS min_stock,
       p.is_active AS is_active
FROM ${DatabaseConstants.tableProducts} p
LEFT JOIN ${DatabaseConstants.tableStock} s
  ON s.product_id = p.id AND s.business_id = p.business_id
WHERE p.business_id = ?
  AND p.deleted_at IS NULL
''');
    final List<Object> args = <Object>[businessId];
    if (trimmed.isNotEmpty) {
      sql.write(' AND (p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ?)');
      args
        ..add('%$trimmed%')
        ..add('%$trimmed%')
        ..add('%$trimmed%');
    }
    if (lowStockOnly) {
      sql.write(' AND p.min_stock > 0 AND COALESCE(s.qty, 0) <= p.min_stock');
    }
    sql.write(' ORDER BY p.name COLLATE NOCASE ASC');
    final rows = await (await _database.database).rawQuery(
      sql.toString(),
      args,
    );
    return rows.map(_mapPosition).toList();
  }

  @override
  Future<List<StockPosition>> listLowStock({required String businessId}) {
    return listPositions(businessId: businessId, lowStockOnly: true);
  }

  @override
  Future<StockOpnameResult> commitOpname({
    required String businessId,
    required List<StockOpnameLine> lines,
    String? note,
  }) {
    if (lines.isEmpty) {
      throw const ValidationException('Tidak ada item stock opname');
    }
    return _database.runInTransaction((Transaction txn) async {
      var adjusted = 0;
      var unchanged = 0;
      for (final StockOpnameLine line in lines) {
        if (line.countedQty < 0) {
          throw const ValidationException('Stok fisik tidak boleh negatif');
        }
        final StockBalance? current = await _balanceOn(
          txn,
          businessId: businessId,
          productId: line.productId,
        );
        if (current == null) {
          throw const NotFoundException('Stok produk tidak ditemukan');
        }
        final int delta = line.countedQty - current.qty;
        if (delta == 0) {
          unchanged += 1;
          continue;
        }
        await applyStockDelta(
          txn,
          clock: _clock,
          uuid: _uuid,
          businessId: businessId,
          productId: line.productId,
          type: StockMovementType.adjustment,
          qtyDelta: delta,
          refType: 'opname',
          note: note ?? 'Stock opname',
        );
        adjusted += 1;
      }
      return StockOpnameResult(
        adjustedCount: adjusted,
        unchangedCount: unchanged,
      );
    });
  }

  @override
  Future<bool> allowNegativeStock(String businessId) async {
    return readAllowNegativeStock(await _database.database, businessId);
  }

  @override
  Future<void> setAllowNegativeStock({
    required String businessId,
    required bool allow,
  }) async {
    final Database db = await _database.database;
    final int now = _clock.nowEpochMs();
    final int flag = allow ? 1 : 0;
    await db.execute(
      '''
INSERT INTO ${DatabaseConstants.tableBusinessSettings} (
  id, business_id, currency_code, allow_negative_stock, created_at, updated_at
) VALUES (?, ?, 'IDR', ?, ?, ?)
ON CONFLICT(business_id) DO UPDATE SET
  allow_negative_stock = excluded.allow_negative_stock,
  updated_at = excluded.updated_at
''',
      <Object>[_uuid.v4(), businessId, flag, now, now],
    );
  }

  Future<StockBalance> _adjustTo(
    DatabaseExecutor executor, {
    required String businessId,
    required String productId,
    required int countedQty,
    required String note,
  }) async {
    final StockBalance? current = await _balanceOn(
      executor,
      businessId: businessId,
      productId: productId,
    );
    if (current == null) {
      throw const NotFoundException('Stok produk tidak ditemukan');
    }
    final int delta = countedQty - current.qty;
    if (delta == 0) {
      return current;
    }
    return applyStockDelta(
      executor,
      clock: _clock,
      uuid: _uuid,
      businessId: businessId,
      productId: productId,
      type: StockMovementType.adjustment,
      qtyDelta: delta,
      refType: 'opname',
      note: note,
    );
  }

  Future<StockBalance?> _balanceOn(
    DatabaseExecutor executor, {
    required String businessId,
    required String productId,
  }) async {
    final rows = await executor.query(
      DatabaseConstants.tableStock,
      where: 'business_id = ? AND product_id = ?',
      whereArgs: <Object>[businessId, productId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final Map<String, Object?> row = rows.first;
    return StockBalance(
      id: readString(row['id'], field: 'id'),
      businessId: businessId,
      productId: productId,
      qty: readInt(row['qty'], field: 'qty'),
      createdAt: readInt(row['created_at'], field: 'created_at'),
      updatedAt: readInt(row['updated_at'], field: 'updated_at'),
    );
  }

  StockPosition _mapPosition(Map<String, Object?> row) {
    return StockPosition(
      productId: readString(row['product_id'], field: 'product_id'),
      businessId: readString(row['business_id'], field: 'business_id'),
      name: readString(row['name'], field: 'name'),
      sku: readStringOrNull(row['sku']),
      barcode: readStringOrNull(row['barcode']),
      qty: readInt(row['qty'], field: 'qty'),
      minStock: readInt(row['min_stock'], field: 'min_stock'),
      isActive: readBoolInt(row['is_active'], field: 'is_active'),
    );
  }

  void _assertPositiveQty(int qty) {
    if (qty <= 0) {
      throw const ValidationException('Kuantitas harus lebih dari 0');
    }
  }
}
