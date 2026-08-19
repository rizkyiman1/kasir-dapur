import 'package:kasir_dapur/database/database_constants.dart';
import 'package:sqflite/sqflite.dart';

/// Kolom billing SKU, masa tenggang, dan riwayat pembayaran (aditif).
abstract final class MigrationV8 {
  static Future<void> apply(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tableSubscriptions} '
      "ADD COLUMN plan_code TEXT NOT NULL DEFAULT 'FREE'",
    );
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tableSubscriptions} '
      'ADD COLUMN grace_ends_at INTEGER',
    );
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tableSubscriptions} '
      "ADD COLUMN provider TEXT NOT NULL DEFAULT 'local'",
    );
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tableSubscriptions} '
      'ADD COLUMN provider_order_id TEXT',
    );
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tableSubscriptions} '
      'ADD COLUMN verified_at INTEGER',
    );
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tableSubscriptions} '
      'ADD COLUMN last_synced_at INTEGER',
    );
    await db.execute('''
UPDATE ${DatabaseConstants.tableSubscriptions}
SET plan_code = CASE plan
  WHEN 'pro' THEN 'PRO_MONTHLY'
  WHEN 'business' THEN 'BUSINESS_MONTHLY'
  ELSE 'FREE'
END
''');

    await db.execute('''
CREATE TABLE ${DatabaseConstants.tableSubscriptionPayments} (
  id TEXT PRIMARY KEY NOT NULL,
  business_id TEXT NOT NULL,
  subscription_id TEXT,
  plan_code TEXT NOT NULL,
  amount INTEGER NOT NULL,
  currency TEXT NOT NULL,
  status TEXT NOT NULL,
  provider TEXT NOT NULL,
  client_uuid TEXT NOT NULL,
  provider_order_id TEXT,
  snap_token TEXT,
  snap_redirect_url TEXT,
  verified_at INTEGER,
  failure_reason TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (business_id) REFERENCES ${DatabaseConstants.tableBusinesses}(id),
  FOREIGN KEY (subscription_id) REFERENCES ${DatabaseConstants.tableSubscriptions}(id),
  UNIQUE (client_uuid)
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subscription_payments_business '
      'ON ${DatabaseConstants.tableSubscriptionPayments} (business_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subscriptions_business_status '
      'ON ${DatabaseConstants.tableSubscriptions} (business_id, status, created_at)',
    );

    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(DatabaseConstants.tableSchemaMigrations, <String, Object>{
      'version': 8,
      'applied_at': now,
    });
    await db.update(DatabaseConstants.tableSchemaMeta, <String, Object>{
      'version': 8,
      'applied_at': now,
    });
  }
}
