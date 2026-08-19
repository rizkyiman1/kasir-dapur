import 'package:kasir_dapur/database/database_constants.dart';
import 'package:sqflite/sqflite.dart';

/// Skema POS. Hanya CREATE TABLE / INDEX / ALTER ADD COLUMN.
abstract final class MigrationV2 {
  static Future<void> apply(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableSchemaMigrations} (
  version INTEGER PRIMARY KEY NOT NULL,
  applied_at INTEGER NOT NULL
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableBusinesses} (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  legal_name TEXT,
  address TEXT,
  phone TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableRoles} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableUsers} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  role_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  pin_salt TEXT,
  pin_hash TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id),
  FOREIGN KEY (role_id) REFERENCES ${DatabaseConstants.tableRoles}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableBusinessSettings} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL UNIQUE,
  receipt_footer TEXT,
  currency_code TEXT NOT NULL DEFAULT 'IDR',
  timezone TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableCategories} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableUnits} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  name TEXT NOT NULL,
  symbol TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableProducts} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  category_id TEXT,
  unit_id TEXT,
  name TEXT NOT NULL,
  sku TEXT,
  barcode TEXT,
  cost_price INTEGER NOT NULL DEFAULT 0,
  sell_price INTEGER NOT NULL DEFAULT 0,
  min_stock INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  image_path TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id),
  FOREIGN KEY (category_id) REFERENCES ${DatabaseConstants.tableCategories}(id),
  FOREIGN KEY (unit_id) REFERENCES ${DatabaseConstants.tableUnits}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableStock} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  qty INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id),
  FOREIGN KEY (product_id) REFERENCES ${DatabaseConstants.tableProducts}(id),
  UNIQUE (business_id, product_id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableStockMovements} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  type TEXT NOT NULL,
  qty INTEGER NOT NULL,
  qty_before INTEGER NOT NULL,
  qty_after INTEGER NOT NULL,
  ref_type TEXT,
  ref_id TEXT,
  note TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id),
  FOREIGN KEY (product_id) REFERENCES ${DatabaseConstants.tableProducts}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableCustomers} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableSuppliers} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableExpenseCategories} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableExpenses} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  category_id TEXT,
  amount INTEGER NOT NULL,
  note TEXT,
  spent_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id),
  FOREIGN KEY (category_id) REFERENCES ${DatabaseConstants.tableExpenseCategories}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableDiscounts} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  value INTEGER NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableTaxes} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  name TEXT NOT NULL,
  rate_bp INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableCashSessions} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  user_id TEXT,
  opening_amount INTEGER NOT NULL DEFAULT 0,
  closing_amount INTEGER,
  expected_amount INTEGER,
  difference_amount INTEGER,
  status TEXT NOT NULL DEFAULT 'open',
  opened_at INTEGER NOT NULL,
  closed_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id),
  FOREIGN KEY (user_id) REFERENCES ${DatabaseConstants.tableUsers}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableCashMovements} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  type TEXT NOT NULL,
  amount INTEGER NOT NULL,
  note TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id),
  FOREIGN KEY (session_id) REFERENCES ${DatabaseConstants.tableCashSessions}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableTransactions} (
  id TEXT PRIMARY KEY NOT NULL,
  client_uuid TEXT NOT NULL,
  business_id TEXT NOT NULL,
  user_id TEXT,
  customer_id TEXT,
  cash_session_id TEXT,
  status TEXT NOT NULL,
  subtotal_amount INTEGER NOT NULL,
  discount_amount INTEGER NOT NULL DEFAULT 0,
  tax_amount INTEGER NOT NULL DEFAULT 0,
  total_amount INTEGER NOT NULL,
  note TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id),
  FOREIGN KEY (user_id) REFERENCES ${DatabaseConstants.tableUsers}(id),
  FOREIGN KEY (customer_id) REFERENCES ${DatabaseConstants.tableCustomers}(id),
  FOREIGN KEY (cash_session_id) REFERENCES ${DatabaseConstants.tableCashSessions}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableTransactionItems} (
  id TEXT PRIMARY KEY NOT NULL,
  transaction_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  name_snapshot TEXT NOT NULL,
  qty INTEGER NOT NULL,
  unit_price INTEGER NOT NULL,
  cost_price INTEGER NOT NULL,
  discount_amount INTEGER NOT NULL DEFAULT 0,
  line_total INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (transaction_id) REFERENCES ${DatabaseConstants.tableTransactions}(id),
  FOREIGN KEY (product_id) REFERENCES ${DatabaseConstants.tableProducts}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tablePayments} (
  id TEXT PRIMARY KEY NOT NULL,
  transaction_id TEXT NOT NULL,
  method TEXT NOT NULL,
  amount INTEGER NOT NULL,
  tendered_amount INTEGER NOT NULL DEFAULT 0,
  change_amount INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (transaction_id) REFERENCES ${DatabaseConstants.tableTransactions}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tablePrinterSettings} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  paper_size TEXT NOT NULL,
  device_name TEXT,
  device_address TEXT,
  is_default INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableSyncQueue} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  client_uuid TEXT NOT NULL,
  aggregate TEXT NOT NULL,
  operation TEXT NOT NULL,
  payload TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableSyncLogs} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  queue_id TEXT,
  direction TEXT NOT NULL,
  status TEXT NOT NULL,
  message TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id),
  FOREIGN KEY (queue_id) REFERENCES ${DatabaseConstants.tableSyncQueue}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableSubscriptions} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  plan TEXT NOT NULL,
  status TEXT NOT NULL,
  source TEXT NOT NULL,
  starts_at INTEGER NOT NULL,
  ends_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id)
)
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableEntitlements} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  subscription_id TEXT,
  feature_key TEXT NOT NULL,
  is_enabled INTEGER NOT NULL DEFAULT 0,
  limit_value INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id),
  FOREIGN KEY (subscription_id) REFERENCES ${DatabaseConstants.tableSubscriptions}(id),
  UNIQUE (business_id, feature_key)
)
''');

    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tableAppSettings} ADD COLUMN created_at INTEGER',
    );
    await db.execute('''
