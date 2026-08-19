import 'package:kasir_dapur/database/database_constants.dart';
import 'package:sqflite/sqflite.dart';

/// Setting printer: cetak otomatis dan struk terakhir (aditif).
abstract final class MigrationV7 {
  static Future<void> apply(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tablePrinterSettings} '
      'ADD COLUMN auto_print INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tablePrinterSettings} '
      'ADD COLUMN last_sale_id TEXT',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_printer_settings_business '
      'ON ${DatabaseConstants.tablePrinterSettings} (business_id, is_default)',
    );

    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(DatabaseConstants.tableSchemaMigrations, <String, Object>{
      'version': 7,
      'applied_at': now,
    });
    await db.update(DatabaseConstants.tableSchemaMeta, <String, Object>{
      'version': 7,
      'applied_at': now,
    });
  }
}
