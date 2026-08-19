import 'package:kasir_dapur/database/database_constants.dart';
import 'package:sqflite/sqflite.dart';

/// Kolom deskripsi produk + indeks unik SKU/barcode (aditif).
abstract final class MigrationV4 {
  static Future<void> apply(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tableProducts} '
      'ADD COLUMN description TEXT',
    );

    await db.execute(
      'UPDATE ${DatabaseConstants.tableProducts} SET sku = NULL WHERE sku = \'\'',
    );
    await db.execute(
      'UPDATE ${DatabaseConstants.tableProducts} SET barcode = NULL WHERE barcode = \'\'',
    );

    await db.execute('''
CREATE UNIQUE INDEX idx_products_sku_alive
ON ${DatabaseConstants.tableProducts} (business_id, sku)
WHERE sku IS NOT NULL AND deleted_at IS NULL
''');

    await db.execute('''
CREATE UNIQUE INDEX idx_products_barcode_alive
ON ${DatabaseConstants.tableProducts} (business_id, barcode)
WHERE barcode IS NOT NULL AND deleted_at IS NULL
''');

    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(DatabaseConstants.tableSchemaMigrations, <String, Object>{
      'version': 4,
      'applied_at': now,
    });
    await db.update(DatabaseConstants.tableSchemaMeta, <String, Object>{
      'version': 4,
      'applied_at': now,
    });
  }
}
