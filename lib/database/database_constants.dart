/// Nama file, versi skema, dan tabel SQLite Kasir Dapur.
abstract final class DatabaseConstants {
  static const String fileName = 'kasir_dapur.db';

  /// Versi skema saat ini. Naikkan hanya dengan migrasi aditif.
  static const int schemaVersion = 13;

  static const String tableSchemaMeta = 'schema_meta';
  static const String tableSchemaMigrations = 'schema_migrations';
  static const String tableAppSettings = 'app_settings';
  static const String tableLocalUsers = 'local_users';
  static const String tableLocalSessions = 'local_sessions';

  static const String tableBusinesses = 'businesses';
  static const String tableBusinessSettings = 'business_settings';
  static const String tableUsers = 'users';
  static const String tableRoles = 'roles';
  static const String tableProducts = 'products';
  static const String tableCategories = 'categories';
  static const String tableUnits = 'units';
  static const String tableStock = 'stock';
  static const String tableStockMovements = 'stock_movements';
  static const String tableTransactions = 'transactions';
  static const String tableTransactionItems = 'transaction_items';
  static const String tablePayments = 'payments';
  static const String tableCustomers = 'customers';
  static const String tableSuppliers = 'suppliers';
  static const String tableExpenses = 'expenses';
  static const String tableExpenseCategories = 'expense_categories';
  static const String tableCashSessions = 'cash_sessions';
  static const String tableCashMovements = 'cash_movements';
  static const String tableDiscounts = 'discounts';
  static const String tableTaxes = 'taxes';
  static const String tablePosCarts = 'pos_carts';
  static const String tablePrinterSettings = 'printer_settings';
  static const String tableSyncQueue = 'sync_queue';
  static const String tableSyncLogs = 'sync_logs';
  static const String tableSubscriptions = 'subscriptions';
  static const String tableEntitlements = 'entitlements';
  static const String tableSubscriptionPayments = 'subscription_payments';
  static const String tableBackupLogs = 'backup_logs';
  static const String tableContactHistory = 'contact_history';
}
