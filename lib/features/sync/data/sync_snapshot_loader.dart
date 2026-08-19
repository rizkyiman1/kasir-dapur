import 'dart:convert';

import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:sqflite/sqflite.dart';

/// Membaca SQLite saat flush. Antrian hanya menyimpan id, bukan salinan hidup.
final class SyncSnapshotLoader {
  SyncSnapshotLoader(this._database);

  final AppDatabase _database;

  Future<Map<String, Object?>> load(SyncJob job) async {
    final Map<String, Object?> envelope = _decode(job.payload);
    final String? id = envelope['id'] as String?;
    final Database db = await _database.database;
    return switch (job.aggregate) {
      'business' => _business(db, id),
      'user_account' => _users(db, job.businessId),
      'product' => _product(db, id),
      'inventory' => _inventory(db, id, job.businessId),
      'transaction' => _transaction(db, id),
      'stock_movement' => _movement(db, id),
      'expense' => _expense(db, id),
      'customer' => _customer(db, id),
      'supplier' => _supplier(db, id),
      'cash_session' => _cashSession(db, id),
      'cash_movement' => _cashMovement(db, id),
      'category' => _category(db, id, job.businessId),
      'settings' => _settings(db, job.businessId),
      'subscription_meta' => _subscriptionMeta(db, job.businessId),
      'daily_report' => _dailyReport(db, job.businessId, envelope),
      _ => envelope,
    };
  }

  Future<Map<String, Object?>> _business(Database db, String? id) async {
    if (id == null || id.isEmpty) {
      return <String, Object?>{};
    }
    final rows = await db.query(
      DatabaseConstants.tableBusinesses,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return <String, Object?>{'id': id, 'missing': 1};
    }
    return Map<String, Object?>.from(rows.first);
  }

  Future<Map<String, Object?>> _users(Database db, String businessId) async {
    final rows = await db.query(DatabaseConstants.tableLocalUsers);
    return <String, Object?>{
      'business_id': businessId,
      'rows': rows
          .map(
            (Map<String, Object?> row) => <String, Object?>{
              'id': row['id'],
              'display_name': row['display_name'],
              'role': row['role'],
              'created_at': row['created_at'],
              'updated_at': row['updated_at'],
            },
          )
          .toList(),
    };
  }

  Map<String, Object?> _decode(String payload) {
    final Object decoded = jsonDecode(payload) as Object;
    if (decoded is Map) {
      return decoded.map(
        (Object? key, Object? value) =>
            MapEntry<String, Object?>(key.toString(), value),
      );
    }
    return <String, Object?>{'raw': payload};
  }

  Future<Map<String, Object?>> _product(Database db, String? id) async {
    if (id == null) {
      return <String, Object?>{};
    }
    final rows = await db.query(
      DatabaseConstants.tableProducts,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return <String, Object?>{'id': id, 'missing': 1};
    }
    final Map<String, Object?> row = rows.first;
    return <String, Object?>{
      'id': row['id'],
      'business_id': row['business_id'],
      'name': row['name'],
      'sku': row['sku'],
      'barcode': row['barcode'],
      'cost_price': row['cost_price'],
      'sell_price': row['sell_price'],
      'min_stock': row['min_stock'],
      'is_active': row['is_active'],
      'updated_at': row['updated_at'],
    };
  }

