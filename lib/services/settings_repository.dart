import 'package:kasir_dapur/core/constants/app_constants.dart';
import 'package:kasir_dapur/core/logging/app_logger.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/services/clock_service.dart';

abstract class SettingsRepository {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

final class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository({required this._database, required this._clock});

  final AppDatabase _database;
  final ClockService _clock;

  @override
  Future<String?> read(String key) async {
    try {
      final db = await _database.database;
      final rows = await db.query(
        DatabaseConstants.tableAppSettings,
        columns: <String>['value'],
        where: 'key = ?',
        whereArgs: <Object>[key],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      final Object? raw = rows.first['value'];
      // Pastikan nilai memang String — jika tidak, kembalikan null dengan aman.
      return raw is String ? raw : null;
    } catch (error, stack) {
      AppLogger.instance.error(
        'settings_repository: gagal membaca key=$key',
        error: error,
        stackTrace: stack,
      );
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      final db = await _database.database;
      final int now = _clock.nowEpochMs();
      await db.execute(
        '''
INSERT INTO ${DatabaseConstants.tableAppSettings} (key, value, created_at, updated_at)
VALUES (?, ?, ?, ?)
ON CONFLICT(key) DO UPDATE SET
  value = excluded.value,
  updated_at = excluded.updated_at
''',
        <Object>[key, value, now, now],
      );
    } catch (error, stack) {
      AppLogger.instance.error(
        'settings_repository: gagal menulis key=$key',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}

enum AppThemePreference {
  system,
  light,
  dark;

  static AppThemePreference fromStorage(String? value) {
    return switch (value) {
      'light' => AppThemePreference.light,
      'dark' => AppThemePreference.dark,
      _ => AppThemePreference.system,
    };
  }

  String get storageValue => name;
}

extension SettingsThemeX on SettingsRepository {
  Future<AppThemePreference> readTheme() async {
    return AppThemePreference.fromStorage(
      await read(AppConstants.settingsKeyThemeMode),
    );
  }

  Future<void> writeTheme(AppThemePreference preference) {
    return write(AppConstants.settingsKeyThemeMode, preference.storageValue);
  }
}
