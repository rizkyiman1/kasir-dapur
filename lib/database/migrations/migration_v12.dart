import 'package:kasir_dapur/database/database_constants.dart';
import 'package:sqflite/sqflite.dart';

/// Profil toko, pembayaran default, dan perilaku struk. Aditif, tanpa DROP.
abstract final class MigrationV12 {
  static Future<void> apply(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tableBusinesses} '
      'ADD COLUMN logo_path TEXT',
    );
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tableBusinessSettings} '
      "ADD COLUMN default_payment TEXT NOT NULL DEFAULT 'cash'",
    );
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tableBusinessSettings} '
      "ADD COLUMN receipt_behavior TEXT NOT NULL DEFAULT 'ask'",
    );

    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(DatabaseConstants.tableSchemaMigrations, <String, Object>{
      'version': 12,
      'applied_at': now,
    });
    await db.update(DatabaseConstants.tableSchemaMeta, <String, Object>{
      'version': 12,
      'applied_at': now,
    });
  }
}
