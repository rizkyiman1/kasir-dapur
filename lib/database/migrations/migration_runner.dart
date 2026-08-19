import 'package:kasir_dapur/database/migrations/migration_v1.dart';
import 'package:kasir_dapur/database/migrations/migration_v10.dart';
import 'package:kasir_dapur/database/migrations/migration_v11.dart';
import 'package:kasir_dapur/database/migrations/migration_v12.dart';
import 'package:kasir_dapur/database/migrations/migration_v13.dart';
import 'package:kasir_dapur/database/migrations/migration_v2.dart';
import 'package:kasir_dapur/database/migrations/migration_v3.dart';
import 'package:kasir_dapur/database/migrations/migration_v4.dart';
import 'package:kasir_dapur/database/migrations/migration_v5.dart';
import 'package:kasir_dapur/database/migrations/migration_v6.dart';
import 'package:kasir_dapur/database/migrations/migration_v7.dart';
import 'package:kasir_dapur/database/migrations/migration_v8.dart';
import 'package:kasir_dapur/database/migrations/migration_v9.dart';
import 'package:sqflite/sqflite.dart';

typedef MigrationApply = Future<void> Function(DatabaseExecutor db);

/// Menjalankan migrasi berurutan. Dilarang DROP TABLE / DROP DATABASE.
abstract final class MigrationRunner {
  static const List<MigrationApply> _migrations = [
    MigrationV1.apply,
    MigrationV2.apply,
    MigrationV3.apply,
    MigrationV4.apply,
    MigrationV5.apply,
    MigrationV6.apply,
    MigrationV7.apply,
    MigrationV8.apply,
    MigrationV9.apply,
    MigrationV10.apply,
    MigrationV11.apply,
    MigrationV12.apply,
    MigrationV13.apply,
  ];

  static int get currentVersion => _migrations.length;

  static Future<void> applyRange(
    DatabaseExecutor db, {
    required int oldVersion,
    required int newVersion,
  }) async {
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      await _migrations[version - 1](db);
    }
  }
}