  Future<Map<String, Object?>> _transaction(Database db, String? id) async {
    if (id == null) {
      return <String, Object?>{};
    }
    final headers = await db.query(
      DatabaseConstants.tableTransactions,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (headers.isEmpty) {
      return <String, Object?>{'id': id, 'missing': 1};
    }
    final Map<String, Object?> header = headers.first;
    final items = await db.query(
      DatabaseConstants.tableTransactionItems,
      where: 'transaction_id = ?',
      whereArgs: <Object>[id],
    );
    return <String, Object?>{
      'id': header['id'],
      'business_id': header['business_id'],
      'client_uuid': header['client_uuid'],
      'status': header['status'],
      'subtotal_amount': header['subtotal_amount'],
      'discount_amount': header['discount_amount'],
      'tax_amount': header['tax_amount'],
      'total_amount': header['total_amount'],
      'user_id': header['user_id'],
      'customer_id': header['customer_id'],
      'created_at': header['created_at'],
      'items': items
          .map(
            (Map<String, Object?> row) => <String, Object?>{
              'id': row['id'],
              'transaction_id': row['transaction_id'],
              'product_id': row['product_id'],
              'name_snapshot': row['name_snapshot'],
              'qty': row['qty'],
              'unit_price': row['unit_price'],
              'cost_price': row['cost_price'],
              'discount_amount': row['discount_amount'],
              'line_total': row['line_total'],
            },
          )
          .toList(),
    };
  }

  Future<Map<String, Object?>> _movement(Database db, String? id) async {
    if (id == null) {
      return <String, Object?>{};
    }
    final rows = await db.query(
      DatabaseConstants.tableStockMovements,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return <String, Object?>{'id': id, 'missing': 1};
    }
    final Map<String, Object?> row = rows.first;
    return <String, Object?>{
      'id': row['id'],
      'business_id': row['business_id'],
      'product_id': row['product_id'],
      'type': row['type'],
      'qty': row['qty'],
      'qty_before': row['qty_before'],
      'qty_after': row['qty_after'],
      'ref_type': row['ref_type'],
      'ref_id': row['ref_id'],
      'created_at': row['created_at'],
    };
  }

  Future<Map<String, Object?>> _inventory(
    Database db,
    String? productId,
    String businessId,
  ) async {
    if (productId == null || productId.isEmpty) {
      return <String, Object?>{};
    }
    final rows = await db.rawQuery(
      '''
SELECT s.id, s.business_id, s.product_id, s.qty, s.updated_at, p.name AS product_name
FROM ${DatabaseConstants.tableStock} s
LEFT JOIN ${DatabaseConstants.tableProducts} p ON p.id = s.product_id
WHERE s.business_id = ? AND s.product_id = ?
LIMIT 1
''',
      <Object>[businessId, productId],
    );
    if (rows.isEmpty) {
      return <String, Object?>{'id': productId, 'missing': 1};
    }
    return Map<String, Object?>.from(rows.first);
  }

  Future<Map<String, Object?>> _expense(Database db, String? id) async {
    if (id == null) {
      return <String, Object?>{};
    }
    final rows = await db.query(
      DatabaseConstants.tableExpenses,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return <String, Object?>{'id': id, 'missing': 1};
    }
    final Map<String, Object?> row = rows.first;
    return <String, Object?>{
      'id': row['id'],
      'business_id': row['business_id'],
      'amount': row['amount'],
      'note': row['note'],
      'spent_at': row['spent_at'],
      'category_id': row['category_id'],
    };
  }

  Future<Map<String, Object?>> _customer(Database db, String? id) async {
    if (id == null) {
      return <String, Object?>{};
    }
    final rows = await db.query(
      DatabaseConstants.tableCustomers,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return <String, Object?>{'id': id, 'missing': 1};
    }
    final Map<String, Object?> row = rows.first;
    return <String, Object?>{
      'id': row['id'],
      'business_id': row['business_id'],
      'name': row['name'],
      'phone': row['phone'],
      'email': row['email'],
      'address': row['address'],
    };
  }

  Future<Map<String, Object?>> _supplier(Database db, String? id) async {
    if (id == null || id.isEmpty) {
      return <String, Object?>{};
    }
    final rows = await db.query(
      DatabaseConstants.tableSuppliers,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return <String, Object?>{'id': id, 'missing': 1};
    }
    return Map<String, Object?>.from(rows.first);
  }

  Future<Map<String, Object?>> _cashSession(Database db, String? id) async {
    if (id == null || id.isEmpty) {
      return <String, Object?>{};
    }
    final rows = await db.query(
      DatabaseConstants.tableCashSessions,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return <String, Object?>{'id': id, 'missing': 1};
    }
    return Map<String, Object?>.from(rows.first);
  }

  Future<Map<String, Object?>> _cashMovement(Database db, String? id) async {
    if (id == null || id.isEmpty) {
      return <String, Object?>{};
    }
    final rows = await db.query(
      DatabaseConstants.tableCashMovements,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return <String, Object?>{'id': id, 'missing': 1};
    }
    return Map<String, Object?>.from(rows.first);
  }

  Future<Map<String, Object?>> _category(
    Database db,
    String? id,
    String businessId,
  ) async {
    if (id == null || id.isEmpty) {
      return <String, Object?>{};
    }
    final rows = await db.rawQuery(
      '''
SELECT id, business_id, name, 'product' AS source, created_at, updated_at, deleted_at
FROM ${DatabaseConstants.tableCategories}
WHERE id = ? AND business_id = ?
UNION ALL
SELECT id, business_id, name, 'expense' AS source, created_at, updated_at, deleted_at
FROM ${DatabaseConstants.tableExpenseCategories}
WHERE id = ? AND business_id = ?
LIMIT 1
''',
      <Object>[id, businessId, id, businessId],
    );
    if (rows.isEmpty) {
      return <String, Object?>{'id': id, 'missing': 1};
    }
    return Map<String, Object?>.from(rows.first);
  }

  Future<Map<String, Object?>> _settings(Database db, String businessId) async {
    final app = await db.query(DatabaseConstants.tableAppSettings);
    final biz = await db.query(
      DatabaseConstants.tableBusinessSettings,
      where: 'business_id = ?',
      whereArgs: <Object>[businessId],
      limit: 1,
    );
    return <String, Object?>{
      'business_id': businessId,
      'app_settings': app,
      'business_settings': biz.isEmpty ? null : biz.first,
    };
  }

  Future<Map<String, Object?>> _subscriptionMeta(
    Database db,
    String businessId,
  ) async {
    final sub = await db.query(
      DatabaseConstants.tableSubscriptions,
      where: 'business_id = ?',
      whereArgs: <Object>[businessId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    final ents = await db.query(
      DatabaseConstants.tableEntitlements,
      where: 'business_id = ?',
      whereArgs: <Object>[businessId],
    );
    return <String, Object?>{
      'business_id': businessId,
      'subscription': sub.isEmpty ? null : sub.first,
      'entitlements': ents,
    };
  }

  Future<Map<String, Object?>> _dailyReport(
    Database db,
    String businessId,
    Map<String, Object?> envelope,
  ) async {
    final int startMs = readInt(envelope['start_ms'], field: 'start_ms');
    final int endMs = readInt(envelope['end_ms'], field: 'end_ms');
    final String dateKey = envelope['date'] as String? ?? '';
    final omzetRows = await db.rawQuery(
      '''
SELECT CAST(COALESCE(SUM(total_amount), 0) AS INTEGER) AS omzet,
       CAST(COUNT(*) AS INTEGER) AS trx
FROM ${DatabaseConstants.tableTransactions}
WHERE business_id = ? AND status = 'completed'
  AND created_at >= ? AND created_at < ?
''',
      <Object>[businessId, startMs, endMs],
    );
    final expenseRows = await db.rawQuery(
      '''
SELECT CAST(COALESCE(SUM(amount), 0) AS INTEGER) AS value
FROM ${DatabaseConstants.tableExpenses}
WHERE business_id = ? AND spent_at >= ? AND spent_at < ?
''',
      <Object>[businessId, startMs, endMs],
    );
    return <String, Object?>{
      'business_id': businessId,
      'date': dateKey,
      'start_ms': startMs,
      'end_ms': endMs,
      'omzet': readInt(omzetRows.first['omzet'], field: 'omzet'),
      'transaction_count': readInt(omzetRows.first['trx'], field: 'trx'),
      'expenses_total': readInt(expenseRows.first['value'], field: 'value'),
    };
  }
}
