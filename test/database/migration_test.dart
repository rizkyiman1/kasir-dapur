import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/migrations/migration_runner.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_mig_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('versi runner selaras dengan konstanta skema', () {
    expect(MigrationRunner.currentVersion, DatabaseConstants.schemaVersion);
    expect(DatabaseConstants.schemaVersion, 13);
  });

  test('upgrade v1 ke v2 tidak menghapus local_users', () async {
    final String path = p.join(tempDir.path, 'kasir_dapur.db');
    final AppDatabase v1 = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: path,
      schemaVersion: 1,
    );
    final Database first = await v1.database;
    await first.insert(DatabaseConstants.tableLocalUsers, <String, Object>{
      'id': 'owner-1',
      'display_name': 'Budi',
      'role': 'owner',
      'pin_salt': 'salt',
      'pin_hash': 'hash',
      'created_at': 1,
      'updated_at': 1,
    });
    await v1.close();

    final AppDatabase v2 = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: path,
      schemaVersion: 2,
    );
    final Database upgraded = await v2.database;
    final users = await upgraded.query(DatabaseConstants.tableLocalUsers);
    expect(users, hasLength(1));
    expect(users.first['display_name'], 'Budi');

    final tables = await upgraded.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final Set<String> names = tables
        .map((Map<String, Object?> row) => row['name']! as String)
        .toSet();
    expect(
      names,
      containsAll(<String>[
        DatabaseConstants.tableProducts,
        DatabaseConstants.tableTransactions,
        DatabaseConstants.tableStock,
        DatabaseConstants.tableCustomers,
        DatabaseConstants.tableSyncQueue,
        DatabaseConstants.tableSubscriptions,
        DatabaseConstants.tableAppSettings,
      ]),
    );
    await v2.close();
  });

  test(
    'upgrade v2 ke v3 menambah pin_algo dan sesi tanpa menghapus user',
    () async {
      final String path = p.join(tempDir.path, 'kasir_dapur_v3.db');
      final AppDatabase v2 = AppDatabase(
        factory: databaseFactoryFfi,
        filePath: path,
        schemaVersion: 2,
      );
      final Database first = await v2.database;
      await first.insert(DatabaseConstants.tableLocalUsers, <String, Object>{
        'id': 'owner-1',
        'display_name': 'Budi',
        'role': 'owner',
        'pin_salt': 'salt',
        'pin_hash': 'hash',
        'created_at': 1,
        'updated_at': 1,
      });
      await v2.close();

      final AppDatabase v3 = AppDatabase(
        factory: databaseFactoryFfi,
        filePath: path,
        schemaVersion: 3,
      );
      final Database upgraded = await v3.database;
      final users = await upgraded.query(DatabaseConstants.tableLocalUsers);
      expect(users, hasLength(1));
      expect(users.first['display_name'], 'Budi');
      expect(users.first['pin_algo'], 'sha256-iter');

      final tables = await upgraded.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final Set<String> names = tables
          .map((Map<String, Object?> row) => row['name']! as String)
          .toSet();
      expect(names, contains(DatabaseConstants.tableLocalSessions));
      await v3.close();
    },
  );

  test('instal baru membuat seluruh tabel POS', () async {
    final AppDatabase database = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(tempDir.path, 'fresh.db'),
    );
    final Database db = await database.database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    );
    final Set<String> names = tables
        .map((Map<String, Object?> row) => row['name']! as String)
        .toSet();
    const List<String> required = [
      'businesses',
      'business_settings',
      'users',
      'roles',
      'products',
      'categories',
      'units',
      'stock',
      'stock_movements',
      'transactions',
      'transaction_items',
      'payments',
      'customers',
      'suppliers',
      'expenses',
      'expense_categories',
      'cash_sessions',
      'cash_movements',
      'discounts',
      'taxes',
      'pos_carts',
      'printer_settings',
      'sync_queue',
      'sync_logs',
      'subscriptions',
      'entitlements',
      'app_settings',
      'local_sessions',
      'backup_logs',
      'contact_history',
    ];
    expect(names, containsAll(required));
    await database.close();
  });

  test(
    'upgrade v3 ke v5 menambah setting stok tanpa menghapus produk',
    () async {
      final String path = p.join(tempDir.path, 'kasir_dapur_v5.db');
      final AppDatabase v3 = AppDatabase(
        factory: databaseFactoryFfi,
        filePath: path,
        schemaVersion: 3,
      );
      final Database first = await v3.database;
      await first.insert(DatabaseConstants.tableBusinesses, <String, Object>{
        'id': 'biz-1',
        'name': 'Dapur Rasa',
        'status': 'active',
        'created_at': 1,
        'updated_at': 1,
      });
      await first.insert(DatabaseConstants.tableProducts, <String, Object>{
        'id': 'prod-1',
        'business_id': 'biz-1',
        'name': 'Es Teh',
        'cost_price': 2000,
        'sell_price': 5000,
        'min_stock': 2,
        'is_active': 1,
        'created_at': 1,
        'updated_at': 1,
      });
      await first.insert(DatabaseConstants.tableStock, <String, Object>{
        'id': 'stk-1',
        'business_id': 'biz-1',
        'product_id': 'prod-1',
        'qty': 10,
        'created_at': 1,
        'updated_at': 1,
      });
      await first.insert(
        DatabaseConstants.tableStockMovements,
        <String, Object>{
          'id': 'mov-1',
          'business_id': 'biz-1',
          'product_id': 'prod-1',
          'type': 'in',
          'qty': 10,
          'qty_before': 0,
          'qty_after': 10,
          'created_at': 1,
          'updated_at': 1,
        },
      );
      await v3.close();

      final AppDatabase v5 = AppDatabase(
        factory: databaseFactoryFfi,
        filePath: path,
        schemaVersion: 5,
      );
      final Database upgraded = await v5.database;
      final products = await upgraded.query(DatabaseConstants.tableProducts);
      expect(products, hasLength(1));
      expect(products.first['name'], 'Es Teh');
      expect(products.first.containsKey('description'), isTrue);

      final movements = await upgraded.query(
        DatabaseConstants.tableStockMovements,
      );
      expect(movements.single['type'], 'stock_in');

      final settingCols = await upgraded.rawQuery(
        'PRAGMA table_info(${DatabaseConstants.tableBusinessSettings})',
      );
      final Set<String> colNames = settingCols
          .map((Map<String, Object?> row) => row['name']! as String)
          .toSet();
      expect(colNames, contains('allow_negative_stock'));
      await v5.close();
    },
  );

  test('upgrade v5 ke v6 menambah pos_carts tanpa menghapus produk', () async {
    final String path = p.join(tempDir.path, 'kasir_dapur_v6.db');
    final AppDatabase v5 = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: path,
      schemaVersion: 5,
    );
    final Database first = await v5.database;
    await first.insert(DatabaseConstants.tableBusinesses, <String, Object>{
      'id': 'biz-1',
      'name': 'Dapur Rasa',
      'status': 'active',
      'created_at': 1,
      'updated_at': 1,
    });
    await first.insert(DatabaseConstants.tableProducts, <String, Object>{
      'id': 'prod-1',
      'business_id': 'biz-1',
      'name': 'Es Teh',
      'cost_price': 2000,
      'sell_price': 5000,
      'min_stock': 0,
      'is_active': 1,
      'created_at': 1,
      'updated_at': 1,
    });
    await v5.close();

    final AppDatabase v6 = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: path,
      schemaVersion: 6,
    );
    final Database upgraded = await v6.database;
    final products = await upgraded.query(DatabaseConstants.tableProducts);
    expect(products, hasLength(1));
    final tables = await upgraded.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'pos_carts'",
    );
    expect(tables, isNotEmpty);
    await v6.close();
  });

  test(
    'upgrade v6 ke v7 menambah auto_print tanpa menghapus pos_carts',
    () async {
      final String path = p.join(tempDir.path, 'kasir_dapur_v7.db');
      final AppDatabase v6 = AppDatabase(
        factory: databaseFactoryFfi,
        filePath: path,
        schemaVersion: 6,
      );
      final Database first = await v6.database;
      await first.insert(DatabaseConstants.tableBusinesses, <String, Object>{
        'id': 'biz-1',
        'name': 'Dapur Rasa',
        'status': 'active',
        'created_at': 1,
        'updated_at': 1,
      });
      await first.insert(DatabaseConstants.tablePosCarts, <String, Object>{
        'id': 'cart-1',
        'business_id': 'biz-1',
        'client_uuid': 'uuid-1',
        'status': 'open',
        'discount_amount': 0,
        'payload': '[]',
        'created_at': 1,
        'updated_at': 1,
      });
      await v6.close();

      final AppDatabase v7 = AppDatabase(
        factory: databaseFactoryFfi,
        filePath: path,
        schemaVersion: 7,
      );
      final Database upgraded = await v7.database;
      final carts = await upgraded.query(DatabaseConstants.tablePosCarts);
      expect(carts, hasLength(1));
      final cols = await upgraded.rawQuery(
        'PRAGMA table_info(${DatabaseConstants.tablePrinterSettings})',
      );
      final Set<String> colNames = cols
          .map((Map<String, Object?> row) => row['name']! as String)
          .toSet();
      expect(colNames, containsAll(<String>['auto_print', 'last_sale_id']));
      await v7.close();
    },
  );

  test('upgrade v7 ke v8 menambah plan_code dan riwayat pembayaran tanpa menghapus langganan', () async {
    final String path = p.join(tempDir.path, 'kasir_dapur_v8.db');
    final AppDatabase v7 = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: path,
      schemaVersion: 7,
    );
    final Database first = await v7.database;
    await first.insert(DatabaseConstants.tableBusinesses, <String, Object>{
      'id': 'biz-1',
      'name': 'Dapur Rasa',
      'status': 'active',
      'created_at': 1,
      'updated_at': 1,
    });
    await first.insert(DatabaseConstants.tableSubscriptions, <String, Object>{
      'id': 'sub-1',
      'business_id': 'biz-1',
      'plan': 'pro',
      'status': 'active',
      'source': 'local',
      'starts_at': 1,
      'created_at': 1,
      'updated_at': 1,
    });
    await v7.close();

    final AppDatabase v8 = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: path,
      schemaVersion: 8,
    );
    final Database upgraded = await v8.database;
    final subs = await upgraded.query(DatabaseConstants.tableSubscriptions);
    expect(subs, hasLength(1));
    expect(subs.first['plan'], 'pro');
    expect(subs.first['plan_code'], 'PRO_MONTHLY');
    final tables = await upgraded.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name = '${DatabaseConstants.tableSubscriptionPayments}'",
    );
    expect(tables, isNotEmpty);
    await v8.close();
  });

  test(
    'upgrade v8 ke v9 menambah backup_logs tanpa menghapus langganan',
    () async {
      final String path = p.join(tempDir.path, 'kasir_dapur_v9.db');
      final AppDatabase v8 = AppDatabase(
        factory: databaseFactoryFfi,
        filePath: path,
        schemaVersion: 8,
      );
      final Database first = await v8.database;
      await first.insert(DatabaseConstants.tableBusinesses, <String, Object>{
        'id': 'biz-1',
        'name': 'Dapur Rasa',
        'status': 'active',
        'created_at': 1,
        'updated_at': 1,
      });
      await first.insert(DatabaseConstants.tableSubscriptions, <String, Object>{
        'id': 'sub-1',
        'business_id': 'biz-1',
        'plan': 'pro',
        'plan_code': 'PRO_MONTHLY',
        'status': 'active',
        'source': 'local',
        'starts_at': 1,
        'created_at': 1,
        'updated_at': 1,
      });
      await v8.close();

      final AppDatabase v9 = AppDatabase(
        factory: databaseFactoryFfi,
        filePath: path,
        schemaVersion: 9,
      );
      final Database upgraded = await v9.database;
      final subs = await upgraded.query(DatabaseConstants.tableSubscriptions);
      expect(subs, hasLength(1));
      final tables = await upgraded.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = '${DatabaseConstants.tableBackupLogs}'",
      );
      expect(tables, isNotEmpty);
      await v9.close();
    },
  );

  test(
    'upgrade v9 ke v10 menambah contact_history tanpa menghapus cadangan',
    () async {
      final String path = p.join(tempDir.path, 'kasir_dapur_v10.db');
      final AppDatabase v9 = AppDatabase(
        factory: databaseFactoryFfi,
        filePath: path,
        schemaVersion: 9,
      );
      final Database first = await v9.database;
      await first.insert(DatabaseConstants.tableBusinesses, <String, Object>{
        'id': 'biz-1',
        'name': 'Dapur Rasa',
        'status': 'active',
        'created_at': 1,
        'updated_at': 1,
      });
      await first.insert(DatabaseConstants.tableBackupLogs, <String, Object>{
        'id': 'bak-1',
        'business_id': 'biz-1',
        'direction': 'upload',
        'status': 'success',
        'created_at': 1,
        'updated_at': 1,
      });
      await v9.close();

      final AppDatabase v10 = AppDatabase(
        factory: databaseFactoryFfi,
        filePath: path,
        schemaVersion: 10,
      );
      final Database upgraded = await v10.database;
      final logs = await upgraded.query(DatabaseConstants.tableBackupLogs);
      expect(logs, hasLength(1));
      final tables = await upgraded.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = '${DatabaseConstants.tableContactHistory}'",
      );
      expect(tables, isNotEmpty);
      await v10.close();
    },
  );

  test('upgrade v10 ke v11 menambah kode kategori dan laporan kas tanpa menghapus riwayat', () async {
    final String path = p.join(tempDir.path, 'kasir_dapur_v11.db');
    final AppDatabase v10 = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: path,
      schemaVersion: 10,
    );
    final Database first = await v10.database;
    await first.insert(DatabaseConstants.tableBusinesses, <String, Object>{
      'id': 'biz-1',
      'name': 'Dapur Rasa',
      'status': 'active',
      'created_at': 1,
      'updated_at': 1,
    });
    await first.insert(DatabaseConstants.tableContactHistory, <String, Object>{
      'id': 'ch-1',
      'business_id': 'biz-1',
      'party_type': 'customer',
      'party_id': 'c-1',
      'event': 'created',
      'summary': 'Pelanggan ditambahkan',
      'created_at': 1,
    });
    await v10.close();

    final AppDatabase v11 = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: path,
      schemaVersion: 11,
    );
    final Database upgraded = await v11.database;
    final history = await upgraded.query(DatabaseConstants.tableContactHistory);
    expect(history, hasLength(1));
    final categoryCols = await upgraded.rawQuery(
      'PRAGMA table_info(${DatabaseConstants.tableExpenseCategories})',
    );
    expect(
      categoryCols.map((Map<String, Object?> row) => row['name']),
      contains('code'),
    );
    final sessionCols = await upgraded.rawQuery(
      'PRAGMA table_info(${DatabaseConstants.tableCashSessions})',
    );
    expect(
      sessionCols.map((Map<String, Object?> row) => row['name']),
      contains('report_json'),
    );
    await v11.close();
  });

  test('upgrade v11 ke v12 menambah logo toko dan pengaturan struk tanpa menghapus laporan kas', () async {
    final String path = p.join(tempDir.path, 'kasir_dapur_v12.db');
    final AppDatabase v11 = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: path,
      schemaVersion: 11,
    );
    final Database first = await v11.database;
    await first.insert(DatabaseConstants.tableBusinesses, <String, Object>{
      'id': 'biz-1',
      'name': 'Dapur Rasa',
      'status': 'active',
      'created_at': 1,
      'updated_at': 1,
    });
    await first.insert(DatabaseConstants.tableCashSessions, <String, Object>{
      'id': 'ses-1',
      'business_id': 'biz-1',
      'opening_amount': 100000,
      'status': 'closed',
      'opened_at': 1,
      'created_at': 1,
      'updated_at': 1,
      'report_json': '{"expectedAmount":100000}',
    });
    await v11.close();

    final AppDatabase v12 = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: path,
      schemaVersion: 12,
    );
    final Database upgraded = await v12.database;
    final sessions = await upgraded.query(DatabaseConstants.tableCashSessions);
    expect(sessions, hasLength(1));
    expect(sessions.first['report_json'], '{"expectedAmount":100000}');
    final businessCols = await upgraded.rawQuery(
      'PRAGMA table_info(${DatabaseConstants.tableBusinesses})',
    );
    expect(
      businessCols.map((Map<String, Object?> row) => row['name']),
      contains('logo_path'),
    );
    final settingCols = await upgraded.rawQuery(
      'PRAGMA table_info(${DatabaseConstants.tableBusinessSettings})',
    );
    final Set<Object?> settingNames = settingCols
        .map((Map<String, Object?> row) => row['name'])
        .toSet();
    expect(
      settingNames,
      containsAll(<String>['default_payment', 'receipt_behavior']),
    );
    await v12.close();
  });
}
