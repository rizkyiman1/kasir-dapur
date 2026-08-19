import 'dart:async';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

final class BillingDatabase {
  BillingDatabase._(this._db);

  static const int schemaVersion = 1;
  final Database _db;
  Future<void> _txQueue = Future<void>.value();

  Database get raw => _db;

  static BillingDatabase open(String path) {
    final File file = File(path);
    file.parent.createSync(recursive: true);
    final Database db = sqlite3.open(path);
    _configure(db);
    _migrate(db);
    return BillingDatabase._(db);
  }

  void close() {
    _db.dispose();
  }

  T transaction<T>(T Function(Database db) action) {
    _db.execute('BEGIN IMMEDIATE TRANSACTION;');
    try {
      final T result = action(_db);
      _db.execute('COMMIT;');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  Future<T> transactionAsync<T>(
    FutureOr<T> Function(Database db) action,
  ) async {
    final Completer<T> completer = Completer<T>();
    _txQueue = _txQueue.then((_) async {
      try {
        _db.execute('BEGIN IMMEDIATE TRANSACTION;');
        final T result = await action(_db);
        _db.execute('COMMIT;');
        completer.complete(result);
      } catch (e, s) {
        try {
          _db.execute('ROLLBACK;');
        } catch (_) {
          // BEGIN bisa gagal (mis. SQLITE_BUSY), abaikan rollback secondary error.
        }
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  static void _configure(Database db) {
    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA synchronous = NORMAL;');
    db.execute('PRAGMA temp_store = MEMORY;');
    db.execute('PRAGMA busy_timeout = 5000;');
  }

  static void _migrate(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS schema_meta (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        schema_version INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    final ResultSet rs = db.select(
      'SELECT schema_version FROM schema_meta WHERE id = 1 LIMIT 1;',
    );
    final int current = rs.isEmpty ? 0 : (rs.first['schema_version'] as int);
    if (current >= schemaVersion) {
      return;
    }
    if (current < 1) {
      _createV1(db);
    }
    final int now = DateTime.now().millisecondsSinceEpoch;
    db.execute(
      '''
      INSERT INTO schema_meta (id, schema_version, updated_at)
      VALUES (1, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        schema_version = excluded.schema_version,
        updated_at = excluded.updated_at;
      ''',
      <Object?>[schemaVersion, now],
    );
  }

  static void _createV1(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL UNIQUE,
        business_id TEXT NOT NULL,
        client_uuid TEXT NOT NULL UNIQUE,
        plan_code TEXT NOT NULL,
        amount INTEGER NOT NULL,
        currency TEXT NOT NULL,
        provider TEXT NOT NULL,
        provider_transaction_id TEXT,
        state TEXT NOT NULL,
        midtrans_status TEXT NOT NULL,
        snap_token TEXT,
        snap_redirect_url TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        verified_at INTEGER,
        failure_reason TEXT
      );
    ''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_business_created ON payments (business_id, created_at);',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_state ON payments (state, updated_at);',
    );

    db.execute('''
      CREATE TABLE IF NOT EXISTS subscriptions (
        id TEXT PRIMARY KEY,
        subscription_id TEXT NOT NULL UNIQUE,
        business_id TEXT NOT NULL,
        plan_code TEXT NOT NULL,
        status TEXT NOT NULL,
        starts_at INTEGER NOT NULL,
        ends_at INTEGER,
        grace_ends_at INTEGER,
        order_id TEXT,
        verified_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subscriptions_business_updated ON subscriptions (business_id, updated_at DESC);',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions (status, ends_at);',
    );

    db.execute('''
      CREATE TABLE IF NOT EXISTS entitlements (
        id TEXT PRIMARY KEY,
        business_id TEXT NOT NULL,
        feature_key TEXT NOT NULL,
        plan_code TEXT NOT NULL,
        is_enabled INTEGER NOT NULL,
        limit_value INTEGER NOT NULL,
        effective_until INTEGER,
        order_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE (business_id, feature_key)
      );
    ''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_entitlements_business ON entitlements (business_id);',
    );

    db.execute('''
      CREATE TABLE IF NOT EXISTS webhook_events (
        id TEXT PRIMARY KEY,
        fingerprint TEXT NOT NULL UNIQUE,
        order_id TEXT NOT NULL,
        processed_at INTEGER NOT NULL,
        result_status TEXT NOT NULL,
        provider_status TEXT,
        created_at INTEGER NOT NULL
      );
    ''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_webhook_events_order ON webhook_events (order_id, processed_at);',
    );

    db.execute('''
      CREATE TABLE IF NOT EXISTS billing_audit_events (
        id TEXT PRIMARY KEY,
        event_type TEXT NOT NULL,
        business_id TEXT,
        order_id TEXT,
        detail TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
    ''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_billing_audit_created ON billing_audit_events (created_at DESC);',
    );
  }
}