UPDATE ${DatabaseConstants.tableAppSettings}
SET created_at = updated_at
WHERE created_at IS NULL
''');

    await _createIndexes(db);

    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(DatabaseConstants.tableSchemaMigrations, <String, Object>{
      'version': 1,
      'applied_at': now,
    });
    await db.insert(DatabaseConstants.tableSchemaMigrations, <String, Object>{
      'version': 2,
      'applied_at': now,
    });
  }

  static Future<void> _createIndexes(DatabaseExecutor db) async {
    const List<String> statements = [
      'CREATE INDEX idx_roles_business_code ON roles (business_id, code)',
      'CREATE INDEX idx_users_business_name ON users (business_id, display_name)',
      'CREATE INDEX idx_users_role ON users (role_id)',
      'CREATE INDEX idx_categories_business_name ON categories (business_id, name)',
      'CREATE INDEX idx_units_business_name ON units (business_id, name)',
      'CREATE INDEX idx_products_business_name ON products (business_id, name)',
      'CREATE INDEX idx_products_sku ON products (business_id, sku)',
      'CREATE INDEX idx_products_barcode ON products (business_id, barcode)',
      'CREATE INDEX idx_products_active ON products (business_id, is_active)',
      'CREATE INDEX idx_stock_product ON stock (business_id, product_id)',
      'CREATE INDEX idx_stock_movements_product ON stock_movements (product_id, created_at)',
      'CREATE INDEX idx_stock_movements_ref ON stock_movements (ref_type, ref_id)',
      'CREATE INDEX idx_customers_business_name ON customers (business_id, name)',
      'CREATE INDEX idx_customers_phone ON customers (business_id, phone)',
      'CREATE INDEX idx_suppliers_business_name ON suppliers (business_id, name)',
      'CREATE INDEX idx_expenses_business_spent ON expenses (business_id, spent_at)',
      'CREATE INDEX idx_cash_sessions_status ON cash_sessions (business_id, status)',
      'CREATE INDEX idx_cash_movements_session ON cash_movements (session_id, created_at)',
      'CREATE UNIQUE INDEX idx_transactions_client_uuid ON transactions (business_id, client_uuid)',
      'CREATE INDEX idx_transactions_created ON transactions (business_id, created_at)',
      'CREATE INDEX idx_transactions_status ON transactions (business_id, status)',
      'CREATE INDEX idx_transaction_items_sale ON transaction_items (transaction_id)',
      'CREATE INDEX idx_payments_sale ON payments (transaction_id)',
      'CREATE UNIQUE INDEX idx_sync_queue_client_uuid ON sync_queue (business_id, client_uuid)',
      'CREATE INDEX idx_sync_queue_status ON sync_queue (status, created_at)',
      'CREATE INDEX idx_sync_logs_queue ON sync_logs (queue_id, created_at)',
      'CREATE INDEX idx_subscriptions_business ON subscriptions (business_id, status)',
      'CREATE INDEX idx_entitlements_feature ON entitlements (business_id, feature_key)',
    ];
    for (final String sql in statements) {
      await db.execute(sql);
    }
  }
}
