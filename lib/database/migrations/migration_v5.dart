import 'package:kasir_dapur/database/database_constants.dart';
import 'package:sqflite/sqflite.dart';

/// Setting stok negatif + nama movement yang selaras (aditif).
abstract final class MigrationV5 {
  static Future<void> apply(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tableBusinessSettings} '
      'ADD COLUMN allow_negative_stock INTEGER NOT NULL DEFAULT 0',
    );

    await db.execute(
      'UPDATE ${DatabaseConstants.tableStockMovements} '
      "SET type = 'stock_in' WHERE type = 'in'",
    );
    await db.execute(
      'UPDATE ${DatabaseConstants.tableStockMovements} '
      "SET type = 'stock_out' WHERE type = 'out'",
    );
    await db.execute(
      'UPDATE ${DatabaseConstants.tableStockMovements} '
      "SET type = 'sale_return' WHERE type IN ('return', 'retur')",
    );
    await db.execute(
      'UPDATE ${DatabaseConstants.tableStockMovements} '
      "SET type = 'damaged' WHERE type = 'damage'",
    );

    await db.execute(
      'CREATE INDEX idx_stock_business_qty '
      'ON ${DatabaseConstants.tableStock} (business_id, qty)',
    );

    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(DatabaseConstants.tableSchemaMigrations, <String, Object>{
      'version': 5,
      'applied_at': now,
    });
    await db.update(DatabaseConstants.tableSchemaMeta, <String, Object>{
      'version': 5,
      'applied_at': now,
    });
  }
}
