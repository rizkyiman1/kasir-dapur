import 'package:kasir_dapur/database/database_constants.dart';
import 'package:sqflite/sqflite.dart';

/// v13 — Tambah index yang kurang untuk query produksi dan perbaiki
/// update schema_meta agar menggunakan WHERE eksplisit.
///
/// Semua index menggunakan IF NOT EXISTS — aman untuk dijalankan ulang.
/// Tidak ada perubahan skema tabel, tidak ada DROP.
abstract final class MigrationV13 {
  static Future<void> apply(DatabaseExecutor db) async {
    // Laporan per pelanggan — JOIN transactions ON customer_id
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_transactions_customer
ON ${DatabaseConstants.tableTransactions} (business_id, customer_id)
''');

    // Laporan produk terlaris — JOIN transaction_items ON product_id
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_transaction_items_product
ON ${DatabaseConstants.tableTransactionItems} (product_id, created_at)
''');

    // Filter pengeluaran per kategori
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_expenses_category
ON ${DatabaseConstants.tableExpenses} (business_id, category_id, spent_at)
''');

    // Pastikan hanya ada satu baris di schema_meta — hapus duplikat jika ada.
    // Jika > 1 baris (tidak normal), pertahankan yang version-nya tertinggi.
    await db.execute('''
DELETE FROM ${DatabaseConstants.tableSchemaMeta}
WHERE rowid NOT IN (
  SELECT rowid FROM ${DatabaseConstants.tableSchemaMeta}
  ORDER BY version DESC, applied_at DESC
  LIMIT 1
)
''');

    // Update schema_meta dengan WHERE rowid eksplisit agar tidak ada ambiguitas.
    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.rawUpdate(
      '''
UPDATE ${DatabaseConstants.tableSchemaMeta}
SET version = 13, applied_at = ?
WHERE rowid = (SELECT rowid FROM ${DatabaseConstants.tableSchemaMeta} LIMIT 1)
''',
      <Object>[now],
    );
  }
}
