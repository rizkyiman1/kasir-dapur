import 'package:kasir_dapur/database/database_constants.dart';
import 'package:sqflite/sqflite.dart';

/// Riwayat pelanggan/pemasok. Aditif, tanpa DROP.
abstract final class MigrationV10 {
  static Future<void> apply(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableContactHistory} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  party_type TEXT NOT NULL,
  party_id TEXT NOT NULL,
  event TEXT NOT NULL,
  summary TEXT NOT NULL,
  amount INTEGER,
  ref_id TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id)
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_contact_history_party '
      'ON ${DatabaseConstants.tableContactHistory} '
      '(party_type, party_id, created_at)',
    );

    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(DatabaseConstants.tableSchemaMigrations, <String, Object>{
      'version': 10,
      'applied_at': now,
    });
    await db.update(DatabaseConstants.tableSchemaMeta, <String, Object>{
      'version': 10,
      'applied_at': now,
    });
  }
}
