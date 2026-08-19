import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/logging/app_logger.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/migrations/migration_runner.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide DatabaseException;

/// SQLite lokal utama. Migrasi bersifat aditif dan tidak mereset data.
final class AppDatabase {
  AppDatabase({DatabaseFactory? factory, this._filePath, int? schemaVersion})
    : _factory = factory ?? databaseFactory,
      _schemaVersion = schemaVersion ?? DatabaseConstants.schemaVersion;

  final DatabaseFactory _factory;
  final String? _filePath;
  final int _schemaVersion;
  Database? _database;

  int get schemaVersion => _schemaVersion;

  Future<Database> get database async {
    final Database? existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    _database = await _open();
    return _database!;
  }

  Future<T> runInTransaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    final Database db = await database;
    return db.transaction<T>(action, exclusive: true);
  }

  Future<Database> _open() async {
    try {
      final String path =
          _filePath ??
          p.join(await _factory.getDatabasesPath(), DatabaseConstants.fileName);
      AppLogger.instance.info('Membuka SQLite di path lokal');
      return await _factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: _schemaVersion,
          onConfigure: (Database db) async {
            await db.execute('PRAGMA foreign_keys = ON');
            await db.rawQuery('PRAGMA busy_timeout = 8000');
          },
          onCreate: (Database db, int version) async {
            await MigrationRunner.applyRange(
              db,
              oldVersion: 0,
              newVersion: version,
            );
          },
          onUpgrade: (Database db, int oldVersion, int newVersion) async {
            AppLogger.instance.info(
              'Migrasi database $oldVersion -> $newVersion (aditif, tanpa reset)',
            );
            await MigrationRunner.applyRange(
              db,
              oldVersion: oldVersion,
              newVersion: newVersion,
            );
          },
          onDowngrade: (Database db, int oldVersion, int newVersion) async {
            throw const DatabaseException(
              'Downgrade database tidak didukung agar data tidak terhapus.',
            );
          },
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.instance.error(
        'Gagal membuka database',
        error: error,
        stackTrace: stackTrace,
      );
      throw const DatabaseException(
        'Database lokal gagal dibuka. Aplikasi tidak dapat berjalan.',
      );
    }
  }

  Future<void> close() async {
    final Database? existing = _database;
    if (existing != null && existing.isOpen) {
      await existing.close();
    }
    _database = null;
  }
}
