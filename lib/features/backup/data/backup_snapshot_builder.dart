import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/features/backup/domain/backup_models.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:sqflite/sqflite.dart';

final class BackupSnapshotBuilder {
  BackupSnapshotBuilder({
    required AppDatabase database,
    required ClockService clock,
  }) : _database = database,
       _clock = clock;

  final AppDatabase _database;
  final ClockService _clock;

  Future<BackupSnapshot> build(String businessId) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> transactions = await db.query(
      DatabaseConstants.tableTransactions,
      where: 'business_id = ?',
      whereArgs: <Object>[businessId],
    );
    final List<Object> transactionIds = transactions
        .map((Map<String, Object?> row) => row['id'])
        .whereType<Object>()
        .toList();
    final Map<String, List<Map<String, Object?>>> tables =
        <String, List<Map<String, Object?>>>{
          BackupTables.businesses: _copy(
            await db.query(
              DatabaseConstants.tableBusinesses,
              where: 'id = ?',
              whereArgs: <Object>[businessId],
            ),
          ),
          BackupTables.businessSettings: _copy(
            await db.query(
              DatabaseConstants.tableBusinessSettings,
              where: 'business_id = ?',
              whereArgs: <Object>[businessId],
            ),
          ),
          BackupTables.localUsers: _copy(
            await db.query(DatabaseConstants.tableLocalUsers),
          ),
          BackupTables.products: _copy(
            await db.query(
              DatabaseConstants.tableProducts,
              where: 'business_id = ?',
              whereArgs: <Object>[businessId],
            ),
          ),
          BackupTables.categories: _copy(
            await db.query(
              DatabaseConstants.tableCategories,
              where: 'business_id = ?',
              whereArgs: <Object>[businessId],
            ),
          ),
          BackupTables.suppliers: _copy(
            await db.query(
              DatabaseConstants.tableSuppliers,
              where: 'business_id = ?',
              whereArgs: <Object>[businessId],
            ),
          ),
          BackupTables.transactions: _copy(transactions),
          BackupTables.transactionItems: _copy(
            await _byParent(
              db,
              table: DatabaseConstants.tableTransactionItems,
              parentColumn: 'transaction_id',
              parentIds: transactionIds,
            ),
          ),
          BackupTables.payments: _copy(
            await _byParent(
              db,
              table: DatabaseConstants.tablePayments,
              parentColumn: 'transaction_id',
              parentIds: transactionIds,
            ),
          ),
          BackupTables.stock: _copy(
            await db.query(
              DatabaseConstants.tableStock,
              where: 'business_id = ?',
              whereArgs: <Object>[businessId],
            ),
          ),
          BackupTables.stockMovements: _copy(
            await db.query(
              DatabaseConstants.tableStockMovements,
              where: 'business_id = ?',
              whereArgs: <Object>[businessId],
            ),
          ),
          BackupTables.cashSessions: _copy(
            await db.query(
              DatabaseConstants.tableCashSessions,
              where: 'business_id = ?',
              whereArgs: <Object>[businessId],
            ),
          ),
          BackupTables.cashMovements: _copy(
            await db.query(
              DatabaseConstants.tableCashMovements,
              where: 'business_id = ?',
              whereArgs: <Object>[businessId],
            ),
          ),
          BackupTables.expenses: _copy(
            await db.query(
              DatabaseConstants.tableExpenses,
              where: 'business_id = ?',
              whereArgs: <Object>[businessId],
            ),
          ),
          BackupTables.expenseCategories: _copy(
            await db.query(
              DatabaseConstants.tableExpenseCategories,
              where: 'business_id = ?',
              whereArgs: <Object>[businessId],
            ),
          ),
          BackupTables.customers: _copy(
            await db.query(
              DatabaseConstants.tableCustomers,
              where: 'business_id = ?',
              whereArgs: <Object>[businessId],
            ),
          ),
          BackupTables.subscriptions: _copy(
            await db.query(
              DatabaseConstants.tableSubscriptions,
              where: 'business_id = ?',
              whereArgs: <Object>[businessId],
            ),
          ),
          BackupTables.entitlements: _copy(
            await db.query(
              DatabaseConstants.tableEntitlements,
              where: 'business_id = ?',
              whereArgs: <Object>[businessId],
            ),
          ),
          BackupTables.settings: await _settings(db, businessId),
        };
    return BackupSnapshot(
      businessId: businessId,
      createdAt: _clock.nowEpochMs(),
      schemaVersion: DatabaseConstants.schemaVersion,
      checksum: _checksum(tables),
      tables: tables,
    );
  }

  String _checksum(Map<String, List<Map<String, Object?>>> tables) {
    final Object normalized = <String, Object?>{
      for (final String key in BackupTables.all)
        key: (tables[key] ?? const <Map<String, Object?>>[])
            .map(
              (Map<String, Object?> row) => <String, Object?>{
                for (final String k in row.keys.toList()..sort()) k: row[k],
              },
            )
            .toList(),
    };
    return sha256.convert(utf8.encode(jsonEncode(normalized))).toString();
  }

  Future<List<Map<String, Object?>>> _settings(
    Database db,
    String businessId,
  ) async {
    final List<Map<String, Object?>> app = _copy(
      await db.query(DatabaseConstants.tableAppSettings),
    );
    final List<Map<String, Object?>> business = _copy(
      await db.query(
        DatabaseConstants.tableBusinessSettings,
        where: 'business_id = ?',
        whereArgs: <Object>[businessId],
      ),
    );
    final List<Map<String, Object?>> stores = _copy(
      await db.query(
        DatabaseConstants.tableBusinesses,
        where: 'id = ?',
        whereArgs: <Object>[businessId],
      ),
    );
    return <Map<String, Object?>>[
      ...app.map(
        (Map<String, Object?> row) => <String, Object?>{
          'store': DatabaseConstants.tableAppSettings,
          ...row,
        },
      ),
      ...business.map(
        (Map<String, Object?> row) => <String, Object?>{
          'store': DatabaseConstants.tableBusinessSettings,
          ...row,
        },
      ),
      ...stores.map(
        (Map<String, Object?> row) => <String, Object?>{
          'store': DatabaseConstants.tableBusinesses,
          ...row,
        },
      ),
    ];
  }

  Future<List<Map<String, Object?>>> _byParent(
    Database db, {
    required String table,
    required String parentColumn,
    required List<Object> parentIds,
  }) async {
    if (parentIds.isEmpty) {
      return const <Map<String, Object?>>[];
    }
    final String placeholders = List<String>.filled(
      parentIds.length,
      '?',
    ).join(',');
    return db.query(
      table,
      where: '$parentColumn IN ($placeholders)',
      whereArgs: parentIds,
    );
  }

  List<Map<String, Object?>> _copy(List<Map<String, Object?>> rows) {
    return rows
        .map(
          (Map<String, Object?> row) => <String, Object?>{
            for (final MapEntry<String, Object?> entry in row.entries)
              entry.key: _jsonValue(entry.value),
          },
        )
        .toList();
  }

  Object? _jsonValue(Object? value) {
    if (value == null || value is int || value is String || value is bool) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return value.toString();
  }
}
