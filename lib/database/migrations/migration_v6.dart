import 'package:kasir_dapur/database/database_constants.dart';
import 'package:sqflite/sqflite.dart';

/// Keranjang kasir (open/hold) agar draft bertahan saat aplikasi tertutup.
abstract final class MigrationV6 {
  static Future<void> apply(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE ${DatabaseConstants.tablePosCarts} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  user_id TEXT,
  client_uuid TEXT NOT NULL,
  status TEXT NOT NULL,
  customer_id TEXT,
  customer_name TEXT,
  discount_amount INTEGER NOT NULL DEFAULT 0,
  note TEXT,
  payload TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id)
)
''');
    await db.execute(
      'CREATE UNIQUE INDEX idx_pos_carts_client_uuid '
      'ON ${DatabaseConstants.tablePosCarts} (business_id, client_uuid)',
    );
    await db.execute(
      'CREATE INDEX idx_pos_carts_status '
      'ON ${DatabaseConstants.tablePosCarts} (business_id, status, updated_at)',
    );

    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(DatabaseConstants.tableSchemaMigrations, <String, Object>{
      'version': 6,
      'applied_at': now,
    });
    await db.update(DatabaseConstants.tableSchemaMeta, <String, Object>{
      'version': 6,
      'applied_at': now,
    });
  }
}
