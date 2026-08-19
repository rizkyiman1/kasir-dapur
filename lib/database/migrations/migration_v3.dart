import 'package:kasir_dapur/database/database_constants.dart';
import 'package:sqflite/sqflite.dart';

/// Auth lokal: algoritma PIN + sesi perangkat. Hanya ADD COLUMN / CREATE TABLE.
abstract final class MigrationV3 {
  static Future<void> apply(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tableLocalUsers} '
      "ADD COLUMN pin_algo TEXT NOT NULL DEFAULT 'sha256-iter'",
    );

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableLocalSessions} (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  last_active_at INTEGER NOT NULL,
  locked INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES ${DatabaseConstants.tableLocalUsers}(id)
)
''');

    await db.execute(
      'CREATE INDEX idx_local_sessions_user '
      'ON ${DatabaseConstants.tableLocalSessions} (user_id)',
    );

    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(DatabaseConstants.tableSchemaMigrations, <String, Object>{
      'version': 3,
      'applied_at': now,
    });
    await db.update(DatabaseConstants.tableSchemaMeta, <String, Object>{
      'version': 3,
      'applied_at': now,
    });
  }
}
