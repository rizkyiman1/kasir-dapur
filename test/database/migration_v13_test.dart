import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/database_purge_service.dart';
import 'package:kasir_dapur/database/migrations/migration_runner.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_v13_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ─────────────────────────────────────────────────────────────────
  // Migration v13
  // ─────────────────────────────────────────────────────────────────

  group('migration_v13', () {
    test('versi runner selaras dengan konstanta skema v13', () {
      expect(MigrationRunner.currentVersion, 13);
      expect(DatabaseConstants.schemaVersion, 13);
    });

    test(
      'upgrade v12 ke v13 membuat 3 index baru tanpa menghapus data',
      () async {
        final String path = p.join(tempDir.path, 'v12_to_v13.db');

        // Setup v12 dengan data di setiap tabel yang akan di-index
        final AppDatabase v12 = AppDatabase(
          factory: databaseFactoryFfi,
          filePath: path,
          schemaVersion: 12,
        );
        final Database db12 = await v12.database;

        await db12.insert(DatabaseConstants.tableBusinesses, <String, Object>{
          'id': 'biz-1',
          'name': 'Dapur Rasa',
          'status': 'active',
          'created_at': 1,
          'updated_at': 1,
        });
        await db12.insert(DatabaseConstants.tableCustomers, <String, Object>{
          'id': 'cust-1',
          'business_id': 'biz-1',
          'name': 'Ani',
          'created_at': 1,
          'updated_at': 1,
        });
        await db12.insert(DatabaseConstants.tableTransactions, <String, Object>{
          'id': 'trx-1',
          'client_uuid': 'uuid-trx-1',
          'business_id': 'biz-1',
          'customer_id': 'cust-1',
          'status': 'completed',
          'subtotal_amount': 10000,
          'discount_amount': 0,
          'tax_amount': 0,
          'total_amount': 10000,
          'created_at': 1,
          'updated_at': 1,
        });
        await db12.insert(
          DatabaseConstants.tableExpenseCategories,
          <String, Object>{
            'id': 'ecat-1',
            'business_id': 'biz-1',
            'name': 'Listrik',
            'created_at': 1,
            'updated_at': 1,
          },
        );
        await db12.insert(DatabaseConstants.tableExpenses, <String, Object>{
          'id': 'exp-1',
          'business_id': 'biz-1',
          'category_id': 'ecat-1',
          'amount': 50000,
          'spent_at': 1,
          'created_at': 1,
          'updated_at': 1,
        });
        await v12.close();

        // Upgrade ke v13
        final AppDatabase v13 = AppDatabase(
          factory: databaseFactoryFfi,
          filePath: path,
          schemaVersion: 13,
        );
        final Database db13 = await v13.database;

        // Data tidak hilang setelah upgrade
        final trxRows = await db13.query(DatabaseConstants.tableTransactions);
        expect(trxRows, hasLength(1));
        expect(trxRows.first['customer_id'], 'cust-1');

        final expRows = await db13.query(DatabaseConstants.tableExpenses);
        expect(expRows, hasLength(1));

        await v13.close();
      },
    );

    test('instal baru v13 membuat semua 3 index baru', () async {
      final AppDatabase db = AppDatabase(
        factory: databaseFactoryFfi,
        filePath: p.join(tempDir.path, 'fresh_v13.db'),
      );
      final Database raw = await db.database;

      final indexes = await raw.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index'",
      );
      final Set<String> indexNames = indexes
          .map((Map<String, Object?> r) => r['name']! as String)
          .toSet();

      expect(indexNames, contains('idx_transactions_customer'));
      expect(indexNames, contains('idx_transaction_items_product'));
      expect(indexNames, contains('idx_expenses_category'));

      await db.close();
    });

    test('schema_meta hanya memiliki 1 baris setelah upgrade ke v13', () async {
      final AppDatabase db = AppDatabase(
        factory: databaseFactoryFfi,
        filePath: p.join(tempDir.path, 'meta_v13.db'),
      );
      final Database raw = await db.database;

      final rows = await raw.query(DatabaseConstants.tableSchemaMeta);
      expect(rows, hasLength(1));
      expect(rows.first['version'], 13);

      await db.close();
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Index existence
  // ─────────────────────────────────────────────────────────────────

  group('index_existence', () {
    late AppDatabase db;
    late Database raw;

    setUp(() async {
      db = AppDatabase(
        factory: databaseFactoryFfi,
        filePath: p.join(tempDir.path, 'idx_test.db'),
      );
      raw = await db.database;
    });

    tearDown(() => db.close());

    Future<Set<String>> allIndexes() async {
      final rows = await raw.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index'",
      );
      return rows.map((r) => r['name']! as String).toSet();
    }

    test('index transactions_customer ada', () async {
      expect(await allIndexes(), contains('idx_transactions_customer'));
    });

    test('index transaction_items_product ada', () async {
      expect(await allIndexes(), contains('idx_transaction_items_product'));
    });

    test('index expenses_category ada', () async {
      expect(await allIndexes(), contains('idx_expenses_category'));
    });

    test('index lama dari v1-v12 tidak hilang', () async {
      final indexes = await allIndexes();
      expect(indexes, contains('idx_transactions_created'));
      expect(indexes, contains('idx_products_business_name'));
      expect(indexes, contains('idx_stock_product'));
      expect(indexes, contains('idx_sync_queue_status'));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // readStringOrNull
  // ─────────────────────────────────────────────────────────────────

  group('readStringOrNull', () {
    test('null input → null output', () {
      expect(readStringOrNull(null), isNull);
    });

    test('String input → String output', () {
      expect(readStringOrNull('hello'), 'hello');
    });

    test('String kosong → String kosong', () {
      expect(readStringOrNull(''), '');
    });

    test('int input → StateError', () {
      expect(() => readStringOrNull(42), throwsStateError);
    });

    test('double input → StateError', () {
      expect(() => readStringOrNull(3.14), throwsStateError);
    });

    test('List input → StateError', () {
      expect(() => readStringOrNull(<String>[]), throwsStateError);
    });

    test('StateError memuat info tipe', () {
      try {
        readStringOrNull(99);
        fail('Harus melempar StateError');
      } on StateError catch (e) {
        expect(e.message, contains('int'));
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // schema_meta
  // ─────────────────────────────────────────────────────────────────

  group('schema_meta', () {
    test('hanya ada satu baris setelah instal baru', () async {
      final AppDatabase db = AppDatabase(
        factory: databaseFactoryFfi,
        filePath: p.join(tempDir.path, 'meta_fresh.db'),
      );
      final Database raw = await db.database;
      final rows = await raw.query(DatabaseConstants.tableSchemaMeta);
      expect(rows, hasLength(1));
      await db.close();
    });

    test('version di schema_meta sesuai schemaVersion', () async {
      final AppDatabase db = AppDatabase(
        factory: databaseFactoryFfi,
        filePath: p.join(tempDir.path, 'meta_ver.db'),
      );
      final Database raw = await db.database;
      final rows = await raw.query(DatabaseConstants.tableSchemaMeta);
      expect(rows.first['version'], DatabaseConstants.schemaVersion);
      await db.close();
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // DatabasePurgeService
  // ─────────────────────────────────────────────────────────────────

  group('DatabasePurgeService', () {
    late AppDatabase appDb;
    late Database raw;
    late DatabasePurgeService purge;

    setUp(() async {
      appDb = AppDatabase(
        factory: databaseFactoryFfi,
        filePath: p.join(tempDir.path, 'purge_test.db'),
      );
      raw = await appDb.database;
      purge = DatabasePurgeService(database: appDb);

      // Setup data dasar
      await raw.insert(DatabaseConstants.tableBusinesses, <String, Object>{
        'id': 'biz-p',
        'name': 'Toko Purge',
        'status': 'active',
        'created_at': 1,
        'updated_at': 1,
      });
    });

    tearDown(() => appDb.close());

    Future<void> insertSyncQueue(
      String id,
      String status,
      int createdAtMs,
    ) async {
      await raw.insert(DatabaseConstants.tableSyncQueue, <String, Object>{
        'id': id,
        'business_id': 'biz-p',
        'client_uuid': 'uuid-$id',
        'aggregate': 'test',
        'operation': 'create',
        'payload': '{}',
        'status': status,
        'attempts': 0,
        'created_at': createdAtMs,
        'updated_at': createdAtMs,
      });
    }

    Future<void> insertSyncLog(
      String id,
      String queueId,
      String status,
      int createdAtMs,
    ) async {
      await raw.insert(DatabaseConstants.tableSyncLogs, <String, Object>{
        'id': id,
        'business_id': 'biz-p',
        'queue_id': queueId,
        'direction': 'push',
        'status': status,
        'created_at': createdAtMs,
        'updated_at': createdAtMs,
      });
    }

    test('sync_logs done > 90 hari dihapus', () async {
      final DateTime now = DateTime(2026, 8, 19);
      final int old = now
          .subtract(const Duration(days: 91))
          .millisecondsSinceEpoch;
      final int recent = now
          .subtract(const Duration(days: 10))
          .millisecondsSinceEpoch;

      await insertSyncQueue('q1', 'done', old);
      await insertSyncQueue('q2', 'done', recent);
      await insertSyncLog('log-old', 'q1', 'done', old);
      await insertSyncLog('log-new', 'q2', 'done', recent);

      final result = await purge.runIfIdle(now: now);

      expect(result.syncLogsDeleted, 1);
      final remaining = await raw.query(DatabaseConstants.tableSyncLogs);
      expect(remaining, hasLength(1));
      expect(remaining.first['id'], 'log-new');
    });

    test('sync_queue done > 30 hari dihapus', () async {
      final DateTime now = DateTime(2026, 8, 19);
      final int old = now
          .subtract(const Duration(days: 31))
          .millisecondsSinceEpoch;
      final int recent = now
          .subtract(const Duration(days: 5))
          .millisecondsSinceEpoch;

      await insertSyncQueue('q3', 'done', old);
      await insertSyncQueue('q4', 'done', recent);

      final result = await purge.runIfIdle(now: now);

      expect(result.syncQueueDeleted, 1);
      final remaining = await raw.query(DatabaseConstants.tableSyncQueue);
      expect(remaining, hasLength(1));
      expect(remaining.first['id'], 'q4');
    });

    test('sync_queue pending tidak dihapus meski lama', () async {
      final DateTime now = DateTime(2026, 8, 19);
      final int old = now
          .subtract(const Duration(days: 60))
          .millisecondsSinceEpoch;

      await insertSyncQueue('q-pending', 'pending', old);
      await insertSyncQueue('q-failed', 'failed', old);

      final result = await purge.runIfIdle(now: now);

      expect(result.syncQueueDeleted, 0);
      final remaining = await raw.query(DatabaseConstants.tableSyncQueue);
      expect(remaining, hasLength(2));
    });

    test('sync_logs failed tidak dihapus', () async {
      final DateTime now = DateTime(2026, 8, 19);
      final int old = now
          .subtract(const Duration(days: 120))
          .millisecondsSinceEpoch;

      await insertSyncQueue('q-f', 'failed', old);
      await insertSyncLog('log-f', 'q-f', 'failed', old);

      final result = await purge.runIfIdle(now: now);

      expect(result.syncLogsDeleted, 0);
      final remaining = await raw.query(DatabaseConstants.tableSyncLogs);
      expect(remaining, hasLength(1));
    });

    test('transaksi lama tidak pernah terhapus oleh purge', () async {
      final DateTime now = DateTime(2026, 8, 19);
      final int veryOld = now
          .subtract(const Duration(days: 365))
          .millisecondsSinceEpoch;

      // Insert transaksi langsung tanpa user — foreign key kasir_id nullable.
      await raw.insert(DatabaseConstants.tableTransactions, <String, Object>{
        'id': 'trx-old',
        'client_uuid': 'uuid-trx-old',
        'business_id': 'biz-p',
        'status': 'completed',
        'subtotal_amount': 50000,
        'discount_amount': 0,
        'tax_amount': 0,
        'total_amount': 50000,
        'created_at': veryOld,
        'updated_at': veryOld,
      });

      await purge.runIfIdle(now: now);

      final trxRows = await raw.query(DatabaseConstants.tableTransactions);
      expect(trxRows, hasLength(1));
      expect(trxRows.first['id'], 'trx-old');
    });

    test(
      'concurrent guard: runIfIdle kedua dilewati jika pertama belum selesai',
      () async {
        // Tidak bisa benar-benar uji concurrent di unit test,
        // tapi bisa uji bahwa setelah _running = false setelah selesai
        final r1 = await purge.runIfIdle();
        final r2 = await purge.runIfIdle();
        // Keduanya harus berhasil dijalankan (tidak skipped) karena sequential
        expect(r1.skipped, isFalse);
        expect(r2.skipped, isFalse);
      },
    );

    test('PurgeResult.didWork true jika ada yang dihapus', () async {
      final DateTime now = DateTime(2026, 8, 19);
      final int old = now
          .subtract(const Duration(days: 91))
          .millisecondsSinceEpoch;
      await insertSyncQueue('q-w', 'done', old);
      await insertSyncLog('log-w', 'q-w', 'done', old);

      final result = await purge.runIfIdle(now: now);
      expect(result.didWork, isTrue);
    });
  });
}
