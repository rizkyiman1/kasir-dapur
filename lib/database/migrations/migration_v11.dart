import 'package:kasir_dapur/database/database_constants.dart';
import 'package:sqflite/sqflite.dart';

/// Kode kategori pengeluaran dan laporan tutup kas. Aditif, tanpa DROP.
abstract final class MigrationV11 {
  static Future<void> apply(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tableExpenseCategories} '
      'ADD COLUMN code TEXT',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_expense_categories_code '
      'ON ${DatabaseConstants.tableExpenseCategories} (business_id, code)',
    );
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tableCashSessions} '
      'ADD COLUMN report_json TEXT',
    );

    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(DatabaseConstants.tableSchemaMigrations, <String, Object>{
      'version': 11,
      'applied_at': now,
    });
    await db.update(DatabaseConstants.tableSchemaMeta, <String, Object>{
      'version': 11,
      'applied_at': now,
    });
  }
}
