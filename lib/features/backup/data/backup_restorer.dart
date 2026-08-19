import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/features/backup/domain/backup_models.dart';
import 'package:sqflite/sqflite.dart';

/// Menimpa baris cadangan menurut id. Tidak DROP TABLE. Baris lokal baru tetap ada.
final class BackupRestorer {
  BackupRestorer(this._database);

  final AppDatabase _database;

  static const List<String> _order = <String>[
    BackupTables.businesses,
    BackupTables.businessSettings,
    BackupTables.localUsers,
    BackupTables.categories,
    BackupTables.expenseCategories,
    BackupTables.suppliers,
    BackupTables.customers,
    BackupTables.products,
    BackupTables.stock,
    BackupTables.stockMovements,
    BackupTables.cashSessions,
    BackupTables.cashMovements,
    BackupTables.transactions,
    BackupTables.payments,
    BackupTables.transactionItems,
    BackupTables.expenses,
    BackupTables.subscriptions,
    BackupTables.entitlements,
    BackupTables.settings,
  ];

  static const Map<String, String> _sqliteTable = <String, String>{
    BackupTables.businesses: DatabaseConstants.tableBusinesses,
    BackupTables.businessSettings: DatabaseConstants.tableBusinessSettings,
    BackupTables.localUsers: DatabaseConstants.tableLocalUsers,
    BackupTables.categories: DatabaseConstants.tableCategories,
    BackupTables.expenseCategories: DatabaseConstants.tableExpenseCategories,
    BackupTables.suppliers: DatabaseConstants.tableSuppliers,
    BackupTables.customers: DatabaseConstants.tableCustomers,
    BackupTables.products: DatabaseConstants.tableProducts,
    BackupTables.stock: DatabaseConstants.tableStock,
    BackupTables.stockMovements: DatabaseConstants.tableStockMovements,
    BackupTables.cashSessions: DatabaseConstants.tableCashSessions,
    BackupTables.cashMovements: DatabaseConstants.tableCashMovements,
    BackupTables.transactions: DatabaseConstants.tableTransactions,
    BackupTables.payments: DatabaseConstants.tablePayments,
    BackupTables.transactionItems: DatabaseConstants.tableTransactionItems,
    BackupTables.expenses: DatabaseConstants.tableExpenses,
    BackupTables.subscriptions: DatabaseConstants.tableSubscriptions,
    BackupTables.entitlements: DatabaseConstants.tableEntitlements,
  };

  Future<void> restore(
    BackupSnapshot snapshot, {
    required String businessId,
  }) async {
    _validateSnapshot(snapshot, businessId: businessId);
    final Database db = await _database.database;
    await db.transaction((Transaction txn) async {
      await txn.execute('PRAGMA defer_foreign_keys = ON');
      for (final String name in _order) {
        final List<Map<String, Object?>> rows =
            snapshot.tables[name] ?? const <Map<String, Object?>>[];
        if (name == BackupTables.settings) {
          await _restoreSettings(txn, rows);
          continue;
        }
        final String table = _sqliteTable[name]!;
        for (final Map<String, Object?> row in rows) {
          await txn.insert(
            table,
            _withoutStore(row),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<void> _restoreSettings(
    DatabaseExecutor txn,
    List<Map<String, Object?>> rows,
  ) async {
    for (final Map<String, Object?> row in rows) {
      final String store =
          row['store'] as String? ?? DatabaseConstants.tableAppSettings;
      final Map<String, Object?> data = _withoutStore(row);
      if (data.isEmpty) {
        continue;
      }
      await txn.insert(
        store,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Map<String, Object?> _withoutStore(Map<String, Object?> row) {
    return <String, Object?>{
      for (final MapEntry<String, Object?> entry in row.entries)
        if (entry.key != 'store') entry.key: entry.value,
    };
  }

  void _validateSnapshot(
    BackupSnapshot snapshot, {
    required String businessId,
  }) {
    if (snapshot.businessId != businessId) {
      throw const ForbiddenException(
        'Cadangan bukan milik bisnis yang sedang login.',
      );
    }
    if (snapshot.schemaVersion != DatabaseConstants.schemaVersion) {
      throw ValidationException(
        'Versi skema tidak cocok (${snapshot.schemaVersion} != ${DatabaseConstants.schemaVersion}).',
      );
    }
    final String computed = _checksum(snapshot.tables);
    if (snapshot.checksum == null || snapshot.checksum != computed) {
      throw const ValidationException(
        'Integritas cadangan tidak valid (checksum mismatch).',
      );
    }
    final List<Map<String, Object?>> trxRows =
        snapshot.tables[BackupTables.transactions] ??
        const <Map<String, Object?>>[];
    final Set<String> seen = <String>{};
    for (final Map<String, Object?> row in trxRows) {
      final String? clientUuid = row['client_uuid'] as String?;
      if (clientUuid == null || clientUuid.isEmpty) {
        continue;
      }
      if (!seen.add(clientUuid)) {
        throw ValidationException(
          'Cadangan korup: duplicate client_uuid transaksi ($clientUuid).',
        );
      }
    }
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
}
