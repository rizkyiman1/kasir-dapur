import 'package:kasir_dapur/database/database_constants.dart';
import 'package:sqflite/sqflite.dart';

/// Migrasi awal. Versi berikutnya hanya boleh ADD, tidak boleh DROP/reset.
abstract final class MigrationV1 {
  static Future<void> apply(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableSchemaMeta} (
  version INTEGER NOT NULL,
  applied_at INTEGER NOT NULL
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableAppSettings} (
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL,
  updated_at INTEGER NOT NULL
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableLocalUsers} (
  id TEXT PRIMARY KEY NOT NULL,
  display_name TEXT NOT NULL,
  role TEXT NOT NULL,
  pin_salt TEXT NOT NULL,
  pin_hash TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');

    await db.insert(DatabaseConstants.tableSchemaMeta, <String, Object>{
      'version': 1,
      'applied_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
