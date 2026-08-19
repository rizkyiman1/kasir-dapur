import 'dart:io';

import 'package:kasir_dapur_backend/billing/billing_database.dart';
import 'package:test/test.dart';

void main() {
  test('inisialisasi database billing membuat tabel inti', () {
    final String path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-db-init-${DateTime.now().microsecondsSinceEpoch}.db';
    final BillingDatabase db = BillingDatabase.open(path);
    final rows = db.raw.select('''
      SELECT name FROM sqlite_master
      WHERE type='table'
      ORDER BY name;
      ''');
    final names = rows.map((row) => row['name'] as String).toSet();
    expect(names.contains('payments'), isTrue);
    expect(names.contains('subscriptions'), isTrue);
    expect(names.contains('entitlements'), isTrue);
    expect(names.contains('webhook_events'), isTrue);
    expect(names.contains('billing_audit_events'), isTrue);
    db.close();
  });
}
