import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:kasir_dapur/features/backup/domain/backup_models.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:uuid/uuid.dart';

final class SqliteBackupLogRepository {
  SqliteBackupLogRepository({
    required AppDatabase database,
    required ClockService clock,
    Uuid? uuid,
  }) : _database = database,
       _clock = clock,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final ClockService _clock;
  final Uuid _uuid;

  Future<BackupLog> write({
    required String businessId,
    String? remoteId,
    required String direction,
    required String status,
    String? message,
    String? tablesJson,
  }) async {
    final String id = _uuid.v4();
    final int now = _clock.nowEpochMs();
    await (await _database.database).insert(
      DatabaseConstants.tableBackupLogs,
      <String, Object?>{
        'id': id,
        'business_id': businessId,
        'remote_id': remoteId,
        'direction': direction,
        'status': status,
        'message': message,
        'tables_json': tablesJson,
        'created_at': now,
        'updated_at': now,
      },
    );
    return BackupLog(
      id: id,
      businessId: businessId,
      remoteId: remoteId,
      direction: direction,
      status: status,
      message: message,
      tablesJson: tablesJson,
      createdAt: now,
    );
  }

  Future<List<BackupLog>> recent({
    required String businessId,
    int limit = 20,
  }) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableBackupLogs,
      where: 'business_id = ?',
      whereArgs: <Object>[businessId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows
        .map(
          (Map<String, Object?> row) => BackupLog(
            id: readString(row['id'], field: 'id'),
            businessId: readString(row['business_id'], field: 'business_id'),
            remoteId: readStringOrNull(row['remote_id']),
            direction: readString(row['direction'], field: 'direction'),
            status: readString(row['status'], field: 'status'),
            message: readStringOrNull(row['message']),
            tablesJson: readStringOrNull(row['tables_json']),
            createdAt: readInt(row['created_at'], field: 'created_at'),
          ),
        )
        .toList();
  }
}
