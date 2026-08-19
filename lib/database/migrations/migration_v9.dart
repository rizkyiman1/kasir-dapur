import 'package:kasir_dapur/database/database_constants.dart';
import 'package:sqflite/sqflite.dart';

/// Jejak cadangan cloud. Aditif, tanpa DROP.
abstract final class MigrationV9 {
  static Future<void> apply(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableBackupLogs} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  remote_id TEXT,
  direction TEXT NOT NULL,
  status TEXT NOT NULL,
  message TEXT,
  tables_json TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id)
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_backup_logs_business '
      'ON ${DatabaseConstants.tableBackupLogs} (business_id, created_at)',
    );

    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(DatabaseConstants.tableSchemaMigrations, <String, Object>{
      'version': 9,
      'applied_at': now,
    });
    await db.update(DatabaseConstants.tableSchemaMeta, <String, Object>{
      'version': 9,
      'applied_at': now,
    });
  }
}
